//
//  JetModule.swift
//  ssto
//
//  Computes fuel consumption and validates thermal limits for jet-powered flight segments
//  Based on modern J58-type turbojet with afterburner (SR-71 Blackbird heritage)
//
//  Operating Limits:
//  - Altitude: 0 - 25,000 meters (0 - 82,000 feet)
//  - Speed: Mach 0 - 3.2
//

import Foundation

/// Module for analyzing jet flight segments with thermal, drag, and lift considerations
class JetModule {

    // MARK: - Constants

    /// Time step for numerical integration (seconds)
    static let timeStep: Double = 1.0

    /// Maximum iterations for segment simulation
    static let maxIterations: Int = 10000

    /// Maximum operating altitude for jet engines (meters)
    static let maxAltitude: Double = 25001.0

    /// Lift coefficient (simplified, typical for lifting body)
    static let liftCoefficient: Double = 0.5

    /// Reference wing area for lift calculation (m²)
    /// This should ideally come from the aircraft design
    static let referenceArea: Double = 50.0

    /// Number of J58-type engines
    static let engineCount: Int = 2

    // MARK: - Segment Analysis Result

    struct JetSegmentResult {
        let startAltitude: Double       // feet
        let endAltitude: Double         // feet
        let startSpeed: Double          // Mach
        let endSpeed: Double            // Mach
        let fuelConsumed: Double        // kg
        let timeElapsed: Double         // seconds
        let maxTemperature: Double      // °C
        let thermalLimitExceeded: Bool  // true if thermal limit exceeded
        let thermalMargin: Double       // °C (negative if exceeded)
        let averageDrag: Double         // Newtons
        let averageLift: Double         // Newtons
        let averageThrust: Double       // Newtons
        let flightPathAngle: Double     // degrees (average)
        let trajectoryPoints: [(time: Double, altitude: Double, speed: Double, temp: Double)] // trajectory data
    }

    // MARK: - Thermal Validation

    /// Check if a jet waypoint is thermally safe
    /// - Parameters:
    ///   - startWaypoint: Starting waypoint
    ///   - endWaypoint: Ending waypoint
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Tuple (isSafe, maxTemp, thermalMargin, message)
    static func validateThermalLimits(startWaypoint: Waypoint, endWaypoint: Waypoint,
                                     planeDesign: PlaneDesign) -> (isSafe: Bool, maxTemp: Double, margin: Double, message: String) {

        // Check altitude limit for jet engines
        let startAltitudeMeters = startWaypoint.altitude * PhysicsConstants.feetToMeters
        let endAltitudeMeters = endWaypoint.altitude * PhysicsConstants.feetToMeters
        let maxAltitudeReached = max(startAltitudeMeters, endAltitudeMeters)

        if maxAltitudeReached > maxAltitude {
            let message = String(format: "ALTITUDE LIMIT EXCEEDED!\n\nJet engines cannot operate above %.0f meters (%.0f feet).\n\nWaypoint altitude: %.0f meters (%.0f feet)\nExceeded by: %.0f meters\n\nUse ramjet or scramjet engines at higher altitudes.",
                               maxAltitude, maxAltitude * PhysicsConstants.metersToFeet,
                               maxAltitudeReached, maxAltitudeReached * PhysicsConstants.metersToFeet,
                               maxAltitudeReached - maxAltitude)
            return (false, 0.0, -(maxAltitudeReached - maxAltitude), message)
        }

        // Sample multiple points along the trajectory to find max temperature
        let numSamples = 10
        var maxTemperature: Double = 0.0
        var maxTempAltitude: Double = 0.0
        var maxTempSpeed: Double = 0.0

        for i in 0...numSamples {
            let fraction = Double(i) / Double(numSamples)

            // Linear interpolation between waypoints
            let altitude = startWaypoint.altitude + (endWaypoint.altitude - startWaypoint.altitude) * fraction
            let speed = startWaypoint.speed + (endWaypoint.speed - startWaypoint.speed) * fraction

            // Calculate temperature at this point
            let temperature = ThermalModel.calculateTemperature(altitude: altitude, speed: speed)

            if temperature > maxTemperature {
                maxTemperature = temperature
                maxTempAltitude = altitude
                maxTempSpeed = speed
            }
        }

        // Get thermal limit for the aircraft
        let thermalLimit = ThermalModel.getMaxTemperature(for: planeDesign)
        let margin = thermalLimit - maxTemperature
        let isSafe = maxTemperature <= thermalLimit

        // Create detailed message
        var message = ""
        if !isSafe {
            message = String(format: "THERMAL LIMIT EXCEEDED!\n\nMax Temperature: %.0f°C (at %.0f ft, Mach %.1f)\nThermal Limit: %.0f°C\nExceeded by: %.0f°C\n\nReduce speed or altitude to stay within thermal limits.",
                           maxTemperature, maxTempAltitude, maxTempSpeed, thermalLimit, -margin)
        } else {
            message = String(format: "Thermal Check: OK\n\nMax Temperature: %.0f°C\nThermal Limit: %.0f°C\nMargin: %.0f°C",
                           maxTemperature, thermalLimit, margin)
        }

        return (isSafe, maxTemperature, margin, message)
    }

