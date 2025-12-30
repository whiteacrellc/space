//
//  RocketModule.swift
//  ssto
//
//  Computes propellant requirements for rocket-powered flight segments
//

import Foundation

/// Module for computing rocket propellant requirements using slush hydrogen and liquid oxygen
class RocketModule {

    // MARK: - Constants

    /// Specific impulse at sea level (seconds) for LH2/LOX engine
    static let ispSeaLevel: Double = 420.0

    /// Specific impulse in vacuum (seconds) for LH2/LOX engine
    static let ispVacuum: Double = 450.0

    /// Mixture ratio: mass of LOX to mass of LH2 (typical for LH2/LOX is ~6:1)
    static let mixtureRatio: Double = 6.0

    /// Standard gravity (m/s²)
    static let g0: Double = 9.80665

    /// Transition altitude where ISP begins to increase (feet)
    static let ispTransitionAltitude: Double = 50000.0

    /// Full vacuum altitude where ISP reaches maximum (feet)
    static let ispVacuumAltitude: Double = 200000.0

    // MARK: - Propellant Calculation Result

    struct PropellantRequirement {
        let deltaV: Double              // Required velocity change (m/s)
        let initialMass: Double         // Mass at start of rocket segment (kg)
        let finalMass: Double           // Mass at end of rocket segment (kg)
        let totalPropellantMass: Double // Total propellant needed (kg)
        let loxMass: Double             // Liquid oxygen mass (kg)
        let slushH2Mass: Double         // Slush hydrogen mass (kg)
        let startAltitude: Double       // Starting altitude (feet)
        let endAltitude: Double         // Ending altitude (feet)
        let startSpeed: Double          // Starting speed (Mach)
        let endSpeed: Double            // Ending speed (Mach)
        let averageIsp: Double          // Average ISP used for this segment
    }

    // MARK: - Segment Analysis Result

    struct RocketSegmentResult {
        let startAltitude: Double       // feet
        let endAltitude: Double         // feet
        let startSpeed: Double          // Mach
        let endSpeed: Double            // Mach
        let fuelConsumed: Double        // kg
        let timeElapsed: Double         // seconds
        let maxTemperature: Double      // °C
        let trajectoryPoints: [(time: Double, altitude: Double, speed: Double, temp: Double)] // trajectory data
    }

    // MARK: - ISP Calculation

    /// Calculate effective ISP at a given altitude
    /// ISP increases linearly from sea level to vacuum as atmospheric pressure decreases
    /// - Parameter altitude: Altitude in feet
    /// - Returns: Specific impulse in seconds
    static func calculateIsp(at altitude: Double) -> Double {
        if altitude <= ispTransitionAltitude {
            return ispSeaLevel
        } else if altitude >= ispVacuumAltitude {
            return ispVacuum
        } else {
            // Linear interpolation between transition and vacuum altitude
            let fraction = (altitude - ispTransitionAltitude) / (ispVacuumAltitude - ispTransitionAltitude)
            return ispSeaLevel + (ispVacuum - ispSeaLevel) * fraction
        }
    }

    // MARK: - Delta-V Calculation

