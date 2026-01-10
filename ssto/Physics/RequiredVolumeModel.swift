//
//  RequiredVolumeModel.swift
//  ssto
//
//  DEPRECATED: Use FuelEstimator.calculateRequiredVolume() instead
//  This file is kept for backward compatibility only
//  FuelEstimator provides the same functionality with actual PropulsionManager data
//

import Foundation

/// DEPRECATED: Use FuelEstimator instead
/// FuelEstimator.calculateRequiredVolume() provides the same functionality with accurate PropulsionManager data
@available(*, deprecated, message: "Use FuelEstimator.calculateRequiredVolume() instead")
struct RequiredVolumeModel {

    // MARK: - Fixed Volume Requirements

    /// Payload box volume (3m × 3m × 20m)
    static let payloadVolume = 3.0 * 3.0 * 20.0 // 180 m³

    /// Pilot box volume (3m × 3m × 5m)
    static let pilotVolume = 3.0 * 3.0 * 5.0 // 45 m³

    // MARK: - Fuel Densities

    /// Slush hydrogen density for air-breathing engines (kg/m³)
    static let slushHydrogenDensity = 86.0 // kg/m³ (80 kg/L = 80,000 kg/m³ is wrong, should be 80 kg/m³)

    /// Liquid hydrogen density for rocket fuel (kg/m³)
    static let liquidHydrogenDensity = 70.0 // kg/m³

    /// Liquid oxygen (LOX) density for rocket oxidizer (kg/m³)
    static let liquidOxygenDensity = 1141.0 // kg/m³

    // MARK: - Rocket Propellant Ratios

    /// Oxygen-to-fuel mass ratio for hydrogen/oxygen rockets
    /// H2 + O2 -> H2O requires 8 kg of O2 per 1 kg of H2
    static let oxygenToHydrogenMassRatio = 8.0

    // MARK: - Engine Volume

    /// Engine density (average for jet engines, rockets, etc.)
    /// Typical jet engine density: ~2500 kg/m³ (compact metal construction)
    static let engineDensity = 2500.0 // kg/m³

    // MARK: - Volume Calculation

    /// Calculate total required volume for a flight plan
    /// DEPRECATED: Use FuelEstimator.calculateRequiredVolume() instead
    /// - Parameters:
    ///   - flightPlan: Flight plan with waypoints
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Required internal volume in m³
    @available(*, deprecated, message: "Use FuelEstimator.calculateRequiredVolume() instead")
    static func calculateRequiredVolume(
        flightPlan: FlightPlan,
        planeDesign: PlaneDesign
    ) -> Double {

        // Fixed volumes
        let fixedVolume = payloadVolume + pilotVolume

        // Calculate fuel requirements for the mission
        let fuelRequirements = estimateFuelRequirements(
            flightPlan: flightPlan,
            planeDesign: planeDesign
        )

        // Air-breathing fuel volume (hydrogen for jet/ramjet/scramjet)
        let airBreathingFuelVolume = fuelRequirements.airBreathingFuel / slushHydrogenDensity

        // Rocket fuel volume (liquid hydrogen)
        let rocketFuelVolume = fuelRequirements.rocketFuel / liquidHydrogenDensity

        // Rocket oxidizer volume (liquid oxygen)
        let rocketOxidizerVolume = fuelRequirements.rocketOxidizer / liquidOxygenDensity

        // Calculate engine volume
        // Use initial volume estimate for engine weight calculation
        let volumeGuessForEngines = 1000.0 // m³ (initial guess)
        let estimatedMassForEngines = volumeGuessForEngines * 50.0 // ~50 kg/m³ structural weight
        let engineWeight = EngineWeightModel.calculateTotalEngineWeight(
            waypoints: flightPlan.waypoints,
            estimatedMass: estimatedMassForEngines,
            planeDesign: planeDesign
        )
        let engineVolume = engineWeight / engineDensity

        // Total volume
        let totalVolume = fixedVolume + airBreathingFuelVolume + rocketFuelVolume + rocketOxidizerVolume + engineVolume

        print("\n=== Required Volume Breakdown ===")
        print("Payload:              \(String(format: "%6.1f", payloadVolume)) m³")
        print("Pilot:                \(String(format: "%6.1f", pilotVolume)) m³")
        print("Air-breathing fuel:   \(String(format: "%6.1f", airBreathingFuelVolume)) m³ (\(String(format: "%.0f", fuelRequirements.airBreathingFuel)) kg)")
        print("Rocket fuel (LH2):    \(String(format: "%6.1f", rocketFuelVolume)) m³ (\(String(format: "%.0f", fuelRequirements.rocketFuel)) kg)")
        print("Rocket oxidizer (LOX):\(String(format: "%6.1f", rocketOxidizerVolume)) m³ (\(String(format: "%.0f", fuelRequirements.rocketOxidizer)) kg)")
        print("Engines:              \(String(format: "%6.1f", engineVolume)) m³ (\(String(format: "%.0f", engineWeight)) kg)")
        print("--------------------------------")
        print("TOTAL REQUIRED:       \(String(format: "%6.1f", totalVolume)) m³")
        print("=================================\n")

        return totalVolume
    }

