//
//  FlightPlanningScene.swift
//  ssto
//
//  Created by tom whittaker on 11/25/25.
//

import SpriteKit

class FlightPlanningScene: SKScene {
    private var flightPlan: FlightPlan!
    private var waypointLabels: [SKLabelNode] = []

    // UI Elements
    private var titleLabel: SKLabelNode?
    private var altitudeInputBox: TextInputBox?
    private var speedInputBox: TextInputBox?
    private var engineLabel: SKLabelNode?
    private var addButton: SKLabelNode?
    private var simulateButton: SKLabelNode?
    private var backButton: SKLabelNode?

    // Graph elements
    private var graphNode: SKNode?
    private var graphPoints: [SKShapeNode] = []
    private var graphLines: [SKShapeNode] = []
    private var xAxisLabels: [SKLabelNode] = []
    private var yAxisLabels: [SKLabelNode] = []

    // Graph parameters
    private var maxTimeMinutes: CGFloat = 60.0 // X-axis max (minutes)
    private var maxAltitudeKm: CGFloat = 20.0  // Y-axis max (kilometers)

    // Current waypoint being edited
    private var currentAltitudeThousands: Int = 100 // In thousands of feet
    private var currentSpeed: Double = 10.0
    private var currentEngine: EngineMode = .auto

    // Active text input
    private var activeInput: TextInputBox?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        flightPlan = GameManager.shared.getFlightPlan()

