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

    /// Default initializer - uses current design from GameManager
    init() {
        self.planeDesign = GameManager.shared.getPlaneDesign()
        self.machNumber = 2.5  // Default Mach number
        super.init(nibName: nil, bundle: nil)
    }

    /// Custom initializer with specific parameters
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

        // Create SwiftUI view
        let liftingBodyView = LiftingBody3DView(
            coneAngle: coneAngle,
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
    @State private var flatTopPct: Double = 70
    @State private var heightFactor: Double = 10
    @State private var slopeCurve: Double = 1.5

    let planeDesign: PlaneDesign
    let onDismiss: () -> Void

    @State private var scene: SCNScene = {
        let scene = SCNScene()
        scene.background.contents = UIColor.darkGray

        // Lighting for wireframe visibility
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 1000
        scene.rootNode.addChildNode(ambientLight)

        return scene
    }()

    @State private var airplaneNode: SCNNode?
    @State private var cameraNode: SCNNode?
    @State private var zoomLevel: Double = 1.0

    init(coneAngle: Double, planeDesign: PlaneDesign, onDismiss: @escaping () -> Void) {
        _coneAngle = State(initialValue: coneAngle)
        self.planeDesign = planeDesign
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            // 3D Viewport
            SceneView(
                scene: scene,
                pointOfView: cameraNode,
                options: [.allowsCameraControl]
            )
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                setupCamera()
                addCargoBox()
                updateGeometry()
            }
            .onChange(of: coneAngle) { _ in updateGeometry() }
            .onChange(of: flatTopPct) { _ in updateGeometry() }
            .onChange(of: heightFactor) { _ in updateGeometry() }
            .onChange(of: slopeCurve) { _ in updateGeometry() }
            .onChange(of: zoomLevel) { _ in updateCameraZoom() }

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

                    // Zoom controls
                    HStack(spacing: 8) {
                        Text("Zoom")
                            .foregroundColor(.white)
                            .font(.system(size: 14))

                        Button(action: zoomIn) {
                            Text("+")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }

                        Text(":")
                            .foregroundColor(.white)
                            .font(.system(size: 14))

                        Button(action: zoomOut) {
                            Text("-")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.blue)
                                .cornerRadius(6)
                        }
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

    private func zoomIn() {
        zoomLevel = min(zoomLevel + 0.2, 3.0) // Max zoom in: 3x
    }

    private func zoomOut() {
        zoomLevel = max(zoomLevel - 0.2, 0.3) // Max zoom out: 0.3x (further away)
    }

    private func updateCameraZoom() {
        guard let camera = cameraNode else { return }

        // Base camera distance is 300m
        let baseDistance: Double = 300.0
        let adjustedDistance = baseDistance / zoomLevel

        // Keep camera position relative to the center point
        camera.position = SCNVector3(50, -adjustedDistance, 50)
        camera.look(at: SCNVector3(50, 0, 0))
    }

    private func setupCamera() {
        let camera = SCNNode()
        camera.camera = SCNCamera()

        // Set camera clipping planes for large geometry
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 10000.0
        camera.camera?.fieldOfView = 60

        // Aircraft extends from x=0 (apex) to x=100m (tail)
        // Width can be up to 300m at widest point
        // Position camera to see entire aircraft centered
        // Center point is around x=50m

        // Position camera far enough to see 300m span and 100m length
        camera.position = SCNVector3(50, -300, 50)  // Side view: centered on x=50, 300m to the side, elevated
        camera.look(at: SCNVector3(50, 0, 0))       // Look at center of aircraft

        scene.rootNode.addChildNode(camera)
        self.cameraNode = camera
    }

    private func updateGeometry() {
        let newGeo = LiftingBodyEngine.generateGeometry(
            coneAngle: coneAngle,
            sweepAngle: planeDesign.sweepAngle,
            tiltAngle: planeDesign.tiltAngle,
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

        print("Geometry updated: \(newGeo.sources.count) sources")
    }

    private func addCargoBox() {
        // Create 8×8×16m cargo box in red wireframe
        // Position at x=40 (center of payload region)
        // Dimensions: width (X) = 16m length, height (Y) = 8m span, length (Z) = 8m height
        let cargoBox = SCNBox(width: 16.0, height: 8.0, length: 8.0, chamferRadius: 0)

        let cargoMaterial = SCNMaterial()
        cargoMaterial.diffuse.contents = UIColor.red
        cargoMaterial.emission.contents = UIColor.red
        cargoMaterial.fillMode = .lines  // Wireframe
        cargoMaterial.lightingModel = .constant
        cargoBox.firstMaterial = cargoMaterial

        let cargoNode = SCNNode(geometry: cargoBox)
        // Position at center of payload region
        // X = 40m (center of payload region: 30-50m)
        // Y = 0 (centerline, spanwise)
        // Z = 0 (centerline, vertical) - box extends ±4m in Z
        cargoNode.position = SCNVector3(40, 0, 0)
        scene.rootNode.addChildNode(cargoNode)

        print("Cargo box added at position (40, 0, 0) - 16m×8m×8m (L×W×H)")
    }
}
