//
//  SettingsScene.swift
//  ssto
//
//  Settings screen with Resume Game and Manage Files options
//

import SpriteKit

class SettingsScene: SKScene {

    private var titleLabel: SKLabelNode?
    private var resumeGameButton: SKLabelNode?
    private var manageFilesButton: SKLabelNode?
    private var backButton: SKLabelNode?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupUI()
    }

    private func setupUI() {
        // Title label
        titleLabel = SKLabelNode(text: "Settings")
        titleLabel?.fontName = "AvenirNext-Bold"
        titleLabel?.fontSize = 32
        titleLabel?.fontColor = .white
        titleLabel?.position = CGPoint(x: size.width / 2, y: size.height - 60)

        if let titleLabel = titleLabel {
            addChild(titleLabel)
        }

        // Calculate button positioning
        let buttonHeight: CGFloat = 45
        let buttonSpacing: CGFloat = 60
        let startY = size.height / 2 + 40

        // Resume Game button
        resumeGameButton = createButton(text: "Resume Game", position: CGPoint(x: size.width / 2, y: startY), height: buttonHeight)
        resumeGameButton?.name = "Resume Game"
        if let resumeGameButton = resumeGameButton {
            addChild(resumeGameButton)
        }

        // Manage Files button
        manageFilesButton = createButton(text: "Manage Files", position: CGPoint(x: size.width / 2, y: startY - buttonSpacing), height: buttonHeight)
        manageFilesButton?.name = "Manage Files"
        if let manageFilesButton = manageFilesButton {
            addChild(manageFilesButton)
        }

        // Back button
        backButton = createButton(text: "Back to Menu", position: CGPoint(x: size.width / 2, y: 80), height: 40)
        backButton?.name = "Back"
        if let backButton = backButton {
            addChild(backButton)
        }
    }

    private func createButton(text: String, position: CGPoint, height: CGFloat = 45) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontName = "AvenirNext-Medium"
        button.fontSize = 20
        button.fontColor = .white
        button.position = position
        button.verticalAlignmentMode = .center
        button.horizontalAlignmentMode = .center

        // Add background for button
        let buttonWidth = max(250, CGFloat(text.count) * button.fontSize * 0.6)
        let background = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: height), cornerRadius: 8)
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
            if let labelNode = node as? SKLabelNode {
                // Add button press effect
                let scaleDown = SKAction.scale(to: 0.9, duration: 0.1)
                let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
                labelNode.run(SKAction.sequence([scaleDown, scaleUp]))

                // Handle button actions
                switch labelNode.name {
                case "Resume Game":
                    resumeGame()
                case "Manage Files":
                    manageFiles()
                case "Back":
                    backToMenu()
                default:
                    break
                }
            }
        }
    }

    private func resumeGame() {
        #if os(iOS)
        let savedGames = GameManager.shared.getSavedDesignNames()

        guard !savedGames.isEmpty else {
            showAlert(title: "No Saved Games", message: "No saved games found. Please start a new game.")
            return
        }

        guard let viewController = view?.window?.rootViewController else { return }

        let alert = UIAlertController(
            title: "Load Saved Game",
            message: "Select a saved game to resume",
            preferredStyle: .actionSheet
        )

        for name in savedGames {
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.loadAndResumeGame(name: name)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view!.bounds.midX, y: view!.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        viewController.present(alert, animated: true)
        #endif
    }

    #if os(iOS)
    private func loadAndResumeGame(name: String) {
        if GameManager.shared.loadDesign(name: name) {
            // Successfully loaded the game, now transition to flight planning
            let transition = SKTransition.fade(withDuration: 1.0)
            let planningScene = FlightPlanningScene(size: size)
            planningScene.scaleMode = .aspectFill
            view?.presentScene(planningScene, transition: transition)
        } else {
            showAlert(title: "Error", message: "Failed to load saved game '\(name)'")
        }
    }

    private func showAlert(title: String, message: String) {
        guard let viewController = view?.window?.rootViewController else { return }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        viewController.present(alert, animated: true)
    }
    #endif

    private func manageFiles() {
        // Transition to File Management Scene
        let transition = SKTransition.fade(withDuration: 0.5)
        let fileManagementScene = FileManagementScene(size: size)
        fileManagementScene.scaleMode = .aspectFill
        view?.presentScene(fileManagementScene, transition: transition)
    }

    private func backToMenu() {
        // Return to menu
        let transition = SKTransition.fade(withDuration: 0.5)
        let menuScene = MenuScene(size: size)
        menuScene.scaleMode = .aspectFill
        view?.presentScene(menuScene, transition: transition)
    }
}