        setupUI()
        setupGraph()
        refreshWaypointList()
        updateGraph()
    }

    private func setupUI() {
        // Title
        titleLabel = SKLabelNode(text: "Flight Planning")
        titleLabel?.fontName = "AvenirNext-Bold"
        titleLabel?.fontSize = 28
        titleLabel?.fontColor = .white
        titleLabel?.position = CGPoint(x: size.width / 2, y: size.height - 50)
        if let label = titleLabel {
            addChild(label)
        }

        // Waypoint editor section (right side) - 10 pixels from right edge
        let inputBoxX = size.width - 150 - 50 // 10px from right, 50 is half the box width (100/2)
        let startY = size.height - 40

        let editorTitle = SKLabelNode(text: "New Waypoint")
        editorTitle.fontName = "AvenirNext-Medium"
        editorTitle.fontSize = 20
        editorTitle.fontColor = .cyan
        editorTitle.position = CGPoint(x: inputBoxX, y: startY)
        addChild(editorTitle)

        // Altitude input
        let altLabel = SKLabelNode(text: "Altitude (x1000 ft):")
        altLabel.fontName = "AvenirNext-Regular"
        altLabel.fontSize = 16
        altLabel.fontColor = .white
        altLabel.position = CGPoint(x: inputBoxX - 50, y: startY - 40)
        altLabel.horizontalAlignmentMode = .right
        addChild(altLabel)

        altitudeInputBox = TextInputBox(
            position: CGPoint(x: inputBoxX + 50, y: startY - 35),
            width: 100,
            height: 35,
            initialValue: "100",
            inputType: .integer
        )
        if let inputBox = altitudeInputBox {
            addChild(inputBox)
        }

        // Speed input
        let speedLabel = SKLabelNode(text: "Speed (Mach):")
        speedLabel.fontName = "AvenirNext-Regular"
        speedLabel.fontSize = 16
        speedLabel.fontColor = .white
        speedLabel.position = CGPoint(x: inputBoxX - 50, y: startY - 90)
        speedLabel.horizontalAlignmentMode = .right
        addChild(speedLabel)

        speedInputBox = TextInputBox(
            position: CGPoint(x: inputBoxX + 50, y: startY - 85),
            width: 100,
            height: 35,
            initialValue: "10.0",
            inputType: .float
        )
        if let inputBox = speedInputBox {
            addChild(inputBox)
        }

        // Engine mode controls
        let engineTitleLabel = SKLabelNode(text: "Engine Mode:")
        engineTitleLabel.fontName = "AvenirNext-Regular"
        engineTitleLabel.fontSize = 16
        engineTitleLabel.fontColor = .white
        engineTitleLabel.position = CGPoint(x: inputBoxX - 50, y: startY - 140)
        engineTitleLabel.horizontalAlignmentMode = .right
        addChild(engineTitleLabel)

        engineLabel = createLabel(text: "Auto", position: CGPoint(x: inputBoxX, y: startY - 140))
        if let label = engineLabel {
            addChild(label)
        }

        let engineButton = createSmallButton(text: "Change", position: CGPoint(x: inputBoxX + 80, y: startY - 140), name: "change_engine")
        addChild(engineButton)

        // Add waypoint button
        addButton = createButton(text: "Add Waypoint", position: CGPoint(x: inputBoxX, y: startY - 200), name: "add_waypoint")
        if let button = addButton {
            addChild(button)
        }

        // Start simulation button (under add waypoint)
        simulateButton = createButton(text: "Start Simulation", position: CGPoint(x: inputBoxX, y: startY - 260), name: "simulate")
        if let button = simulateButton {
            addChild(button)
        }

        // Back button (under start simulation)
        backButton = createButton(text: "Back to Menu", position: CGPoint(x: inputBoxX, y: startY - 320), name: "back")
        if let button = backButton {
            addChild(button)
        }
    }

    private func setupGraph() {
        // Create main graph container
        graphNode = SKNode()
        if let graph = graphNode {
            addChild(graph)
        }

        // Graph dimensions - Y-axis 10 pixels from left edge
        let yAxisX: CGFloat = 10
        let graphWidth = size.width * 0.5
        let graphHeight = size.height * 0.6
        let graphCenterY = size.height * 0.45

        // Draw axes
        // Y-axis (vertical, 10px from left)
        let yAxis = SKShapeNode()
        let yAxisPath = CGMutablePath()
        yAxisPath.move(to: CGPoint(x: yAxisX, y: graphCenterY - graphHeight / 2))
        yAxisPath.addLine(to: CGPoint(x: yAxisX, y: graphCenterY + graphHeight / 2))
        yAxis.path = yAxisPath
        yAxis.strokeColor = .white
        yAxis.lineWidth = 2
        graphNode?.addChild(yAxis)

        // X-axis (horizontal, along the bottom)
        let xAxis = SKShapeNode()
        let xAxisPath = CGMutablePath()
        xAxisPath.move(to: CGPoint(x: yAxisX, y: graphCenterY - graphHeight / 2))
        xAxisPath.addLine(to: CGPoint(x: yAxisX + graphWidth, y: graphCenterY - graphHeight / 2))
        xAxis.path = xAxisPath
        xAxis.strokeColor = .white
        xAxis.lineWidth = 2
        graphNode?.addChild(xAxis)

        // Add grid lines and labels
        drawGraphGrid(yAxisX: yAxisX, centerY: graphCenterY, width: graphWidth, height: graphHeight)

        // Add axis titles
        let xTitle = SKLabelNode(text: "Time (minutes)")
        xTitle.fontName = "AvenirNext-Medium"
        xTitle.fontSize = 14
        xTitle.fontColor = .white
        xTitle.position = CGPoint(x: yAxisX + graphWidth / 2, y: graphCenterY - graphHeight / 2 - 40)
        graphNode?.addChild(xTitle)

        let yTitle = SKLabelNode(text: "Altitude (km)")
        yTitle.fontName = "AvenirNext-Medium"
        yTitle.fontSize = 14
        yTitle.fontColor = .white
        yTitle.position = CGPoint(x: yAxisX + 50, y: graphCenterY + graphHeight / 2 + 10)
        graphNode?.addChild(yTitle)
    }

    private func drawGraphGrid(yAxisX: CGFloat, centerY: CGFloat, width: CGFloat, height: CGFloat) {
        // Clear old labels
        for label in xAxisLabels {
            label.removeFromParent()
        }
        for label in yAxisLabels {
            label.removeFromParent()
        }
        xAxisLabels.removeAll()
        yAxisLabels.removeAll()

        // X-axis labels (time in minutes)
        let numXDivisions = 6
        for i in 0...numXDivisions {
            let fraction = CGFloat(i) / CGFloat(numXDivisions)
            let xPos = yAxisX + width * fraction
            let yPos = centerY - height / 2

            // Grid line
            if i > 0 {
                let gridLine = SKShapeNode()
                let gridPath = CGMutablePath()
                gridPath.move(to: CGPoint(x: xPos, y: yPos))
                gridPath.addLine(to: CGPoint(x: xPos, y: centerY + height / 2))
                gridLine.path = gridPath
                gridLine.strokeColor = UIColor(white: 0.3, alpha: 0.5)
                gridLine.lineWidth = 1
                graphNode?.addChild(gridLine)
            }

            // Label
            let timeValue = Int(maxTimeMinutes * fraction)
            let label = SKLabelNode(text: "\(timeValue)")
            label.fontName = "AvenirNext-Regular"
            label.fontSize = 12
            label.fontColor = .gray
            label.position = CGPoint(x: xPos, y: yPos - 20)
            graphNode?.addChild(label)
            xAxisLabels.append(label)
        }

        // Y-axis labels (altitude in km)
        let numYDivisions = 5
        for i in 0...numYDivisions {
            let fraction = CGFloat(i) / CGFloat(numYDivisions)
            let xPos = yAxisX
            let yPos = centerY - height / 2 + height * fraction

            // Grid line
            if i > 0 {
                let gridLine = SKShapeNode()
                let gridPath = CGMutablePath()
                gridPath.move(to: CGPoint(x: xPos, y: yPos))
                gridPath.addLine(to: CGPoint(x: yAxisX + width, y: yPos))
                gridLine.path = gridPath
                gridLine.strokeColor = UIColor(white: 0.3, alpha: 0.5)
                gridLine.lineWidth = 1
                graphNode?.addChild(gridLine)
            }

            // Label
            let altValue = Int(maxAltitudeKm * fraction)
            let label = SKLabelNode(text: "\(altValue)")
            label.fontName = "AvenirNext-Regular"
            label.fontSize = 12
            label.fontColor = .gray
            label.position = CGPoint(x: xPos + 25, y: yPos - 5)
            label.horizontalAlignmentMode = .left
            graphNode?.addChild(label)
            yAxisLabels.append(label)
        }
    }

    private func updateGraph() {
        // Clear old graph elements
        for point in graphPoints {
            point.removeFromParent()
        }
        for line in graphLines {
            line.removeFromParent()
        }
        graphPoints.removeAll()
        graphLines.removeAll()

        // Calculate time-altitude points from waypoints
        var timePoints: [(time: Double, altitude: Double)] = []
        var cumulativeTime: Double = 0.0

        for i in 0..<flightPlan.waypoints.count {
            let waypoint = flightPlan.waypoints[i]

            if i > 0 {
                // Calculate time to reach this waypoint from previous
                let prevWaypoint = flightPlan.waypoints[i - 1]
                let altitudeDiff = abs(waypoint.altitude - prevWaypoint.altitude) // feet

                // Estimate horizontal distance (simplified - assumes 45-degree climb/descent)
                let verticalDistance = altitudeDiff
                let horizontalDistance = sqrt(2.0) * verticalDistance // Rough estimate

                // Calculate time based on average speed between waypoints
                let averageSpeed = (prevWaypoint.speed + waypoint.speed) / 2.0
                let speedFeetPerSecond = averageSpeed * PhysicsConstants.speedOfSoundSeaLevel * PhysicsConstants.metersToFeet
                let timeSeconds = horizontalDistance / speedFeetPerSecond
                cumulativeTime += timeSeconds
            }

            let altitudeKm = waypoint.altitude * PhysicsConstants.feetToMeters / 1000.0
            timePoints.append((time: cumulativeTime / 60.0, altitude: altitudeKm)) // Convert to minutes
        }

        // Adapt graph scale if needed
        adaptGraphScale(timePoints: timePoints)

        // Draw points and lines
        let yAxisX: CGFloat = 10
        let graphWidth = size.width * 0.5
        let graphHeight = size.height * 0.6
        let graphCenterY = size.height * 0.45

        for i in 0..<timePoints.count {
            let point = timePoints[i]

            // Calculate screen position
            let xFraction = CGFloat(point.time / maxTimeMinutes)
            let yFraction = CGFloat(point.altitude / maxAltitudeKm)

            let screenX = yAxisX + graphWidth * xFraction
            let screenY = graphCenterY - graphHeight / 2 + graphHeight * yFraction

            // Draw circle at point
            let circle = SKShapeNode(circleOfRadius: 5)
            circle.fillColor = .cyan
            circle.strokeColor = .white
            circle.lineWidth = 2
            circle.position = CGPoint(x: screenX, y: screenY)
            graphNode?.addChild(circle)
            graphPoints.append(circle)

            // Draw line from previous point
            if i > 0 {
                let prevPoint = timePoints[i - 1]
                let prevXFraction = CGFloat(prevPoint.time / maxTimeMinutes)
                let prevYFraction = CGFloat(prevPoint.altitude / maxAltitudeKm)

                let prevScreenX = yAxisX + graphWidth * prevXFraction
                let prevScreenY = graphCenterY - graphHeight / 2 + graphHeight * prevYFraction

                let line = SKShapeNode()
                let linePath = CGMutablePath()
                linePath.move(to: CGPoint(x: prevScreenX, y: prevScreenY))
                linePath.addLine(to: CGPoint(x: screenX, y: screenY))
                line.path = linePath
                line.strokeColor = .cyan
                line.lineWidth = 2
                graphNode?.addChild(line)
                graphLines.append(line)
            }
        }
    }

    private func adaptGraphScale(timePoints: [(time: Double, altitude: Double)]) {
        // Find max values in data
        var maxTime: Double = 60.0 // Default to 60 minutes
        var maxAlt: Double = 20.0  // Default to 20 km

        for point in timePoints {
            maxTime = max(maxTime, point.time)
            maxAlt = max(maxAlt, point.altitude)
        }

        // Round up to nice values
        maxTimeMinutes = CGFloat(ceil(maxTime / 10.0) * 10.0) // Round to nearest 10 minutes
        maxAltitudeKm = CGFloat(ceil(maxAlt / 5.0) * 5.0)     // Round to nearest 5 km

        // Ensure minimum scale
        maxTimeMinutes = max(60, maxTimeMinutes)
        maxAltitudeKm = max(20, maxAltitudeKm)

        // Redraw grid with new scale
        let yAxisX: CGFloat = 10
        let graphWidth = size.width * 0.5
        let graphHeight = size.height * 0.6
        let graphCenterY = size.height * 0.45
        drawGraphGrid(yAxisX: yAxisX, centerY: graphCenterY, width: graphWidth, height: graphHeight)
    }

    private func refreshWaypointList() {
        // Clear existing labels
        for label in waypointLabels {
            label.removeFromParent()
        }
        waypointLabels.removeAll()

        // Create new labels for each waypoint - positioned at 15% from left
        let startY = size.height - 130
        let spacing: CGFloat = 30
        let listX = size.width * 0.15

        let listTitle = SKLabelNode(text: "Waypoints")
        listTitle.fontName = "AvenirNext-Medium"
        listTitle.fontSize = 20
        listTitle.fontColor = .cyan
        listTitle.position = CGPoint(x: listX, y: size.height - 50)
        listTitle.horizontalAlignmentMode = .left
        addChild(listTitle)
        waypointLabels.append(listTitle)

        for (index, waypoint) in flightPlan.waypoints.enumerated() {
            let altThousands = Int(waypoint.altitude / 1000)
            let text = "WP\(index + 1): \(altThousands)k ft, M\(String(format: "%.1f", waypoint.speed)), \(waypoint.engineMode.rawValue)"
            let label = SKLabelNode(text: text)
            label.fontName = "AvenirNext-Regular"
            label.fontSize = 14
            label.fontColor = index == 0 ? .gray : .white
            label.position = CGPoint(x: listX, y: startY - CGFloat(index) * spacing)
            label.horizontalAlignmentMode = .left
            label.name = "waypoint_\(index)"
            addChild(label)
            waypointLabels.append(label)
        }
    }

    private func createLabel(text: String, position: CGPoint) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Regular"
        label.fontSize = 16
        label.fontColor = .white
        label.position = position
        return label
    }

    private func createButton(text: String, position: CGPoint, name: String) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontName = "AvenirNext-Medium"
        button.fontSize = 20
        button.fontColor = .white
        button.position = position
        button.name = name
        button.verticalAlignmentMode = .center

        let background = SKShapeNode(rectOf: CGSize(width: 200, height: 40), cornerRadius: 8)
        background.fillColor = UIColor(white: 0.2, alpha: 0.6)
        background.strokeColor = .white
        background.lineWidth = 2
        background.zPosition = -1
        button.addChild(background)

        return button
    }

    private func createSmallButton(text: String, position: CGPoint, name: String) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontName = "AvenirNext-Medium"
        button.fontSize = 14
        button.fontColor = .white
        button.position = position
        button.name = name
        button.verticalAlignmentMode = .center

        let background = SKShapeNode(rectOf: CGSize(width: 80, height: 30), cornerRadius: 5)
        background.fillColor = UIColor(white: 0.3, alpha: 0.6)
        background.strokeColor = .white
        background.lineWidth = 1
        background.zPosition = -1
        button.addChild(background)

        return button
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)

        // Check if tapping on a text input box
        if let altBox = altitudeInputBox, altBox.contains(location) {
            activateInput(altBox)
            return
        }

        if let speedBox = speedInputBox, speedBox.contains(location) {
            activateInput(speedBox)
            return
        }

        // Deactivate any active input
        deactivateInput()

        // Check other buttons
        for node in touchedNodes {
            if let labelNode = node as? SKLabelNode, let name = labelNode.name {
                handleButtonTap(name)
            }
        }
    }

    private func activateInput(_ inputBox: TextInputBox) {
        // Deactivate previous input
        activeInput?.setActive(false)

        // Activate new input
        inputBox.setActive(true)
        activeInput = inputBox

        #if os(iOS)
        // Show alert dialog for input on iOS
        showInputAlert(for: inputBox)
        #endif
    }

    #if os(iOS)
    private func showInputAlert(for inputBox: TextInputBox) {
        guard let viewController = view?.window?.rootViewController else { return }

        // Determine which input box this is
        let isAltitude = (inputBox === altitudeInputBox)
        let isSpeed = (inputBox === speedInputBox)

        let title = isAltitude ? "Enter Altitude" : "Enter Speed"
        let message = isAltitude ? "Altitude in thousands of feet" : "Speed in Mach number"

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = isAltitude ? "e.g., 100" : "e.g., 10.0"
            textField.text = inputBox.getValue()
            textField.keyboardType = isAltitude ? .numberPad : .decimalPad
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.deactivateInput()
        })

        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self else { return }
            if let text = alert.textFields?.first?.text, !text.isEmpty {
                inputBox.updateValue(text)

                if isAltitude {
                    if let value = Int(text) {
                        self.currentAltitudeThousands = value
                    }
                } else if isSpeed {
                    if let value = Double(text) {
                        self.currentSpeed = value
                    }
                }
            }
            self.deactivateInput()
        })

        viewController.present(alert, animated: true)
    }
    #endif

    private func deactivateInput() {
        activeInput?.setActive(false)
        activeInput = nil
    }

    #if os(macOS)
    override func keyDown(with event: NSEvent) {
        guard let activeInput = activeInput else { return }

        if let characters = event.characters {
            for char in characters {
                if char == "\r" || char == "\n" {
                    // Enter key - deactivate input
                    deactivateInput()
                } else if char == "\u{7f}" {
                    // Delete/backspace
                    activeInput.deleteCharacter()
                } else {
                    // Regular character
                    activeInput.addCharacter(char)
                }
            }
        }
    }
    #endif

    private func handleButtonTap(_ name: String) {
        switch name {
        case "change_engine":
            cycleEngine()
        case "add_waypoint":
            addWaypoint()
        case "simulate":
            startSimulation()
        case "back":
            returnToMenu()
        default:
            break
        }
    }

    private func cycleEngine() {
        let allModes: [EngineMode] = [.auto, .ejectorRamjet, .ramjet, .scramjet, .rocket]
        if let currentIndex = allModes.firstIndex(of: currentEngine) {
            let nextIndex = (currentIndex + 1) % allModes.count
            currentEngine = allModes[nextIndex]
            engineLabel?.text = currentEngine.rawValue
        }
    }

    private func addWaypoint() {
        // Get values from text boxes
        guard let altText = altitudeInputBox?.getValue(),
              let altThousands = Int(altText),
              let speedText = speedInputBox?.getValue(),
              let speed = Double(speedText) else {
            print("Invalid input values")
            return
        }

        let altitude = Double(altThousands) * 1000.0 // Convert to feet
        let waypoint = Waypoint(altitude: altitude, speed: speed, engineMode: currentEngine)
        flightPlan.addWaypoint(waypoint)
        refreshWaypointList()
        updateGraph()
    }

    private func startSimulation() {
        guard flightPlan.isValidForFlight() else {
            print("Flight plan is not valid for launch!")
            return
        }

        let transition = SKTransition.fade(withDuration: 0.5)
        let simulationScene = SimulationScene(size: size)
        simulationScene.scaleMode = .aspectFill
        view?.presentScene(simulationScene, transition: transition)
    }

    private func returnToMenu() {
        let transition = SKTransition.fade(withDuration: 0.5)
        let menuScene = MenuScene(size: size)
        menuScene.scaleMode = .aspectFill
        view?.presentScene(menuScene, transition: transition)
    }
}

