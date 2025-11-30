//
//  GameManager.swift
//  ssto
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation
import CoreGraphics

/// Stores the spline control points for cross-section design
struct CrossSectionPoints: Codable {
    var topPoints: [SerializablePoint]
    var bottomPoints: [SerializablePoint]

    static let defaultPoints = CrossSectionPoints(
        topPoints: [
            SerializablePoint(x: 100, y: 250, isFixedX: true),
            SerializablePoint(x: 200, y: 190, isFixedX: false),
            SerializablePoint(x: 400, y: 160, isFixedX: false),
            SerializablePoint(x: 600, y: 200, isFixedX: false),
            SerializablePoint(x: 700, y: 250, isFixedX: true)
        ],
        bottomPoints: [
            SerializablePoint(x: 100, y: 250, isFixedX: true),
            SerializablePoint(x: 200, y: 280, isFixedX: false),
            SerializablePoint(x: 400, y: 290, isFixedX: false),
            SerializablePoint(x: 600, y: 270, isFixedX: false),
            SerializablePoint(x: 700, y: 250, isFixedX: true)
        ]
    )
}

/// Stores the top view planform shape (leading edge) design
struct TopViewPlanform: Codable {
    var noseTip: SerializablePoint
    var frontControlLeft: SerializablePoint
    var midLeft: SerializablePoint
    var rearControlLeft: SerializablePoint
    var tailLeft: SerializablePoint

    static let defaultPlanform = TopViewPlanform(
        noseTip: SerializablePoint(x: 50, y: 0, isFixedX: true),
        frontControlLeft: SerializablePoint(x: 150, y: -30, isFixedX: false),
        midLeft: SerializablePoint(x: 300, y: -100, isFixedX: false),
        rearControlLeft: SerializablePoint(x: 500, y: -80, isFixedX: false),
        tailLeft: SerializablePoint(x: 750, y: -50, isFixedX: false)
    )
}

/// Stores the side profile (fuselage) shape design
struct SideProfileShape: Codable {
    var frontStart: SerializablePoint
    var frontControl: SerializablePoint
    var frontEnd: SerializablePoint
    var engineEnd: SerializablePoint
    var exhaustControl: SerializablePoint
    var exhaustEnd: SerializablePoint
    var topStart: SerializablePoint
    var topControl: SerializablePoint
    var topEnd: SerializablePoint
    var engineLength: Double
    var maxHeight: Double

    static let defaultProfile = SideProfileShape(
        frontStart: SerializablePoint(x: 50, y: 200, isFixedX: true),
        frontControl: SerializablePoint(x: 150, y: 80, isFixedX: false),
        frontEnd: SerializablePoint(x: 250, y: 100, isFixedX: false),
        engineEnd: SerializablePoint(x: 490, y: 100, isFixedX: false),
        exhaustControl: SerializablePoint(x: 650, y: 80, isFixedX: false),
        exhaustEnd: SerializablePoint(x: 750, y: 200, isFixedX: true),
        topStart: SerializablePoint(x: 50, y: 200, isFixedX: true),
        topControl: SerializablePoint(x: 400, y: 320, isFixedX: false),
        topEnd: SerializablePoint(x: 750, y: 200, isFixedX: true),
        engineLength: 240,
        maxHeight: 120
    )
}

/// Serializable version of CGPoint with fixedX flag
struct SerializablePoint: Codable {
    var x: Double
    var y: Double
    var isFixedX: Bool

    func toCGPoint() -> CGPoint {
        return CGPoint(x: x, y: y)
    }

    init(x: Double, y: Double, isFixedX: Bool) {
        self.x = x
        self.y = y
        self.isFixedX = isFixedX
    }

    init(from point: CGPoint, isFixedX: Bool) {
        self.x = Double(point.x)
        self.y = Double(point.y)
        self.isFixedX = isFixedX
    }
}

class GameManager {
    static let shared = GameManager()

    private(set) var currentFlightPlan: FlightPlan?
    private(set) var lastMissionResult: MissionResult?
    private(set) var currentPlaneDesign: PlaneDesign = PlaneDesign.defaultDesign
    private(set) var currentCrossSectionPoints: CrossSectionPoints = CrossSectionPoints.defaultPoints
    private(set) var currentTopViewPlanform: TopViewPlanform = TopViewPlanform.defaultPlanform
    private(set) var currentSideProfile: SideProfileShape = SideProfileShape.defaultProfile
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

