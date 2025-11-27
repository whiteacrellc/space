import SwiftUI
import SceneKit
import ModelIO
import SceneKit.ModelIO

// MARK: - Geometry Engine

struct ProfilePoint {
    let x: Float
    let width: Float
}

class LiftingBodyEngine {
    
    /// Generates the lifting body geometry based on the provided parameters.
    static func generateGeometry(
        coneAngle: Double,
        planeAngle: Double,
        flatTopPct: Double,
        heightFactor: Double,
        slopeCurve: Double
    ) -> SCNGeometry {
        
        // 1. Setup Parameters
        let length: Float = 10.0
        let segmentsX: Int = 60
        let segmentsY: Int = 30
        
        // 2. Calculate Leading Edge Profile (XY Shape)
        // Convert angles to radians
        let alpha = Float(coneAngle) * (Float.pi / 180.0)
        let beta = Float(planeAngle) * (Float.pi / 180.0)
        
        let profile = calculateProfile(
            length: length,
            segments: segmentsX,
            alpha: alpha,
            beta: beta
        )
        
        // 3. Calculate Area (Trapezoidal Rule)
        var area: Float = 0
        for i in 0..<(profile.count - 1) {
            let w1 = profile[i].width * 2
            let w2 = profile[i+1].width * 2
            let dx = profile[i+1].x - profile[i].x
            area += (w1 + w2) * 0.5 * dx
        }
        
        // 4. Determine Max Z Height
        let maxZ = area * Float(heightFactor / 100.0)
        
        // 5. Build Vertices and Indices
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        
        let flatScale = sqrt(Float(flatTopPct / 100.0))
        
        // --- Top Surface ---
        for i in 0...segmentsX {
            let p = profile[i]
            
            for j in 0...segmentsY {
                let v = Float(j) / Float(segmentsY)
                // Map v to actual width coordinates (-width to +width)
                let zPos = (v - 0.5) * 2 * p.width // Width mapped to Z axis in SceneKit
                
                let distFromCenter = abs((v - 0.5) * 2)
                
                var yPos: Float = 0 // Height mapped to Y axis in SceneKit
                
                if p.width < 0.001 {
                    yPos = 0
                } else if distFromCenter <= flatScale {
                    yPos = maxZ
                } else {
                    let slopePos = (distFromCenter - flatScale) / (1.0 - flatScale)
                    let curveVal = pow(slopePos, Float(slopeCurve))
                    yPos = maxZ * (1.0 - curveVal)
                }
                
                // Centering the model on X
                vertices.append(SCNVector3(p.x - (length/2), yPos, zPos))
            }
        }
        
        // Indices for Top Surface
        for i in 0..<segmentsX {
            for j in 0..<segmentsY {
                let rowLen = segmentsY + 1
                let a = Int32(i * rowLen + j)
                let b = Int32(i * rowLen + (j + 1))
                let c = Int32((i + 1) * rowLen + j)
                let d = Int32((i + 1) * rowLen + (j + 1))
                
                // Triangle 1
                indices.append(contentsOf: [a, b, d])
                // Triangle 2
                indices.append(contentsOf: [a, d, c])
            }
        }
        
        // --- Bottom Cap ---
        let bottomOffset = Int32(vertices.count)
        
        for i in 0...segmentsX {
            let p = profile[i]
            for j in 0...segmentsY {
                let v = Float(j) / Float(segmentsY)
                let zPos = (v - 0.5) * 2 * p.width
                // Bottom is flat at Y = 0
                vertices.append(SCNVector3(p.x - (length/2), 0, zPos))
            }
        }
        
        // Indices for Bottom Cap (Reversed winding order for downward face)
        for i in 0..<segmentsX {
            for j in 0..<segmentsY {
                let rowLen = segmentsY + 1
                let a = bottomOffset + Int32(i * rowLen + j)
                let b = bottomOffset + Int32(i * rowLen + (j + 1))
                let c = bottomOffset + Int32((i + 1) * rowLen + j)
                let d = bottomOffset + Int32((i + 1) * rowLen + (j + 1))
                
                // Triangle 1
                indices.append(contentsOf: [a, d, b])
                // Triangle 2
                indices.append(contentsOf: [a, c, d])
            }
        }
        
        // --- Trailing Edge Closure ---
        // Connect the last row of top to last row of bottom
        let lastRow = segmentsX
        let rowLen = segmentsY + 1
        let topStart = Int32(lastRow * rowLen)
        let botStart = bottomOffset + Int32(lastRow * rowLen)
        
        for j in 0..<segmentsY {
            let topCurrent = topStart + Int32(j)
            let topNext = topStart + Int32(j + 1)
            let botCurrent = botStart + Int32(j)
            let botNext = botStart + Int32(j + 1)
            
            // Quad split into two triangles
            indices.append(contentsOf: [topCurrent, botCurrent, topNext])
            indices.append(contentsOf: [topNext, botCurrent, botNext])
        }
        
        // 6. Create Geometry Sources
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        
        // 7. Calculate Normals using ModelIO
        // This makes the surface smooth instead of faceted or broken
        let mdlMesh = MDLMesh(scnGeometry: geometry)
        mdlMesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.5)
        
