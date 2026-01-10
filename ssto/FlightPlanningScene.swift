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
    private var maxGInputBox: TextInputBox?
    private var engineLabel: SKLabelNode?
    private var addButton: SKLabelNode?
    private var simulateButton: SKLabelNode?
    private var backButton: SKLabelNode?
    private var saveButton: SKLabelNode?
    private var deleteButton: SKLabelNode?
    private var defaultButton: SKLabelNode?

    // Graph elements
    private var graphNode: SKNode?
    private var graphPoints: [SKShapeNode] = []
    private var graphLines: [SKShapeNode] = []
    private var xAxisLabels: [SKLabelNode] = []
    private var yAxisLabels: [SKLabelNode] = []

    // Graph parameters
    private var maxMach: CGFloat = 24.0         // X-axis max (Mach number)
    private var maxAltitudeMeters: CGFloat = 200000.0  // Y-axis max (meters)

    // Current waypoint being edited
    private var currentAltitudeThousands: Int = 100 // In thousands of feet
    private var currentSpeed: Double = 10.0
    private var currentEngine: EngineMode = .auto
    private var currentMaxG: Double = 2.0 // Maximum G-force for rocket mode

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

        // Default flight plan button (to the left of Delete)
        defaultButton = createSmallButton(text: "Default", position: CGPoint(x: inputBoxX - 10, y: startY + 10), name: "default_plan")
        if let button = defaultButton {
            addChild(button)
        }

        // Delete last waypoint button
        deleteButton = createSmallButton(text: "Delete", position: CGPoint(x: inputBoxX + 80, y: startY + 10), name: "delete_waypoint")
        if let button = deleteButton {
            addChild(button)
        }

        // Altitude input
        let altLabel = SKLabelNode(text: "Altitude (m):")
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
            initialValue: "30000",
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

        // Max G input (for rocket mode)
        let maxGTitleLabel = SKLabelNode(text: "Max G (Rocket):")
        maxGTitleLabel.fontName = "AvenirNext-Regular"
        maxGTitleLabel.fontSize = 16
        maxGTitleLabel.fontColor = .white
        maxGTitleLabel.position = CGPoint(x: inputBoxX - 50, y: startY - 180)
        maxGTitleLabel.horizontalAlignmentMode = .right
        addChild(maxGTitleLabel)

        maxGInputBox = TextInputBox(
            position: CGPoint(x: inputBoxX + 50, y: startY - 185),
            width: 100,
            height: 35,
            initialValue: "2.0",
            inputType: .float
        )
        if let inputBox = maxGInputBox {
            addChild(inputBox)
        }

        // Add waypoint button
        addButton = createButton(text: "Add Waypoint", position: CGPoint(x: inputBoxX, y: startY - 230), name: "add_waypoint")
        if let button = addButton {
            addChild(button)
        }

        // Start simulation button (under add waypoint)
        simulateButton = createButton(text: "Start Simulation", position: CGPoint(x: inputBoxX, y: startY - 272), name: "simulate")
        if let button = simulateButton {
            addChild(button)
        }

        // Back button (under start simulation)
        backButton = createButton(text: "Back to Menu", position: CGPoint(x: inputBoxX, y: startY - 314), name: "back")
        if let button = backButton {
            addChild(button)
        }

        // Save button (under back button)
        saveButton = createButton(text: "Save Game", position: CGPoint(x: inputBoxX, y: startY - 356), name: "save_game")
        if let button = saveButton {
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
        let xTitle = SKLabelNode(text: "Mach")
        xTitle.fontName = "AvenirNext-Medium"
        xTitle.fontSize = 14
        xTitle.fontColor = .white
        xTitle.position = CGPoint(x: yAxisX + graphWidth / 2, y: graphCenterY - graphHeight / 2 - 40)
        graphNode?.addChild(xTitle)

        let yTitle = SKLabelNode(text: "Altitude (m)")
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

        // X-axis labels (Mach number)
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
            let machValue = maxMach * fraction
            let label = SKLabelNode(text: String(format: "%.0f", machValue))
            label.fontName = "AvenirNext-Regular"
            label.fontSize = 12
            label.fontColor = .gray
            label.position = CGPoint(x: xPos, y: yPos - 20)
            graphNode?.addChild(label)
            xAxisLabels.append(label)
        }

        // Y-axis labels (altitude in meters, linear scale)
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

            // Label - using linear scale
            let altValue = Double(maxAltitudeMeters) * Double(fraction)
            let label = SKLabelNode(text: String(format: "%.0f", altValue))
            label.fontName = "AvenirNext-Regular"
            label.fontSize = 12
            label.fontColor = .gray
            label.position = CGPoint(x: xPos + 30, y: yPos - 5)
            label.horizontalAlignmentMode = .left
            graphNode?.addChild(label)
            yAxisLabels.append(label)
        }
    }

    private func updateGraph() {
        // Clear old graph elements
        graphNode?.removeAllChildren()
        graphPoints.removeAll()
        graphLines.removeAll()

        // Calculate mach-altitude points from waypoints
        var machAltitudePoints: [(mach: Double, altitude: Double)] = []

        for waypoint in flightPlan.waypoints {
            let altitudeMeters = waypoint.altitude * PhysicsConstants.feetToMeters
            let mach = waypoint.speed
            machAltitudePoints.append((mach: mach, altitude: altitudeMeters))
        }

        // Adapt graph scale if needed
        adaptGraphScale(machAltitudePoints: machAltitudePoints)

        // Draw points and lines
        let yAxisX: CGFloat = 10
        let graphWidth = size.width * 0.5
        let graphHeight = size.height * 0.6
        let graphCenterY = size.height * 0.45

        for i in 0..<machAltitudePoints.count {
            let point = machAltitudePoints[i]

            // Calculate screen position
            // X-axis: linear scale for Mach
            let xFraction = CGFloat(point.mach / Double(maxMach))

            // Y-axis: linear scale for altitude
            let yFraction = CGFloat(point.altitude / Double(maxAltitudeMeters))

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
                let prevPoint = machAltitudePoints[i - 1]
                let prevXFraction = CGFloat(prevPoint.mach / Double(maxMach))
                let prevYFraction = CGFloat(prevPoint.altitude / Double(maxAltitudeMeters))

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

        // Always draw max altitude reference lines for jet, ramjet, and scramjet
        drawAltitudeLimitLines(graphWidth: graphWidth, graphHeight: graphHeight, graphCenterY: graphCenterY, yAxisX: yAxisX)
    }

    private func drawAltitudeLimitLines(graphWidth: CGFloat, graphHeight: CGFloat, graphCenterY: CGFloat, yAxisX: CGFloat) {
        // Define engine max altitudes with colors (altitudes in meters)
        let engineLimits: [(altitude: Double, name: String, color: UIColor)] = [
            (JetModule.maxAltitude, "Jet", UIColor.systemBlue),
            (RamjetModule.maxAltitude, "Ramjet", UIColor.systemOrange),
            (ScramjetModule.maxAltitude, "Scramjet", UIColor.systemPurple)
        ]

        for engineLimit in engineLimits {
            let altitudeMeters = engineLimit.altitude
            // Linear scale for altitude
            let yFraction = CGFloat(altitudeMeters / Double(maxAltitudeMeters))
            let screenY = graphCenterY - graphHeight / 2 + graphHeight * yFraction

            // Only draw if within visible range
            if yFraction >= 0 && yFraction <= 1.0 {
                let line = SKShapeNode()
                let linePath = CGMutablePath()
                linePath.move(to: CGPoint(x: yAxisX, y: screenY))
                linePath.addLine(to: CGPoint(x: yAxisX + graphWidth, y: screenY))
                line.path = linePath
                line.strokeColor = engineLimit.color
                line.lineWidth = 1.5
                line.alpha = 0.5

                // Add dashed pattern
                let pattern: [CGFloat] = [4, 4]
                line.path = linePath.copy(dashingWithPhase: 0, lengths: pattern)

                graphNode?.addChild(line)
                graphLines.append(line)

                // Add label
                let label = SKLabelNode(text: engineLimit.name)
                label.fontName = "AvenirNext-Regular"
                label.fontSize = 9
                label.fontColor = engineLimit.color
                label.position = CGPoint(x: yAxisX + graphWidth + 30, y: screenY - 5)
                label.horizontalAlignmentMode = .left
                graphNode?.addChild(label)
            }
        }
    }

    private func adaptGraphScale(machAltitudePoints: [(mach: Double, altitude: Double)]) {
        // Find max values in data
        var maxMachValue: Double = 24.0 // Default to Mach 24
        var maxAlt: Double = 200000.0  // Default to 200,000 meters

        for point in machAltitudePoints {
            maxMachValue = max(maxMachValue, point.mach)
            maxAlt = max(maxAlt, point.altitude)
        }

        // Round up to nice values
        maxMach = CGFloat(ceil(maxMachValue / 5.0) * 5.0) // Round to nearest 5 Mach
        maxAltitudeMeters = CGFloat(ceil(maxAlt / 50000.0) * 50000.0)     // Round to nearest 50,000 m

        // Ensure minimum scale
        maxMach = max(24, maxMach)
        maxAltitudeMeters = max(200000, maxAltitudeMeters)

        // Redraw grid with new scale
        let yAxisX: CGFloat = 10
        let graphWidth = size.width * 0.5
        let graphHeight = size.height * 0.6
        let graphCenterY = size.height * 0.45
        drawGraphGrid(yAxisX: yAxisX, centerY: graphCenterY, width: graphWidth, height: graphHeight)
    }

    /// Calculate time to travel between two waypoints with acceleration limits
    /// - Parameters:
    ///   - from: Starting waypoint
    ///   - to: Ending waypoint
    /// - Returns: Time in seconds
    private func calculateSegmentTime(from: Waypoint, to: Waypoint) -> Double {
        // Maximum acceleration: 3g = 3 * 9.81 m/s²
        let maxAcceleration = 3.0 * 9.81 // m/s²

        // Get average altitude for speed of sound calculation
        let avgAltitudeFeet = (from.altitude + to.altitude) / 2.0
        let avgAltitudeMeters = avgAltitudeFeet * PhysicsConstants.feetToMeters

        // Calculate speed of sound at average altitude
        let speedOfSound = AtmosphereModel.speedOfSound(at: avgAltitudeMeters) // m/s

        // Convert Mach speeds to m/s
        let v0 = from.speed * speedOfSound // m/s
        let vf = to.speed * speedOfSound   // m/s

        // Calculate total distance to travel
        let altitudeDiffMeters = abs(to.altitude - from.altitude) * PhysicsConstants.feetToMeters
        // Assume approximately 45-degree climb angle for distance estimation
        let totalDistance = sqrt(2.0) * altitudeDiffMeters // m

        // Phase 1: Acceleration/Deceleration
        let deltaV = abs(vf - v0) // m/s
        let accelerationTime = deltaV / maxAcceleration // seconds

        // Distance covered during acceleration (using average velocity during acceleration)
        let avgSpeedDuringAccel = (v0 + vf) / 2.0
        let accelerationDistance = avgSpeedDuringAccel * accelerationTime

        // Phase 2: Constant velocity (if any distance remains)
        var constantVelocityTime = 0.0
        if accelerationDistance < totalDistance {
            let remainingDistance = totalDistance - accelerationDistance
            // Use final velocity for constant velocity phase
            constantVelocityTime = remainingDistance / max(1.0, vf)
        }

        let totalTime = accelerationTime + constantVelocityTime

        #if DEBUG
        print("─────────────────────────────────────")
        print("Segment: Mach \(String(format: "%.1f", from.speed)) → Mach \(String(format: "%.1f", to.speed))")
        print("  Altitude: \(Int(from.altitude * PhysicsConstants.feetToMeters))m → \(Int(to.altitude * PhysicsConstants.feetToMeters))m")
        print("  Speed: \(Int(v0)) m/s → \(Int(vf)) m/s")
        print("  Distance: \(Int(totalDistance)) m")
        print("  Accel phase: \(String(format: "%.1f", accelerationTime))s over \(Int(accelerationDistance))m")
        print("  Const vel phase: \(String(format: "%.1f", constantVelocityTime))s")
        print("  Total time: \(String(format: "%.1f", totalTime))s (\(String(format: "%.2f", totalTime/60.0)) min)")
        #endif

        // Safety check: ensure minimum time
        return max(1.0, totalTime) // At least 1 second
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
            let altitudeMeters = Int(waypoint.altitude * PhysicsConstants.feetToMeters)
            let text = "WP\(index + 1): \(altitudeMeters)m, M\(String(format: "%.1f", waypoint.speed)), \(waypoint.engineMode.rawValue)"
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
        button.fontSize = 17
        button.fontColor = .white
        button.position = position
        button.name = name
        button.verticalAlignmentMode = .center

        let background = SKShapeNode(rectOf: CGSize(width: 160, height: 32), cornerRadius: 6)
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

        if let maxGBox = maxGInputBox, maxGBox.contains(location) {
            activateInput(maxGBox)
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
        case "delete_waypoint":
            deleteLastWaypoint()
        case "default_plan":
            createDefaultFlightPlan()
        case "simulate":
            startSimulation()
        case "back":
            returnToMenu()
        case "save_game":
            saveGameState()
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
              let altMeters = Int(altText),
              let speedText = speedInputBox?.getValue(),
              let speed = Double(speedText) else {
            print("Invalid input values")
            return
        }

        // Get maxG value (default to 2.0 if not provided)
        let maxG: Double
        if let maxGText = maxGInputBox?.getValue(), let value = Double(maxGText) {
            maxG = value
        } else {
            maxG = 2.0
        }

        let altitude = Double(altMeters) * PhysicsConstants.metersToFeet // Convert meters to feet
        let waypoint = Waypoint(altitude: altitude, speed: speed, engineMode: currentEngine, maxG: maxG)

        // Validate thermal limits for air-breathing engine waypoints
        if currentEngine == .scramjet || currentEngine == .ramjet || currentEngine == .ejectorRamjet {
            guard let previousWaypoint = flightPlan.waypoints.last else {
                flightPlan.addWaypoint(waypoint)
                refreshWaypointList()
                updateGraph()
                return
            }

            // Get plane design for thermal calculations
            let planeDesign = GameManager.shared.getPlaneDesign()

            // Validate thermal limits using appropriate module
            let validation: (isSafe: Bool, maxTemp: Double, margin: Double, message: String)

            switch currentEngine {
            case .scramjet:
                validation = ScramjetModule.validateThermalLimits(
                    startWaypoint: previousWaypoint,
                    endWaypoint: waypoint,
                    planeDesign: planeDesign
                )
            case .ramjet:
                validation = RamjetModule.validateThermalLimits(
                    startWaypoint: previousWaypoint,
                    endWaypoint: waypoint,
                    planeDesign: planeDesign
                )
            case .ejectorRamjet:
                validation = JetModule.validateThermalLimits(
                    startWaypoint: previousWaypoint,
                    endWaypoint: waypoint,
                    planeDesign: planeDesign
                )
            default:
                // Should not reach here given the if condition
                validation = (true, 0, 0, "")
            }

            if !validation.isSafe {
                // Show alert and prevent adding waypoint
                #if os(iOS)
                showThermalAlert(message: validation.message)
                #else
                print(validation.message)
                #endif
                return
            }
        }

        // Waypoint is valid, add it
        flightPlan.addWaypoint(waypoint)
        refreshWaypointList()
        updateGraph()
    }

    private func deleteLastWaypoint() {
        // Get the index of the last waypoint
        let lastIndex = flightPlan.waypoints.count - 1

        // Cannot delete if only the starting waypoint remains
        if lastIndex <= 0 {
            #if os(iOS)
            showInfoAlert(message: "Cannot delete the starting waypoint.")
            #else
            print("Cannot delete the starting waypoint.")
            #endif
            return
        }

        // Remove the last waypoint
        flightPlan.removeWaypoint(at: lastIndex)
        refreshWaypointList()
        updateGraph()
    }

    private func createDefaultFlightPlan() {
        // Clear existing waypoints except the starting one
        while flightPlan.waypoints.count > 1 {
            flightPlan.removeWaypoint(at: flightPlan.waypoints.count - 1)
        }

        // Create default waypoints (altitude in feet, converted from meters)
        let defaultWaypoints: [(altitudeMeters: Double, speed: Double, engineMode: EngineMode)] = [
            (20000.0, 3.1, .ejectorRamjet),
            (40000.0, 6.0, .ramjet),
            (70000.0, 15.0, .scramjet),
            (200000.0, 24.0, .rocket)
        ]

        // Add each waypoint
        for wp in defaultWaypoints {
            let altitudeFeet = wp.altitudeMeters * PhysicsConstants.metersToFeet
            let waypoint = Waypoint(altitude: altitudeFeet, speed: wp.speed, engineMode: wp.engineMode)
            flightPlan.addWaypoint(waypoint)
        }

        // Update display
        refreshWaypointList()
        updateGraph()
    }

    #if os(iOS)
    private func showInfoAlert(message: String) {
        guard let viewController = view?.window?.rootViewController else { return }

        let alert = UIAlertController(
            title: "Info",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }

    private func showThermalAlert(message: String) {
        guard let viewController = view?.window?.rootViewController else { return }

        let alert = UIAlertController(
            title: "⚠️ Thermal Limit Exceeded",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
    #endif

    private func startSimulation() {
        guard flightPlan.isValidForFlight() else {
            print("Flight plan is not valid for launch!")
            return
        }

        // Go to optimization scene first to find optimal aircraft length
        let transition = SKTransition.fade(withDuration: 0.5)
        let optimizationScene = OptimizationScene(size: size)
        optimizationScene.scaleMode = .aspectFill
        view?.presentScene(optimizationScene, transition: transition)
    }

    private func returnToMenu() {
        let transition = SKTransition.fade(withDuration: 0.5)
        let menuScene = MenuScene(size: size)
        menuScene.scaleMode = .aspectFill
        view?.presentScene(menuScene, transition: transition)
    }

    private func saveGameState() {
        #if os(iOS)
        guard let viewController = view?.window?.rootViewController else { return }

        let alert = UIAlertController(
            title: "Save Game",
            message: "Enter a name for this save",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Save Name"
            textField.autocapitalizationType = .words
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty else {
                self?.showSaveAlert(title: "Error", message: "Please enter a valid name")
                return
            }

            // Check if save already exists
            let existingNames = GameManager.shared.getSavedDesignNames()
            if existingNames.contains(name) {
                self?.showOverwriteConfirmation(name: name)
            } else {
                self?.performSave(name: name)
            }
        })

        viewController.present(alert, animated: true)
        #endif
    }

    #if os(iOS)
    private func showOverwriteConfirmation(name: String) {
        guard let viewController = view?.window?.rootViewController else { return }

        let alert = UIAlertController(
            title: "Overwrite Save?",
            message: "A save named '\(name)' already exists. Overwrite it?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Overwrite", style: .destructive) { [weak self] _ in
            self?.performSave(name: name)
        })

        viewController.present(alert, animated: true)
    }

    private func performSave(name: String) {
        // Save the current flight plan to GameManager first
        GameManager.shared.setFlightPlan(flightPlan)

        // Save the entire game state (aircraft design + flight plan)
        if GameManager.shared.saveDesign(name: name) {
            showSaveAlert(title: "Success", message: "Game saved as '\(name)'")
        } else {
            showSaveAlert(title: "Error", message: "Failed to save game")
        }
    }

    private func showSaveAlert(title: String, message: String) {
        guard let viewController = view?.window?.rootViewController else { return }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
    #endif
}

