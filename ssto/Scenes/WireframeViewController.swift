import UIKit
import SceneKit

class WireframeViewController: UIViewController {

    var shapeView: ShapeView?  // Side profile (fuselage cross-section)
    var topViewShape: TopViewShapeView?  // Top view (planform/leading edge)
    var maxHeight: CGFloat = 120.0

    private var scnView: SCNView!
    private var scnScene: SCNScene!
    private var cameraNode: SCNNode!
    private var wireframeNode: SCNNode?
    private var payloadNode: SCNNode?
    private var engineNode: SCNNode?
    private var pilotNode: SCNNode?
    private var axesNode: SCNNode?

    // Gesture tracking
    private var lastPanLocation: CGPoint = .zero
    private var cameraDistance: Float = 600.0
    private var cameraRotationX: Float = 0.3  // Vertical rotation (around X axis)
    private var cameraRotationY: Float = 0.0  // Horizontal rotation (around Y axis)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        setupHeader()
        setupGestures()
        generateWireframe()
        updateCameraPosition()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    private func setupHeader() {
        let headerView = UIView()
        headerView.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        view.addSubview(headerView)

        // Done Button
        var doneConfig = UIButton.Configuration.filled()
        doneConfig.title = "← Back to Designer"
        doneConfig.baseForegroundColor = .yellow
        doneConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.1)
        doneConfig.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        doneConfig.cornerStyle = .medium
        
        let doneButton = UIButton(configuration: doneConfig)
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        headerView.addSubview(doneButton)

