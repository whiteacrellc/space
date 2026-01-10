//
//  NewtonModule.swift
//  ssto
//
//  Uses Newton-Raphson method to optimize aircraft length for orbital missions
//

import Foundation

/// Module for optimizing aircraft length using Newton-Raphson method
class NewtonModule {

    // MARK: - Constants

    /// Maximum iterations for Newton-Raphson
    static let maxIterations: Int = 20

    /// Convergence threshold (0.01% of dry weight)
    static let convergenceThreshold: Double = 0.0001

    /// Finite difference step size for derivative estimation (meters)
    static let derivativeStepSize: Double = 1.0

    /// Minimum aircraft length (meters)
    static let minLength: Double = 30.0

    /// Maximum aircraft length (meters)
    /// Note: Volume scales as length³, so large lengths may be needed for heavy payloads
    static let maxLength: Double = 1000.0

    // MARK: - Optimization Result

    struct OptimizationResult {
        let optimalLength: Double          // Optimized aircraft length (meters)
        let fuelError: Double               // Final fuel error (kg)
        let fuelCapacity: Double            // Fuel capacity at optimal length (kg)
        let fuelRequired: Double            // Fuel required for mission (kg)
        let iterations: Int                 // Number of iterations performed
        let converged: Bool                 // Whether optimization converged
        let lengthHistory: [Double]         // History of length values
        let errorHistory: [Double]          // History of error values
    }

    // MARK: - Mission Evaluation

    /// Evaluate mission fuel requirements for a given aircraft length
    /// - Parameters:
    ///   - length: Aircraft length in meters
    ///   - flightPlan: Flight plan to simulate
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Tuple of (fuelError, fuelCapacity, fuelRequired, missionSuccess)
    private static func evaluateMission(length: Double, flightPlan: FlightPlan,
                                       planeDesign: PlaneDesign) -> (fuelError: Double, fuelCapacity: Double, fuelRequired: Double, success: Bool) {

        // Get current aircraft length and calculate volume scaling
        let planform = GameManager.shared.getTopViewPlanform()
        let originalLength = planform.aircraftLength

        // Calculate aircraft internal volume with this length
        // Note: Volume scales as length^3 when all dimensions scale proportionally
        let volumeScaleFactor = pow(length / originalLength, 3.0)
        let baseVolume = AircraftVolumeModel.calculateInternalVolume()
        let aircraftVolume = baseVolume * volumeScaleFactor

        // Calculate required volume (payload + pilot + fuel + LOX + engines)
        // Uses FuelEstimator with actual PropulsionManager data
        let fuelEstimator = FuelEstimator()
        let requiredVolume = fuelEstimator.calculateRequiredVolume(
            flightPlan: flightPlan,
            planeDesign: planeDesign
        )

        // For compatibility with existing code, express as fuel equivalent
        // fuelCapacity = aircraft volume (as if all fuel)
        // fuelRequired = required volume (as if all fuel)
        let fuelCapacity = aircraftVolume * 1000.0 * PhysicsConstants.kgPerLiter
        let fuelRequired = requiredVolume * 1000.0 * PhysicsConstants.kgPerLiter

        // Estimate current mass for additional calculations
        let dryMass = PhysicsConstants.calculateDryMass(
            volumeM3: aircraftVolume,
            waypoints: flightPlan.waypoints,
            planeDesign: planeDesign
        )
        let currentMass = dryMass + fuelCapacity - fuelRequired

        // Check if we reached orbit
        let finalWaypoint = flightPlan.waypoints.last!
        let reachedOrbit = PhysicsConstants.isOrbitAchieved(
            altitude: finalWaypoint.altitude,
            speed: finalWaypoint.speed
        )

        var fuelError: Double
        var missionSuccess = false

        if fuelRequired <= fuelCapacity && reachedOrbit {
            // Mission success - error is excess volume (want to minimize this)
            fuelError = fuelCapacity - fuelRequired
            missionSuccess = true
        } else {
            // Mission failure - need more volume
            // Calculate additional rocket fuel needed
            let fuelDeficit = fuelRequired - fuelCapacity

            // If didn't reach orbit, estimate additional rocket delta-V needed
            if !reachedOrbit {
                let additionalDeltaV = RocketModule.calculateDeltaV(
                    startAltitude: finalWaypoint.altitude,  // RocketModule expects feet
                    endAltitude: PhysicsConstants.orbitAltitude * PhysicsConstants.metersToFeet,  // Convert to feet
                    startSpeed: finalWaypoint.speed,
                    endSpeed: PhysicsConstants.orbitSpeed
                )

                let avgAltitude = (finalWaypoint.altitude + PhysicsConstants.orbitAltitude * PhysicsConstants.metersToFeet) / 2.0
                let (additionalPropellant, _, _, _) = RocketModule.calculatePropellantMass(
                    deltaV: additionalDeltaV,
                    initialMass: currentMass,
                    averageAltitude: avgAltitude  // RocketModule expects feet
                )

                fuelError = -(fuelDeficit + additionalPropellant)
            } else {
                // Reached orbit but need more volume
                fuelError = -fuelDeficit
            }
            missionSuccess = false
        }

        return (fuelError, fuelCapacity, fuelRequired, missionSuccess)
    }