        return SCNGeometry(mdlMesh: mdlMesh)
    }
    
    private static func calculateProfile(length: Float, segments: Int, alpha: Float, beta: Float) -> [ProfilePoint] {
        var profile: [ProfilePoint] = []
        
        // Geometric shape factor
        // Avoid division by zero
        let cosAlpha = cos(alpha)
        let k = abs(cos(beta) / (cosAlpha == 0 ? 0.001 : cosAlpha))
        let shapePower = 0.5 + (k * 0.5)
        
        for i in 0...segments {
            let t = Float(i) / Float(segments)
            let xPos = t * length
            
            var width: Float = 0
            if xPos > 0.001 {
                width = pow(xPos, shapePower) * (1.5 + sin(alpha))
            }
            
            profile.append(ProfilePoint(x: xPos, width: width))
        }
        
        return profile
    }
}

// MARK: - SwiftUI View

struct ContentView: View {
    // --- State ---
    @State private var coneAngle: Double = 30
    @State private var planeAngle: Double = 15
    @State private var flatTopPct: Double = 70
    @State private var heightFactor: Double = 10
    @State private var slopeCurve: Double = 1.5
    @State private var isBlueMaterial: Bool = false
    
    // --- Scene ---
    @State private var scene: SCNScene = {
        let scene = SCNScene()
        scene.background.contents = UIColor.systemGroupedBackground
        
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
        
        // Floor
        let floorGeo = SCNFloor()
        floorGeo.reflectivity = 0.1
        let floorNode = SCNNode(geometry: floorGeo)
        floorNode.position = SCNVector3(0, -2, 0) // Slightly below
        scene.rootNode.addChildNode(floorNode)
        
        return scene
    }()
    
    // Node reference to update geometry without rebuilding scene
    @State private var airplaneNode: SCNNode?
    
    var body: some View {
        ZStack {
            // 3D Viewport
            SceneView(
                scene: scene,
                pointOfView: nil,
                options: [.allowsCameraControl, .autoenablesDefaultLighting],
                delegate: nil
            )
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                updateGeometry()
            }
            // Trigger updates when state changes
            .onChange(of: coneAngle) { _ in updateGeometry() }
            .onChange(of: planeAngle) { _ in updateGeometry() }
            .onChange(of: flatTopPct) { _ in updateGeometry() }
            .onChange(of: heightFactor) { _ in updateGeometry() }
            .onChange(of: slopeCurve) { _ in updateGeometry() }
            .onChange(of: isBlueMaterial) { _ in updateMaterial() }
            
            // Header
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("AeroDesign")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Lifting Body Prototype")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button(action: { isBlueMaterial.toggle() }) {
                        Circle()
                            .fill(isBlueMaterial ? Color.blue : Color.gray)
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 2)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Spacer()
                
                // Controls ScrollView
                ScrollView {
                    VStack(spacing: 20) {
                        
                        ControlGroup(title: "Geometry Base", icon: "cube.transparent") {
                            SliderRow(label: "Cone Angle", value: $coneAngle, range: 10...60)
                            SliderRow(label: "Plane Intersection", value: $planeAngle, range: 0...45)
                        }
                        
                        ControlGroup(title: "Top Surface", icon: "arrow.up.left.and.arrow.down.right") {
                            SliderRow(label: "Flat Top Area %", value: $flatTopPct, range: 10...90)
                            SliderRow(label: "Z-Height (Volume)", value: $heightFactor, range: 2...25)
                            SliderRow(label: "Slope Curve", value: $slopeCurve, range: 0.5...3.0)
                        }
                        
                        // Info Box
                        VStack(spacing: 8) {
                            InfoRow(key: "Class", value: "Lifting Body")
                            InfoRow(key: "Symmetry", value: "Axial (XZ)")
                            InfoRow(key: "Material", value: "Ceramic Composite")
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding()
                }
                .frame(maxHeight: 350)
                .background(.ultraThinMaterial)
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .padding(.bottom, 0)
            }
        }
    }
    
    // Logic to rebuild the mesh
    private func updateGeometry() {
        // Generate new geometry
        let newGeo = LiftingBodyEngine.generateGeometry(
            coneAngle: coneAngle,
            planeAngle: planeAngle,
            flatTopPct: flatTopPct,
            heightFactor: heightFactor,
            slopeCurve: slopeCurve
        )
        
        // Apply material
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = isBlueMaterial ? UIColor.systemBlue : UIColor.systemGray5
        material.metalness.contents = 0.6
        material.roughness.contents = 0.2
        newGeo.firstMaterial = material
        
        // Update Scene Node
        if let node = airplaneNode {
            node.geometry = newGeo
        } else {
            let node = SCNNode(geometry: newGeo)
            // Initial positioning if needed
            scene.rootNode.addChildNode(node)
            airplaneNode = node
            
            // Focus camera slightly
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.position = SCNVector3(10, 8, 10)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            scene.rootNode.addChildNode(cameraNode)
        }
    }
    
    private func updateMaterial() {
        guard let material = airplaneNode?.geometry?.firstMaterial else { return }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        material.diffuse.contents = isBlueMaterial ? UIColor.systemBlue : UIColor.systemGray5
        SCNTransaction.commit()
    }
}

// MARK: - Helper UI Components

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            Slider(value: $value, in: range)
        }
    }
}

struct ControlGroup<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .textCase(.uppercase)
            }
            .padding(.bottom, 4)
            Divider()
            content
        }
    }
}

struct InfoRow: View {
    let key: String
    let value: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.caption)
                .foregroundColor(.blue)
            Spacer()
            Text(value)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundColor(.blue)
        }
    }
}

// Extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
