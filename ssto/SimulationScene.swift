//
//  SimulationScene.swift
//  ssto
//
//  Created by tom whittaker on 11/25/25.
//

import SpriteKit

class SimulationScene: SKScene {
    private var missionResult: MissionResult?
    private var isSimulating = false

    // UI Elements
    private var statusLabel: SKLabelNode?
    private var resultsLabels: [SKLabelNode] = []

    // Graph
    private var graphNode: SKShapeNode?
    private var trajectoryLine: SKShapeNode?
    private var waypointNodes: [SKShapeNode] = []

    // Simulation state
    private var currentTrajectory: [TrajectoryPoint] = []
    private var currentSegmentIndex = 0
    private var waypoints: [Waypoint] = []

    // Buttons
    private var doneButton: SKLabelNode?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupUI()
        startSimulation()
    }

    private func setupUI() {
        // Title - moved up and to the left
        let titleLabel = SKLabelNode(text: "Flight Simulation")
        titleLabel.fontName = "AvenirNext-Bold"
        titleLabel.fontSize = 28
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 200, y: size.height - 35)
        titleLabel.horizontalAlignmentMode = .left
        addChild(titleLabel)

        // Status - aligned to left of screen
        statusLabel = SKLabelNode(text: "Simulating flight...")
        statusLabel?.fontName = "AvenirNext-Medium"
        statusLabel?.fontSize = 20
        statusLabel?.fontColor = .cyan
        statusLabel?.position = CGPoint(x: 50, y: size.height - 90)
        statusLabel?.horizontalAlignmentMode = .left
        if let label = statusLabel {
            addChild(label)
        }

        // Graph area (right side)
        let graphWidth: CGFloat = size.width * 0.55
        let graphHeight: CGFloat = size.height * 0.65
        let graphX = size.width - graphWidth / 2 - 40
        let graphY = size.height / 2 + 20

        graphNode = SKShapeNode(rectOf: CGSize(width: graphWidth, height: graphHeight))
        graphNode?.fillColor = UIColor(white: 0.1, alpha: 0.8)
        graphNode?.strokeColor = .white
        graphNode?.lineWidth = 2
        graphNode?.position = CGPoint(x: graphX, y: graphY)
        if let graph = graphNode {
            addChild(graph)
        }

        let graphTitle = SKLabelNode(text: "Altitude vs Time")
        graphTitle.fontName = "AvenirNext-Medium"
        graphTitle.fontSize = 16
        graphTitle.fontColor = .white
        graphTitle.position = CGPoint(x: graphX, y: graphY + graphHeight / 2 + 20)
        addChild(graphTitle)

        // Add axis labels
        let yAxisLabel = SKLabelNode(text: "Altitude (m)")
        yAxisLabel.fontName = "AvenirNext-Regular"
        yAxisLabel.fontSize = 12
        yAxisLabel.fontColor = .white
        yAxisLabel.zRotation = .pi / 2
        yAxisLabel.position = CGPoint(x: graphX - graphWidth / 2 - 35, y: graphY)
        addChild(yAxisLabel)

        let xAxisLabel = SKLabelNode(text: "Time (s)")
        xAxisLabel.fontName = "AvenirNext-Regular"
        xAxisLabel.fontSize = 12
        xAxisLabel.fontColor = .white
        xAxisLabel.position = CGPoint(x: graphX, y: graphY - graphHeight / 2 - 20)
        addChild(xAxisLabel)

        // Done button (initially hidden) - positioned under graph, smaller
        let buttonY = graphY - graphHeight / 2 - 40
        doneButton = SKLabelNode(text: "Return to Flight Plan")
        doneButton?.fontName = "AvenirNext-Medium"
        doneButton?.fontSize = 16
        doneButton?.fontColor = .white
        doneButton?.position = CGPoint(x: graphX, y: buttonY)
        doneButton?.name = "done"
        doneButton?.isHidden = true

        let buttonBG = SKShapeNode(rectOf: CGSize(width: 200, height: 40), cornerRadius: 8)
        buttonBG.fillColor = UIColor(white: 0.2, alpha: 0.6)
        buttonBG.strokeColor = .white
        buttonBG.lineWidth = 2
        buttonBG.zPosition = -1
        doneButton?.addChild(buttonBG)

        if let button = doneButton {
            addChild(button)
        }
    }

    private func createInstrumentLabel(text: String, position: CGPoint) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Regular"
        label.fontSize = 16
        label.fontColor = .white
        label.position = position
        label.horizontalAlignmentMode = .left
        return label
    }

    private func startSimulation() {
        isSimulating = true
        statusLabel?.text = "Simulating..."

        // Get waypoints from flight plan
        let plan = GameManager.shared.getFlightPlan()
        waypoints = plan.waypoints

        // Run simulation using the proper physics modules
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let result = self.runPhysicsSimulation()

            DispatchQueue.main.async {
                self.missionResult = result
                GameManager.shared.setLastResult(result)
                self.isSimulating = false
                self.showResults()
            }
        }

        // Start animation update
        animateSimulation()
    }

    private func runPhysicsSimulation() -> MissionResult {
        let planeDesign = GameManager.shared.getPlaneDesign()
        let propulsionSystem = JetEngine() // Default propulsion system for air-breathing engines

        // Calculate initial mass - now dynamic based on flight plan
        let internalVolumeM3 = AircraftVolumeModel.calculateInternalVolume()
        let fuelVolumeLiters = internalVolumeM3 * 1000.0

        // Calculate dry mass based on flight plan and design
        let dryMass = PhysicsConstants.calculateDryMass(
            volumeM3: internalVolumeM3,
            waypoints: waypoints,
            planeDesign: planeDesign,
            maxTemperature: 800.0 // Estimated - will be updated after simulation
        )

        var currentMass = dryMass + (fuelVolumeLiters * 0.086) // kg (slush hydrogen density)

        print("Dynamic dry mass calculation:")
        print("  - Volume: \(String(format: "%.1f", internalVolumeM3)) m³")
        print("  - Calculated dry mass: \(String(format: "%.0f", dryMass)) kg")
        print("  - Fuel capacity: \(String(format: "%.0f", fuelVolumeLiters * 0.086)) kg")
        print("  - Total mass: \(String(format: "%.0f", currentMass)) kg")

        var segments: [FlightSegmentResult] = []
        var totalFuel = 0.0
        var totalTime = 0.0
        var allTrajectoryPoints: [TrajectoryPoint] = []

        // Simulate each segment using the appropriate module
        for i in 0..<(waypoints.count - 1) {
            let current = waypoints[i]
            let next = waypoints[i + 1]

            currentSegmentIndex = i

            let currentAltM = current.altitude * PhysicsConstants.feetToMeters
            let nextAltM = next.altitude * PhysicsConstants.feetToMeters
            print("Simulating segment \(i + 1): \(Int(currentAltM))m @ Mach \(current.speed) → \(Int(nextAltM))m @ Mach \(next.speed)")

            // Determine which module to use based on engine mode
            let engineMode = next.engineMode != .auto ? next.engineMode : determineEngineMode(altitude: next.altitude, speed: next.speed)

            var segmentResult: FlightSegmentResult
            var fuelConsumed = 0.0

            switch engineMode {
            case .jet:
                let result = JetModule.analyzeSegment(
                    startWaypoint: current,
                    endWaypoint: next,
                    initialMass: currentMass,
                    planeDesign: planeDesign,
                    propulsion: propulsionSystem
                )
                fuelConsumed = result.fuelConsumed
                segmentResult = convertJetResultToSegment(result, from: current, to: next, timeOffset: totalTime)

            case .ramjet:
                let result = RamjetModule.analyzeSegment(
                    startWaypoint: current,
                    endWaypoint: next,
                    initialMass: currentMass,
                    planeDesign: planeDesign,
                    propulsion: propulsionSystem
                )
                fuelConsumed = result.fuelConsumed
                segmentResult = convertRamjetResultToSegment(result, from: current, to: next, timeOffset: totalTime)

            case .scramjet:
                let result = ScramjetModule.analyzeSegment(
                    startWaypoint: current,
                    endWaypoint: next,
                    initialMass: currentMass,
                    planeDesign: planeDesign,
                    propulsion: propulsionSystem
                )
                fuelConsumed = result.fuelConsumed
                segmentResult = convertScramjetResultToSegment(result, from: current, to: next, timeOffset: totalTime)

            case .rocket:
                let result = RocketModule.analyzeSegment(
                    startWaypoint: current,
                    endWaypoint: next,
                    initialMass: currentMass,
                    planeDesign: planeDesign
                )
                fuelConsumed = result.fuelConsumed
                segmentResult = convertRocketResultToSegment(result, from: current, to: next, timeOffset: totalTime)

            case .auto:
                // Shouldn't reach here, but default to jet
                let result = JetModule.analyzeSegment(
                    startWaypoint: current,
                    endWaypoint: next,
                    initialMass: currentMass,
                    planeDesign: planeDesign,
                    propulsion: propulsionSystem
                )
                fuelConsumed = result.fuelConsumed
                segmentResult = convertJetResultToSegment(result, from: current, to: next, timeOffset: totalTime)
            }

            // Update trajectory for real-time visualization
            DispatchQueue.main.async {
                self.currentTrajectory.append(contentsOf: segmentResult.trajectory)
                self.updateGraph()
            }

            segments.append(segmentResult)
            currentMass -= fuelConsumed
            totalFuel += segmentResult.fuelUsed
            totalTime += segmentResult.duration

            allTrajectoryPoints.append(contentsOf: segmentResult.trajectory)

            print("  Segment completed: \(Int(segmentResult.duration))s, \(Int(fuelConsumed))kg fuel")
        }

        // Check if orbit was achieved
        let finalSegment = segments.last
        let finalAltitude = finalSegment?.finalAltitude ?? 0
        let finalSpeed = finalSegment?.finalSpeed ?? 0

        let finalAltitudeMeters = finalAltitude * PhysicsConstants.feetToMeters
        let success = finalAltitudeMeters >= PhysicsConstants.orbitAltitude && finalSpeed >= PhysicsConstants.orbitSpeed

        // Calculate score
        let maxTemp = allTrajectoryPoints.map { $0.temperature }.max() ?? 0.0
        let tempLimit = ThermalModel.getMaxTemperature(for: planeDesign)
        let score = calculateScore(fuel: totalFuel, time: totalTime, success: success, maxTemp: maxTemp, tempLimit: tempLimit)

        return MissionResult(
            segments: segments,
            totalFuelUsed: totalFuel,
            totalDuration: totalTime,
            success: success,
            finalAltitude: finalAltitude,
            finalSpeed: finalSpeed,
            score: score,
            maxTemperature: maxTemp
        )
    }

    // Helper functions to convert module results to FlightSegmentResult
    private func convertJetResultToSegment(_ result: JetModule.JetSegmentResult, from: Waypoint, to: Waypoint, timeOffset: Double) -> FlightSegmentResult {
        let trajectory = result.trajectoryPoints.map { point in
            TrajectoryPoint(
                time: point.time + timeOffset,
                altitude: point.altitude,
                speed: point.speed,
                fuelRemaining: 0.0, // Not tracked in module results
                engineMode: .jet,
                temperature: point.temp
            )
        }
        return FlightSegmentResult(
            trajectory: trajectory,
            fuelUsed: result.fuelConsumed,
            finalAltitude: result.endAltitude,
            finalSpeed: result.endSpeed,
            duration: result.timeElapsed,
            engineUsed: .jet
        )
    }

    private func convertRamjetResultToSegment(_ result: RamjetModule.RamjetSegmentResult, from: Waypoint, to: Waypoint, timeOffset: Double) -> FlightSegmentResult {
        let trajectory = result.trajectoryPoints.map { point in
            TrajectoryPoint(
                time: point.time + timeOffset,
                altitude: point.altitude,
                speed: point.speed,
                fuelRemaining: 0.0,
                engineMode: .ramjet,
                temperature: point.temp
            )
        }
        return FlightSegmentResult(
            trajectory: trajectory,
            fuelUsed: result.fuelConsumed,
            finalAltitude: result.endAltitude,
            finalSpeed: result.endSpeed,
            duration: result.timeElapsed,
            engineUsed: .ramjet
        )
    }

    private func convertScramjetResultToSegment(_ result: ScramjetModule.ScramjetSegmentResult, from: Waypoint, to: Waypoint, timeOffset: Double) -> FlightSegmentResult {
        let trajectory = result.trajectoryPoints.map { point in
            TrajectoryPoint(
                time: point.time + timeOffset,
                altitude: point.altitude,
                speed: point.speed,
                fuelRemaining: 0.0,
                engineMode: .scramjet,
                temperature: point.temp
            )
        }
        return FlightSegmentResult(
            trajectory: trajectory,
            fuelUsed: result.fuelConsumed,
            finalAltitude: result.endAltitude,
            finalSpeed: result.endSpeed,
            duration: result.timeElapsed,
            engineUsed: .scramjet
        )
    }

    private func convertRocketResultToSegment(_ result: RocketModule.RocketSegmentResult, from: Waypoint, to: Waypoint, timeOffset: Double) -> FlightSegmentResult {
        let trajectory = result.trajectoryPoints.map { point in
            TrajectoryPoint(
                time: point.time + timeOffset,
                altitude: point.altitude,
                speed: point.speed,
                fuelRemaining: 0.0,
                engineMode: .rocket,
                temperature: point.temp
            )
        }
        return FlightSegmentResult(
            trajectory: trajectory,
            fuelUsed: result.fuelConsumed,
            finalAltitude: result.endAltitude,
            finalSpeed: result.endSpeed,
            duration: result.timeElapsed,
            engineUsed: .rocket
        )
    }

    private func determineEngineMode(altitude: Double, speed: Double) -> EngineMode {
        // Convert altitude to meters for comparison
        let altMeters = altitude * PhysicsConstants.feetToMeters

        // Rocket for extreme conditions
        if altMeters > 75000 || speed > 16.0 {
            return .rocket
        }

        // Scramjet for hypersonic
        if speed >= 5.0 && altMeters >= 25000 {
            return .scramjet
        }

        // Ramjet for supersonic
        if speed >= 2.5 && altMeters >= 12500 {
            return .ramjet
        }

        // Jet for subsonic/low supersonic
        return .jet
    }

    private func calculateScore(fuel: Double, time: Double, success: Bool, maxTemp: Double, tempLimit: Double) -> Int {
        guard success else { return 0 }

        var score = 10000

        // Fuel efficiency bonus
        let fuelScore = max(0, Int((50000 - fuel) * 2.0))
        score += fuelScore

        // Time bonus
        let timeScore = max(0, Int((1000 - time) * 5))
        score += timeScore

        // Thermal safety bonus
        let thermalMargin = tempLimit - maxTemp
        if thermalMargin > 0 {
            score += Int(thermalMargin * 10)
        }

        return score
    }

    private func animateSimulation() {
        guard isSimulating else { return }

        // Update display with current trajectory
        updateGraph()

        // Continue animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.animateSimulation()
        }
    }

    private func updateGraph() {
        guard let graphNode = graphNode else { return }
        guard !currentTrajectory.isEmpty else { return }

        // Remove old trajectory and waypoints
        trajectoryLine?.removeFromParent()
        waypointNodes.forEach { $0.removeFromParent() }
        waypointNodes.removeAll()

        // Get graph dimensions
        let graphBounds = graphNode.frame
        let graphWidth = graphBounds.width - 80
        let graphHeight = graphBounds.height - 60

        // Convert trajectory to meters
        let trajectoryMeters = currentTrajectory.map { point -> (time: Double, altitude: Double) in
            (time: point.time, altitude: point.altitude * PhysicsConstants.feetToMeters)
        }

        // Find max values for scaling
        let maxTime = max(1.0, trajectoryMeters.last?.time ?? 1.0)
        let maxAltitude = max(PhysicsConstants.orbitAltitude, trajectoryMeters.map { $0.altitude }.max() ?? 1.0)

        // Create path
        let path = CGMutablePath()
        var isFirst = true

        for point in trajectoryMeters {
            let x = (point.time / maxTime) * graphWidth - graphWidth / 2
            let y = (point.altitude / maxAltitude) * graphHeight - graphHeight / 2

            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Create and add trajectory line
        trajectoryLine = SKShapeNode(path: path)
        trajectoryLine?.strokeColor = .cyan
        trajectoryLine?.lineWidth = 3
        trajectoryLine?.position = graphNode.position
        if let line = trajectoryLine {
            addChild(line)
        }

        // Draw waypoints at their actual trajectory positions
        // Build a list of segment end times for better waypoint matching
        var segmentEndTimes: [Double] = [0.0]
        var cumulativeTime = 0.0

        if let result = missionResult {
            for segment in result.segments {
                cumulativeTime += segment.duration
                segmentEndTimes.append(cumulativeTime)
            }
        }

        // Plot each waypoint at the segment boundary
        for (index, _) in waypoints.enumerated() {
            // Use the cumulative time at this segment boundary
            let waypointTime = segmentEndTimes.count > index ? segmentEndTimes[index] : 0.0

            // Find the trajectory point at this time
            var closestPoint: (time: Double, altitude: Double)? = nil
            var minTimeDiff = Double.infinity

            for trajPoint in trajectoryMeters {
                let timeDiff = abs(trajPoint.time - waypointTime)
                if timeDiff < minTimeDiff {
                    minTimeDiff = timeDiff
                    closestPoint = trajPoint
                }
            }

            // Use the found point, or fall back to altitude-based positioning
            if let point = closestPoint {
                let x = (point.time / maxTime) * graphWidth - graphWidth / 2
                let y = (point.altitude / maxAltitude) * graphHeight - graphHeight / 2

                let node = SKShapeNode(circleOfRadius: 6)
                node.fillColor = .yellow
                node.strokeColor = .white
                node.lineWidth = 2
                node.position = CGPoint(x: graphNode.position.x + x, y: graphNode.position.y + y)
                addChild(node)
                waypointNodes.append(node)
            }
        }

        // Draw orbit line
        let orbitY = (PhysicsConstants.orbitAltitude / maxAltitude) * graphHeight - graphHeight / 2
        let orbitPath = CGMutablePath()
        orbitPath.move(to: CGPoint(x: -graphWidth / 2, y: orbitY))
        orbitPath.addLine(to: CGPoint(x: graphWidth / 2, y: orbitY))

        let orbitLine = SKShapeNode(path: orbitPath)
        orbitLine.strokeColor = .green
        orbitLine.lineWidth = 2
        orbitLine.position = graphNode.position
        orbitLine.zPosition = -1
        addChild(orbitLine)

        // Add scale labels
        let maxAltLabel = SKLabelNode(text: "\(Int(maxAltitude/1000))k")
        maxAltLabel.fontName = "AvenirNext-Regular"
        maxAltLabel.fontSize = 10
        maxAltLabel.fontColor = .white
        maxAltLabel.horizontalAlignmentMode = .right
        maxAltLabel.position = CGPoint(x: graphNode.position.x - graphWidth / 2 - 5, y: graphNode.position.y + graphHeight / 2 - 5)
        addChild(maxAltLabel)

        let maxTimeLabel = SKLabelNode(text: "\(Int(maxTime))")
        maxTimeLabel.fontName = "AvenirNext-Regular"
        maxTimeLabel.fontSize = 10
        maxTimeLabel.fontColor = .white
        maxTimeLabel.position = CGPoint(x: graphNode.position.x + graphWidth / 2, y: graphNode.position.y - graphHeight / 2 - 10)
        addChild(maxTimeLabel)
    }

    private func showResults() {
        guard let result = missionResult else { return }

        // Update final graph
        currentTrajectory = result.completeTrajectory()
        updateGraph()

        // Calculate adjusted dry mass based on actual max temperature from simulation
        let internalVolumeM3 = AircraftVolumeModel.calculateInternalVolume()
        let planeDesign = GameManager.shared.getPlaneDesign()
        let flightPlan = GameManager.shared.getFlightPlan()

        let adjustedMass = PhysicsConstants.calculateDryMass(
            volumeM3: internalVolumeM3,
            waypoints: flightPlan.waypoints,
            planeDesign: planeDesign,
            maxTemperature: result.maxTemperature
        )

        // For comparison, calculate with baseline temperature
        let baseMass = PhysicsConstants.calculateDryMass(
            volumeM3: internalVolumeM3,
            waypoints: flightPlan.waypoints,
            planeDesign: planeDesign,
            maxTemperature: 600.0 // Baseline (no thermal protection penalty)
        )

        let massIncrease = adjustedMass - baseMass
        let percentIncrease = (massIncrease / baseMass) * 100.0

        // Show completion status
        if result.success {
            statusLabel?.text = "ORBIT ACHIEVED!"
            statusLabel?.fontColor = .green

            // Add to leaderboard if successful
            promptForLeaderboardEntry(result: result)
        } else {
            let finalAltMeters = result.finalAltitude * PhysicsConstants.feetToMeters
            statusLabel?.text = String(format: "FAILED - Reached %dm at Mach %.1f",
                                     Int(finalAltMeters), result.finalSpeed)
            statusLabel?.fontColor = .red
        }

        // Display detailed results as a list on the left
        displayResultsList(result: result, adjustedMass: adjustedMass, percentIncrease: percentIncrease)

        // Show done button
        doneButton?.isHidden = false
    }

    private func displayResultsList(result: MissionResult, adjustedMass: Double, percentIncrease: Double) {
        // Remove any existing result labels
        resultsLabels.forEach { $0.removeFromParent() }
        resultsLabels.removeAll()

        let startY: CGFloat = size.height - 140
        let lineSpacing: CGFloat = 25
        let leftMargin: CGFloat = 50

        // Calculate additional stats
        let internalVolumeM3 = AircraftVolumeModel.calculateInternalVolume()
        let fuelCapacityKg = internalVolumeM3 * 1000.0 * 0.086

        // Create result labels
        let resultData: [(String, UIColor)] = [
            ("Score: \(result.score)", .green),
            ("", .clear),  // Spacer
            ("Final Altitude: \(Int(result.finalAltitude * PhysicsConstants.feetToMeters).formatted()) m", .white),
            ("Final Speed: Mach \(String(format: "%.1f", result.finalSpeed))", .white),
            ("Flight Time: \(Int(result.totalDuration)) s", .white),
            ("", .clear),  // Spacer
            ("Max Temperature: \(Int(result.maxTemperature))°C", result.maxTemperature > 1600 ? .orange : .white),
            ("Dry Mass: \(Int(adjustedMass).formatted()) kg", .green),
            ("Thermal Penalty: +\(String(format: "%.1f", percentIncrease))%", percentIncrease > 10 ? .orange : .green),
            ("", .clear),  // Spacer
            ("Fuel Used: \(Int(result.totalFuelUsed).formatted()) kg", .white),
            ("Fuel Capacity: \(Int(fuelCapacityKg).formatted()) kg", .white),
            ("Volume: \(String(format: "%.1f", internalVolumeM3)) m³", .yellow)
        ]

        for (index, data) in resultData.enumerated() {
            let label = SKLabelNode(text: data.0)
            label.fontName = data.0.isEmpty ? "" : (data.0.hasPrefix("Score:") ? "AvenirNext-Bold" : "AvenirNext-Regular")
            label.fontSize = data.0.hasPrefix("Score:") ? 20 : 16
            label.fontColor = data.1
            label.position = CGPoint(x: leftMargin, y: startY - CGFloat(index) * lineSpacing)
            label.horizontalAlignmentMode = .left

            if !data.0.isEmpty {
                addChild(label)
                resultsLabels.append(label)
            }
        }
    }

    private func promptForLeaderboardEntry(result: MissionResult) {
        #if os(iOS)
        guard let viewController = view?.window?.rootViewController else {
            // Fallback: add with default name
            addToLeaderboard(playerName: "Player")
            return
        }

        let volume = AircraftVolumeModel.calculateInternalVolume()

        // Check if this would make top 10
        let wouldMakeTop10 = LeaderboardManager.shared.wouldMakeTopTen(volume: volume)

        let title = wouldMakeTop10 ? "Top 10 Achievement!" : "Mission Success!"
        let message = wouldMakeTop10
            ? "Your vehicle (\(String(format: "%.1f", volume)) m³) would rank in the top 10!\nEnter your name for the leaderboard:"
            : "Mission successful! Enter your name:"

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "Player Name"
            textField.text = "Player"
        }

        alert.addAction(UIAlertAction(title: "Submit", style: .default) { [weak self] _ in
            let name = alert.textFields?.first?.text ?? "Player"
            self?.addToLeaderboard(playerName: name)
        })

        alert.addAction(UIAlertAction(title: "Skip", style: .cancel) { [weak self] _ in
            self?.addToLeaderboard(playerName: "Anonymous")
        })

        viewController.present(alert, animated: true)
        #else
        // For non-iOS platforms, use default name
        addToLeaderboard(playerName: "Player")
        #endif
    }

    private func addToLeaderboard(playerName: String) {
        let planform = GameManager.shared.getTopViewPlanform()
        let optimalLength = planform.aircraftLength

        // Calculate internal volume and fuel capacity
        let internalVolumeM3 = AircraftVolumeModel.calculateInternalVolume()
        let fuelCapacityKg = internalVolumeM3 * 1000.0 * 0.086 // Slush hydrogen density

        LeaderboardManager.shared.addEntry(
            playerName: playerName.isEmpty ? "Player" : playerName,
            volume: internalVolumeM3,
            optimalLength: optimalLength,
            fuelCapacity: fuelCapacityKg
        )

        print("Added to leaderboard: \(playerName) with \(String(format: "%.1f", internalVolumeM3)) m³ volume")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)

        for node in touchedNodes {
            if let labelNode = node as? SKLabelNode, labelNode.name == "done" {
                returnToFlightPlan()
            }
        }
    }

    private func returnToFlightPlan() {
        let transition = SKTransition.fade(withDuration: 0.5)
        let planningScene = FlightPlanningScene(size: size)
        planningScene.scaleMode = .aspectFill
        view?.presentScene(planningScene, transition: transition)
    }
}
