//
//  FlightSimulator.swift
//  ssto
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

class FlightSimulator {
    // Aircraft properties
    private var altitude: Double // meters
    private var velocity: Double // m/s
    private var fuelMass: Double // kg
    private let dryMass: Double
    private let dragCalculator: DragCalculator  // Legacy - kept for backward compatibility
    private let planeDesign: PlaneDesign

    // New aerodynamics system
    private let aeroGeometry: AerodynamicGeometry
    private let aeroSolver: PanelAerodynamicsSolver

    // Simulation parameters
    private let timeStep: Double
    private let maxSimulationTime: Double

    init(
        dryMass: Double = PhysicsConstants.dryMass,
        dragCoefficient: Double = PhysicsConstants.dragCoefficient,
        planeDesign: PlaneDesign = PlaneDesign.defaultDesign,
        timeStep: Double = 0.1,
        maxSimulationTime: Double = 1000.0
    ) {
        self.altitude = 0
        self.velocity = 0
        
        // Calculate fuel mass based on internal volume from wireframe geometry
        let internalVolumeM3 = AircraftVolumeModel.calculateInternalVolume()
        // Convert m³ to Liters (1 m³ = 1000 L) then to kg
        // Assuming tanks are 100% full for the mission
        let fuelVolumeLiters = internalVolumeM3 * 1000.0
        self.fuelMass = fuelVolumeLiters * PhysicsConstants.kgPerLiter
        
        print("FlightSimulator initialized:")
        print("  - Internal Volume: \(String(format: "%.1f", internalVolumeM3)) m³")
        print("  - Fuel Capacity: \(String(format: "%.0f", fuelVolumeLiters)) L")
        print("  - Fuel Mass: \(String(format: "%.0f", self.fuelMass)) kg")
        
        self.dryMass = dryMass
        self.planeDesign = planeDesign
        self.dragCalculator = DragCalculator(
            baselineDragCoefficient: dragCoefficient,
            planeDesign: planeDesign
        )

        // Initialize new aerodynamics system
        print("Initializing panel method aerodynamics...")
        self.aeroGeometry = AerodynamicCache.getGeometry(
            planform: GameManager.shared.getTopViewPlanform(),
            profile: GameManager.shared.getSideProfile(),
            crossSection: GameManager.shared.getCrossSectionPoints()
        )
        self.aeroSolver = PanelAerodynamicsSolver(geometry: aeroGeometry)

        print("  - Panels: \(aeroGeometry.panels.count)")
        print("  - Fineness Ratio: \(String(format: "%.2f", aeroGeometry.finenessRatio))")
        print("  - Aspect Ratio: \(String(format: "%.2f", aeroGeometry.aspectRatio))")
        print("  - Wetted Area: \(String(format: "%.1f", aeroGeometry.wettedArea)) m²")

        self.timeStep = timeStep
        self.maxSimulationTime = maxSimulationTime
    }