    /// Update the current cross-section spline points
    func setCrossSectionPoints(_ points: CrossSectionPoints) {
        currentCrossSectionPoints = points
        print("Cross-section points updated: \(points.topPoints.count) top, \(points.bottomPoints.count) bottom")
    }

    /// Get the current cross-section spline points
    func getCrossSectionPoints() -> CrossSectionPoints {
        return currentCrossSectionPoints
    }

    /// Update the current top view planform
    func setTopViewPlanform(_ planform: TopViewPlanform) {
        currentTopViewPlanform = planform
        print("Top view planform updated")
    }

    /// Get the current top view planform
    func getTopViewPlanform() -> TopViewPlanform {
        return currentTopViewPlanform
    }

    /// Update the current side profile shape
    func setSideProfile(_ profile: SideProfileShape) {
        currentSideProfile = profile
        print("Side profile shape updated")
    }

    /// Get the current side profile shape
    func getSideProfile() -> SideProfileShape {
        return currentSideProfile
    }

    /// Simulate the entire flight based on the current flight plan
    func simulateFlight(plan: FlightPlan) -> MissionResult {
        // Reset simulator with current plane design
        simulator = FlightSimulator(initialFuel: 50000.0, planeDesign: currentPlaneDesign)
        propulsionManager.enableAutoMode()

        print("Using plane design: Sweep \(currentPlaneDesign.sweepAngle)°, Tilt \(currentPlaneDesign.tiltAngle)°, Pos \(currentPlaneDesign.position)")
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

    // MARK: - Aircraft Design Bundle for Save/Load

    /// Bundle containing all aircraft design parameters for saving/loading
    struct AircraftDesignBundle: Codable {
        let sideProfile: SideProfileShape
        let topViewPlanform: TopViewPlanform
        let planeDesign: PlaneDesign
        let crossSectionPoints: CrossSectionPoints
        let savedDate: Date
    }

    // MARK: - Save/Load Methods

    /// Save the current aircraft design with a given name
    /// - Parameter name: The name to save the design under
    /// - Returns: true if save was successful, false otherwise
    func saveDesign(name: String) -> Bool {
        let bundle = AircraftDesignBundle(
            sideProfile: currentSideProfile,
            topViewPlanform: currentTopViewPlanform,
            planeDesign: currentPlaneDesign,
            crossSectionPoints: currentCrossSectionPoints,
            savedDate: Date()
        )

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(bundle) else {
            print("Failed to encode design bundle")
            return false
        }

        UserDefaults.standard.set(data, forKey: "savedDesign_\(name)")
        print("Design '\(name)' saved successfully")
        return true
    }

    /// Load a saved aircraft design by name
    /// - Parameter name: The name of the design to load
    /// - Returns: true if load was successful, false otherwise
    func loadDesign(name: String) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "savedDesign_\(name)") else {
            print("No saved design found with name '\(name)'")
            return false
        }

        let decoder = JSONDecoder()
        guard let bundle = try? decoder.decode(AircraftDesignBundle.self, from: data) else {
            print("Failed to decode design bundle")
            return false
        }

        currentSideProfile = bundle.sideProfile
        currentTopViewPlanform = bundle.topViewPlanform
        currentPlaneDesign = bundle.planeDesign
        currentCrossSectionPoints = bundle.crossSectionPoints

        print("Design '\(name)' loaded successfully")
        return true
    }

    /// Get a list of all saved design names
    /// - Returns: Array of design names, sorted alphabetically
    func getSavedDesignNames() -> [String] {
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        return defaults.keys
            .filter { $0.hasPrefix("savedDesign_") }
            .map { String($0.dropFirst("savedDesign_".count)) }
            .sorted()
    }

    /// Delete a saved design by name
    /// - Parameter name: The name of the design to delete
    func deleteDesign(name: String) {
        UserDefaults.standard.removeObject(forKey: "savedDesign_\(name)")
        print("Design '\(name)' deleted")
    }
}
