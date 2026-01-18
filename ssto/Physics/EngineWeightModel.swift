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

    /// Calculate structural weight using hybrid model:
    /// - Volume scaling (2/3 power law) for base structure
    /// - Aerodynamic efficiency bonus/penalty
    /// - Area-based thermal reinforcement for high-heat regions
    /// - Parameter areaBreakdown: Surface area breakdown by region
    /// - Parameter volumeM3: Internal volume in cubic meters
    /// - Returns: Structural weight in kg
    static func calculateStructuralWeight(
        areaBreakdown: AircraftVolumeModel.SurfaceAreaBreakdown,
        volumeM3: Double
    ) -> Double {

        // 1. Base structural weight from volume (2/3 power law - scaling principle)
        // Larger aircraft need proportionally more structure, but benefit from size efficiency
        let baseStructural = pow(volumeM3, 2.0/3.0) * 85.0  // Calibrated constant (kg/m^(2/3))

        // 2. Calculate aerodynamic efficiency at cruise condition (Mach 6, 80k ft)
        // This provides a bonus/penalty based on aerodynamic quality
        let aeroGeometry = AerodynamicCache.getGeometry(
            planform: GameManager.shared.getTopViewPlanform(),
            profile: GameManager.shared.getSideProfile(),
            crossSection: GameManager.shared.getCrossSectionPoints()
        )
        let aeroSolver = PanelAerodynamicsSolver(geometry: aeroGeometry)

        // Reference cruise condition: Mach 6 at 80,000 ft
        let cruiseMach = 6.0
        let cruiseAltitude = 80000.0  // feet
        let atm = AtmosphereModel.getAtmosphericConditions(altitudeFeet: cruiseAltitude)
        let cruiseVelocity = cruiseMach * atm.speedOfSound

        // Assume lift = 0.5 * weight for cruise (aircraft is climbing/accelerating)
        let estimatedMass = 25000.0  // kg (rough estimate)
        let requiredLift = estimatedMass * 9.81 * 0.5

        let aeroForces = aeroSolver.solveTrimCondition(
            mach: cruiseMach,
            altitude: cruiseAltitude,
            velocity: cruiseVelocity,
            requiredLift: requiredLift
        )

        let liftToDrag = aeroForces.CL / max(0.01, aeroForces.CD)

        // Aerodynamic efficiency multiplier:
        // L/D = 8 → multiplier = 1.0 (baseline)
        // L/D > 8 → lighter structure (more efficient design allows weight savings)
        // L/D < 8 → heavier structure (inefficient design needs reinforcement)
        let referenceLoverD = 8.0
        let aeroMultiplier = 1.0 / (1.0 + max(0.0, referenceLoverD - liftToDrag) * 0.05)

        // 3. Thermal reinforcement (area-based, unavoidable for high-temp regions)
        let noseCapThermal = areaBreakdown.noseCap * 45.0       // 45 kg/m² (high thermal load)
        let leadingEdgeThermal = areaBreakdown.leadingEdges * 40.0  // 40 kg/m²
        let topSurfaceThermal = areaBreakdown.topSurface * 8.0   // 8 kg/m² (moderate)
        let bottomSurfaceThermal = areaBreakdown.bottomSurface * 12.0  // 12 kg/m² (compression)
        let engineInletThermal = areaBreakdown.engineInlet * 15.0  // 15 kg/m²

        let thermalReinforcement = noseCapThermal + leadingEdgeThermal + topSurfaceThermal +
                                   bottomSurfaceThermal + engineInletThermal

        // 4. Total structural weight
        let totalStructuralWeight = baseStructural * aeroMultiplier + thermalReinforcement

        print("\n=== Structural Weight Breakdown (New Model) ===")
        print("Base structural (volume):  \(String(format: "%6.0f", baseStructural)) kg")
        print("Aero efficiency (L/D):     \(String(format: "%6.2f", liftToDrag))")
        print("Aero multiplier:           \(String(format: "%6.3f", aeroMultiplier))")
        print("After aero bonus:          \(String(format: "%6.0f", baseStructural * aeroMultiplier)) kg")
        print("")
        print("Thermal Reinforcement:")
        print("  Nose cap:                \(String(format: "%6.0f", noseCapThermal)) kg")
        print("  Leading edges:           \(String(format: "%6.0f", leadingEdgeThermal)) kg")
        print("  Top surface:             \(String(format: "%6.0f", topSurfaceThermal)) kg")
        print("  Bottom surface:          \(String(format: "%6.0f", bottomSurfaceThermal)) kg")
        print("  Engine inlet:            \(String(format: "%6.0f", engineInletThermal)) kg")
        print("  Subtotal thermal:        \(String(format: "%6.0f", thermalReinforcement)) kg")
        print("-----------------------------------------------")
        print("Total structural:          \(String(format: "%6.0f", totalStructuralWeight)) kg")
        print("===============================================\n")

        return totalStructuralWeight
    }

    /// Calculate total dry mass including structure, engines, and cargo
    /// - Parameters:
    ///   - areaBreakdown: Surface area breakdown by region
    ///   - volumeM3: Internal volume in cubic meters (for fuel capacity estimation)
    ///   - waypoints: Flight plan waypoints
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Total dry mass in kg (structure + engines + cargo)
    static func calculateDryMass(
        areaBreakdown: AircraftVolumeModel.SurfaceAreaBreakdown,
        volumeM3: Double,
        waypoints: [Waypoint],
        planeDesign: PlaneDesign
    ) -> Double {

        // Calculate structural weight with new hybrid model
        let structuralWeight = calculateStructuralWeight(
            areaBreakdown: areaBreakdown,
            volumeM3: volumeM3
        )

        // Fixed cargo weight
        let cargoWeight = PhysicsConstants.cargoMass

        // Estimate total mass for thrust calculation (structure + cargo + 50% fuel load)
        let fuelCapacity = volumeM3 * 1000.0 * 0.086 // kg
        let estimatedMass = structuralWeight + cargoWeight + (fuelCapacity * 0.5)

        // Calculate engine weight based on thrust requirements
        let engineWeight = calculateTotalEngineWeight(
            waypoints: waypoints,
            estimatedMass: estimatedMass,
            planeDesign: planeDesign
        )

        // Total dry mass = structure + engines + cargo
        return structuralWeight + engineWeight + cargoWeight
    }
}
