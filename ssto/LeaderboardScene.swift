//
//  LeaderboardScene.swift
//  ssto
//
//  Displays top 10 players ranked by vehicle dry mass (lower is better)
//

import SpriteKit

class LeaderboardScene: SKScene {

    private var scrollView: UIScrollView?

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
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 40)
        addChild(titleLabel)

        // Back button (upper left, smaller)
        let backButton = createButton(
            text: "← Menu",
            position: CGPoint(x: 80, y: size.height - 40),
            width: 120,
            height: 35,
            fontSize: 16
        )
        backButton.name = "back"
        addChild(backButton)

        // Delete Entry button (upper right)
        let deleteButton = createButton(
            text: "Delete Entry",
            position: CGPoint(x: size.width - 100, y: size.height - 40),
            width: 140,
            height: 35,
            fontSize: 16
        )
        deleteButton.name = "delete"
        addChild(deleteButton)

        // Create scrollable leaderboard
        setupScrollableLeaderboard()
    }

    private func setupScrollableLeaderboard() {
        guard let view = view else { return }

        // Get leaderboard data
        let entries = LeaderboardManager.shared.getTopEntries(limit: 100) // Get all entries

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
            return
        }

        // Create scroll view for leaderboard entries
        let scrollView = UIScrollView()
        scrollView.frame = CGRect(
            x: 40,
            y: 80,  // Bottom margin
            width: view.bounds.width - 80,
            height: view.bounds.height - 180  // Space for title and buttons
        )
        scrollView.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        scrollView.layer.cornerRadius = 10
        scrollView.layer.borderColor = UIColor.cyan.withAlphaComponent(0.5).cgColor
        scrollView.layer.borderWidth = 2
        scrollView.isUserInteractionEnabled = true
        scrollView.showsVerticalScrollIndicator = true

        view.addSubview(scrollView)
        self.scrollView = scrollView

        // Add headers (fixed at top of scroll view)
        let headerHeight: CGFloat = 30
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: scrollView.frame.width, height: headerHeight))
        headerView.backgroundColor = UIColor(white: 0.15, alpha: 1.0)

        let rankHeader = createUILabel(text: "Rank", fontSize: 14, bold: true, color: .cyan)
        rankHeader.frame = CGRect(x: 10, y: 5, width: 60, height: 20)
        headerView.addSubview(rankHeader)

        let nameHeader = createUILabel(text: "Player", fontSize: 14, bold: true, color: .cyan)
        nameHeader.frame = CGRect(x: 80, y: 5, width: 120, height: 20)
        headerView.addSubview(nameHeader)

        let volumeHeader = createUILabel(text: "Volume (m³)", fontSize: 14, bold: true, color: .cyan)
        volumeHeader.frame = CGRect(x: scrollView.frame.width - 280, y: 5, width: 130, height: 20)
        volumeHeader.addSubview(nameHeader)

        let lengthHeader = createUILabel(text: "Length (m)", fontSize: 14, bold: true, color: .cyan)
        lengthHeader.frame = CGRect(x: scrollView.frame.width - 140, y: 5, width: 130, height: 20)
        headerView.addSubview(lengthHeader)

        scrollView.addSubview(headerView)

        // Add entries
        let rowHeight: CGFloat = 30
        var yOffset = headerHeight + 5

        for (index, entry) in entries.enumerated() {
            let rowView = createLeaderboardRow(
                rank: index + 1,
                entry: entry,
                width: scrollView.frame.width,
                yPosition: yOffset
            )
            scrollView.addSubview(rowView)
            yOffset += rowHeight
        }

        // Set content size
        scrollView.contentSize = CGSize(width: scrollView.frame.width, height: yOffset + 10)
    }

    private func createLeaderboardRow(rank: Int, entry: LeaderboardEntry, width: CGFloat, yPosition: CGFloat) -> UIView {
        let rowView = UIView(frame: CGRect(x: 0, y: yPosition, width: width, height: 30))

        // Alternate row colors
        if rank % 2 == 0 {
            rowView.backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        } else {
            rowView.backgroundColor = UIColor(white: 0.08, alpha: 1.0)
        }

        // Make row tappable
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(rowTapped(_:)))
        rowView.addGestureRecognizer(tapGesture)
        rowView.isUserInteractionEnabled = true

        // Store rank in tag for later lookup
        rowView.tag = rank

        // Rank
        let rankLabel = createUILabel(text: "#\(rank)", fontSize: 13, bold: false, color: rankUIColor(for: rank - 1))
        rankLabel.frame = CGRect(x: 10, y: 5, width: 60, height: 20)
        rowView.addSubview(rankLabel)

        // Player name
        let nameLabel = createUILabel(text: entry.name, fontSize: 13, bold: false, color: .white)
        nameLabel.frame = CGRect(x: 80, y: 5, width: 120, height: 20)
        rowView.addSubview(nameLabel)

        // Volume
        let volumeLabel = createUILabel(
            text: String(format: "%.1f", entry.volume),
            fontSize: 13,
            bold: false,
            color: .white
        )
        volumeLabel.frame = CGRect(x: width - 280, y: 5, width: 130, height: 20)
        rowView.addSubview(volumeLabel)

        // Length
        let lengthLabel = createUILabel(
            text: String(format: "%.1f", entry.optimalLength),
            fontSize: 13,
            bold: false,
            color: .white
        )
        lengthLabel.frame = CGRect(x: width - 140, y: 5, width: 130, height: 20)
        rowView.addSubview(lengthLabel)

        return rowView
    }

    private func createUILabel(text: String, fontSize: CGFloat, bold: Bool, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        label.textColor = color
        label.textAlignment = .left
        return label
    }

    private func rankUIColor(for index: Int) -> UIColor {
        switch index {
        case 0: return .systemYellow  // Gold
        case 1: return .lightGray      // Silver
        case 2: return UIColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1.0)  // Bronze
        default: return .white
        }
    }

    @objc private func rowTapped(_ gesture: UITapGestureRecognizer) {
        guard let rowView = gesture.view else { return }
        let rank = rowView.tag

        // Get all entries and find the tapped one
        let entries = LeaderboardManager.shared.getTopEntries(limit: 100)
        guard rank > 0 && rank <= entries.count else { return }

        let entry = entries[rank - 1]

        // Check if entry has a designName
        guard let designName = entry.designName else {
            showErrorDialog(message: "Design file not linked. This entry was created before design linking was implemented.")
            return
        }

        // Load the design
        let loadSuccess = GameManager.shared.loadDesign(name: designName)

        if loadSuccess {
            // Navigate to TopViewDesignViewController
            openTopViewDesign()
        } else {
            showErrorDialog(message: "Failed to load design '\(designName)'. The file may have been deleted.")
        }
    }

    private func openTopViewDesign() {
        // Clean up scroll view before transitioning
        cleanupScrollView()

        // Get the root view controller and present TopViewDesignViewController
        guard let skView = view,
              let window = skView.window,
              let rootVC = window.rootViewController else { return }

        let designViewController = TopViewDesignViewController()
        designViewController.modalPresentationStyle = .fullScreen
        rootVC.present(designViewController, animated: true)
    }

    private func createButton(text: String, position: CGPoint, width: CGFloat = 250, height: CGFloat = 45, fontSize: CGFloat = 20) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontName = "AvenirNext-Medium"
        button.fontSize = fontSize
        button.fontColor = .white
        button.position = position
        button.verticalAlignmentMode = .center
        button.horizontalAlignmentMode = .center

        let background = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8)
        background.fillColor = UIColor(white: 0.2, alpha: 0.6)
        background.strokeColor = .white
        background.lineWidth = 2
        background.zPosition = -1
        button.addChild(background)

        return button
    }

    private func showDeleteDialog() {
        #if os(iOS)
        guard let viewController = view?.window?.rootViewController else { return }

        let alert = UIAlertController(
            title: "Delete Leaderboard Entry",
            message: "Enter the rank number (e.g., 1, 2, 3...) to delete:",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Rank number"
            textField.keyboardType = .numberPad
            textField.returnKeyType = .done
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let rankText = alert.textFields?.first?.text,
                  let rank = Int(rankText),
                  rank > 0 else {
                self?.showErrorDialog(message: "Please enter a valid rank number (e.g., 1, 2, 3...)")
                return
            }

            // Get current entries
            let entries = LeaderboardManager.shared.getTopEntries(limit: 100)

            guard rank <= entries.count else {
                self?.showErrorDialog(message: "Rank #\(rank) does not exist. There are only \(entries.count) entries.")
                return
            }

            // Delete the entry at this rank (rank-1 because array is 0-indexed)
            let entryToDelete = entries[rank - 1]
            LeaderboardManager.shared.deleteEntry(volume: entryToDelete.volume)

            // Refresh the leaderboard display
            self?.refreshLeaderboard()
        })

        viewController.present(alert, animated: true)
        #else
        // macOS version - not implemented
        print("Delete dialog not available on macOS")
        #endif
    }

    private func showErrorDialog(message: String) {
        #if os(iOS)
        guard let viewController = view?.window?.rootViewController else { return }

        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))

        viewController.present(alert, animated: true)
        #endif
    }

    private func refreshLeaderboard() {
        // Clean up existing scroll view
        cleanupScrollView()

        // Remove all children and recreate UI
        removeAllChildren()
        setupUI()
    }

    private func cleanupScrollView() {
        scrollView?.removeFromSuperview()
        scrollView = nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)

        for node in touchedNodes {
            if let labelNode = node as? SKLabelNode {
                if labelNode.name == "back" {
                    // Add button press effect
                    let scaleDown = SKAction.scale(to: 0.9, duration: 0.1)
                    let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
                    labelNode.run(SKAction.sequence([scaleDown, scaleUp]))

                    // Clean up scroll view before transitioning
                    cleanupScrollView()

                    // Return to menu
                    let transition = SKTransition.fade(withDuration: 0.5)
                    let menuScene = MenuScene(size: size)
                    menuScene.scaleMode = .aspectFill
                    view?.presentScene(menuScene, transition: transition)
                } else if labelNode.name == "delete" {
                    // Add button press effect
                    let scaleDown = SKAction.scale(to: 0.9, duration: 0.1)
                    let scaleUp = SKAction.scale(to: 1.0, duration: 0.1)
                    labelNode.run(SKAction.sequence([scaleDown, scaleUp]))

                    // Show delete dialog
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.showDeleteDialog()
                    }
                }
            }
        }
    }

    deinit {
        cleanupScrollView()
    }
}
