//
//  EngineWeightModel.swift
//  ssto
//
//  Calculates engine weights based on required thrust
//  Uses SR-71 data for jets and SpaceX data for rockets
//

import Foundation

struct EngineWeightModel {

    // MARK: - Reference Data

    // SR-71 Blackbird (Pratt & Whitney J58)
    // Each engine: ~151 kN thrust, ~3,400 kg weight
    // Thrust-to-weight ratio: ~4.5:1 (44.4 N/kg)
    private static let jetThrustToWeightRatio = 44.4 // N/kg

    // SpaceX Merlin 1D (used on Falcon 9)
    // ~845 kN thrust, ~470 kg weight
    // Thrust-to-weight ratio: ~180:1
    private static let rocketThrustToWeightRatio = 180.0 // N/kg

    // Ramjet/Scramjet: Fixed weight (no moving parts, simpler than turbojets)
    // Based on typical airbreathing ramjet designs
    private static let ramjetWeight = 800.0 // kg (fixed)
    private static let scramjetWeight = 1200.0 // kg (fixed, more exotic materials)

    // MARK: - Engine Weight Calculations

    /// Calculate jet engine weight based on required thrust
    /// Uses SR-71 (J58) as reference
    /// - Parameter thrustNewtons: Required thrust in Newtons
    /// - Returns: Engine weight in kg
    static func jetEngineWeight(thrustNewtons: Double) -> Double {
        return thrustNewtons / jetThrustToWeightRatio
    }

    /// Calculate rocket engine weight based on required thrust
    /// Uses SpaceX Merlin 1D as reference
    /// - Parameter thrustNewtons: Required thrust in Newtons
    /// - Returns: Engine weight in kg
    static func rocketEngineWeight(thrustNewtons: Double) -> Double {
        return thrustNewtons / rocketThrustToWeightRatio
    }

    /// Get ramjet engine weight (constant)
    /// - Returns: Engine weight in kg
    static func ramjetEngineWeight() -> Double {
        return ramjetWeight
    }

    /// Get scramjet engine weight (constant)
    /// - Returns: Engine weight in kg
    static func scramjetEngineWeight() -> Double {
        return scramjetWeight
    }

    // MARK: - Thrust Requirement Calculations

    /// Calculate required thrust for a flight segment
    /// - Parameters:
    ///   - mass: Aircraft mass in kg
    ///   - altitude: Altitude in meters
    ///   - speed: Speed in Mach
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Required thrust in Newtons
    static func calculateRequiredThrust(
        mass: Double,
        altitude: Double,
        speed: Double,
        planeDesign: PlaneDesign
    ) -> Double {
        // Convert speed to m/s
        let speedOfSound = AtmosphereModel.speedOfSound(at: altitude)
        let velocityMs = speed * speedOfSound

        // Calculate drag
        let density = AtmosphereModel.atmosphericDensity(at: altitude)
        let dragCoefficient = 0.02 * planeDesign.dragMultiplier()
        let referenceArea = 50.0 // m²
        let drag = 0.5 * density * velocityMs * velocityMs * dragCoefficient * referenceArea

        // Calculate gravity
        let gravity = PhysicsConstants.gravity(at: altitude)

        // Assume shallow climb angle - thrust must overcome drag plus some vertical component
        // For SSTO, we need thrust > drag for acceleration
        // Add safety margin of 20% for acceleration capability
        let requiredThrust = drag * 1.2 + (mass * gravity * 0.1) // 10% of weight for climb

        return max(requiredThrust, mass * gravity * 0.3) // Minimum 0.3 TWR
    }

