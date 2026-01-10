//
//  FuelEstimator.swift
//  ssto
//
//  Fast fuel estimation using actual PropulsionManager data
//  Replaces hardcoded fuel rates in NewtonModule and RequiredVolumeModel
//

import Foundation

/// Unified fuel estimator that uses PropulsionManager for accurate predictions
class FuelEstimator {
    private let propulsionManager: PropulsionManager

    /// Result of fuel estimation for a mission
    struct FuelEstimate {
        let totalFuelKg: Double
        let timeSeconds: Double
        let segmentBreakdown: [(waypoint: Int, fuelKg: Double, time: Double)]
    }

    init(propulsionManager: PropulsionManager = PropulsionManager()) {
        self.propulsionManager = propulsionManager
    }

    /// Estimate total fuel requirements for a complete mission
    /// - Parameters:
    ///   - waypoints: Flight plan waypoints
    ///   - initialMass: Starting mass (dry + fuel) in kg
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Complete fuel estimate with breakdown
    func estimateMissionFuel(
        waypoints: [Waypoint],
        initialMass: Double,
        planeDesign: PlaneDesign
    ) -> FuelEstimate {
        var currentMass = initialMass
        var totalFuel = 0.0
        var totalTime = 0.0
        var breakdown: [(Int, Double, Double)] = []

        for i in 0..<waypoints.count-1 {
            let (fuel, time) = estimateSegment(
                from: waypoints[i],
                to: waypoints[i+1],
                currentMass: currentMass,
                planeDesign: planeDesign
            )
            totalFuel += fuel
            totalTime += time
            currentMass -= fuel
            breakdown.append((i, fuel, time))
        }

        return FuelEstimate(totalFuelKg: totalFuel, timeSeconds: totalTime, segmentBreakdown: breakdown)
    }

    /// Estimate fuel consumption for a single flight segment
    /// - Parameters:
    ///   - start: Starting waypoint
    ///   - end: Ending waypoint
    ///   - currentMass: Current aircraft mass (kg)
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Tuple of (fuel in kg, time in seconds)
    func estimateSegment(
        from start: Waypoint,
        to end: Waypoint,
        currentMass: Double,
        planeDesign: PlaneDesign
    ) -> (fuelKg: Double, time: Double) {
        // Use average conditions for fuel rate lookup
        let avgAltitude = (start.altitude + end.altitude) / 2.0
        let avgSpeed = (start.speed + end.speed) / 2.0

        // Determine engine mode (handle .auto)
        let engineMode = end.engineMode == .auto ?
            PropulsionManager.selectEngineMode(altitude: end.altitude, speed: end.speed) :
            end.engineMode

        // Special handling for rocket mode (use Tsiolkovsky equation)
        if engineMode == .rocket {
            let deltaV = RocketModule.calculateDeltaV(
                startAltitude: start.altitude,
                endAltitude: end.altitude,
                startSpeed: start.speed,
                endSpeed: end.speed
            )
            let (propellantMass, _, _, _) = RocketModule.calculatePropellantMass(
                deltaV: deltaV,
                initialMass: currentMass,
                averageAltitude: avgAltitude
            )
            // Estimate time for rocket segment
            let time = calculateSegmentTime(start: start, end: end, currentMass: currentMass, planeDesign: planeDesign)
            return (propellantMass, time)
        }

        // For air-breathing engines, use actual PropulsionManager fuel consumption
        guard let engine = propulsionManager.getEngine(for: engineMode) else {
            // Fallback to rocket if engine not available
            let time = calculateSegmentTime(start: start, end: end, currentMass: currentMass, planeDesign: planeDesign)
            return (0.0, time)
        }

        // Get REAL fuel consumption rate from PropulsionManager (L/s)
        let fuelRateLitersPerSec = engine.getFuelConsumption(altitude: avgAltitude, speed: avgSpeed)
        let fuelRateKgPerSec = fuelRateLitersPerSec * PhysicsConstants.kgPerLiter

        // Estimate time for segment
        let time = calculateSegmentTime(start: start, end: end, currentMass: currentMass, planeDesign: planeDesign)

        return (fuelRateKgPerSec * time, time)
    }

