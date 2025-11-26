//
//  GameManager.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

class GameManager {
    static let shared = GameManager()

    private(set) var currentFlightPlan: FlightPlan?
    private(set) var lastMissionResult: MissionResult?
    private(set) var currentPlaneDesign: PlaneDesign = PlaneDesign.defaultDesign
    private let propulsionManager = PropulsionManager()
    private var simulator: FlightSimulator?

    private init() {
        // Singleton
    }

    /// Start a new mission with a fresh flight plan
    func startNewMission() {
        currentFlightPlan = FlightPlan()
        lastMissionResult = nil
        simulator = nil
    }

    /// Get the current flight plan (create if needed)
    func getFlightPlan() -> FlightPlan {
        if currentFlightPlan == nil {
            currentFlightPlan = FlightPlan()
        }
        return currentFlightPlan!
    }

    /// Update the current plane design
    func setPlaneDesign(_ design: PlaneDesign) {
        currentPlaneDesign = design
        print("Plane design updated: \(design.summary())")
        print("Design score: \(design.score())/100")
    }

    /// Get the current plane design
    func getPlaneDesign() -> PlaneDesign {
        return currentPlaneDesign
    }

    /// Simulate the entire flight based on the current flight plan
    func simulateFlight(plan: FlightPlan) -> MissionResult {
        // Reset simulator with current plane design
        simulator = FlightSimulator(initialFuel: 50000.0, planeDesign: currentPlaneDesign)
        propulsionManager.enableAutoMode()

        print("Using plane design: Pitch \(currentPlaneDesign.pitchAngle)°, Yaw \(currentPlaneDesign.yawAngle)°, Pos \(currentPlaneDesign.position)")
        print("  \(currentPlaneDesign.summary())")

        var segments: [FlightSegmentResult] = []
        var totalFuel = 0.0
        var totalTime = 0.0

        // Simulate each segment
        for i in 0..<(plan.waypoints.count - 1) {
            let start = plan.waypoints[i]
            let end = plan.waypoints[i + 1]

            print("Simulating segment \(i + 1): \(start.altitude)ft @ Mach \(start.speed) → \(end.altitude)ft @ Mach \(end.speed)")

            let result = simulator!.simulateSegment(
                from: start,
                to: end,
                propulsionManager: propulsionManager
            )

            segments.append(result)
            totalFuel += result.fuelUsed
            totalTime += result.duration

            print("  Completed in \(Int(result.duration))s, used \(Int(result.fuelUsed))L fuel")
        }

        // Check if orbit was achieved
        let success = checkOrbitAchieved(segments: segments)

        // Calculate score
        let score = calculateScore(fuel: totalFuel, time: totalTime, success: success)

        // Get final state
        let finalSegment = segments.last
        let finalAltitude = finalSegment?.finalAltitude ?? 0
        let finalSpeed = finalSegment?.finalSpeed ?? 0

        let result = MissionResult(
            segments: segments,
            totalFuelUsed: totalFuel,
            totalDuration: totalTime,
            success: success,
            finalAltitude: finalAltitude,
            finalSpeed: finalSpeed,
            score: score
        )

        lastMissionResult = result
        return result
    }

    /// Check if orbit was achieved
    private func checkOrbitAchieved(segments: [FlightSegmentResult]) -> Bool {
        guard let lastSegment = segments.last else { return false }

        let altitudeReached = lastSegment.finalAltitude >= PhysicsConstants.orbitAltitude
        let speedReached = lastSegment.finalSpeed >= PhysicsConstants.orbitSpeed

        return altitudeReached && speedReached
    }

    /// Calculate score based on performance
    private func calculateScore(fuel: Double, time: Double, success: Bool) -> Int {
        guard success else { return 0 }

        // Base score for success
        var score = 10000

        // Fuel efficiency bonus (less fuel = higher score)
        // Typical missions might use 20,000-40,000 liters
        let fuelScore = max(0, Int(50000 - fuel))
        score += fuelScore

        // Time bonus (faster = higher score)
        // Typical missions might take 200-500 seconds
        let timeScore = max(0, Int((1000 - time) * 2))
        score += timeScore

        return score
    }

    /// Get the last mission result
    func getLastResult() -> MissionResult? {
        return lastMissionResult
    }

    /// Get the propulsion manager (for UI display)
    func getPropulsionManager() -> PropulsionManager {
        return propulsionManager
    }
}
