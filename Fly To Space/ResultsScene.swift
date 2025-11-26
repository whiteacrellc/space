//
//  ResultsScene.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import SpriteKit

class ResultsScene: SKScene {
    private var result: MissionResult?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        result = GameManager.shared.getLastResult()
        setupUI()
    }

    private func setupUI() {
        guard let result = result else {
            let errorLabel = SKLabelNode(text: "No results available")
            errorLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
            addChild(errorLabel)
            return
        }

        // Title/Status
        let titleLabel = SKLabelNode(text: result.success ? "ORBIT ACHIEVED!" : "MISSION FAILED")
        titleLabel.fontName = "AvenirNext-Bold"
        titleLabel.fontSize = 36
        titleLabel.fontColor = result.success ? .green : .red
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 60)
        addChild(titleLabel)

        // Statistics panel
        let statsY = size.height - 150
        let spacing: CGFloat = 35

        createStatLabel(text: "Final Altitude: \(Int(result.finalAltitude).formatted()) ft", y: statsY)
        createStatLabel(text: "Final Speed: Mach \(String(format: "%.1f", result.finalSpeed))", y: statsY - spacing)
        createStatLabel(text: "Total Fuel Used: \(Int(result.totalFuelUsed).formatted()) L", y: statsY - spacing * 2)
        createStatLabel(text: "Flight Duration: \(Int(result.totalDuration)) seconds", y: statsY - spacing * 3)
        createStatLabel(text: "Fuel Efficiency: \(String(format: "%.0f", result.efficiency))", y: statsY - spacing * 4)

        // Score (if successful)
        if result.success {
            let scoreLabel = SKLabelNode(text: "SCORE: \(result.score)")
            scoreLabel.fontName = "AvenirNext-Bold"
            scoreLabel.fontSize = 32
            scoreLabel.fontColor = .yellow
            scoreLabel.position = CGPoint(x: size.width / 2, y: statsY - spacing * 5 - 20)
            addChild(scoreLabel)
        }

        // Trajectory graph
        drawTrajectoryGraph(result: result)

        // Buttons
        let buttonY: CGFloat = 80

        let retryButton = createButton(text: "New Plan", position: CGPoint(x: size.width / 2 - 120, y: buttonY), name: "retry")
        let menuButton = createButton(text: "Main Menu", position: CGPoint(x: size.width / 2 + 120, y: buttonY), name: "menu")

        addChild(retryButton)
        addChild(menuButton)
    }

    private func createStatLabel(text: String, y: CGFloat) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Regular"
        label.fontSize = 18
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: y)
        addChild(label)
    }

    private func drawTrajectoryGraph(result: MissionResult) {
        let graphWidth: CGFloat = size.width * 0.7
        let graphHeight: CGFloat = 200
        let graphX = size.width / 2
        let graphY: CGFloat = 250

        // Background
        let background = SKShapeNode(rectOf: CGSize(width: graphWidth, height: graphHeight))
        background.fillColor = UIColor(white: 0.1, alpha: 0.8)
        background.strokeColor = .white
        background.lineWidth = 2
        background.position = CGPoint(x: graphX, y: graphY)
        addChild(background)

        // Title
        let graphTitle = SKLabelNode(text: "Flight Trajectory")
        graphTitle.fontName = "AvenirNext-Medium"
        graphTitle.fontSize = 16
        graphTitle.fontColor = .white
        graphTitle.position = CGPoint(x: graphX, y: graphY + graphHeight / 2 + 15)
        addChild(graphTitle)

        // Get trajectory data
        let trajectory = result.completeTrajectory()
        guard !trajectory.isEmpty else { return }

        // Find max values for scaling
        let maxTime = trajectory.last?.time ?? 1.0
        let maxAltitude = max(300000.0, trajectory.map { $0.altitude }.max() ?? 1.0)

        // Create path
        let path = CGMutablePath()
        var isFirst = true

        let marginX: CGFloat = 20
        let marginY: CGFloat = 20
        let plotWidth = graphWidth - marginX * 2
        let plotHeight = graphHeight - marginY * 2

        for point in trajectory {
            let x = (point.time / maxTime) * plotWidth - plotWidth / 2
            let y = (point.altitude / maxAltitude) * plotHeight - plotHeight / 2

            if isFirst {
                path.move(to: CGPoint(x: x, y: y))
                isFirst = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Draw trajectory line
        let trajectoryLine = SKShapeNode(path: path)
        trajectoryLine.strokeColor = .cyan
        trajectoryLine.lineWidth = 3
        trajectoryLine.position = CGPoint(x: graphX, y: graphY)
        addChild(trajectoryLine)

        // Draw orbit threshold line
        let orbitY = (PhysicsConstants.orbitAltitude / maxAltitude) * plotHeight - plotHeight / 2
        let orbitPath = CGMutablePath()
        orbitPath.move(to: CGPoint(x: -plotWidth / 2, y: orbitY))
        orbitPath.addLine(to: CGPoint(x: plotWidth / 2, y: orbitY))

        let orbitLine = SKShapeNode(path: orbitPath)
        orbitLine.strokeColor = .green
        orbitLine.lineWidth = 1
        orbitLine.setLineLength(5, dash: 5)
        orbitLine.position = CGPoint(x: graphX, y: graphY)
        addChild(orbitLine)

        // Labels
        let orbitLabel = SKLabelNode(text: "Orbit")
        orbitLabel.fontName = "AvenirNext-Regular"
        orbitLabel.fontSize = 12
        orbitLabel.fontColor = .green
        orbitLabel.position = CGPoint(x: graphX + plotWidth / 2 - 30, y: graphY + orbitY + 5)
        addChild(orbitLabel)
    }

    private func createButton(text: String, position: CGPoint, name: String) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontName = "AvenirNext-Medium"
        button.fontSize = 20
        button.fontColor = .white
        button.position = position
        button.name = name
        button.verticalAlignmentMode = .center

        let background = SKShapeNode(rectOf: CGSize(width: 180, height: 40), cornerRadius: 8)
        background.fillColor = UIColor(white: 0.2, alpha: 0.6)
        background.strokeColor = .white
        background.lineWidth = 2
        background.zPosition = -1
        button.addChild(background)

        return button
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)

        for node in touchedNodes {
            if let labelNode = node as? SKLabelNode, let name = labelNode.name {
                handleButtonTap(name)
            }
        }
    }

    private func handleButtonTap(_ name: String) {
        let transition = SKTransition.fade(withDuration: 0.5)

        switch name {
        case "retry":
            GameManager.shared.startNewMission()
            let planningScene = FlightPlanningScene(size: size)
            planningScene.scaleMode = .aspectFill
            view?.presentScene(planningScene, transition: transition)

        case "menu":
            let menuScene = MenuScene(size: size)
            menuScene.scaleMode = .aspectFill
            view?.presentScene(menuScene, transition: transition)

        default:
            break
        }
    }
}

// Extension to add dashed line support
extension SKShapeNode {
    func setLineLength(_ length: CGFloat, dash: CGFloat) {
        let pattern: [CGFloat] = [length, dash]
        let dashed = SKShapeNode(path: self.path!)
        dashed.strokeColor = self.strokeColor
        dashed.lineWidth = self.lineWidth
        self.path = CGPath(rect: CGRect.zero, transform: nil)
    }
}