    /// Calculate delta-V required for a trajectory segment
    /// This is a simplified calculation that considers altitude and speed changes
    /// - Parameters:
    ///   - startAltitude: Starting altitude (feet)
    ///   - endAltitude: Ending altitude (feet)
    ///   - startSpeed: Starting speed (Mach)
    ///   - endSpeed: Ending speed (Mach)
    /// - Returns: Required delta-V in m/s
    static func calculateDeltaV(startAltitude: Double, endAltitude: Double,
                                startSpeed: Double, endSpeed: Double) -> Double {
        // Convert altitudes to meters
        let startAltM = startAltitude * PhysicsConstants.feetToMeters
        let endAltM = endAltitude * PhysicsConstants.feetToMeters

        // Convert Mach to m/s (use average speed of sound)
        let avgAltM = (startAltM + endAltM) / 2.0
        let speedOfSound = getSpeedOfSound(at: avgAltM)
        let startVelocity = startSpeed * speedOfSound
        let endVelocity = endSpeed * speedOfSound

        // Velocity change component
        let deltaVVelocity = endVelocity - startVelocity

        // Gravitational potential energy change (converted to equivalent velocity)
        // ΔE_potential = m * g * Δh
        // Equivalent velocity: v_equiv = sqrt(2 * g * Δh)
        let deltaH = endAltM - startAltM

        // Use average gravity
        let avgGravity = PhysicsConstants.gravity(at: avgAltM)

        // Gravity loss approximation (simplified)
        // For vertical/steep ascent, gravity losses are significant
        // v_gravity ≈ sqrt(2 * g * Δh) for potential energy
        let deltaVGravity = sqrt(2.0 * avgGravity * abs(deltaH)) * (deltaH > 0 ? 1.0 : 0.0)

        // Total delta-V (simplified vector addition)
        // This is an approximation; real trajectory optimization would be more complex
        let totalDeltaV = sqrt(deltaVVelocity * deltaVVelocity + deltaVGravity * deltaVGravity)

        return totalDeltaV
    }

    /// Get speed of sound at a given altitude
    /// - Parameter altitude: Altitude in meters
    /// - Returns: Speed of sound in m/s
    static func getSpeedOfSound(at altitude: Double) -> Double {
        // Simplified model: temperature decreases with altitude in troposphere
        // T = T0 - L * h (where L is lapse rate ~6.5 K/km)
        // Speed of sound: a = sqrt(gamma * R * T)
        // Simplified: use constant value, refined models would adjust

        if altitude < 11000 { // Troposphere
            let temperature = 288.15 - 0.0065 * altitude // Kelvin
            return sqrt(1.4 * 287.05 * temperature)
        } else if altitude < 25000 { // Lower stratosphere
            return 295.0 // Approximately constant
        } else {
            return 300.0 // Approximate for higher altitudes
        }
    }

    // MARK: - Propellant Mass Calculation

    /// Calculate propellant requirements for a rocket segment
    /// Uses the Tsiolkovsky rocket equation: Δv = Isp * g0 * ln(m_initial / m_final)
    /// - Parameters:
    ///   - deltaV: Required velocity change (m/s)
    ///   - initialMass: Vehicle mass at start of segment (kg)
    ///   - averageAltitude: Average altitude of segment for ISP calculation (feet)
    /// - Returns: Propellant requirement breakdown
    static func calculatePropellantMass(deltaV: Double, initialMass: Double, averageAltitude: Double) -> (totalMass: Double, loxMass: Double, slushH2Mass: Double, isp: Double) {

        // Calculate ISP at average altitude
        let isp = calculateIsp(at: averageAltitude)
        let exhaustVelocity = isp * g0

        // Tsiolkovsky rocket equation rearranged:
        // m_final = m_initial / exp(Δv / (Isp * g0))
        let massRatio = exp(deltaV / exhaustVelocity)
        let finalMass = initialMass / massRatio

        // Total propellant mass
        let totalPropellantMass = initialMass - finalMass

        // Split into LOX and slush H2 based on mixture ratio
        // Mixture ratio = m_LOX / m_H2
        // Total = m_LOX + m_H2 = m_H2 * (mixtureRatio + 1)
        // Therefore: m_H2 = Total / (mixtureRatio + 1)
        let slushH2Mass = totalPropellantMass / (mixtureRatio + 1.0)
        let loxMass = totalPropellantMass - slushH2Mass

        return (totalPropellantMass, loxMass, slushH2Mass, isp)
    }

    // MARK: - Flight Plan Analysis

