//
//  LeaderboardScene.swift
//  ssto
//
//  Displays top 10 players ranked by vehicle dry mass (lower is better)
//

import SpriteKit

class LeaderboardScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupUI()
    }

    private func setupUI() {
        // Title
        let titleLabel = SKLabelNode(text: "Leaderboard - Smallest Successful Vehicles")
        titleLabel.fontName = "AvenirNext-Bold"
        titleLabel.fontSize = 24
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 60)
        addChild(titleLabel)

        // Get leaderboard data
        let entries = LeaderboardManager.shared.getTopEntries(limit: 10)

        if entries.isEmpty {
            // No entries yet
            let emptyLabel = SKLabelNode(text: "No successful missions yet!")
            emptyLabel.fontName = "AvenirNext-Medium"
            emptyLabel.fontSize = 20
            emptyLabel.fontColor = .gray
            emptyLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
            addChild(emptyLabel)

            let hintLabel = SKLabelNode(text: "Successfully reach orbit to appear on the leaderboard")
            hintLabel.fontName = "AvenirNext-Regular"
            hintLabel.fontSize = 16
            hintLabel.fontColor = .gray
            hintLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 40)
            addChild(hintLabel)
        } else {
            // Display leaderboard entries
            let startY = size.height - 120
            let rowHeight: CGFloat = 40

            // Headers
            let rankHeader = SKLabelNode(text: "Rank")
            rankHeader.fontName = "AvenirNext-Bold"
            rankHeader.fontSize = 16
            rankHeader.fontColor = .cyan
            rankHeader.position = CGPoint(x: size.width * 0.15, y: startY)
            rankHeader.horizontalAlignmentMode = .left
            addChild(rankHeader)

            let nameHeader = SKLabelNode(text: "Player")
            nameHeader.fontName = "AvenirNext-Bold"
            nameHeader.fontSize = 16
            nameHeader.fontColor = .cyan
            nameHeader.position = CGPoint(x: size.width * 0.30, y: startY)
            nameHeader.horizontalAlignmentMode = .left
            addChild(nameHeader)

            let volumeHeader = SKLabelNode(text: "Volume (m³)")
            volumeHeader.fontName = "AvenirNext-Bold"
            volumeHeader.fontSize = 16
            volumeHeader.fontColor = .cyan
            volumeHeader.position = CGPoint(x: size.width * 0.50, y: startY)
            volumeHeader.horizontalAlignmentMode = .left
            addChild(volumeHeader)

            let lengthHeader = SKLabelNode(text: "Length (m)")
            lengthHeader.fontName = "AvenirNext-Bold"
            lengthHeader.fontSize = 16
            lengthHeader.fontColor = .cyan
            lengthHeader.position = CGPoint(x: size.width * 0.70, y: startY)
            lengthHeader.horizontalAlignmentMode = .left
            addChild(lengthHeader)

            // Entries
            for (index, entry) in entries.enumerated() {
                let yPosition = startY - CGFloat(index + 1) * rowHeight - 10

                // Rank
                let rankLabel = SKLabelNode(text: "#\(index + 1)")
                rankLabel.fontName = "AvenirNext-Medium"
                rankLabel.fontSize = 14
                rankLabel.fontColor = rankColor(for: index)
                rankLabel.position = CGPoint(x: size.width * 0.15, y: yPosition)
                rankLabel.horizontalAlignmentMode = .left
                addChild(rankLabel)

                // Player name
                let nameLabel = SKLabelNode(text: entry.name)
                nameLabel.fontName = "AvenirNext-Regular"
                nameLabel.fontSize = 14
                nameLabel.fontColor = .white
                nameLabel.position = CGPoint(x: size.width * 0.30, y: yPosition)
                nameLabel.horizontalAlignmentMode = .left
                addChild(nameLabel)

                // Volume
                let volumeLabel = SKLabelNode(text: String(format: "%.1f m³", entry.volume))
                volumeLabel.fontName = "AvenirNext-Regular"
                volumeLabel.fontSize = 14
                volumeLabel.fontColor = .white
                volumeLabel.position = CGPoint(x: size.width * 0.50, y: yPosition)
                volumeLabel.horizontalAlignmentMode = .left
                addChild(volumeLabel)

                // Length
                let lengthLabel = SKLabelNode(text: String(format: "%.1f m", entry.optimalLength))
                lengthLabel.fontName = "AvenirNext-Regular"
                lengthLabel.fontSize = 14
                lengthLabel.fontColor = .white
                lengthLabel.position = CGPoint(x: size.width * 0.70, y: yPosition)
                lengthLabel.horizontalAlignmentMode = .left
                addChild(lengthLabel)
            }
        }

        // Back button
        let backButton = createButton(text: "Back to Menu", position: CGPoint(x: size.width / 2, y: 80))
        backButton.name = "back"
        addChild(backButton)
    }

    private func rankColor(for index: Int) -> UIColor {
        switch index {
        case 0: return .systemYellow  // Gold
        case 1: return .lightGray      // Silver
        case 2: return UIColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1.0)  // Bronze
        default: return .white
        }
    }

    private func createButton(text: String, position: CGPoint) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontName = "AvenirNext-Medium"
        button.fontSize = 20
        button.fontColor = .white
        button.position = position
        button.verticalAlignmentMode = .center
        button.horizontalAlignmentMode = .center

        let background = SKShapeNode(rectOf: CGSize(width: 250, height: 45), cornerRadius: 8)
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
            if let labelNode = node as? SKLabelNode, labelNode.name == "back" {
                // Add button press effect
                let scaleDown = SKAction.scale(to: 0.9, duration: 0.1)
                let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
                labelNode.run(SKAction.sequence([scaleDown, scaleUp]))

                // Return to menu
                let transition = SKTransition.fade(withDuration: 0.5)
                let menuScene = MenuScene(size: size)
                menuScene.scaleMode = .aspectFill
                view?.presentScene(menuScene, transition: transition)
            }
        }
    }
}
