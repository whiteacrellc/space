//
//  FlightPlanningScene.swift
//  Fly To Space
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
        refreshWaypointList()
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

        // Waypoint editor section (right side)
        let editorX = size.width * 0.7
        let labelOffsetX = size.width * 0.1 // 10% left offset
        let labelOffsetY = size.height * 0.1 // 10% down offset

        let editorTitle = SKLabelNode(text: "New Waypoint")
        editorTitle.fontName = "AvenirNext-Medium"
        editorTitle.fontSize = 20
        editorTitle.fontColor = .cyan
        editorTitle.position = CGPoint(x: editorX, y: size.height - 100)
        addChild(editorTitle)

        // Altitude input
        let altLabel = SKLabelNode(text: "Altitude (x1000 ft):")
        altLabel.fontName = "AvenirNext-Regular"
        altLabel.fontSize = 16
        altLabel.fontColor = .white
        altLabel.position = CGPoint(x: editorX - 80 - labelOffsetX, y: size.height - 140 - labelOffsetY)
        altLabel.horizontalAlignmentMode = .left
        addChild(altLabel)

        altitudeInputBox = TextInputBox(
            position: CGPoint(x: editorX + 100 - labelOffsetX + size.width * 0.05, y: size.height - 135 - labelOffsetY),
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
        speedLabel.position = CGPoint(x: editorX - 80 - labelOffsetX, y: size.height - 190 - labelOffsetY)
        speedLabel.horizontalAlignmentMode = .left
        addChild(speedLabel)

        speedInputBox = TextInputBox(
            position: CGPoint(x: editorX + 100 - labelOffsetX + size.width * 0.05, y: size.height - 185 - labelOffsetY),
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
        engineTitleLabel.position = CGPoint(x: editorX - 80 - labelOffsetX, y: size.height - 240 - labelOffsetY)
        engineTitleLabel.horizontalAlignmentMode = .left
        addChild(engineTitleLabel)

        engineLabel = createLabel(text: "Auto", position: CGPoint(x: editorX + 60 - labelOffsetX, y: size.height - 240 - labelOffsetY))
        if let label = engineLabel {
            addChild(label)
        }

        let engineButton = createSmallButton(text: "Change", position: CGPoint(x: editorX + 130 - labelOffsetX, y: size.height - 240 - labelOffsetY), name: "change_engine")
        addChild(engineButton)

        // Add waypoint button
        addButton = createButton(text: "Add Waypoint", position: CGPoint(x: editorX, y: size.height - 340), name: "add_waypoint")
        if let button = addButton {
            addChild(button)
        }

        // Bottom buttons
        simulateButton = createButton(text: "Start Simulation", position: CGPoint(x: size.width * 0.35, y: 60), name: "simulate")
        if let button = simulateButton {
            addChild(button)
        }

        backButton = createSmallButton(text: "Back to Menu", position: CGPoint(x: 100, y: 30), name: "back")
        if let button = backButton {
            addChild(button)
        }
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
        listTitle.position = CGPoint(x: listX, y: size.height - 100)
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
    }

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
        let allModes: [EngineMode] = [.auto, .jet, .ramjet, .scramjet, .rocket]
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

// MARK: - TextInputBox Component

enum InputType {
    case integer
    case float
}

class TextInputBox: SKNode {
    private var background: SKShapeNode
    private var textLabel: SKLabelNode
    private var cursor: SKShapeNode?
    private var currentValue: String
    private let inputType: InputType
    private var isActive: Bool = false
    private let boxWidth: CGFloat
    private let boxHeight: CGFloat

    init(position: CGPoint, width: CGFloat, height: CGFloat, initialValue: String, inputType: InputType) {
        self.boxWidth = width
        self.boxHeight = height
        self.currentValue = initialValue
        self.inputType = inputType

        // Create background box
        background = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 5)
        background.fillColor = UIColor(white: 0.15, alpha: 0.9)
        background.strokeColor = .white
        background.lineWidth = 2

        // Create text label
        textLabel = SKLabelNode(text: initialValue)
        textLabel.fontName = "Courier"
        textLabel.fontSize = 16
        textLabel.fontColor = .white
        textLabel.verticalAlignmentMode = .center
        textLabel.horizontalAlignmentMode = .center

        super.init()

        self.position = position
        addChild(background)
        addChild(textLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setActive(_ active: Bool) {
        isActive = active
        background.strokeColor = active ? .cyan : .white
        background.lineWidth = active ? 3 : 2

        // Show/hide cursor
        if active {
            showCursor()
        } else {
            hideCursor()
        }
    }

    private func showCursor() {
        if cursor == nil {
            cursor = SKShapeNode(rectOf: CGSize(width: 2, height: 20))
            cursor?.fillColor = .cyan
            cursor?.strokeColor = .clear
            if let cursor = cursor {
                addChild(cursor)
            }

            // Blinking animation
            let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: 0.5)
            let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
            let blink = SKAction.sequence([fadeOut, fadeIn])
            cursor?.run(SKAction.repeatForever(blink))
        }
        updateCursorPosition()
    }

    private func hideCursor() {
        cursor?.removeFromParent()
        cursor = nil
    }

    private func updateCursorPosition() {
        // Position cursor after the text
        let textWidth = textLabel.frame.width
        cursor?.position = CGPoint(x: textWidth / 2 + 5, y: 0)
    }

    func addCharacter(_ char: Character) {
        let charString = String(char)

        // Validate input based on type
        switch inputType {
        case .integer:
            if charString.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
                currentValue += charString
            }
        case .float:
            if charString.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789.")) != nil {
                // Only allow one decimal point
                if charString == "." && currentValue.contains(".") {
                    return
                }
                currentValue += charString
            }
        }

        updateDisplay()
    }

    func deleteCharacter() {
        if !currentValue.isEmpty {
            currentValue.removeLast()
            updateDisplay()
        }
    }

    private func updateDisplay() {
        textLabel.text = currentValue.isEmpty ? "0" : currentValue
        updateCursorPosition()
    }

    func getValue() -> String {
        return currentValue.isEmpty ? "0" : currentValue
    }

    override func contains(_ point: CGPoint) -> Bool {
        let localPoint = convert(point, from: parent!)
        return background.contains(localPoint)
    }
}
