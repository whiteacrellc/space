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
    private var resultLabel: SKLabelNode?
    private var continueButton: SKLabelNode?
    private var iterationsScrollView: UIScrollView?

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
        // Title (left-aligned above scroll view)
        titleLabel = SKLabelNode(text: "Finding Optimal Weight")
        titleLabel?.fontName = "AvenirNext-Bold"
        titleLabel?.fontSize = 20
        titleLabel?.fontColor = .white
        titleLabel?.position = CGPoint(x: size.width * 0.5, y: size.height - 30)
        titleLabel?.horizontalAlignmentMode = .center
        if let label = titleLabel {
            addChild(label)
        }

        // Subtitle (smaller, left side)
        let subtitle = SKLabelNode(text: "Newton-Raphson Optimal Weight")
        subtitle.fontName = "AvenirNext-Regular"
        subtitle.fontSize = 16
        subtitle.fontColor = .cyan
        subtitle.position = CGPoint(x: size.width * 0.25, y: size.height - 50)
        subtitle.horizontalAlignmentMode = .center
        addChild(subtitle)

        // Create scrollable iterations container (left side)
        setupIterationsScrollView()
    }

    private func setupIterationsScrollView() {
        guard let view = view else { return }

        let scrollView = UIScrollView()
        scrollView.frame = CGRect(
            x: 20,
            y: view.bounds.height * 0.0 + 70,  // Bottom at 50% of screen (inverted Y)
            width: view.bounds.width * 0.5 - 30,
            height: view.bounds.height * 0.5
        )
        scrollView.backgroundColor = UIColor(white: 0.1, alpha: 0.8)
        scrollView.layer.cornerRadius = 10
        scrollView.layer.borderColor = UIColor.cyan.withAlphaComponent(0.5).cgColor
        scrollView.layer.borderWidth = 2
        scrollView.isUserInteractionEnabled = true
        scrollView.showsVerticalScrollIndicator = true

        view.addSubview(scrollView)
        iterationsScrollView = scrollView
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
                    error: result.errorHistory[min(self.currentIteration, result.errorHistory.count - 1)]
                )
                self.currentIteration += 1

                // Update scroll view content size
                if let scrollView = self.iterationsScrollView {
                    let contentHeight = CGFloat(self.currentIteration) * lineHeight + 20
                    scrollView.contentSize = CGSize(width: scrollView.frame.width, height: contentHeight)
                    // Auto-scroll to bottom
                    let bottomOffset = CGPoint(x: 0, y: max(0, contentHeight - scrollView.bounds.height))
                    scrollView.setContentOffset(bottomOffset, animated: true)
                }
            } else {
                timer.invalidate()
                self.displayFinalResult(result: result)
            }
        }
    }

    private func displayIteration(iteration: Int, length: Double, error: Double) {
        guard let scrollView = iterationsScrollView else { return }

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
            planeDesign: planeDesign
        )

        let iterationText = String(format: "Iteration %d: Length = %.2f m, Dry Weight = %.0f kg, Error = %+.0f kg",
                                   iteration + 1, length, dryWeight, error)

        // Create UILabel for scroll view
        let label = UILabel()
        label.text = iterationText
        label.font = UIFont(name: "Menlo-Regular", size: 12)
        label.textColor = .white
        label.textAlignment = .left

        let lineHeight: CGFloat = 25
        let yPosition = CGFloat(iteration) * lineHeight + 10
        label.frame = CGRect(x: 10, y: yPosition, width: scrollView.frame.width - 20, height: lineHeight)

        // Fade in animation
        label.alpha = 0
        UIView.animate(withDuration: 0.3) {
            label.alpha = 1
        }

        scrollView.addSubview(label)
    }

    private func displayFinalResult(result: NewtonModule.OptimizationResult) {
        // Right side layout - center of right 50%
        let rightX = size.width * 0.75
        let rightStartY = size.height - 150

        // Convergence status
        let statusText = result.converged ? "✓ CONVERGED" : "⚠️ MAX ITERATIONS REACHED"
        let statusLabel = SKLabelNode(text: statusText)
        statusLabel.fontName = "AvenirNext-Bold"
        statusLabel.fontSize = 20
        statusLabel.fontColor = result.converged ? .green : .yellow
        statusLabel.position = CGPoint(x: rightX, y: rightStartY)
        addChild(statusLabel)

        // Optimal length
        let lengthText = String(format: "Optimal Length: %.2f m", result.optimalLength)
        let lengthLabel = SKLabelNode(text: lengthText)
        lengthLabel.fontName = "AvenirNext-Medium"
        lengthLabel.fontSize = 18
        lengthLabel.fontColor = .cyan
        lengthLabel.position = CGPoint(x: rightX, y: rightStartY - 35)
        addChild(lengthLabel)

        // Fuel capacity
        let capacityText = String(format: "Fuel Capacity: %.0f kg", result.fuelCapacity)
        let capacityLabel = SKLabelNode(text: capacityText)
        capacityLabel.fontName = "AvenirNext-Medium"
        capacityLabel.fontSize = 18
        capacityLabel.fontColor = .white
        capacityLabel.position = CGPoint(x: rightX, y: rightStartY - 70)
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
            planeDesign: planeDesign
        )

        let dryWeightText = String(format: "Dry Weight: %.0f kg", dryWeight)
        let dryWeightLabel = SKLabelNode(text: dryWeightText)
        dryWeightLabel.fontName = "AvenirNext-Bold"
        dryWeightLabel.fontSize = 20
        dryWeightLabel.fontColor = .yellow
        dryWeightLabel.position = CGPoint(x: rightX, y: rightStartY - 105)
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
                // Show "New High Score!" message - positioned below scroll view on left side
                let leftX = size.width * 0.25
                let leftY = size.height * 0.2

                let highScoreLabel = SKLabelNode(text: "🏆 NEW TOP 10 SCORE! 🏆")
                highScoreLabel.fontName = "AvenirNext-Bold"
                highScoreLabel.fontSize = 22
                highScoreLabel.fontColor = .yellow
                highScoreLabel.position = CGPoint(x: leftX, y: leftY)
                addChild(highScoreLabel)

                // Pulse animation
                let scaleUp = SKAction.scale(to: 1.2, duration: 0.5)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.5)
                let pulse = SKAction.sequence([scaleUp, scaleDown])
                highScoreLabel.run(SKAction.repeatForever(pulse))

                // Prompt for name
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.promptForName(score: score, leftX: leftX, leftY: leftY)
                }
            } else {
                // Not in top 10, just show continue button
                showContinueButton(yPosition: 0)
            }
        } else {
            // Failed to converge, show continue button
            showContinueButton(yPosition: 0)
        }
    }

    private func promptForName(score: LeaderboardEntry, leftX: CGFloat, leftY: CGFloat) {
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
                let designName = GameManager.shared.currentSaveName ?? "Optimized Design"
                LeaderboardManager.shared.addEntry(
                    playerName: "Anonymous",
                    volume: score.volume,
                    optimalLength: score.optimalLength,
                    fuelCapacity: score.fuelCapacity,
                    designName: designName
                )
                self?.showContinueButton(yPosition: 0)
                return
            }

            let designName = GameManager.shared.currentSaveName ?? "Optimized Design"
            LeaderboardManager.shared.addEntry(
                playerName: name,
                volume: score.volume,
                optimalLength: score.optimalLength,
                fuelCapacity: score.fuelCapacity,
                designName: designName
            )

            self?.showLeaderboardPosition(volume: score.volume, leftX: leftX, leftY: leftY)
            self?.showContinueButton(yPosition: 0)
        })

        viewController.present(alert, animated: true)
        #else
        // macOS version - just use default name
        let designName = GameManager.shared.currentSaveName ?? "Optimized Design"
        LeaderboardManager.shared.addEntry(
            playerName: "Player",
            volume: score.volume,
            optimalLength: score.optimalLength,
            fuelCapacity: score.fuelCapacity,
            designName: designName
        )
        showContinueButton(yPosition: 0)
        #endif
    }

    private func showLeaderboardPosition(volume: Double, leftX: CGFloat, leftY: CGFloat) {
        if let rank = LeaderboardManager.shared.getRank(volume: volume) {
            let positionText = "Your Rank: #\(rank)"
            let positionLabel = SKLabelNode(text: positionText)
            positionLabel.fontName = "AvenirNext-Bold"
            positionLabel.fontSize = 20
            positionLabel.fontColor = .green
            positionLabel.position = CGPoint(x: leftX, y: leftY - 40)
            addChild(positionLabel)
        }
    }

    private func showContinueButton(yPosition: CGFloat) {
        // Position button in upper right corner
        let xPosition = size.width - 100
        let yPosition = size.height - 60
        continueButton = createButton(
            text: "Continue →",
            position: CGPoint(x: xPosition, y: yPosition),
            name: "continue",
            width: 180,
            height: 35,
            fontSize: 16
        )
        if let button = continueButton {
            addChild(button)
        }
    }

    private func createButton(text: String, position: CGPoint, name: String, width: CGFloat = 250, height: CGFloat = 40, fontSize: CGFloat = 20) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontName = "AvenirNext-Medium"
        button.fontSize = fontSize
        button.fontColor = .white
        button.position = position
        button.name = name
        button.verticalAlignmentMode = .center

        let background = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8)
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

                // Clean up scroll view before transitioning
                cleanupScrollView()

                // Transition to simulation scene
                let transition = SKTransition.fade(withDuration: 0.5)
                let simulationScene = SimulationScene(size: size)
                simulationScene.scaleMode = .aspectFill
                view?.presentScene(simulationScene, transition: transition)
            }
        }
    }

    private func cleanupScrollView() {
        iterationsScrollView?.removeFromSuperview()
        iterationsScrollView = nil
    }

    deinit {
        displayTimer?.invalidate()
        cleanupScrollView()
    }
}