    // MARK: - Lift Calculation

    /// Calculate lift force at given conditions
    /// - Parameters:
    ///   - altitude: Altitude in meters
    ///   - velocity: Velocity in m/s
    ///   - angleOfAttack: Angle of attack in radians (default: 0 for cruise)
    /// - Returns: Lift force in Newtons
    static func calculateLift(altitude: Double, velocity: Double, angleOfAttack: Double = 0.0) -> Double {
        let density = AtmosphereModel.atmosphericDensity(at: altitude)

        // Lift coefficient varies with angle of attack
        // For cruise, assume trimmed flight with Cl providing enough lift to offset weight
        let cl = liftCoefficient * (1.0 + angleOfAttack * 2.0) // Simplified linear relationship

        // Lift = 0.5 * ρ * v² * Cl * S
        let lift = 0.5 * density * velocity * velocity * cl * referenceArea

        return lift
    }

    // MARK: - Segment Simulation

    /// Simulate a jet segment and calculate fuel consumption
    /// This integrates the equations of motion including thrust, drag, lift, and gravity
    /// - Parameters:
    ///   - startWaypoint: Starting waypoint
    ///   - endWaypoint: Ending waypoint
    ///   - initialMass: Aircraft mass at start of segment (kg)
    ///   - planeDesign: Aircraft design parameters
    ///   - propulsion: Jet propulsion system
    /// - Returns: Segment analysis result
    static func analyzeSegment(startWaypoint: Waypoint, endWaypoint: Waypoint,
                              initialMass: Double, planeDesign: PlaneDesign,
                              propulsion: PropulsionSystem) -> JetSegmentResult {

        // Initialize state variables
        var altitude = startWaypoint.altitude * PhysicsConstants.feetToMeters // Convert to meters
        var speed = startWaypoint.speed // Mach number
        var mass = initialMass // kg
        var time: Double = 0.0
        var fuelConsumed: Double = 0.0

        // Target conditions
        let targetAltitude = endWaypoint.altitude * PhysicsConstants.feetToMeters
        let targetSpeed = endWaypoint.speed

        // Drag calculator
        let dragCalc = DragCalculator(planeDesign: planeDesign)

        // Tracking variables
        var maxTemperature: Double = 0.0
        var totalDrag: Double = 0.0
        var totalLift: Double = 0.0
        var totalThrust: Double = 0.0
        var sampleCount: Int = 0
        var trajectoryPoints: [(Double, Double, Double, Double)] = []

        // Numerical integration loop
        var iteration = 0
        while iteration < maxIterations {
            // Check if we've reached the target
            let altitudeError = abs(altitude - targetAltitude) / max(1.0, targetAltitude)
            let speedError = abs(speed - targetSpeed) / max(0.1, targetSpeed)

            if altitudeError < 0.01 && speedError < 0.01 {
                break // Close enough to target
            }

            // Get atmospheric properties
            let speedOfSound = AtmosphereModel.speedOfSound(at: altitude)
            let velocity = speed * speedOfSound // m/s

            // Calculate temperature and track maximum
            let temperature = ThermalModel.calculateLeadingEdgeTemperature(
                altitude: altitude,
                velocity: velocity,
                planeDesign: planeDesign
            )
            maxTemperature = max(maxTemperature, temperature)

            // Store trajectory point every 10 iterations
            if iteration % 10 == 0 {
                trajectoryPoints.append((time, altitude * PhysicsConstants.metersToFeet, speed, temperature))
            }

            // Calculate forces
            let thrust = propulsion.getThrust(altitude: altitude * PhysicsConstants.metersToFeet, speed: speed)
            let drag = dragCalc.calculateDrag(altitude: altitude, velocity: velocity)
            let lift = calculateLift(altitude: altitude, velocity: velocity)
            let weight = mass * PhysicsConstants.gravity(at: altitude)

            // Track averages
            totalDrag += drag
            totalLift += lift
            totalThrust += thrust
            sampleCount += 1

            // Determine flight path angle (simplified: climb or descend to target)
            let altitudeToTarget = targetAltitude - altitude
            let flightPathAngle = atan2(altitudeToTarget, velocity * timeStep) // radians

            // Forces along flight path
            // Longitudinal: Thrust - Drag - Weight*sin(gamma)
            // Normal: Lift - Weight*cos(gamma)
            let longitudinalForce = thrust - drag - weight * sin(flightPathAngle)
            _ = lift - weight * cos(flightPathAngle)  // normalForce calculation (unused)

            // Accelerations
            let longitudinalAccel = longitudinalForce / mass

            // Update velocity (m/s)
            let newVelocity = velocity + longitudinalAccel * timeStep

            // Update speed (Mach)
            let newSpeedOfSound = AtmosphereModel.speedOfSound(at: altitude)
            speed = newVelocity / newSpeedOfSound

            // Clamp speed to jet operating range (0 - Mach 3.2)
            speed = max(0.0, min(speed, 3.2))

            // Update altitude
            // Vertical velocity component = velocity * sin(gamma)
            let verticalVelocity = velocity * sin(flightPathAngle)
            altitude += verticalVelocity * timeStep

            // Clamp altitude to jet operating range
            altitude = max(0.0, min(altitude, maxAltitude))

            // Calculate fuel consumption
            let fuelRate = propulsion.getFuelConsumption(
                altitude: altitude * PhysicsConstants.metersToFeet,
                speed: speed
            ) // liters/second

            // Convert to mass (using JP-7 density for jet fuel, though game uses hydrogen)
            // Using 800 kg/m³ for jet fuel (JP-7)
            let fuelMassRate = fuelRate * 0.8 // kg/s (JP-7 ~800 kg/m³)
            let fuelThisStep = fuelMassRate * timeStep

            fuelConsumed += fuelThisStep
            mass -= fuelThisStep

            // Update time
            time += timeStep
            iteration += 1

            // Safety check: prevent negative mass
            if mass < PhysicsConstants.dryMass * 0.5 {
                print("WARNING: Excessive fuel consumption in jet segment")
                break
            }
        }

        // Calculate averages
        let averageDrag = sampleCount > 0 ? totalDrag / Double(sampleCount) : 0.0
        let averageLift = sampleCount > 0 ? totalLift / Double(sampleCount) : 0.0
        let averageThrust = sampleCount > 0 ? totalThrust / Double(sampleCount) : 0.0

        // Calculate average flight path angle
        let deltaAltitude = endWaypoint.altitude - startWaypoint.altitude
        let horizontalDistance = time * (startWaypoint.speed + endWaypoint.speed) / 2.0 *
                                 PhysicsConstants.speedOfSoundSeaLevel
        let avgFlightPathAngle = atan2(deltaAltitude * PhysicsConstants.feetToMeters,
                                       horizontalDistance) * 180.0 / .pi

        // Check thermal limits
        let thermalLimit = ThermalModel.getMaxTemperature(for: planeDesign)
        let thermalMargin = thermalLimit - maxTemperature
        let thermalExceeded = maxTemperature > thermalLimit

        return JetSegmentResult(
            startAltitude: startWaypoint.altitude,
            endAltitude: endWaypoint.altitude,
            startSpeed: startWaypoint.speed,
            endSpeed: endWaypoint.speed,
            fuelConsumed: fuelConsumed,
            timeElapsed: time,
            maxTemperature: maxTemperature,
            thermalLimitExceeded: thermalExceeded,
            thermalMargin: thermalMargin,
            averageDrag: averageDrag,
            averageLift: averageLift,
            averageThrust: averageThrust,
            flightPathAngle: avgFlightPathAngle,
            trajectoryPoints: trajectoryPoints
        )
    }