    /// Calculate peak thrust requirements for each engine mode in a flight plan
    /// - Parameters:
    ///   - waypoints: Flight plan waypoints
    ///   - estimatedMass: Estimated aircraft mass in kg
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Tuple of (jetThrust, ramjetThrust, scramjetThrust, rocketThrust) in Newtons
    static func calculatePeakThrustRequirements(
        waypoints: [Waypoint],
        estimatedMass: Double,
        planeDesign: PlaneDesign
    ) -> (jet: Double, ramjet: Double, scramjet: Double, rocket: Double) {

        var maxJetThrust = 0.0
        var maxRamjetThrust = 0.0
        var maxScramjetThrust = 0.0
        var maxRocketThrust = 0.0

        for waypoint in waypoints {
            let altitude = waypoint.altitude * PhysicsConstants.feetToMeters
            let speed = waypoint.speed

            let thrust = calculateRequiredThrust(
                mass: estimatedMass,
                altitude: altitude,
                speed: speed,
                planeDesign: planeDesign
            )

            // Determine which engine mode and track peak thrust
            let engineMode = waypoint.engineMode == .auto ?
                PropulsionManager.selectEngineMode(altitude: waypoint.altitude, speed: speed) :
                waypoint.engineMode

            switch engineMode {
            case .ejectorRamjet:
                maxJetThrust = max(maxJetThrust, thrust)
            case .ramjet:
                maxRamjetThrust = max(maxRamjetThrust, thrust)
            case .scramjet:
                maxScramjetThrust = max(maxScramjetThrust, thrust)
            case .rocket:
                maxRocketThrust = max(maxRocketThrust, thrust)
            case .auto:
                break // Should not reach here
            }
        }

        return (maxJetThrust, maxRamjetThrust, maxScramjetThrust, maxRocketThrust)
    }

    /// Calculate total engine weight for a flight plan
    /// - Parameters:
    ///   - waypoints: Flight plan waypoints
    ///   - estimatedMass: Estimated aircraft mass in kg (for thrust calculation)
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Total engine weight in kg
    static func calculateTotalEngineWeight(
        waypoints: [Waypoint],
        estimatedMass: Double,
        planeDesign: PlaneDesign
    ) -> Double {

        let peakThrusts = calculatePeakThrustRequirements(
            waypoints: waypoints,
            estimatedMass: estimatedMass,
            planeDesign: planeDesign
        )

        var totalWeight = 0.0

        // Add jet engine weight if used
        if peakThrusts.jet > 0 {
            totalWeight += jetEngineWeight(thrustNewtons: peakThrusts.jet)
        }

        // Add ramjet weight if used (constant)
        if peakThrusts.ramjet > 0 {
            totalWeight += ramjetEngineWeight()
        }

        // Add scramjet weight if used (constant)
        if peakThrusts.scramjet > 0 {
            totalWeight += scramjetEngineWeight()
        }

        // Add rocket engine weight if used
        if peakThrusts.rocket > 0 {
            totalWeight += rocketEngineWeight(thrustNewtons: peakThrusts.rocket)
        }

        return totalWeight
    }

    // MARK: - Helper Functions

    /// Calculate structural weight (airframe without engines)
    /// Based on volume and thermal protection requirements
    /// - Parameters:
    ///   - volumeM3: Internal volume in cubic meters
    ///   - maxTemperature: Maximum temperature expected in Celsius
    /// - Returns: Structural weight in kg
    static func calculateStructuralWeight(volumeM3: Double, maxTemperature: Double) -> Double {
        // Base structural weight: ~50 kg/m³ for lightweight composite structure
        let baseWeight = volumeM3 * 50.0

        // Add thermal protection weight for high temperatures
        let thermalProtectionWeight: Double
        if maxTemperature <= 600 {
            thermalProtectionWeight = 0.0
        } else {
            // Additional thermal protection: 10 kg/m³ per 100°C over 600°C
            let tempExcess = maxTemperature - 600.0
            let protectionFactor = tempExcess / 100.0
            thermalProtectionWeight = volumeM3 * 10.0 * protectionFactor
        }

        return baseWeight + thermalProtectionWeight
    }

    /// Calculate total dry mass including structure and engines
    /// - Parameters:
    ///   - volumeM3: Internal volume in cubic meters
    ///   - maxTemperature: Maximum expected temperature in Celsius
    ///   - waypoints: Flight plan waypoints
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Total dry mass in kg
    static func calculateDryMass(
        volumeM3: Double,
        maxTemperature: Double,
        waypoints: [Waypoint],
        planeDesign: PlaneDesign
    ) -> Double {

        // Start with structural weight
        let structuralWeight = calculateStructuralWeight(volumeM3: volumeM3, maxTemperature: maxTemperature)

        // Estimate total mass for thrust calculation (structure + 50% fuel load)
        let fuelCapacity = volumeM3 * 1000.0 * 0.086 // kg
        let estimatedMass = structuralWeight + (fuelCapacity * 0.5)

        // Calculate engine weight
        let engineWeight = calculateTotalEngineWeight(
            waypoints: waypoints,
            estimatedMass: estimatedMass,
            planeDesign: planeDesign
        )

        // Total dry mass
        return structuralWeight + engineWeight
    }
}