    /// Simulate flight between two waypoints
    func simulateSegment(
        from start: Waypoint,
        to end: Waypoint,
        propulsionManager: PropulsionManager
    ) -> FlightSegmentResult {
        // Convert to SI units
        var h = start.altitude * PhysicsConstants.feetToMeters
        var v = start.speed * PhysicsConstants.speedOfSoundSeaLevel

        let targetH = end.altitude * PhysicsConstants.feetToMeters
        let targetV = end.speed * PhysicsConstants.speedOfSoundSeaLevel

        var time = 0.0
        var fuelUsed = 0.0
        var trajectory: [TrajectoryPoint] = []

        // Set engine mode if manual
        if end.engineMode != .auto {
            propulsionManager.setManualEngine(end.engineMode)
        } else {
            propulsionManager.enableAutoMode()
        }

        // Flight Path Angle (Gamma)
        // For an SSTO, we fly a shallow ascent to build speed.
        // 5 degrees is a reasonable average for a lifting ascent.
        let flightPathAngle = 5.0 * Double.pi / 180.0
        let sinGamma = sin(flightPathAngle)
        let cosGamma = cos(flightPathAngle)

        // Initial trajectory point
        let initialFuelRemaining = fuelMass / PhysicsConstants.kgPerLiter
        let initialTemp = ThermalModel.calculateLeadingEdgeTemperature(altitude: h, velocity: v, planeDesign: planeDesign)
        trajectory.append(TrajectoryPoint(
            time: 0,
            altitude: start.altitude,
            speed: start.speed,
            fuelRemaining: initialFuelRemaining,
            engineMode: propulsionManager.currentMode,
            temperature: initialTemp
        ))

        // Simulation loop
        while time < maxSimulationTime {
            // Update engine selection if in auto mode
            let altitudeFeet = h * PhysicsConstants.metersToFeet
            let speedMach = v / PhysicsConstants.speedOfSoundSeaLevel
            propulsionManager.update(altitude: altitudeFeet, speed: speedMach)

            // Calculate forces
            var thrust = propulsionManager.getThrust(altitude: altitudeFeet, speed: speedMach)
            
            // FLIGHT PLAN INTERPOLATION / GUIDANCE
            // If we have exceeded target speed but not target altitude, throttle back to save fuel
            // This simulates managing energy rather than just burning max thrust blindly
            if v > targetV && h < targetH {
                // We are fast but low. Coast up.
                // Maintain enough thrust to overcome drag+gravity if possible, or just idle.
                thrust *= 0.1
            } else if v > targetV * 1.1 {
                 // Overspeed protection
                 thrust *= 0.0
            }

            // MAX G LIMITING FOR ROCKET MODE
            // Throttle rocket thrust to maintain G-force limit
            if propulsionManager.currentMode == .rocket {
                let gravityAccelTemp = PhysicsConstants.gravity(at: h)
                let massTemp = dryMass + fuelMass

                // Calculate current drag estimate for G calculation
                // Use zero lift for initial estimate
                let dragEstimate = dragCalculator.calculateDrag(altitude: h, velocity: v, lift: 0)

                // Calculate max allowed thrust to stay at maxG limit
                // acceleration = (thrust - drag - gravity*sin(gamma)) / mass
                // maxG * g0 = (thrust_max - drag - gravity*sin(gamma)) / mass
                // thrust_max = mass * maxG * g0 + drag + gravity*sin(gamma)*mass
                let g0 = 9.80665
                let maxAllowedAccel = end.maxG * g0
                let gravityDragTemp = massTemp * gravityAccelTemp * sinGamma
                let maxAllowedThrust = massTemp * maxAllowedAccel + dragEstimate + gravityDragTemp

                // Throttle down if current thrust exceeds limit
                if thrust > maxAllowedThrust {
                    thrust = maxAllowedThrust
                }
            }

            // MAX DYNAMIC PRESSURE LIMITING (for all engine modes)
            // Reduce thrust when dynamic pressure exceeds safe limit
            let density = AtmosphereModel.atmosphericDensity(at: h)
            let dynamicPressure = 0.5 * density * v * v

            // Max Q limits vary by engine mode (in Pascals)
            let maxDynamicPressure: Double
            switch propulsionManager.currentMode {
            case .ejectorRamjet:
                maxDynamicPressure = 50000.0 // 50 kPa - subsonic inlet limit
            case .ramjet:
                maxDynamicPressure = 75000.0 // 75 kPa - structural limit
            case .scramjet:
                maxDynamicPressure = 100000.0 // 100 kPa - high-speed structural limit
            case .rocket:
                maxDynamicPressure = 150000.0 // 150 kPa - payload bay pressure limit
            case .auto:
                maxDynamicPressure = 50000.0 // Conservative default
            }

            // Scale thrust down if Q exceeds limit
            if dynamicPressure > maxDynamicPressure {
                let scaleFactor = maxDynamicPressure / dynamicPressure
                thrust *= scaleFactor
            }

            // Calculate Lift Required (Equilibrium Glide/Climb)
            // L = W * cos(gamma) - CentrifugalForce
            // F_centrifugal = m * v^2 / r
            let gravityAccel = PhysicsConstants.gravity(at: h)
            let radius = PhysicsConstants.earthRadius + h
            let mass = dryMass + fuelMass
            let centrifugalForce = mass * v * v / radius
            let weightComp = mass * gravityAccel * cosGamma

            // We need enough lift to stay on the path.
            // If centrifugal force > weight component, we are effectively orbiting (negative lift needed to stay down, or just float)
            // For drag calculations, we take magnitude of lift, but effectively if we are orbital, lift drag is zero.
            let liftRequired = max(0.0, weightComp - centrifugalForce)

            // NEW: Use panel method aerodynamic solver
            let aeroForces = aeroSolver.solveTrimCondition(
                mach: speedMach,
                altitude: altitudeFeet,
                velocity: v,
                requiredLift: liftRequired
            )
            let drag = aeroForces.drag

            // Calculate Reynolds number for diagnostics
            let atm = AtmosphereModel.getAtmosphericConditions(altitudeFeet: altitudeFeet)
            let Re = atm.density * v * aeroGeometry.aircraftLength / atm.viscosity
            
            // Net acceleration along the flight path
            // F_net = Thrust - Drag - Weight * sin(gamma)
            let gravityDrag = mass * gravityAccel * sinGamma
            let acceleration = (thrust - drag - gravityDrag) / mass

            // Update velocity and altitude
            v += acceleration * timeStep
            h += v * sinGamma * timeStep

            // Prevent going underground
            if h < 0 {
                h = 0
                v = max(0, v) // Can't go down if on ground
            }

            // Update fuel
            let fuelRate = propulsionManager.getFuelConsumption(altitude: altitudeFeet, speed: speedMach)
            let fuelBurnedLiters = fuelRate * timeStep
            let fuelBurnedKg = fuelBurnedLiters * PhysicsConstants.kgPerLiter
            fuelMass -= fuelBurnedKg
            fuelUsed += fuelBurnedLiters

            time += timeStep

            // Calculate temperature for thermal monitoring
            let currentTemp = ThermalModel.calculateLeadingEdgeTemperature(altitude: h, velocity: v, planeDesign: planeDesign)

            // Check thermal limits
            let maxTemp = ThermalModel.getMaxTemperature(for: planeDesign)
            if currentTemp > maxTemp {
                // Thermal failure logic can be handled here or by the caller analyzing the trajectory
            }

            // Record trajectory point every 10 steps (1 second) to reduce data
            if Int(time * 10) % 10 == 0 {
                var point = TrajectoryPoint(
                    time: time,
                    altitude: h * PhysicsConstants.metersToFeet,
                    speed: v / PhysicsConstants.speedOfSoundSeaLevel,
                    fuelRemaining: max(0, fuelMass / PhysicsConstants.kgPerLiter),
                    engineMode: propulsionManager.currentMode,
                    temperature: currentTemp
                )
                // Add aerodynamic diagnostics
                point.liftCoefficient = aeroForces.CL
                point.dragCoefficient = aeroForces.CD
                point.angleOfAttack = aeroForces.angleOfAttack
                point.reynoldsNumber = Re
                point.dragBreakdown = aeroForces.breakdown

                trajectory.append(point)
            }

            // Check termination conditions
            if fuelMass <= 0 {
                print("Simulation ended: Out of fuel")
                break
            }

            // Check if we've reached the target (within tolerance)
            let altitudeDiff = abs(h - targetH)
            let velocityDiff = abs(v - targetV)

            if altitudeDiff < 1000 && velocityDiff < 50 {
                // Close enough to target
                break
            }
            
            // Simple timeout for "stuck" simulations
            if time > 600 && v < 100 {
                 break
            }
        }

        // Update simulator state for next segment
        self.altitude = h
        self.velocity = v

        // Create final trajectory point
        let finalTemp = ThermalModel.calculateLeadingEdgeTemperature(altitude: h, velocity: v, planeDesign: planeDesign)
        trajectory.append(TrajectoryPoint(
            time: time,
            altitude: h * PhysicsConstants.metersToFeet,
            speed: v / PhysicsConstants.speedOfSoundSeaLevel,
            fuelRemaining: max(0, fuelMass / PhysicsConstants.kgPerLiter),
            engineMode: propulsionManager.currentMode,
            temperature: finalTemp
        ))

        return FlightSegmentResult(
            trajectory: trajectory,
            fuelUsed: fuelUsed,
            finalAltitude: h * PhysicsConstants.metersToFeet,
            finalSpeed: v / PhysicsConstants.speedOfSoundSeaLevel,
            duration: time,
            engineUsed: propulsionManager.currentMode
        )
    }


    /// Reset simulator state
    func reset(fuelLiters: Double = 50000.0) {
        self.altitude = 0
        self.velocity = 0
        self.fuelMass = fuelLiters * PhysicsConstants.kgPerLiter
    }

    /// Get current fuel remaining in liters
    func getFuelRemaining() -> Double {
        return max(0, fuelMass / PhysicsConstants.kgPerLiter)
    }
}
