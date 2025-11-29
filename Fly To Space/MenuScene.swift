//
//  MenuScene.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import SpriteKit
import GameplayKit
import SwiftUI // Imported to enable UIHostingController

class MenuScene: SKScene {
    
    private var titleLabel: SKLabelNode?
    private var newGameButton: SKLabelNode?
    private var planeDesignButton: SKLabelNode?
    private var resumeGameButton: SKLabelNode?
    private var exitButton: SKLabelNode?
    private var jupiter: SKSpriteNode?
    
    override func didMove(to view: SKView) {
        setupBackground()
        setupJupiter()
        setupUI()
    }
    
    private func setupBackground() {
        // Set background to black
        backgroundColor = .black
        
        // Create starfield
        for _ in 0..<200 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...2.0))
            star.fillColor = .white
            star.strokeColor = .clear
            star.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            star.alpha = CGFloat.random(in: 0.3...1.0)
            
            // Add twinkling effect to some stars
            if Bool.random() {
                let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: Double.random(in: 1.0...3.0))
                let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: Double.random(in: 1.0...3.0))
                let twinkle = SKAction.sequence([fadeOut, fadeIn])
                star.run(SKAction.repeatForever(twinkle))
            }
            
            addChild(star)
        }
    }
    
    private func setupJupiter() {
        // Create Jupiter using texture image
        let jupiterTexture = SKTexture(imageNamed: "jupiter.png")
        let jupiterSize: CGFloat = 240 // Diameter
        jupiter = SKSpriteNode(texture: jupiterTexture, size: CGSize(width: jupiterSize, height: jupiterSize))
        
        // Position in upper right corner
        jupiter?.position = CGPoint(x: size.width - 150, y: size.height - 150)
        
        // Add slow rotation
        let rotateAction = SKAction.rotate(byAngle: .pi * 2, duration: 60.0) // Full rotation in 60 seconds
        jupiter?.run(SKAction.repeatForever(rotateAction))
        
        if let jupiter = jupiter {
            addChild(jupiter)
        }
    }
    
    private func setupUI() {
        // Title label
        titleLabel = SKLabelNode(text: "Welcome to Fly to Space")
        titleLabel?.fontName = "AvenirNext-Bold"
        titleLabel?.fontSize = 32
        titleLabel?.fontColor = .white
        titleLabel?.position = CGPoint(x: size.width / 2, y: size.height * 0.75 + 20)
        
        // Add a subtle glow effect
        titleLabel?.addGlow(radius: 8)
        
        if let titleLabel = titleLabel {
            addChild(titleLabel)
        }
        
        // Calculate button positioning
        let availableHeight = size.height * 0.55
        let buttonSpacing: CGFloat = availableHeight / 5
        let startY = size.height * 0.625

        // New Game button
        newGameButton = createButton(text: "New Game", position: CGPoint(x: size.width / 2, y: startY))
        if let newGameButton = newGameButton {
            addChild(newGameButton)
        }

        // Plane Design button
        planeDesignButton = createButton(text: "Plane Design", position: CGPoint(x: size.width / 2, y: startY - buttonSpacing))
        if let planeDesignButton = planeDesignButton {
            addChild(planeDesignButton)
        }

        // Resume Game button
        resumeGameButton = createButton(text: "Resume Game", position: CGPoint(x: size.width / 2, y: startY - buttonSpacing * 2))
        if let resumeGameButton = resumeGameButton {
            addChild(resumeGameButton)
        }

        // Exit button
        exitButton = createButton(text: "Exit", position: CGPoint(x: size.width / 2, y: startY - buttonSpacing * 3))
        if let exitButton = exitButton {
            addChild(exitButton)
        }
    }
    
    private func createButton(text: String, position: CGPoint) -> SKLabelNode {
        let button = SKLabelNode(text: text)
        button.fontName = "AvenirNext-Medium"
        button.fontSize = 24
        button.fontColor = .white
        button.position = position
        button.name = text
        button.verticalAlignmentMode = .center
        button.horizontalAlignmentMode = .center
        
        // Add background for button
        let background = SKShapeNode(rectOf: CGSize(width: 240, height: 40), cornerRadius: 8) // Widened slightly for longer text
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
                case "New Game":
                    startNewGame()
                case "Plane Design":
                    openPlaneDesign()
                case "Resume Game":
                    resumeGame()
                case "Exit":
                    exitGame()
                default:
                    break
                }
            }
        }
    }
    
    private func startNewGame() {
        // Start a new mission and transition to flight planning
        GameManager.shared.startNewMission()
        
        let transition = SKTransition.fade(withDuration: 1.0)
        let planningScene = FlightPlanningScene(size: size)
        planningScene.scaleMode = .aspectFill
        view?.presentScene(planningScene, transition: transition)
    }
    
    private func openPlaneDesign() {
        // Open the TopViewDesignViewController
        let designViewController = TopViewDesignViewController()
        designViewController.modalPresentationStyle = .fullScreen

        // Get the view controller from the view
        if let skView = view,
           let window = skView.window,
           let rootVC = window.rootViewController {
            rootVC.present(designViewController, animated: true)
        }
    }

    private func resumeGame() {
        // Resume existing flight plan (if any)
        let transition = SKTransition.fade(withDuration: 1.0)
        let planningScene = FlightPlanningScene(size: size)
        planningScene.scaleMode = .aspectFill
        view?.presentScene(planningScene, transition: transition)
    }
    
    private func exitGame() {
        // Exit the application
        exit(0)
    }
}

// Extension to add glow effect
extension SKLabelNode {
    func addGlow(radius: CGFloat = 20) {
        let effectNode = SKEffectNode()
        effectNode.shouldRasterize = true
        effectNode.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": radius])
        
        if let parent = self.parent {
            parent.insertChild(effectNode, at: 0)
            effectNode.addChild(SKLabelNode(text: self.text))
            effectNode.position = self.position
            if let glowLabel = effectNode.children.first as? SKLabelNode {
                glowLabel.fontName = self.fontName
                glowLabel.fontSize = self.fontSize
                glowLabel.fontColor = .cyan
                glowLabel.alpha = 0.6
            }
        }
    }
}