    /// Analyze a flight plan and calculate propellant requirements for all rocket segments
    /// - Parameters:
    ///   - waypoints: Array of waypoints from the flight plan
    ///   - fuelUsedBeforeRocket: Fuel consumed before reaching the first rocket waypoint (kg)
    /// - Returns: Array of propellant requirements for each rocket segment
    static func analyzeRocketSegments(waypoints: [Waypoint], fuelUsedBeforeRocket: Double) -> [PropellantRequirement] {
        var results: [PropellantRequirement] = []
        var currentMass = PhysicsConstants.dryMass - fuelUsedBeforeRocket

        // Find consecutive rocket waypoints
        var i = 0
        while i < waypoints.count - 1 {
            let current = waypoints[i]
            let next = waypoints[i + 1]

            // Check if this is a rocket segment
            if next.engineMode == .rocket || current.engineMode == .rocket {
                // Calculate delta-V for this segment
                let deltaV = calculateDeltaV(
                    startAltitude: current.altitude,
                    endAltitude: next.altitude,
                    startSpeed: current.speed,
                    endSpeed: next.speed
                )

                // Average altitude for ISP calculation
                let avgAltitude = (current.altitude + next.altitude) / 2.0

                // Calculate propellant requirements
                let (propellantMass, loxMass, h2Mass, isp) = calculatePropellantMass(
                    deltaV: deltaV,
                    initialMass: currentMass,
                    averageAltitude: avgAltitude
                )

                let finalMass = currentMass - propellantMass

                // Create result
                let requirement = PropellantRequirement(
                    deltaV: deltaV,
                    initialMass: currentMass,
                    finalMass: finalMass,
                    totalPropellantMass: propellantMass,
                    loxMass: loxMass,
                    slushH2Mass: h2Mass,
                    startAltitude: current.altitude,
                    endAltitude: next.altitude,
                    startSpeed: current.speed,
                    endSpeed: next.speed,
                    averageIsp: isp
                )

                results.append(requirement)

                // Update current mass for next segment
                currentMass = finalMass
            }

            i += 1
        }

        return results
    }

    /// Calculate total propellant requirements for all rocket segments
    /// - Parameters:
    ///   - waypoints: Array of waypoints from the flight plan
    ///   - fuelUsedBeforeRocket: Fuel consumed before reaching the first rocket waypoint (kg)
    /// - Returns: Total LOX and slush H2 masses required (kg)
    static func calculateTotalRocketPropellant(waypoints: [Waypoint], fuelUsedBeforeRocket: Double) -> (totalLox: Double, totalSlushH2: Double, totalPropellant: Double) {
        let segments = analyzeRocketSegments(waypoints: waypoints, fuelUsedBeforeRocket: fuelUsedBeforeRocket)

        var totalLox: Double = 0.0
        var totalSlushH2: Double = 0.0

        for segment in segments {
            totalLox += segment.loxMass
            totalSlushH2 += segment.slushH2Mass
        }

        let totalPropellant = totalLox + totalSlushH2

        return (totalLox, totalSlushH2, totalPropellant)
    }

    /// Print detailed report of rocket propellant requirements
    /// - Parameter requirements: Array of propellant requirements to report
    static func printPropellantReport(requirements: [PropellantRequirement]) {
        print("\n========== ROCKET PROPELLANT ANALYSIS ==========")

        if requirements.isEmpty {
            print("No rocket segments found in flight plan.")
            print("===============================================\n")
            return
        }

        for (index, req) in requirements.enumerated() {
            print("\nRocket Segment \(index + 1):")
            print("  Altitude: \(Int(req.startAltitude)) ft → \(Int(req.endAltitude)) ft")
            print("  Speed: Mach \(String(format: "%.1f", req.startSpeed)) → Mach \(String(format: "%.1f", req.endSpeed))")
            print("  Delta-V Required: \(Int(req.deltaV)) m/s")
            print("  Average ISP: \(String(format: "%.1f", req.averageIsp)) seconds")
            print("  Initial Mass: \(Int(req.initialMass)) kg")
            print("  Final Mass: \(Int(req.finalMass)) kg")
            print("  Propellant Breakdown:")
            print("    - Liquid Oxygen: \(Int(req.loxMass)) kg")
            print("    - Slush Hydrogen: \(Int(req.slushH2Mass)) kg")
            print("    - Total: \(Int(req.totalPropellantMass)) kg")
        }

        // Print totals
        let totalLox = requirements.reduce(0.0) { $0 + $1.loxMass }
        let totalH2 = requirements.reduce(0.0) { $0 + $1.slushH2Mass }
        let totalPropellant = totalLox + totalH2

        print("\n--- Total Rocket Propellant Required ---")
        print("  Liquid Oxygen: \(Int(totalLox)) kg")
        print("  Slush Hydrogen: \(Int(totalH2)) kg")
        print("  Total: \(Int(totalPropellant)) kg")
        print("===============================================\n")
    }

