//
//  TextInputBox.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/26/25.
//

import SpriteKit

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

    func updateValue(_ newValue: String) {
        currentValue = newValue
        updateDisplay()
    }

    override func contains(_ point: CGPoint) -> Bool {
        let localPoint = convert(point, from: parent!)
        return background.contains(localPoint)
    }
}
