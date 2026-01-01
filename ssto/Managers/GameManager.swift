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

    // Wing parameters
    var wingStartPosition: Double  // X position where wings start (0.0 to 1.0, representing fraction of fuselage length)
    var wingSpan: Double            // Wing half-span (distance from centerline to wingtip)
    var aircraftLength: Double      // Total aircraft length in meters

    // Custom decoding to handle old saves without aircraftLength
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        noseTip = try container.decode(SerializablePoint.self, forKey: .noseTip)
        frontControlLeft = try container.decode(SerializablePoint.self, forKey: .frontControlLeft)
        midLeft = try container.decode(SerializablePoint.self, forKey: .midLeft)
        rearControlLeft = try container.decode(SerializablePoint.self, forKey: .rearControlLeft)
        tailLeft = try container.decode(SerializablePoint.self, forKey: .tailLeft)
        wingStartPosition = try container.decodeIfPresent(Double.self, forKey: .wingStartPosition) ?? 0.67
        wingSpan = try container.decodeIfPresent(Double.self, forKey: .wingSpan) ?? 150.0
        aircraftLength = try container.decodeIfPresent(Double.self, forKey: .aircraftLength) ?? 70.0
    }

    // Standard init
    init(noseTip: SerializablePoint, frontControlLeft: SerializablePoint, midLeft: SerializablePoint,
         rearControlLeft: SerializablePoint, tailLeft: SerializablePoint,
         wingStartPosition: Double, wingSpan: Double, aircraftLength: Double) {
        self.noseTip = noseTip
        self.frontControlLeft = frontControlLeft
        self.midLeft = midLeft
        self.rearControlLeft = rearControlLeft
        self.tailLeft = tailLeft
        self.wingStartPosition = wingStartPosition
        self.wingSpan = wingSpan
        self.aircraftLength = aircraftLength
    }

    static let defaultPlanform = TopViewPlanform(
        noseTip: SerializablePoint(x: 50, y: 0, isFixedX: true),
        frontControlLeft: SerializablePoint(x: 63.333343505859375, y: -88.66665649414062, isFixedX: false),
        midLeft: SerializablePoint(x: 300, y: -84.33332824707031, isFixedX: false),
        rearControlLeft: SerializablePoint(x: 522, y: -85.33332824707031, isFixedX: false),
        tailLeft: SerializablePoint(x: 750, y: -50, isFixedX: false),
        wingStartPosition: 0.5872832536697388,     // Wing start position
        wingSpan: 67.23506927490234,             // Default wing span
        aircraftLength: 70.0         // Default length in meters
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

/// Leaderboard entry for aircraft optimization scores
struct LeaderboardEntry: Codable, Identifiable, Comparable {
    var id: UUID = UUID()
    var name: String
    var volume: Double         // m³ (lower is better)
    var optimalLength: Double  // meters
    var fuelCapacity: Double   // kg
    var date: Date

    /// Compare entries (lower volume is better)
    static func < (lhs: LeaderboardEntry, rhs: LeaderboardEntry) -> Bool {
        return lhs.volume < rhs.volume
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

    /// Tracks the name of the currently loaded/saved design file
    private(set) var currentSaveName: String?

    private init() {
        // Singleton
        // Load "Tom" save file as default if it exists
        if let data = UserDefaults.standard.data(forKey: "savedDesign_Tom"),
           let bundle = try? JSONDecoder().decode(AircraftDesignBundle.self, from: data) {

            // Print the decoded JSON string for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("========== LOADED JSON FOR 'Tom' (at startup) ==========")
                print(jsonString)
                print("========================================================")
            }

            currentSideProfile = bundle.sideProfile
            currentTopViewPlanform = bundle.topViewPlanform
            currentPlaneDesign = bundle.planeDesign
            currentCrossSectionPoints = bundle.crossSectionPoints
            currentSaveName = "Tom"
            print("Loaded 'Tom' design as default")
        } else {
            print("No 'Tom' save found, using built-in defaults")
        }
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

    /// Update the current flight plan
    func setFlightPlan(_ plan: FlightPlan) {
        currentFlightPlan = plan
        print("Flight plan updated: \(plan.waypoints.count) waypoints")
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
        simulator = FlightSimulator(planeDesign: currentPlaneDesign)
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

        // Find max temperature encountered
        let maxTempEncountered = segments.flatMap { $0.trajectory }.map { $0.temperature }.max() ?? 0.0
        let tempLimit = ThermalModel.getMaxTemperature(for: currentPlaneDesign)

        // Calculate score
        let score = calculateScore(fuel: totalFuel, time: totalTime, success: success, maxTemp: maxTempEncountered, tempLimit: tempLimit)

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
            score: score,
            maxTemperature: maxTempEncountered
        )

        lastMissionResult = result
        return result
    }

    /// Check if orbit was achieved
    private func checkOrbitAchieved(segments: [FlightSegmentResult]) -> Bool {
        guard let lastSegment = segments.last else { return false }

        // Convert altitude from feet to meters for comparison
        let finalAltitudeMeters = lastSegment.finalAltitude * PhysicsConstants.feetToMeters
        let altitudeReached = finalAltitudeMeters >= PhysicsConstants.orbitAltitude
        let speedReached = lastSegment.finalSpeed >= PhysicsConstants.orbitSpeed

        return altitudeReached && speedReached
    }

    /// Set the last mission result
    func setLastResult(_ result: MissionResult) {
        lastMissionResult = result
    }

    /// Calculate score based on performance and design efficiency
    private func calculateScore(fuel: Double, time: Double, success: Bool, maxTemp: Double, tempLimit: Double) -> Int {
        guard success else { return 0 }

        // Base score for success
        var score = 10000

        // Fuel efficiency bonus (Critical for SSTO)
        // Weight increased: Every liter saved is points.
        let fuelScore = max(0, Int((50000 - fuel) * 2.0))
        score += fuelScore

        // Time bonus (faster = higher score)
        let timeScore = max(0, Int((1000 - time) * 5))
        score += timeScore
        
        // Thermal Safety Bonus (Reward distinct designs that manage heat well)
        // If maxTemp is 100C below limit, +1000 pts.
        let thermalMargin = tempLimit - maxTemp
        if thermalMargin > 0 {
            let safetyBonus = Int(thermalMargin * 10)
            score += safetyBonus
        } else {
            // Penalty for cooking the ship (even if it survived the logic check)
            score -= 5000
        }

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
        let flightPlan: FlightPlan?
        let savedDate: Date

        // Custom decoding to handle old saves without flightPlan
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sideProfile = try container.decode(SideProfileShape.self, forKey: .sideProfile)
            topViewPlanform = try container.decode(TopViewPlanform.self, forKey: .topViewPlanform)
            planeDesign = try container.decode(PlaneDesign.self, forKey: .planeDesign)
            crossSectionPoints = try container.decode(CrossSectionPoints.self, forKey: .crossSectionPoints)
            flightPlan = try container.decodeIfPresent(FlightPlan.self, forKey: .flightPlan)
            savedDate = try container.decode(Date.self, forKey: .savedDate)
        }

        // Standard init
        init(sideProfile: SideProfileShape, topViewPlanform: TopViewPlanform,
             planeDesign: PlaneDesign, crossSectionPoints: CrossSectionPoints,
             flightPlan: FlightPlan?, savedDate: Date) {
            self.sideProfile = sideProfile
            self.topViewPlanform = topViewPlanform
            self.planeDesign = planeDesign
            self.crossSectionPoints = crossSectionPoints
            self.flightPlan = flightPlan
            self.savedDate = savedDate
        }
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
            flightPlan: currentFlightPlan,
            savedDate: Date()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(bundle) else {
            print("Failed to encode design bundle")
            return false
        }

        // Save to UserDefaults (always)
        UserDefaults.standard.set(data, forKey: "savedDesign_\(name)")
        currentSaveName = name  // Track the current save name
        print("Design '\(name)' saved successfully")

        // In debug builds, also write to Desktop as JSON file
        #if DEBUG
        writeDebugJSONToDesktop(name: name, data: data)
        #endif

        return true
    }

    #if DEBUG
    /// Write design JSON to Desktop for debugging (debug builds only)
    private func writeDebugJSONToDesktop(name: String, data: Data) {
        let fileManager = FileManager.default

        // Get Desktop path
        guard let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first else {
            print("Could not find Desktop directory")
            return
        }

        // Create filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "ssto_\(name)_\(timestamp).json"
        let fileURL = desktopURL.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            print("DEBUG: Design exported to \(fileURL.path)")
        } catch {
            print("DEBUG: Failed to write JSON file: \(error)")
        }
    }
    #endif

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

        // Print the decoded JSON string for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("========== LOADED JSON FOR '\(name)' ==========")
            print(jsonString)
            print("==============================================")
        }

        currentSideProfile = bundle.sideProfile
        currentTopViewPlanform = bundle.topViewPlanform
        currentPlaneDesign = bundle.planeDesign
        currentCrossSectionPoints = bundle.crossSectionPoints
        currentFlightPlan = bundle.flightPlan
        currentSaveName = name  // Track the current save name

        print("Design '\(name)' loaded successfully")
        if let flightPlan = bundle.flightPlan {
            print("Flight plan loaded: \(flightPlan.waypoints.count) waypoints")
        }
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

    /// Metadata for a saved design file
    struct SaveFileMetadata {
        let name: String
        let savedDate: Date
        let aircraftLength: Double
        let volume: Double?  // Internal volume if calculable
        let hasFlightPlan: Bool
    }

    /// Get metadata for a saved design without loading it into current state
    /// - Parameter name: The name of the design
    /// - Returns: Metadata struct, or nil if design doesn't exist
    func getSaveFileMetadata(name: String) -> SaveFileMetadata? {
        guard let data = UserDefaults.standard.data(forKey: "savedDesign_\(name)"),
              let bundle = try? JSONDecoder().decode(AircraftDesignBundle.self, from: data) else {
            return nil
        }

        // Calculate volume by temporarily setting the design (without affecting current state)
        // We'll save the current state, load the bundle, calculate volume, then restore
        let savedCurrentState = (
            sideProfile: currentSideProfile,
            topViewPlanform: currentTopViewPlanform,
            planeDesign: currentPlaneDesign,
            crossSectionPoints: currentCrossSectionPoints
        )

        // Temporarily load the design to calculate volume
        currentSideProfile = bundle.sideProfile
        currentTopViewPlanform = bundle.topViewPlanform
        currentPlaneDesign = bundle.planeDesign
        currentCrossSectionPoints = bundle.crossSectionPoints

        let volume = AircraftVolumeModel.calculateInternalVolume()

        // Restore the previous state
        currentSideProfile = savedCurrentState.sideProfile
        currentTopViewPlanform = savedCurrentState.topViewPlanform
        currentPlaneDesign = savedCurrentState.planeDesign
        currentCrossSectionPoints = savedCurrentState.crossSectionPoints

        return SaveFileMetadata(
            name: name,
            savedDate: bundle.savedDate,
            aircraftLength: bundle.topViewPlanform.aircraftLength,
            volume: volume,
            hasFlightPlan: bundle.flightPlan != nil
        )
    }

    /// Delete a saved design by name
    /// - Parameter name: The name of the design to delete
    func deleteDesign(name: String) {
        UserDefaults.standard.removeObject(forKey: "savedDesign_\(name)")
        print("Design '\(name)' deleted")
    }

    /// Update the aircraft length in the current design and auto-save
    /// Called when optimization completes with a converged length
    /// - Parameter optimizedLength: The optimized aircraft length in meters
    /// - Returns: true if update and save was successful, false otherwise
    func updateOptimizedLength(_ optimizedLength: Double) -> Bool {
        // Update the current design with the optimized length
        currentTopViewPlanform.aircraftLength = optimizedLength
        print("Updated aircraft length to \(optimizedLength) m")

        // Auto-save if we have a current save name
        if let saveName = currentSaveName {
            return saveDesign(name: saveName)
        } else {
            // No save name set - save as "Optimized Design" by default
            return saveDesign(name: "Optimized Design")
        }
    }
}