    /// Estimate fuel requirements for a flight plan
    /// - Parameters:
    ///   - flightPlan: Flight plan with waypoints
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Fuel requirements breakdown
    private static func estimateFuelRequirements(
        flightPlan: FlightPlan,
        planeDesign: PlaneDesign
    ) -> (airBreathingFuel: Double, rocketFuel: Double, rocketOxidizer: Double) {

        var airBreathingFuel = 0.0
        var rocketFuel = 0.0

        // Estimate dry mass for thrust calculation (use a reasonable guess)
        let volumeGuess = 1000.0 // m³
        let dryMassGuess = PhysicsConstants.calculateDryMass(
            volumeM3: volumeGuess,
            waypoints: flightPlan.waypoints,
            planeDesign: planeDesign,
            maxTemperature: 800.0
        )

        var currentMass = dryMassGuess + 10000.0 // Add estimated fuel mass

        // Process each segment
        for i in 0..<(flightPlan.waypoints.count - 1) {
            let start = flightPlan.waypoints[i]
            let end = flightPlan.waypoints[i + 1]

            let engineMode = end.engineMode != .auto ? end.engineMode :
                PropulsionManager.selectEngineMode(altitude: end.altitude, speed: end.speed)

            let segmentFuel = estimateSegmentFuel(
                start: start,
                end: end,
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

        // Calculate LOX requirement for rocket fuel (8:1 mass ratio)
        let rocketOxidizer = rocketFuel * oxygenToHydrogenMassRatio

        return (airBreathingFuel, rocketFuel, rocketOxidizer)
    }

    /// Estimate fuel for a single segment
    private static func estimateSegmentFuel(
        start: Waypoint,
        end: Waypoint,
        currentMass: Double,
        planeDesign: PlaneDesign
    ) -> Double {

        let deltaAltitude = abs(end.altitude - start.altitude) * PhysicsConstants.feetToMeters
        let deltaSpeed = abs(end.speed - start.speed)
        let avgAltitude = (start.altitude + end.altitude) / 2.0 * PhysicsConstants.feetToMeters
        _ = (start.speed + end.speed) / 2.0  // avgSpeed (unused)

        // Determine engine mode
        let engineMode = end.engineMode != .auto ? end.engineMode :
            PropulsionManager.selectEngineMode(altitude: end.altitude, speed: end.speed)

        // Rough fuel estimate based on engine mode and delta-V
        let specificImpulse: Double
        switch engineMode {
        case .ejectorRamjet:
            specificImpulse = 3000.0 // sec
        case .ramjet:
            specificImpulse = 4000.0 // sec
        case .scramjet:
            specificImpulse = 5000.0 // sec
        case .rocket:
            specificImpulse = 450.0 // sec (hydrogen/oxygen)
        case .auto:
            specificImpulse = 3000.0
        }

        // Estimate delta-V needed
        let speedChange = deltaSpeed * PhysicsConstants.speedOfSoundSeaLevel
        let altitudeChange = deltaAltitude
        let gravity = PhysicsConstants.gravity(at: avgAltitude)
        let potentialEnergyChange = gravity * altitudeChange

        // Total energy change (simplified)
        let deltaV = sqrt(speedChange * speedChange + 2 * potentialEnergyChange)

        // Rocket equation: m_fuel = m_total * (1 - exp(-deltaV / (Isp * g0)))
        let exhaustVelocity = specificImpulse * 9.81
        let massRatio = 1.0 - exp(-deltaV / exhaustVelocity)
        let fuelMass = currentMass * massRatio * 1.5 // Add 50% margin for drag losses

        return max(0.0, fuelMass)
    }
}
