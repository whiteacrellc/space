//
//  GameViewController.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Present the MenuScene
        if let view = self.view as! SKView? {
            let menuScene = MenuScene(size: view.bounds.size)
            menuScene.scaleMode = .aspectFill

            view.presentScene(menuScene)
            view.ignoresSiblingOrder = true

            view.showsFPS = true
            view.showsNodeCount = true
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
