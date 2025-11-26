//
//  SimulationScene.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import SpriteKit

class SimulationScene: SKScene {
    private var missionResult: MissionResult?
    private var isSimulating = false
    private var simulationThread: Thread?

    // UI Elements
    private var statusLabel: SKLabelNode?
    private var altitudeLabel: SKLabelNode?
    private var speedLabel: SKLabelNode?
    private var fuelLabel: SKLabelNode?
    private var engineLabel: SKLabelNode?
    private var timeLabel: SKLabelNode?
    private var temperatureLabel: SKLabelNode?

    // Graph
    private var graphNode: SKShapeNode?
    private var trajectoryLine: SKShapeNode?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupUI()
        startSimulation()
    }

    private func setupUI() {
        // Title
        let titleLabel = SKLabelNode(text: "Flight Simulation")
        titleLabel.fontName = "AvenirNext-Bold"
        titleLabel.fontSize = 28
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 50)
        addChild(titleLabel)

        // Status
        statusLabel = SKLabelNode(text: "Preparing launch...")
        statusLabel?.fontName = "AvenirNext-Medium"
        statusLabel?.fontSize = 20
        statusLabel?.fontColor = .cyan
        statusLabel?.position = CGPoint(x: size.width / 2, y: size.height - 90)
        if let label = statusLabel {
            addChild(label)
        }

        // Instrument panel (left side)
        let panelX: CGFloat = 120

        altitudeLabel = createInstrumentLabel(text: "Altitude: 0 ft", position: CGPoint(x: panelX, y: size.height - 150))
        speedLabel = createInstrumentLabel(text: "Speed: Mach 0.0", position: CGPoint(x: panelX, y: size.height - 180))
        fuelLabel = createInstrumentLabel(text: "Fuel: 50,000 L", position: CGPoint(x: panelX, y: size.height - 210))
        engineLabel = createInstrumentLabel(text: "Engine: Jet", position: CGPoint(x: panelX, y: size.height - 240))
        temperatureLabel = createInstrumentLabel(text: "Temp: 0°C", position: CGPoint(x: panelX, y: size.height - 270))
        timeLabel = createInstrumentLabel(text: "Time: 0 s", position: CGPoint(x: panelX, y: size.height - 300))

        if let label = altitudeLabel { addChild(label) }
        if let label = speedLabel { addChild(label) }
        if let label = fuelLabel { addChild(label) }
        if let label = engineLabel { addChild(label) }
        if let label = temperatureLabel { addChild(label) }
        if let label = timeLabel { addChild(label) }

        // Graph area (right side)
        let graphWidth: CGFloat = size.width * 0.5
        let graphHeight: CGFloat = size.height * 0.6
        let graphX = size.width - graphWidth / 2 - 40
        let graphY = size.height / 2

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
        statusLabel?.text = "Launching..."

        // Run simulation in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let plan = GameManager.shared.getFlightPlan()
            let result = GameManager.shared.simulateFlight(plan: plan)

            DispatchQueue.main.async {
                self.missionResult = result
                self.isSimulating = false
                self.showResults()
            }
        }

        // Start animation update
        animateSimulation()
    }

    private func animateSimulation() {
        guard isSimulating else { return }

        // Update display based on current simulation state
        // For now, just show a simple animation
        statusLabel?.text = "Flight in progress..."

        // Continue animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.animateSimulation()
        }
    }

    func update(with trajectory: [TrajectoryPoint]) {
        guard let graphNode = graphNode else { return }

        // Remove old trajectory
        trajectoryLine?.removeFromParent()

        // Get graph dimensions
        let graphBounds = graphNode.frame
        let graphWidth = graphBounds.width - 40
        let graphHeight = graphBounds.height - 40

        // Find max values for scaling
        let maxTime = trajectory.last?.time ?? 1.0
        let maxAltitude = max(300000.0, trajectory.map { $0.altitude }.max() ?? 1.0)

        // Create path
        let path = CGMutablePath()
        var isFirst = true

        for point in trajectory {
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
        trajectoryLine?.lineWidth = 2
        trajectoryLine?.position = graphNode.position
        if let line = trajectoryLine {
            addChild(line)
        }

        // Update instrument panel
        if let lastPoint = trajectory.last {
            altitudeLabel?.text = "Altitude: \(Int(lastPoint.altitude).formatted()) ft"
            speedLabel?.text = "Speed: Mach \(String(format: "%.1f", lastPoint.speed))"
            fuelLabel?.text = "Fuel: \(Int(lastPoint.fuelRemaining).formatted()) L"
            engineLabel?.text = "Engine: \(lastPoint.engineMode.rawValue)"
            timeLabel?.text = "Time: \(Int(lastPoint.time)) s"

            // Update temperature with color-coding based on thermal stress
            let tempColor: UIColor
            if lastPoint.temperature > 600 {
                tempColor = .red
            } else if lastPoint.temperature > 550 {
                tempColor = .orange
            } else {
                tempColor = .white
            }
            temperatureLabel?.text = "Temp: \(Int(lastPoint.temperature))°C"
            temperatureLabel?.fontColor = tempColor
        }
    }

    private func showResults() {
        guard let result = missionResult else { return }

        // Update graph with final trajectory
        let trajectory = result.completeTrajectory()
        update(with: trajectory)

        // Show completion status
        if result.success {
            statusLabel?.text = "ORBIT ACHIEVED!"
            statusLabel?.fontColor = .green
        } else {
            statusLabel?.text = "MISSION FAILED"
            statusLabel?.fontColor = .red
        }

        // Transition to results after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.transitionToResults()
        }
    }

    private func transitionToResults() {
        let transition = SKTransition.fade(withDuration: 0.5)
        let resultsScene = ResultsScene(size: size)
        resultsScene.scaleMode = .aspectFill
        view?.presentScene(resultsScene, transition: transition)
    }
}
