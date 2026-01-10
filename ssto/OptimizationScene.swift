//
//  OptimizationScene.swift
//  ssto
//
//  Displays Newton-Raphson optimization iterations and manages leaderboard
//

import SpriteKit

class OptimizationScene: SKScene {

    // UI Elements
    private var titleLabel: SKLabelNode?
    private var iterationLabels: [SKLabelNode] = []
    private var resultLabel: SKLabelNode?
    private var continueButton: SKLabelNode?

    // Optimization data
    private var currentIteration: Int = 0
    private var optimizationResult: NewtonModule.OptimizationResult?
    private var displayTimer: Timer?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupUI()
        startOptimization()
    }

    private func setupUI() {
        // Title
        titleLabel = SKLabelNode(text: "Aircraft Optimization")
        titleLabel?.fontName = "AvenirNext-Bold"
        titleLabel?.fontSize = 24
        titleLabel?.fontColor = .white
        titleLabel?.position = CGPoint(x: size.width / 2, y: size.height - 40)
        if let label = titleLabel {
            addChild(label)
        }

        // Subtitle
        let subtitle = SKLabelNode(text: "Newton-Raphson Method: Finding Optimal Length")
        subtitle.fontName = "AvenirNext-Regular"
        subtitle.fontSize = 16
        subtitle.fontColor = .cyan
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 70)
        addChild(subtitle)
    }

    private func startOptimization() {
        // Run optimization in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = NewtonModule.optimizeCurrentAircraft()

            DispatchQueue.main.async {
                self?.optimizationResult = result
                self?.displayIterations(result: result)
            }
        }
    }

    private func displayIterations(result: NewtonModule.OptimizationResult) {
        let startY = size.height - 120
        let lineHeight: CGFloat = 25

        // Display iterations one by one with animation
        currentIteration = 0

        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if self.currentIteration < result.iterations {
                self.displayIteration(
                    iteration: self.currentIteration,
                    length: result.lengthHistory[self.currentIteration],
                    error: result.errorHistory[min(self.currentIteration, result.errorHistory.count - 1)],
                    yPosition: startY - CGFloat(self.currentIteration) * lineHeight
                )
                self.currentIteration += 1
            } else {
                timer.invalidate()
                self.displayFinalResult(result: result)
            }
        }
    }

    private func displayIteration(iteration: Int, length: Double, error: Double, yPosition: CGFloat) {
        // Calculate dry weight for this iteration's length to show context
        let planform = GameManager.shared.getTopViewPlanform()
        let originalLength = planform.aircraftLength
        let volumeScaleFactor = pow(length / originalLength, 3.0)
        let baseVolume = AircraftVolumeModel.calculateInternalVolume()
        let scaledVolume = baseVolume * volumeScaleFactor

        let flightPlan = GameManager.shared.getFlightPlan()
        let planeDesign = GameManager.shared.getPlaneDesign()

        let dryWeight = PhysicsConstants.calculateDryMass(
            volumeM3: scaledVolume,
            waypoints: flightPlan.waypoints,
            planeDesign: planeDesign,
            maxTemperature: 800.0
        )

        let iterationText = String(format: "Iteration %d: Length = %.2f m, Dry Weight = %.0f kg, Error = %+.0f kg",
                                   iteration + 1, length, dryWeight, error)

        let label = SKLabelNode(text: iterationText)
        label.fontName = "Menlo-Regular"
        label.fontSize = 14
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: yPosition)
        label.horizontalAlignmentMode = .center

        // Fade in animation
        label.alpha = 0
        label.run(SKAction.fadeIn(withDuration: 0.3))

        addChild(label)
        iterationLabels.append(label)
    }

    private func displayFinalResult(result: NewtonModule.OptimizationResult) {
        let yPosition = size.height - 120 - CGFloat(result.iterations) * 25 - 50

        // Convergence status
        let statusText = result.converged ? "✓ CONVERGED" : "⚠️ MAX ITERATIONS REACHED"
        let statusLabel = SKLabelNode(text: statusText)
        statusLabel.fontName = "AvenirNext-Bold"
        statusLabel.fontSize = 20
        statusLabel.fontColor = result.converged ? .green : .yellow
        statusLabel.position = CGPoint(x: size.width / 2, y: yPosition)
        addChild(statusLabel)

        // Optimal length
        let lengthText = String(format: "Optimal Length: %.2f m", result.optimalLength)
        let lengthLabel = SKLabelNode(text: lengthText)
        lengthLabel.fontName = "AvenirNext-Medium"
        lengthLabel.fontSize = 18
        lengthLabel.fontColor = .cyan
        lengthLabel.position = CGPoint(x: size.width / 2, y: yPosition - 30)
        addChild(lengthLabel)

        // Fuel capacity
        let capacityText = String(format: "Fuel Capacity: %.0f kg", result.fuelCapacity)
        let capacityLabel = SKLabelNode(text: capacityText)
        capacityLabel.fontName = "AvenirNext-Medium"
        capacityLabel.fontSize = 18
        capacityLabel.fontColor = .white
        capacityLabel.position = CGPoint(x: size.width / 2, y: yPosition - 55)
        addChild(capacityLabel)

        // Dry weight (aircraft weight without fuel) - calculated dynamically
        // Scale volume based on optimal length to match SimulationScene
        let planform = GameManager.shared.getTopViewPlanform()
        let originalLength = planform.aircraftLength
        let volumeScaleFactor = pow(result.optimalLength / originalLength, 3.0)
        let baseVolume = AircraftVolumeModel.calculateInternalVolume()
        let scaledVolume = baseVolume * volumeScaleFactor

        let flightPlan = GameManager.shared.getFlightPlan()
        let planeDesign = GameManager.shared.getPlaneDesign()

        let dryWeight = PhysicsConstants.calculateDryMass(
            volumeM3: scaledVolume,
            waypoints: flightPlan.waypoints,
            planeDesign: planeDesign,
            maxTemperature: 800.0 // Estimated max temp
        )

        let dryWeightText = String(format: "Dry Weight: %.0f kg (Optimized)", dryWeight)
        let dryWeightLabel = SKLabelNode(text: dryWeightText)
        dryWeightLabel.fontName = "AvenirNext-Bold"
        dryWeightLabel.fontSize = 20
        dryWeightLabel.fontColor = .yellow
        dryWeightLabel.position = CGPoint(x: size.width / 2, y: yPosition - 90)
        addChild(dryWeightLabel)

        // Check if in top 10 and handle leaderboard
        if result.converged {
            // Auto-save the design with the optimized length
            let saveSuccess = GameManager.shared.updateOptimizedLength(result.optimalLength)
            if saveSuccess {
                print("✓ Design auto-saved with optimized length: \(result.optimalLength) m")
            } else {
                print("⚠️ Failed to auto-save optimized design")
            }

            // Use scaled volume for leaderboard (same as used for dry weight calculation)
            let score = LeaderboardEntry(
                name: "",
                volume: scaledVolume,
                optimalLength: result.optimalLength,
                fuelCapacity: result.fuelCapacity,
                date: Date()
            )

            if LeaderboardManager.shared.wouldMakeTopTen(volume: scaledVolume) {
                // Show "New High Score!" message
                let highScoreLabel = SKLabelNode(text: "🏆 NEW TOP 10 SCORE! 🏆")
                highScoreLabel.fontName = "AvenirNext-Bold"
                highScoreLabel.fontSize = 22
                highScoreLabel.fontColor = .yellow
                highScoreLabel.position = CGPoint(x: size.width / 2, y: yPosition - 130)
                addChild(highScoreLabel)

                // Pulse animation
                let scaleUp = SKAction.scale(to: 1.2, duration: 0.5)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.5)
                let pulse = SKAction.sequence([scaleUp, scaleDown])
                highScoreLabel.run(SKAction.repeatForever(pulse))

                // Prompt for name
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.promptForName(score: score)
                }
            } else {
                // Not in top 10, just show continue button
                showContinueButton(yPosition: yPosition - 130)
            }
        } else {
            // Failed to converge, show continue button
            showContinueButton(yPosition: yPosition - 90)
        }
    }

    private func promptForName(score: LeaderboardEntry) {
        #if os(iOS)
        guard let viewController = view?.window?.rootViewController else { return }

        let alert = UIAlertController(
            title: "🏆 Top 10 Score!",
            message: "Enter your name for the leaderboard:",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Your Name"
            textField.autocapitalizationType = .words
            textField.returnKeyType = .done
        }

        alert.addAction(UIAlertAction(title: "Submit", style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty else {
                // Use default name if empty
                LeaderboardManager.shared.addEntry(
                    playerName: "Anonymous",
                    volume: score.volume,
                    optimalLength: score.optimalLength,
                    fuelCapacity: score.fuelCapacity
                )
                self?.showContinueButton(yPosition: self?.size.height ?? 0 / 2 - 100)
                return
            }

            LeaderboardManager.shared.addEntry(
                playerName: name,
                volume: score.volume,
                optimalLength: score.optimalLength,
                fuelCapacity: score.fuelCapacity
            )

            self?.showLeaderboardPosition(volume: score.volume)
            self?.showContinueButton(yPosition: self?.size.height ?? 0 / 2 - 150)
        })

        viewController.present(alert, animated: true)
        #else
        // macOS version - just use default name
        LeaderboardManager.shared.addEntry(
            playerName: "Player",
            volume: score.volume,
            optimalLength: score.optimalLength,
            fuelCapacity: score.fuelCapacity
        )
        showContinueButton(yPosition: size.height / 2 - 100)
        #endif
    }

    private func showLeaderboardPosition(volume: Double) {
        if let rank = LeaderboardManager.shared.getRank(volume: volume) {
            let positionText = "Your Rank: #\(rank)"
            let positionLabel = SKLabelNode(text: positionText)
            positionLabel.fontName = "AvenirNext-Bold"
            positionLabel.fontSize = 20
            positionLabel.fontColor = .green
            positionLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 120)
            addChild(positionLabel)
        }
    }

    private func showContinueButton(yPosition: CGFloat) {
        // Position button on middle right of scene
        let xPosition = size.width - 180
        let yPosition = size.height / 2
        continueButton = createButton(
            text: "Continue to Simulation",
            position: CGPoint(x: xPosition, y: yPosition),
            name: "continue"
        )
        if let button = continueButton {
            addChild(button)
        }
    }

    private func createButton(text: String, position: CGPoint, name: String) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontName = "AvenirNext-Medium"
        button.fontSize = 20
        button.fontColor = .white
        button.position = position
        button.name = name
        button.verticalAlignmentMode = .center

        let background = SKShapeNode(rectOf: CGSize(width: 250, height: 40), cornerRadius: 8)
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
            if let labelNode = node as? SKLabelNode, labelNode.name == "continue" {
                // Apply optimized length
                if let result = optimizationResult {
                    NewtonModule.applyOptimizedLength(result: result)
                }

                // Transition to simulation scene
                let transition = SKTransition.fade(withDuration: 0.5)
                let simulationScene = SimulationScene(size: size)
                simulationScene.scaleMode = .aspectFill
                view?.presentScene(simulationScene, transition: transition)
            }
        }
    }

    deinit {
        displayTimer?.invalidate()
    }
}