    /// Calculate estimated time for a flight segment
    /// - Parameters:
    ///   - start: Starting waypoint
    ///   - end: Ending waypoint
    ///   - currentMass: Current aircraft mass (kg)
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Estimated time in seconds
    private func calculateSegmentTime(
        start: Waypoint,
        end: Waypoint,
        currentMass: Double,
        planeDesign: PlaneDesign
    ) -> Double {
        let deltaAltitude = abs(end.altitude - start.altitude) * PhysicsConstants.feetToMeters
        let avgSpeed = (start.speed + end.speed) / 2.0

        // Convert Mach to velocity (m/s)
        let avgVelocity = avgSpeed * PhysicsConstants.speedOfSoundSeaLevel

        // Rough distance estimate (assumes ~45 degree climb angle for simplicity)
        // distance ≈ sqrt(deltaAltitude^2 + horizontal_distance^2)
        // For simplicity, assume horizontal distance ≈ avgVelocity * 60 seconds
        let horizontalEstimate = avgVelocity * 60.0
        let distance = sqrt(deltaAltitude * deltaAltitude + horizontalEstimate * horizontalEstimate)

        // Time = distance / average velocity
        let timeEstimate = distance / max(100.0, avgVelocity)

        return max(1.0, timeEstimate) // Minimum 1 second
    }

    // MARK: - Volume Calculation

    /// Calculate total required volume for a flight plan
    /// Replaces RequiredVolumeModel.calculateRequiredVolume()
    /// - Parameters:
    ///   - flightPlan: Flight plan with waypoints
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Required internal volume in m³
    func calculateRequiredVolume(
        flightPlan: FlightPlan,
        planeDesign: PlaneDesign
    ) -> Double {
        // Fixed volumes (from RequiredVolumeModel constants)
        let payloadVolume = 500.0  // 20m × 5m × 5m
        let pilotVolume = 108.0    // 6m × 6m × 3m
        let fixedVolume = payloadVolume + pilotVolume

        // Fuel densities
        let slushHydrogenDensity = 86.0    // kg/m³ (air-breathing)
        let liquidHydrogenDensity = 70.0   // kg/m³ (rocket)
        let liquidOxygenDensity = 1141.0   // kg/m³ (LOX)
        let oxygenToHydrogenRatio = 8.0    // mass ratio

        // Estimate dry mass for fuel calculation
        let volumeGuess = 1000.0  // m³ (initial guess)
        let dryMassGuess = PhysicsConstants.calculateDryMass(
            volumeM3: volumeGuess,
            waypoints: flightPlan.waypoints,
            planeDesign: planeDesign,
            maxTemperature: 800.0
        )

        // Estimate fuel using FuelEstimator (uses actual PropulsionManager!)
        var currentMass = dryMassGuess + 10000.0  // Add estimated fuel
        var airBreathingFuel = 0.0
        var rocketFuel = 0.0

        // Process each segment
        for i in 0..<(flightPlan.waypoints.count - 1) {
            let start = flightPlan.waypoints[i]
            let end = flightPlan.waypoints[i + 1]

            let engineMode = end.engineMode != .auto ? end.engineMode :
                PropulsionManager.selectEngineMode(altitude: end.altitude, speed: end.speed)

            let (segmentFuel, _) = estimateSegment(
                from: start,
                to: end,
                currentMass: currentMass,
                planeDesign: planeDesign
            )

            // Categorize fuel by engine type
            if engineMode == .rocket {
                rocketFuel += segmentFuel
            } else {
                airBreathingFuel += segmentFuel
            }

            currentMass -= segmentFuel
        }

        // Calculate volumes
        let airBreathingFuelVolume = airBreathingFuel / slushHydrogenDensity
        let rocketFuelVolume = rocketFuel / liquidHydrogenDensity
        let rocketOxidizerMass = rocketFuel * oxygenToHydrogenRatio
        let rocketOxidizerVolume = rocketOxidizerMass / liquidOxygenDensity

        // Calculate engine volume
        let volumeGuessForEngines = 1000.0  // m³
        let estimatedMassForEngines = volumeGuessForEngines * 50.0  // ~50 kg/m³
        let engineWeight = EngineWeightModel.calculateTotalEngineWeight(
            waypoints: flightPlan.waypoints,
            estimatedMass: estimatedMassForEngines,
            planeDesign: planeDesign
        )
        let engineVolume = engineWeight / 2500.0  // engine density: 2500 kg/m³

        // Total volume
        let totalVolume = fixedVolume + airBreathingFuelVolume + rocketFuelVolume + rocketOxidizerVolume + engineVolume

        return totalVolume
    }
}