    // MARK: - Flight Plan Analysis

    /// Analyze all jet segments in a flight plan
    /// - Parameters:
    ///   - waypoints: Flight plan waypoints
    ///   - currentMass: Current aircraft mass (kg)
    ///   - planeDesign: Aircraft design
    ///   - propulsion: Jet propulsion system
    /// - Returns: Array of segment results
    static func analyzeJetSegments(waypoints: [Waypoint], currentMass: Double,
                                   planeDesign: PlaneDesign,
                                   propulsion: PropulsionSystem) -> [JetSegmentResult] {
        var results: [JetSegmentResult] = []
        var mass = currentMass

        for i in 0..<waypoints.count - 1 {
            let current = waypoints[i]
            let next = waypoints[i + 1]

            // Check if this is a jet segment
            if next.engineMode == .jet || current.engineMode == .jet {
                let result = analyzeSegment(
                    startWaypoint: current,
                    endWaypoint: next,
                    initialMass: mass,
                    planeDesign: planeDesign,
                    propulsion: propulsion
                )

                results.append(result)
                mass -= result.fuelConsumed
            }
        }

        return results
    }

    // MARK: - Reporting

    /// Print detailed report of jet segment analysis
    /// - Parameter results: Array of segment results
    static func printSegmentReport(results: [JetSegmentResult]) {
        print("\n========== JET ENGINE SEGMENT ANALYSIS ==========")

        if results.isEmpty {
            print("No jet engine segments found in flight plan.")
            print("================================================\n")
            return
        }

        for (index, result) in results.enumerated() {
            print("\nJet Segment \(index + 1):")
            print("  Altitude: \(Int(result.startAltitude)) ft → \(Int(result.endAltitude)) ft")
            print("  Speed: Mach \(String(format: "%.1f", result.startSpeed)) → Mach \(String(format: "%.1f", result.endSpeed))")
            print("  Flight Time: \(String(format: "%.1f", result.timeElapsed)) seconds (\(String(format: "%.1f", result.timeElapsed/60.0)) min)")
            print("  Flight Path Angle: \(String(format: "%.1f", result.flightPathAngle))°")
            print("  Fuel Consumed: \(String(format: "%.1f", result.fuelConsumed)) kg")
            print("  Thermal Analysis:")
            print("    - Max Temperature: \(String(format: "%.0f", result.maxTemperature))°C")
            print("    - Thermal Margin: \(String(format: "%.0f", result.thermalMargin))°C")
            print("    - Status: \(result.thermalLimitExceeded ? "⚠️  EXCEEDED" : "✓ OK")")
            print("  Performance:")
            print("    - Average Thrust: \(String(format: "%.0f", result.averageThrust)) N (\(String(format: "%.0f", result.averageThrust/1000.0)) kN)")
            print("    - Average Drag: \(String(format: "%.0f", result.averageDrag)) N")
            print("    - Average Lift: \(String(format: "%.0f", result.averageLift)) N")
            print("    - Thrust/Drag Ratio: \(String(format: "%.2f", result.averageThrust/max(1.0, result.averageDrag)))")
        }

        // Print totals
        let totalFuel = results.reduce(0.0) { $0 + $1.fuelConsumed }
        let totalTime = results.reduce(0.0) { $0 + $1.timeElapsed }
        let anyExceeded = results.contains { $0.thermalLimitExceeded }

        print("\n--- Total Jet Engine Performance ---")
        print("  Total Fuel: \(String(format: "%.1f", totalFuel)) kg")
        print("  Total Time: \(String(format: "%.1f", totalTime)) seconds (\(String(format: "%.1f", totalTime/60.0)) min)")
        print("  Thermal Status: \(anyExceeded ? "⚠️  LIMITS EXCEEDED" : "✓ ALL SEGMENTS OK")")
        print("================================================\n")
    }
}