        let titleLabel = UILabel()
        titleLabel.text = "3D Wireframe View"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)

        // Save Button
        var saveConfig = UIButton.Configuration.filled()
        saveConfig.title = "Save"
        saveConfig.baseForegroundColor = .green
        saveConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.1)
        saveConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        saveConfig.cornerStyle = .medium
        
        let saveButton = UIButton(configuration: saveConfig)
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        headerView.addSubview(saveButton)

        // Load Button
        var loadConfig = UIButton.Configuration.filled()
        loadConfig.title = "Load"
        loadConfig.baseForegroundColor = .orange
        loadConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.1)
        loadConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
        loadConfig.cornerStyle = .medium
        
        let loadButton = UIButton(configuration: loadConfig)
        loadButton.addTarget(self, action: #selector(loadButtonTapped), for: .touchUpInside)
        headerView.addSubview(loadButton)

        let instructionLabel = UILabel()
        instructionLabel.text = "Drag: Rotate"
        instructionLabel.font = UIFont.systemFont(ofSize: 14)
        instructionLabel.textColor = .cyan
        instructionLabel.textAlignment = .right
        headerView.addSubview(instructionLabel)

        // Zoom Controls
        var zoomInConfig = UIButton.Configuration.filled()
        zoomInConfig.title = "+"
        zoomInConfig.baseForegroundColor = .white
        zoomInConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.2)
        zoomInConfig.cornerStyle = .medium
        
        let zoomInButton = UIButton(configuration: zoomInConfig)
        zoomInButton.addTarget(self, action: #selector(zoomInTapped), for: .touchUpInside)
        headerView.addSubview(zoomInButton)

        var zoomOutConfig = UIButton.Configuration.filled()
        zoomOutConfig.title = "-"
        zoomOutConfig.baseForegroundColor = .white
        zoomOutConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.2)
        zoomOutConfig.cornerStyle = .medium
        
        let zoomOutButton = UIButton(configuration: zoomOutConfig)
        zoomOutButton.addTarget(self, action: #selector(zoomOutTapped), for: .touchUpInside)
        headerView.addSubview(zoomOutButton)

        headerView.translatesAutoresizingMaskIntoConstraints = false
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        loadButton.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        zoomInButton.translatesAutoresizingMaskIntoConstraints = false
        zoomOutButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),

            doneButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            saveButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 20),
            saveButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            loadButton.leadingAnchor.constraint(equalTo: saveButton.trailingAnchor, constant: 10),
            loadButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            // Zoom buttons on the right
            zoomInButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            zoomInButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            zoomInButton.widthAnchor.constraint(equalToConstant: 40),
            zoomInButton.heightAnchor.constraint(equalToConstant: 40),

            zoomOutButton.trailingAnchor.constraint(equalTo: zoomInButton.leadingAnchor, constant: -10),
            zoomOutButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            zoomOutButton.widthAnchor.constraint(equalToConstant: 40),
            zoomOutButton.heightAnchor.constraint(equalToConstant: 40),

            // Instruction label to the left of zoom buttons
            instructionLabel.trailingAnchor.constraint(equalTo: zoomOutButton.leadingAnchor, constant: -20),
            instructionLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
    }

    @objc private func doneButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Save/Load Handlers

    @objc private func saveButtonTapped() {
        let alert = UIAlertController(
            title: "Save Design",
            message: "Enter a name for this aircraft design",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Design Name"
            textField.autocapitalizationType = .words
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty else {
                self?.showAlert(title: "Error", message: "Please enter a valid name")
                return
            }

            // Check if design already exists
            let existingNames = GameManager.shared.getSavedDesignNames()
            if existingNames.contains(name) {
                self?.showOverwriteConfirmation(name: name)
            } else {
                self?.performSave(name: name)
            }
        })

        present(alert, animated: true)
    }

    private func showOverwriteConfirmation(name: String) {
        let alert = UIAlertController(
            title: "Overwrite Design?",
            message: "A design named '\(name)' already exists. Overwrite it?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Overwrite", style: .destructive) { [weak self] _ in
            self?.performSave(name: name)
        })

        present(alert, animated: true)
    }

    private func performSave(name: String) {
        if GameManager.shared.saveDesign(name: name) {
            showAlert(title: "Success", message: "Design '\(name)' saved successfully")
        } else {
            showAlert(title: "Error", message: "Failed to save design")
        }
    }

    @objc private func loadButtonTapped() {
        let savedDesigns = GameManager.shared.getSavedDesignNames()

        guard !savedDesigns.isEmpty else {
            showAlert(title: "No Designs", message: "No saved designs found")
            return
        }

        let alert = UIAlertController(
            title: "Load Design",
            message: "Select a design to load",
            preferredStyle: .actionSheet
        )

        for name in savedDesigns {
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.performLoad(name: name)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }

    private func performLoad(name: String) {
        if GameManager.shared.loadDesign(name: name) {
            // Clear the local shapeView so generateWireframe uses the loaded data from GameManager
            self.shapeView = nil
            self.topViewShape = nil

            showAlert(title: "Success", message: "Design '\(name)' loaded successfully")
            generateWireframe() // Refresh display with loaded design
        } else {
            showAlert(title: "Error", message: "Failed to load design")
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func setupScene() {
        scnView = SCNView(frame: view.bounds)
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        view.insertSubview(scnView, at: 0)

        scnScene = SCNScene()
        scnView.scene = scnScene

        // Setup camera
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 1.0
        cameraNode.camera?.zFar = 10000.0
        cameraNode.camera?.fieldOfView = 60
        scnScene.rootNode.addChildNode(cameraNode)

        // Setup lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.intensity = 800
        ambientLight.light!.color = UIColor.white
        scnScene.rootNode.addChildNode(ambientLight)

        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .directional
        directionalLight.light!.intensity = 600
        directionalLight.light!.color = UIColor.white
        directionalLight.eulerAngles = SCNVector3(x: -.pi / 4, y: .pi / 4, z: 0)
        scnScene.rootNode.addChildNode(directionalLight)
    }

    private func setupGestures() {
        // Pan gesture for rotation
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: scnView)

        // Convert screen movement to rotation
        // Vertical drag (up/down) rotates around X axis
        // Horizontal drag (left/right) rotates around Y axis
        let rotationSpeed: Float = 0.005

        cameraRotationY += Float(translation.x) * rotationSpeed  // Left/right = Y rotation
        cameraRotationX += Float(translation.y) * rotationSpeed  // Up/down = X rotation

        // Clamp X rotation to avoid flipping
        cameraRotationX = max(-Float.pi / 2, min(Float.pi / 2, cameraRotationX))

        updateCameraPosition()

        gesture.setTranslation(.zero, in: scnView)
    }

    @objc private func zoomInTapped() {
        cameraDistance -= 100
        cameraDistance = max(200, min(2000, cameraDistance))
        updateCameraPosition()
    }

    @objc private func zoomOutTapped() {
        cameraDistance += 100
        cameraDistance = max(200, min(2000, cameraDistance))
        updateCameraPosition()
    }

    private func updateCameraPosition() {
        // Position camera based on rotation and distance
        let x = cameraDistance * cos(cameraRotationX) * sin(cameraRotationY)
        let y = cameraDistance * sin(cameraRotationX)
        let z = cameraDistance * cos(cameraRotationX) * cos(cameraRotationY)

        cameraNode.position = SCNVector3(x, y, z)
        cameraNode.look(at: SCNVector3(0, 0, 0))
    }



    private func generateWireframe() {
        // Clear existing geometry nodes except axes and camera
        wireframeNode?.removeFromParentNode()
        payloadNode?.removeFromParentNode()
        engineNode?.removeFromParentNode()
        pilotNode?.removeFromParentNode()
        
        // 1. Get Data from GameManager
        // If local shapeView is set (from previous screen), use it to create a temporary profile
        // Otherwise use the saved one
        var profile = GameManager.shared.getSideProfile()
        if let shapeView = self.shapeView {
            profile = SideProfileShape(
                frontStart: SerializablePoint(from: shapeView.frontStartModel, isFixedX: true),
                frontControl: SerializablePoint(from: shapeView.frontControlModel, isFixedX: false),
                frontEnd: SerializablePoint(from: shapeView.frontEndModel, isFixedX: false),
                engineEnd: SerializablePoint(from: shapeView.engineEndModel, isFixedX: false),
                exhaustControl: SerializablePoint(from: shapeView.exhaustControlModel, isFixedX: false),
                exhaustEnd: SerializablePoint(from: shapeView.exhaustEndModel, isFixedX: true),
                topStart: SerializablePoint(from: shapeView.topStartModel, isFixedX: true),
                topControl: SerializablePoint(from: shapeView.topControlModel, isFixedX: false),
                topEnd: SerializablePoint(from: shapeView.topEndModel, isFixedX: true),
                engineLength: Double(shapeView.engineLength),
                maxHeight: Double(maxHeight)
            )
        }
        
        let planform = GameManager.shared.getTopViewPlanform()
        let crossSection = GameManager.shared.getCrossSectionPoints()
        
        // 2. Prepare Unit Cross Section (Normalized to [-1, 1] range)
        // This gives us the shape of the rib (e.g., airfoil/fuselage section)
        let unitShape = generateUnitCrossSection(from: crossSection, steps: 30)
        
        // 3. Generate Mesh Points
        var meshPoints: [[SCNVector3]] = []
        let numRibs = 40
        
        // Determine X bounds
        // Use the profile's extent as the primary length, but consider planform
        let startX = min(planform.noseTip.x, profile.frontStart.x)
        let endX = max(planform.tailLeft.x, profile.exhaustEnd.x)
        
        for i in 0...numRibs {
            let t = Double(i) / Double(numRibs)
            let x = startX + t * (endX - startX)
            
            // Get Dimensions at X
            let halfWidth = getPlanformWidth(at: x, planform: planform) // Returns distance from centerline
            let (zTop, zBottom) = getProfileHeight(at: x, profile: profile)
            
            // Safety check for dimensions
            let height = max(0.1, zTop - zBottom)
            let zCenter = (zTop + zBottom) / 2.0
            let validHalfWidth = max(0.1, halfWidth)
            
            var ribPoints: [SCNVector3] = []
            for unitPoint in unitShape {
                // unitPoint.x is spanwise (-1 to 1)
                // unitPoint.y is vertical (-1 to 1)
                
                let finalY = unitPoint.x * validHalfWidth
                let finalZ = zCenter + (unitPoint.y * height / 2.0)
                
                ribPoints.append(SCNVector3(Float(x), Float(finalY), Float(finalZ)))
            }
            meshPoints.append(ribPoints)
        }
        
        // 4. Create Geometry (Lines)
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        
        // Flatten points and generate indices
        for (ribIndex, rib) in meshPoints.enumerated() {
            let ribStartIndex = Int32(vertices.count)
            vertices.append(contentsOf: rib)
            
            // Draw Rib Loop (Cross-section)
            for j in 0..<rib.count {
                let current = ribStartIndex + Int32(j)
                let next = ribStartIndex + Int32((j + 1) % rib.count)
                indices.append(contentsOf: [current, next])
            }
            
            // Draw Stringers (Longitudinal lines connecting to previous rib)
            if ribIndex > 0 {
                let prevRibStartIndex = ribStartIndex - Int32(rib.count)
                for j in 0..<rib.count {
                    let current = ribStartIndex + Int32(j)
                    let prev = prevRibStartIndex + Int32(j)
                    indices.append(contentsOf: [prev, current])
                }
            }
        }
        
        // Center the geometry
        let (centeredVertices, centerOffset) = centerVerticesAndGetOffset(vertices)
        
        // Create SCNGeometry
        let vertexSource = SCNGeometrySource(vertices: centeredVertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
        
        // Apply material
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.cyan
        material.lightingModel = .constant
        geometry.firstMaterial = material
        
        // Create Node
        wireframeNode = SCNNode(geometry: geometry)
        wireframeNode!.scale = SCNVector3(0.5, 0.5, 0.5) // Scale down for view
        
        // Add components
        addPayloadBox(centerOffset: centerOffset, profile: profile)
        addEngineBox(centerOffset: centerOffset, profile: profile)
        addPilotBox(centerOffset: centerOffset, profile: profile)
        
        scnScene.rootNode.addChildNode(wireframeNode!)
        
        addCoordinateAxes()
    }
    
    // MARK: - Helper Logic

    /// Generate a normalized unit cross-section from control points
    private func generateUnitCrossSection(from crossSection: CrossSectionPoints, steps: Int) -> [CGPoint] {
        var unitShape: [CGPoint] = []

        // Sample the top curve (right side, spanwise +1 to 0)
        let topCurve = interpolateSpline(points: crossSection.topPoints.map { $0.toCGPoint() }, steps: steps)

        // Sample the bottom curve (left side, spanwise 0 to -1)
        let bottomCurve = interpolateSpline(points: crossSection.bottomPoints.map { $0.toCGPoint() }, steps: steps).reversed()

        // Normalize to [-1, 1] spanwise and vertically
        let allPoints = topCurve + bottomCurve
        let minX = allPoints.map { $0.x }.min() ?? 0
        let maxX = allPoints.map { $0.x }.max() ?? 1
        let minY = allPoints.map { $0.y }.min() ?? 0
        let maxY = allPoints.map { $0.y }.max() ?? 1

        let rangeX = max(maxX - minX, 1)
        let rangeY = max(maxY - minY, 1)
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        // Map top curve to spanwise [0, 1], vertical [-1, 1]
        for point in topCurve {
            let normalizedX = (point.x - centerX) / rangeX * 2.0  // Spanwise
            let normalizedY = (point.y - centerY) / rangeY * 2.0  // Vertical
            unitShape.append(CGPoint(x: normalizedX, y: normalizedY))
        }

        // Map bottom curve to spanwise [-1, 0], vertical [-1, 1]
        for point in bottomCurve {
            let normalizedX = (point.x - centerX) / rangeX * 2.0  // Spanwise
            let normalizedY = (point.y - centerY) / rangeY * 2.0  // Vertical
            unitShape.append(CGPoint(x: normalizedX, y: normalizedY))
        }

        return unitShape
    }

    /// Interpolate a spline curve through given points
    private func interpolateSpline(points: [CGPoint], steps: Int) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        var result: [CGPoint] = []

        for i in 0..<points.count - 1 {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]

            let (cp1, cp2) = SplineCalculator.calculateControlPoints(p0: p0, p1: p1, p2: p2, p3: p3)

            // Sample cubic Bezier curve
            for t in 0..<steps {
                let u = CGFloat(t) / CGFloat(steps)
                let point = cubicBezier(t: u, p0: p1, p1: cp1, p2: cp2, p3: p2)
                result.append(point)
            }
        }

        result.append(points.last!)
        return result
    }

    /// Evaluate cubic Bezier curve at parameter t
    private func cubicBezier(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t

        let x = uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x
        let y = uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y

        return CGPoint(x: x, y: y)
    }

    /// Get planform width (half-span) at given X position
    private func getPlanformWidth(at x: Double, planform: TopViewPlanform) -> Double {
        // The planform defines the left side (negative Y)
        // We need to find the Y coordinate at the given X position
        let points = [
            planform.noseTip.toCGPoint(),
            planform.frontControlLeft.toCGPoint(),
            planform.midLeft.toCGPoint(),
            planform.rearControlLeft.toCGPoint(),
            planform.tailLeft.toCGPoint()
        ]

        // Find which segment contains x
        for i in 0..<points.count - 1 {
            let x1 = points[i].x
            let x2 = points[i + 1].x

            if x >= min(x1, x2) && x <= max(x1, x2) {
                // Linear interpolation for simplicity
                let t = (x - x1) / (x2 - x1)
                let y = points[i].y + t * (points[i + 1].y - points[i].y)
                return abs(y)  // Return absolute value (distance from centerline)
            }
        }

        // If x is outside range, return edge values
        if x < points.first!.x {
            return abs(points.first!.y)
        } else {
            return abs(points.last!.y)
        }
    }

    /// Get profile height (top and bottom Z) at given X position
    private func getProfileHeight(at x: Double, profile: SideProfileShape) -> (Double, Double) {
        // Bottom curve (fuselage floor)
        let bottomZ: Double

        let frontStart = profile.frontStart.toCGPoint()
        let frontControl = profile.frontControl.toCGPoint()
        let frontEnd = profile.frontEnd.toCGPoint()
        let engineEnd = profile.engineEnd.toCGPoint()
        let exhaustControl = profile.exhaustControl.toCGPoint()
        let exhaustEnd = profile.exhaustEnd.toCGPoint()

        // Determine which section x falls into for bottom curve
        if x <= frontEnd.x {
            // Front quadratic Bezier section
            let t = (x - frontStart.x) / (frontEnd.x - frontStart.x)
            bottomZ = solveQuadraticBezierY(t: max(0, min(1, t)), p0: frontStart, p1: frontControl, p2: frontEnd)
        } else if x <= engineEnd.x {
            // Engine bay (flat floor)
            bottomZ = frontEnd.y
        } else {
            // Exhaust quadratic Bezier section
            let t = (x - engineEnd.x) / (exhaustEnd.x - engineEnd.x)
            bottomZ = solveQuadraticBezierY(t: max(0, min(1, t)), p0: engineEnd, p1: exhaustControl, p2: exhaustEnd)
        }

        // Top curve
        let topStart = profile.topStart.toCGPoint()
        let topControl = profile.topControl.toCGPoint()
        let topEnd = profile.topEnd.toCGPoint()

        let t = (x - topStart.x) / (topEnd.x - topStart.x)
        let topZ = solveQuadraticBezierY(t: max(0, min(1, t)), p0: topStart, p1: topControl, p2: topEnd)

        return (topZ, bottomZ)
    }

    /// Evaluate quadratic Bezier curve Y coordinate at parameter t
    private func solveQuadraticBezierY(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> Double {
        let u = 1 - t
        return u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
    }

    /// Center vertices and return the offset used
    private func centerVerticesAndGetOffset(_ vertices: [SCNVector3]) -> ([SCNVector3], SCNVector3) {
        guard !vertices.isEmpty else { return ([], SCNVector3Zero) }

        // Calculate bounds
        var minX: Float = vertices[0].x
        var maxX: Float = vertices[0].x
        var minY: Float = vertices[0].y
        var maxY: Float = vertices[0].y
        var minZ: Float = vertices[0].z
        var maxZ: Float = vertices[0].z

        for vertex in vertices {
            minX = min(minX, vertex.x)
            maxX = max(maxX, vertex.x)
            minY = min(minY, vertex.y)
            maxY = max(maxY, vertex.y)
            minZ = min(minZ, vertex.z)
            maxZ = max(maxZ, vertex.z)
        }

        // Calculate center offset
        let centerOffset = SCNVector3(
            (minX + maxX) / 2,
            (minY + maxY) / 2,
            (minZ + maxZ) / 2
        )

        // Center vertices
        let centeredVertices = vertices.map { vertex in
            SCNVector3(
                vertex.x - centerOffset.x,
                vertex.y - centerOffset.y,
                vertex.z - centerOffset.z
            )
        }

        return (centeredVertices, centerOffset)
    }

    private func addPayloadBox(centerOffset: SCNVector3, profile: SideProfileShape) {
        // Payload box: 8m wide × 8m tall × 16m long
        // Position in the payload region (middle of fuselage)
        
        let boxLength: CGFloat = 16.0
        let boxWidth: CGFloat = 8.0
        let boxHeight: CGFloat = 8.0
        
        let box = SCNBox(width: boxLength, height: boxWidth, length: boxHeight, chamferRadius: 0.0)
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.green
        material.fillMode = .lines  // Wireframe
        material.lightingModel = .constant
        box.firstMaterial = material
        
        payloadNode?.removeFromParentNode()
        payloadNode = SCNNode(geometry: box)
        
        // Position at middle of fuselage
        let midX = (CGFloat(profile.frontStart.x) + CGFloat(profile.exhaustEnd.x)) / 2.0
        
        // Get floor height at this X
        let (_, bottomZ) = getProfileHeight(at: Double(midX), profile: profile)
        let zPos = CGFloat(bottomZ) + boxHeight / 2.0
        
        payloadNode!.position = SCNVector3(
            Float(midX) - centerOffset.x,
            0 - centerOffset.y,
            Float(zPos) - centerOffset.z
        )
        
        wireframeNode?.addChildNode(payloadNode!)
    }
    
    private func addEngineBox(centerOffset: SCNVector3, profile: SideProfileShape) {
        // Engine box positioned in engine bay
        let startX = CGFloat(profile.frontEnd.x)
        let engineLength = CGFloat(profile.engineLength)
        let midX = startX + engineLength / 2.0
        
        // Dynamically size based on available space
        let (_, bottomZ) = getProfileHeight(at: Double(midX), profile: profile)
        let (topZ, _) = getProfileHeight(at: Double(midX), profile: profile)
        
        let availableHeight = CGFloat(topZ - bottomZ)
        let boxHeight = min(6.0, availableHeight * 0.8) // Use up to 6m or 80% of height
        let boxWidth: CGFloat = 8.0
        
        let box = SCNBox(width: engineLength, height: boxWidth, length: boxHeight, chamferRadius: 0.0)
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.blue
        material.lightingModel = .constant
        box.firstMaterial = material
        
        engineNode?.removeFromParentNode()
        engineNode = SCNNode(geometry: box)
        
        // Position on the floor
        let zPos = CGFloat(bottomZ) + boxHeight / 2.0
        
        engineNode!.position = SCNVector3(
            Float(midX) - centerOffset.x,
            0 - centerOffset.y,
            Float(zPos) - centerOffset.z
        )
        
        wireframeNode?.addChildNode(engineNode!)
    }
    
    private func addPilotBox(centerOffset: SCNVector3, profile: SideProfileShape) {
        // Pilot box: Cockpit/crew compartment near the nose
        let boxLength: CGFloat = 6.0
        let boxWidth: CGFloat = 4.0
        let boxHeight: CGFloat = 3.0
        
        let box = SCNBox(width: boxLength, height: boxWidth, length: boxHeight, chamferRadius: 0.0)
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.yellow
        material.fillMode = .lines  // Wireframe
        material.lightingModel = .constant
        box.firstMaterial = material
        
        pilotNode?.removeFromParentNode()
        pilotNode = SCNNode(geometry: box)
        
        // Position near the nose (30 units aft of start)
        let noseX = CGFloat(profile.frontStart.x) + 30.0
        
        // Get floor height at this specific X to ensuring it sits inside
        let (_, bottomZ) = getProfileHeight(at: Double(noseX), profile: profile)
        let zPos = CGFloat(bottomZ) + boxHeight / 2.0 + 1.0 // +1.0 buffer from floor
        
        pilotNode!.position = SCNVector3(
            Float(noseX) - centerOffset.x,
            0 - centerOffset.y,
            Float(zPos) - centerOffset.z
        )
        
        wireframeNode?.addChildNode(pilotNode!)
    }

    private func addCoordinateAxes() {
        // Calculate axis length: 20% of screen height in landscape
        let screenHeight = min(view.bounds.width, view.bounds.height)
        let axisLength = Float(screenHeight * 0.2)

        axesNode?.removeFromParentNode()
        axesNode = SCNNode()

        let arrowRadius: CGFloat = CGFloat(axisLength) * 0.02
        let arrowHeight: CGFloat = CGFloat(axisLength) * 0.1
        let lineRadius: CGFloat = arrowRadius * 0.5

        let xAxis = createAxis(
            length: axisLength,
            lineRadius: lineRadius,
            arrowRadius: arrowRadius,
            arrowHeight: arrowHeight,
            color: .red,
            direction: SCNVector3(1, 0, 0),
            label: "X"
        )
        axesNode!.addChildNode(xAxis)

        let yAxis = createAxis(
            length: axisLength,
            lineRadius: lineRadius,
            arrowRadius: arrowRadius,
            arrowHeight: arrowHeight,
            color: .green,
            direction: SCNVector3(0, 1, 0),
            label: "Y"
        )
        axesNode!.addChildNode(yAxis)

        let zAxis = createAxis(
            length: axisLength,
            lineRadius: lineRadius,
            arrowRadius: arrowRadius,
            arrowHeight: arrowHeight,
            color: .blue,
            direction: SCNVector3(0, 0, 1),
            label: "Z"
        )
        axesNode!.addChildNode(zAxis)

        scnScene.rootNode.addChildNode(axesNode!)
    }

    private func createAxis(
        length: Float,
        lineRadius: CGFloat,
        arrowRadius: CGFloat,
        arrowHeight: CGFloat,
        color: UIColor,
        direction: SCNVector3,
        label: String
    ) -> SCNNode {
        let axisNode = SCNNode()

        let cylinder = SCNCylinder(radius: lineRadius, height: CGFloat(length))
        let lineMaterial = SCNMaterial()
        lineMaterial.diffuse.contents = color
        lineMaterial.lightingModel = .constant
        cylinder.firstMaterial = lineMaterial

        let lineNode = SCNNode(geometry: cylinder)

        if direction.x != 0 {
            lineNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            lineNode.position = SCNVector3(length / 2, 0, 0)
        } else if direction.y != 0 {
            lineNode.position = SCNVector3(0, length / 2, 0)
        } else if direction.z != 0 {
            lineNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            lineNode.position = SCNVector3(0, 0, length / 2)
        }

        axisNode.addChildNode(lineNode)

        let cone = SCNCone(topRadius: 0, bottomRadius: arrowRadius, height: arrowHeight)
        let arrowMaterial = SCNMaterial()
        arrowMaterial.diffuse.contents = color
        arrowMaterial.lightingModel = .constant
        cone.firstMaterial = arrowMaterial

        let arrowNode = SCNNode(geometry: cone)

        if direction.x != 0 {
            arrowNode.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
            arrowNode.position = SCNVector3(length + Float(arrowHeight) / 2, 0, 0)
        } else if direction.y != 0 {
            arrowNode.eulerAngles = SCNVector3(0, 0, 0)
            arrowNode.position = SCNVector3(0, length + Float(arrowHeight) / 2, 0)
        } else if direction.z != 0 {
            arrowNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
            arrowNode.position = SCNVector3(0, 0, length + Float(arrowHeight) / 2)
        }

        axisNode.addChildNode(arrowNode)

        let text = SCNText(string: label, extrusionDepth: 0.5)
        text.font = UIFont.boldSystemFont(ofSize: 10)
        text.firstMaterial?.diffuse.contents = color
        text.firstMaterial?.lightingModel = .constant

        let textNode = SCNNode(geometry: text)
        let fontSize: Float = 1.25
        textNode.scale = SCNVector3(fontSize, fontSize, fontSize)

        let labelOffset = length + Float(arrowHeight) + fontSize * 3
        if direction.x != 0 {
            textNode.position = SCNVector3(labelOffset, 0, 0)
        } else if direction.y != 0 {
            textNode.position = SCNVector3(0, labelOffset, 0)
        } else if direction.z != 0 {
            textNode.position = SCNVector3(0, 0, labelOffset)
        }

        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.X, .Y, .Z]
        textNode.constraints = [billboardConstraint]

        axisNode.addChildNode(textNode)

        return axisNode
    }
}
