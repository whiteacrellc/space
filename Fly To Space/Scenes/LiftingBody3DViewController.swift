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

        // Lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 500
        scene.rootNode.addChildNode(ambientLight)

        let dirLight = SCNNode()
        dirLight.light = SCNLight()
        dirLight.light?.type = .directional
        dirLight.light?.intensity = 1000
        dirLight.light?.castsShadow = true
        dirLight.position = SCNVector3(5, 10, 5)
        dirLight.look(at: SCNVector3(0,0,0))
        scene.rootNode.addChildNode(dirLight)

        // Grid floor
        let floorGeo = SCNFloor()
        floorGeo.reflectivity = 0.05
        let floorMaterial = SCNMaterial()
        floorMaterial.diffuse.contents = UIColor(white: 0.1, alpha: 1.0)
        floorGeo.materials = [floorMaterial]
        let floorNode = SCNNode(geometry: floorGeo)
        floorNode.position = SCNVector3(0, -2, 0)
        scene.rootNode.addChildNode(floorNode)

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
                options: [.allowsCameraControl, .autoenablesDefaultLighting]
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
                        Text("3D Model")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Lifting Body Design")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)

                Spacer()

                // Design info panel
                VStack(spacing: 12) {
                    Text("Design Parameters")
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            InfoText(label: "Pitch", value: "\(Int(planeDesign.pitchAngle))°")
                            InfoText(label: "Yaw", value: "\(Int(planeDesign.yawAngle))°")
                            InfoText(label: "Position", value: "\(Int(planeDesign.position))")
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            InfoText(label: "Cone Angle", value: "\(String(format: "%.1f", coneAngle))°")
                            InfoText(label: "Drag Mult", value: String(format: "%.2fx", planeDesign.dragMultiplier()))
                            InfoText(label: "Thermal", value: String(format: "%.2fx", planeDesign.thermalLimitMultiplier()))
                        }
                    }

                    // Score
                    HStack {
                        Text("Design Score:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(planeDesign.score())/100")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(scoreColor(planeDesign.score()))
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding()
            }
        }
    }

    private func setupCamera() {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(12, 6, 12)
        cameraNode.look(at: SCNVector3(0, 0, 0))
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

        // Apply material based on thermal properties
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased

        // Color based on thermal limit multiplier
        let thermalMult = planeDesign.thermalLimitMultiplier()
        if thermalMult < 0.8 {
            material.diffuse.contents = UIColor.systemRed // Hot
        } else if thermalMult > 1.1 {
            material.diffuse.contents = UIColor.systemBlue // Cool
        } else {
            material.diffuse.contents = UIColor.systemGray // Neutral
        }

        material.metalness.contents = 0.6
        material.roughness.contents = 0.3
        newGeo.firstMaterial = material

        if let node = airplaneNode {
            node.geometry = newGeo
        } else {
            let node = SCNNode(geometry: newGeo)
            scene.rootNode.addChildNode(node)
            airplaneNode = node
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct InfoText: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
    }
}
