//
//  FileManagementScene.swift
//  ssto
//
//  Displays list of saved files with metadata and allows deletion
//

import SpriteKit

class FileManagementScene: SKScene {

    private var titleLabel: SKLabelNode?
    private var fileNodes: [SKNode] = []
    private var scrollOffset: CGFloat = 0
    private var backButton: SKLabelNode?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupUI()
        loadFileList()
    }

    private func setupUI() {
        // Title label
        titleLabel = SKLabelNode(text: "Manage Saved Files")
        titleLabel?.fontName = "AvenirNext-Bold"
        titleLabel?.fontSize = 24
        titleLabel?.fontColor = .white
        titleLabel?.position = CGPoint(x: size.width / 2, y: size.height - 40)

        if let titleLabel = titleLabel {
            addChild(titleLabel)
        }

        // Back button
        backButton = createButton(text: "Back", position: CGPoint(x: size.width / 2, y: 60))
        backButton?.name = "back"
        if let backButton = backButton {
            addChild(backButton)
        }
    }

    private func loadFileList() {
        // Clear existing file nodes
        for node in fileNodes {
            node.removeFromParent()
        }
        fileNodes.removeAll()

        let savedNames = GameManager.shared.getSavedDesignNames()

        if savedNames.isEmpty {
            // No files to display
            let emptyLabel = SKLabelNode(text: "No saved files")
            emptyLabel.fontName = "AvenirNext-Regular"
            emptyLabel.fontSize = 18
            emptyLabel.fontColor = .gray
            emptyLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
            addChild(emptyLabel)
            fileNodes.append(emptyLabel)
            return
        }

        // Display file list
        let startY = size.height - 100
        let rowHeight: CGFloat = 80
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        for (index, name) in savedNames.enumerated() {
            guard let metadata = GameManager.shared.getSaveFileMetadata(name: name) else {
                continue
            }

            let yPosition = startY - CGFloat(index) * rowHeight

            // Create container for file row
            let rowNode = SKNode()
            rowNode.position = CGPoint(x: 0, y: yPosition)
            rowNode.name = "file_row_\(name)"

            // File name (left side)
            let nameLabel = SKLabelNode(text: name)
            nameLabel.fontName = "AvenirNext-Bold"
            nameLabel.fontSize = 16
            nameLabel.fontColor = .white
            nameLabel.position = CGPoint(x: 50, y: 10)
            nameLabel.horizontalAlignmentMode = .left
            rowNode.addChild(nameLabel)

            // Date saved
            let dateLabel = SKLabelNode(text: dateFormatter.string(from: metadata.savedDate))
            dateLabel.fontName = "AvenirNext-Regular"
            dateLabel.fontSize = 12
            dateLabel.fontColor = .lightGray
            dateLabel.position = CGPoint(x: 50, y: -8)
            dateLabel.horizontalAlignmentMode = .left
            rowNode.addChild(dateLabel)

            // Aircraft length
            let lengthText = String(format: "Length: %.1f m", metadata.aircraftLength)
            let lengthLabel = SKLabelNode(text: lengthText)
            lengthLabel.fontName = "AvenirNext-Regular"
            lengthLabel.fontSize = 12
            lengthLabel.fontColor = .cyan
            lengthLabel.position = CGPoint(x: size.width * 0.45, y: 10)
            lengthLabel.horizontalAlignmentMode = .left
            rowNode.addChild(lengthLabel)

            // Leaderboard rank (if applicable)
            if let volume = metadata.volume,
               let rank = LeaderboardManager.shared.getRank(volume: volume) {
                let rankText = "Rank: #\(rank)"
                let rankLabel = SKLabelNode(text: rankText)
                rankLabel.fontName = "AvenirNext-Bold"
                rankLabel.fontSize = 12
                rankLabel.fontColor = .yellow
                rankLabel.position = CGPoint(x: size.width * 0.45, y: -8)
                rankLabel.horizontalAlignmentMode = .left
                rowNode.addChild(rankLabel)
            } else {
                // Not ranked
                let noRankLabel = SKLabelNode(text: "Not ranked")
                noRankLabel.fontName = "AvenirNext-Regular"
                noRankLabel.fontSize = 12
                noRankLabel.fontColor = .gray
                noRankLabel.position = CGPoint(x: size.width * 0.45, y: -8)
                noRankLabel.horizontalAlignmentMode = .left
                rowNode.addChild(noRankLabel)
            }

            // Delete button (right side)
            let deleteButton = createDeleteButton(position: CGPoint(x: size.width - 80, y: 0))
            deleteButton.name = "delete_\(name)"
            rowNode.addChild(deleteButton)

            // Separator line
            let separator = SKShapeNode(rect: CGRect(x: 30, y: -30, width: size.width - 60, height: 1))
            separator.fillColor = UIColor(white: 0.3, alpha: 0.5)
            separator.strokeColor = .clear
            rowNode.addChild(separator)

            addChild(rowNode)
            fileNodes.append(rowNode)
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

        let background = SKShapeNode(rectOf: CGSize(width: 200, height: 40), cornerRadius: 8)
        background.fillColor = UIColor(white: 0.2, alpha: 0.6)
        background.strokeColor = .white
        background.lineWidth = 2
        background.zPosition = -1
        button.addChild(background)

        return button
    }

    private func createDeleteButton(position: CGPoint) -> SKLabelNode {
        let button = SKLabelNode(text: "Delete")
        button.fontName = "AvenirNext-Medium"
        button.fontSize = 14
        button.fontColor = .white
        button.position = position
        button.verticalAlignmentMode = .center
        button.horizontalAlignmentMode = .center

        let background = SKShapeNode(rectOf: CGSize(width: 80, height: 30), cornerRadius: 6)
        background.fillColor = UIColor.systemRed.withAlphaComponent(0.7)
        background.strokeColor = .white
        background.lineWidth = 1.5
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

                if labelNode.name == "back" {
                    backToSettings()
                } else if let name = labelNode.name, name.hasPrefix("delete_") {
                    let fileName = String(name.dropFirst("delete_".count))
                    confirmDelete(fileName: fileName)
                }
            }
        }
    }

    private func confirmDelete(fileName: String) {
        #if os(iOS)
        guard let viewController = view?.window?.rootViewController else { return }

        let alert = UIAlertController(
            title: "Delete File",
            message: "Are you sure you want to delete '\(fileName)'? This cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteFile(name: fileName)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        viewController.present(alert, animated: true)
        #endif
    }

    private func deleteFile(name: String) {
        GameManager.shared.deleteDesign(name: name)

        // Reload the file list
        loadFileList()

        // Show confirmation
        showDeleteConfirmation(fileName: name)
    }

    private func showDeleteConfirmation(fileName: String) {
        let confirmLabel = SKLabelNode(text: "'\(fileName)' deleted")
        confirmLabel.fontName = "AvenirNext-Bold"
        confirmLabel.fontSize = 16
        confirmLabel.fontColor = .green
        confirmLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        confirmLabel.alpha = 0

        addChild(confirmLabel)

        // Fade in, hold, fade out
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let wait = SKAction.wait(forDuration: 1.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()

        confirmLabel.run(SKAction.sequence([fadeIn, wait, fadeOut, remove]))
    }

    private func backToSettings() {
        let transition = SKTransition.fade(withDuration: 0.5)
        let settingsScene = SettingsScene(size: size)
        settingsScene.scaleMode = .aspectFill
        view?.presentScene(settingsScene, transition: transition)
    }
}