    // MARK: - Segment Simulation

    /// Simulate a rocket segment and calculate fuel consumption with trajectory
    /// - Parameters:
    ///   - startWaypoint: Starting waypoint
    ///   - endWaypoint: Ending waypoint
    ///   - initialMass: Aircraft mass at start of segment (kg)
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Segment analysis result
    static func analyzeSegment(startWaypoint: Waypoint, endWaypoint: Waypoint,
                              initialMass: Double, planeDesign: PlaneDesign) -> RocketSegmentResult {

        // Calculate delta-V for this segment
        let deltaV = calculateDeltaV(
            startAltitude: startWaypoint.altitude,
            endAltitude: endWaypoint.altitude,
            startSpeed: startWaypoint.speed,
            endSpeed: endWaypoint.speed
        )

        // Average altitude for ISP calculation
        let avgAltitude = (startWaypoint.altitude + endWaypoint.altitude) / 2.0

        // Calculate propellant requirements
        let (propellantMass, _, _, _) = calculatePropellantMass(
            deltaV: deltaV,
            initialMass: initialMass,
            averageAltitude: avgAltitude
        )

        // Estimate time for the burn (simplified)
        // Assume constant thrust-to-weight ratio of about 1.5
        let avgMass = initialMass - propellantMass / 2.0
        let avgThrust = avgMass * g0 * 1.5 // 1.5 g acceleration
        let avgIsp = calculateIsp(at: avgAltitude)
        let massFlowRate = avgThrust / (avgIsp * g0)
        let burnTime = propellantMass / massFlowRate

        // Create simplified trajectory points
        let numPoints = 10
        var trajectoryPoints: [(Double, Double, Double, Double)] = []

        for i in 0...numPoints {
            let fraction = Double(i) / Double(numPoints)
            let time = burnTime * fraction
            let altitude = startWaypoint.altitude + (endWaypoint.altitude - startWaypoint.altitude) * fraction
            let speed = startWaypoint.speed + (endWaypoint.speed - startWaypoint.speed) * fraction

            // Calculate temperature (simplified - rockets have active cooling)
            let altMeters = altitude * PhysicsConstants.feetToMeters
            let speedOfSound = getSpeedOfSound(at: altMeters)
            let velocity = speed * speedOfSound
            let temp = ThermalModel.calculateLeadingEdgeTemperature(
                altitude: altMeters,
                velocity: velocity,
                planeDesign: planeDesign
            )

            trajectoryPoints.append((time, altitude, speed, temp))
        }

        let maxTemp = trajectoryPoints.map { $0.3 }.max() ?? 0.0

        return RocketSegmentResult(
            startAltitude: startWaypoint.altitude,
            endAltitude: endWaypoint.altitude,
            startSpeed: startWaypoint.speed,
            endSpeed: endWaypoint.speed,
            fuelConsumed: propellantMass,
            timeElapsed: burnTime,
            maxTemperature: maxTemp,
            trajectoryPoints: trajectoryPoints
        )
    }
}