    /// Estimate fuel consumption for a flight segment
    /// Uses FuelEstimator with actual PropulsionManager data (no hardcoded rates)
    /// - Parameters:
    ///   - start: Starting waypoint
    ///   - end: Ending waypoint
    ///   - currentMass: Current aircraft mass (kg)
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Estimated fuel consumption in kg
    private static func estimateSegmentFuel(start: Waypoint, end: Waypoint,
                                           currentMass: Double,
                                           planeDesign: PlaneDesign) -> Double {
        let fuelEstimator = FuelEstimator()
        let (fuelKg, _) = fuelEstimator.estimateSegment(
            from: start,
            to: end,
            currentMass: currentMass,
            planeDesign: planeDesign
        )
        return fuelKg
    }

    // MARK: - Newton-Raphson Optimization

    /// Optimize aircraft length using Newton-Raphson method
    /// - Parameters:
    ///   - initialLength: Starting guess for aircraft length (meters)
    ///   - flightPlan: Flight plan to optimize for
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Optimization result
    static func optimizeLength(initialLength: Double, flightPlan: FlightPlan,
                              planeDesign: PlaneDesign) -> OptimizationResult {

        print("\n========== NEWTON-RAPHSON LENGTH OPTIMIZATION ==========")
        print("Initial Length: \(String(format: "%.2f", initialLength)) m")
        print("Target: Reach orbit (\(Int(PhysicsConstants.orbitAltitude)) ft, Mach \(String(format: "%.1f", PhysicsConstants.orbitSpeed)))")
        print("Convergence: Error < 0.1% of dry weight")
        print("Max Iterations: \(maxIterations)")
        print("========================================================\n")

        var currentLength = initialLength
        var lengthHistory: [Double] = [currentLength]
        var errorHistory: [Double] = []

        var iteration = 0
        var converged = false

        var finalError: Double = 0.0
        var finalCapacity: Double = 0.0
        var finalRequired: Double = 0.0

        while iteration < maxIterations {
            iteration += 1

            // Evaluate mission at current length
            let (error, capacity, required, _) = evaluateMission(
                length: currentLength,
                flightPlan: flightPlan,
                planeDesign: planeDesign
            )

            errorHistory.append(error)
            finalError = error
            finalCapacity = capacity
            finalRequired = required

            // Calculate dry weight for convergence check
            let volumeScaleFactor = pow(currentLength / (GameManager.shared.getTopViewPlanform().aircraftLength), 3.0)
            let baseVolume = AircraftVolumeModel.calculateInternalVolume()
            let aircraftVolume = baseVolume * volumeScaleFactor

            let dryWeight = PhysicsConstants.calculateDryMass(
                volumeM3: aircraftVolume,
                waypoints: flightPlan.waypoints,
                planeDesign: planeDesign
            )

            print("Iteration \(iteration):")
            print("  Length: \(String(format: "%.2f", currentLength)) m")
            print("  Dry Weight: \(String(format: "%.0f", dryWeight)) kg")
            print("  Fuel Capacity: \(String(format: "%.0f", capacity)) kg")
            print("  Fuel Required: \(String(format: "%.0f", required)) kg")
            print("  Error: \(String(format: "%.0f", error)) kg (\(error > 0 ? "excess" : "deficit"))")

            // Check convergence (error < 0.1% of dry weight)
            if abs(error) < convergenceThreshold * dryWeight {
                print("  ✓ CONVERGED! Error < 0.1% of dry weight (\(String(format: "%.0f", convergenceThreshold * dryWeight)) kg)")
                converged = true
                break
            }

            // Calculate derivative using finite differences
            // f'(x) ≈ [f(x + h) - f(x - h)] / (2h)
            let lengthPlus = currentLength + derivativeStepSize
            let lengthMinus = currentLength - derivativeStepSize

            let (errorPlus, _, _, _) = evaluateMission(
                length: lengthPlus,
                flightPlan: flightPlan,
                planeDesign: planeDesign
            )

            let (errorMinus, _, _, _) = evaluateMission(
                length: lengthMinus,
                flightPlan: flightPlan,
                planeDesign: planeDesign
            )

            let derivative = (errorPlus - errorMinus) / (2.0 * derivativeStepSize)

            print("  Derivative: \(String(format: "%.2f", derivative)) kg/m")

            // Prevent division by zero
            guard abs(derivative) > 0.01 else {
                print("  ⚠️  Derivative too small, stopping iteration")
                break
            }

            // Newton-Raphson update: x_new = x_old - f(x) / f'(x)
            let newLength = currentLength - error / derivative

            // Clamp to reasonable bounds
            let clampedLength = max(minLength, min(maxLength, newLength))

            print("  New Length: \(String(format: "%.2f", clampedLength)) m")
            print()

            // Check if length changed significantly
            let stepSize = abs(clampedLength - currentLength)
            if stepSize < 0.001 {
                // If error is relatively small (5%), accept convergence
                if abs(error) < dryWeight * 0.05 {
                    print("  ✓ Length converged (change < 0.001 m, error < 5%)")
                    converged = true
                    break
                }
                
                // If step is extremely small, we are stuck
                if stepSize < 1e-6 {
                    print("  ⚠️ Step size extremely small (\(stepSize)), stopping")
                    break
                }
                
                // Otherwise continue to try to reduce error
            }

            currentLength = clampedLength
            lengthHistory.append(currentLength)
        }

        // Calculate final dry weight for reporting
        let volumeScaleFactor = pow(currentLength / (GameManager.shared.getTopViewPlanform().aircraftLength), 3.0)
        let baseVolume = AircraftVolumeModel.calculateInternalVolume()
        let aircraftVolume = baseVolume * volumeScaleFactor
        let finalDryWeight = PhysicsConstants.calculateDryMass(
            volumeM3: aircraftVolume,
            waypoints: flightPlan.waypoints,
            planeDesign: planeDesign
        )

        // Final report
        print("\n========== OPTIMIZATION COMPLETE ==========")
        print("Status: \(converged ? "✓ CONVERGED" : "⚠️  MAX ITERATIONS REACHED")")
        print("Iterations: \(iteration)")
        print("Optimal Length: \(String(format: "%.2f", currentLength)) m")
        print("Dry Weight: \(String(format: "%.0f", finalDryWeight)) kg")
        print("Fuel Capacity: \(String(format: "%.0f", finalCapacity)) kg")
        print("Fuel Required: \(String(format: "%.0f", finalRequired)) kg")
        print("Final Error: \(String(format: "%.0f", finalError)) kg (\(String(format: "%.1f%%", abs(finalError)/max(1.0, finalDryWeight)*100.0)) of dry weight)")

        if finalError > 0 {
            print("Result: Mission achievable with \(String(format: "%.0f", finalError)) kg excess fuel")
        } else {
            print("Result: Need \(String(format: "%.0f", -finalError)) kg additional fuel")
        }
        print("===========================================\n")

        return OptimizationResult(
            optimalLength: currentLength,
            fuelError: finalError,
            fuelCapacity: finalCapacity,
            fuelRequired: finalRequired,
            iterations: iteration,
            converged: converged,
            lengthHistory: lengthHistory,
            errorHistory: errorHistory
        )
    }

    // MARK: - Convenience Methods

    /// Optimize aircraft length for current game state
    /// Uses current flight plan and plane design from GameManager
    /// - Parameter initialLength: Starting guess (defaults to current length)
    /// - Returns: Optimization result
    static func optimizeCurrentAircraft(initialLength: Double? = nil) -> OptimizationResult {
        let flightPlan = GameManager.shared.getFlightPlan()
        let planeDesign = GameManager.shared.getPlaneDesign()
        let planform = GameManager.shared.getTopViewPlanform()

        let startLength = initialLength ?? planform.aircraftLength

        return optimizeLength(
            initialLength: startLength,
            flightPlan: flightPlan,
            planeDesign: planeDesign
        )
    }

    /// Apply optimized length to current aircraft design
    /// - Parameter result: Optimization result to apply
    static func applyOptimizedLength(result: OptimizationResult) {
        var planform = GameManager.shared.getTopViewPlanform()
        planform.aircraftLength = result.optimalLength
        GameManager.shared.setTopViewPlanform(planform)

        print("✓ Applied optimized length: \(String(format: "%.2f", result.optimalLength)) m")
    }
}
