//
//  LiftingBody3DViewController.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/26/25.
//

import UIKit
import SwiftUI
import SceneKit

class LiftingBody3DViewController: UIViewController {

    private let planeDesign: PlaneDesign
    private let machNumber: Double

    init(planeDesign: PlaneDesign, machNumber: Double) {
        self.planeDesign = planeDesign
        self.machNumber = machNumber
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Convert PlaneDesign parameters to LiftingBody parameters
        let coneAngle = calculateConeAngle(machNumber: machNumber)
        let planeAngle = abs(planeDesign.pitchAngle)

        // Create SwiftUI view
        let liftingBodyView = LiftingBody3DView(
            coneAngle: coneAngle,
            planeAngle: planeAngle,
            planeDesign: planeDesign,
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            }
        )

        // Host SwiftUI view in UIHostingController
        let hostingController = UIHostingController(rootView: liftingBodyView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
    }

    private func calculateConeAngle(machNumber: Double) -> Double {
        // Mach cone angle: μ = arcsin(1/M)
        if machNumber >= 1.0 {
            let angleRadians = asin(1.0 / machNumber)
            return angleRadians * 180.0 / .pi
        }
        return 30.0 // Default for subsonic
    }
}

// MARK: - SwiftUI 3D View

struct LiftingBody3DView: View {
    @State private var coneAngle: Double
    @State private var planeAngle: Double
    @State private var flatTopPct: Double = 70
    @State private var heightFactor: Double = 10
    @State private var slopeCurve: Double = 1.5

    let planeDesign: PlaneDesign
    let onDismiss: () -> Void

    @State private var scene: SCNScene = {
        let scene = SCNScene()
        scene.background.contents = UIColor.black

        // Lighting for wireframe visibility
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 1000
        scene.rootNode.addChildNode(ambientLight)

        return scene
    }()

    @State private var airplaneNode: SCNNode?

    init(coneAngle: Double, planeAngle: Double, planeDesign: PlaneDesign, onDismiss: @escaping () -> Void) {
        _coneAngle = State(initialValue: coneAngle)
        _planeAngle = State(initialValue: planeAngle)
        self.planeDesign = planeDesign
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            // 3D Viewport
            SceneView(
                scene: scene,
                pointOfView: nil,
                options: [.allowsCameraControl]
            )
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                setupCamera()
                updateGeometry()
            }
            .onChange(of: coneAngle) { _ in updateGeometry() }
            .onChange(of: planeAngle) { _ in updateGeometry() }
            .onChange(of: flatTopPct) { _ in updateGeometry() }
            .onChange(of: heightFactor) { _ in updateGeometry() }
            .onChange(of: slopeCurve) { _ in updateGeometry() }

            VStack {
                // Header
                HStack {
                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("3D Wireframe Model")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Drag to rotate")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)

                Spacer()
            }
        }
    }

    private func setupCamera() {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()

        // Aircraft extends from x=0 (apex) to x=100m (tail)
        // Width can be up to 300m at widest point
        // Position camera to see entire aircraft centered
        // Center point is around x=50m

        // Position camera far enough to see 300m span and 100m length
        cameraNode.position = SCNVector3(50, 0, 400)  // Centered on x=50, 400m back in z
        cameraNode.look(at: SCNVector3(50, 0, 0))     // Look at center of aircraft

        scene.rootNode.addChildNode(cameraNode)
    }

    private func updateGeometry() {
        let newGeo = LiftingBodyEngine.generateGeometry(
            coneAngle: coneAngle,
            planeAngle: planeAngle,
            flatTopPct: flatTopPct,
            heightFactor: heightFactor,
            slopeCurve: slopeCurve
        )

        // Apply wireframe material
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.cyan
        material.fillMode = .lines // Wireframe rendering
        material.lightingModel = .constant // Unlit for better wireframe visibility
        newGeo.firstMaterial = material

        if let node = airplaneNode {
            node.geometry = newGeo
        } else {
            let node = SCNNode(geometry: newGeo)
            scene.rootNode.addChildNode(node)
            airplaneNode = node
        }
    }
}
