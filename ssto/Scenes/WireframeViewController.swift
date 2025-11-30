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
        // Use data from GameManager, but prioritize local shapeView for Side Profile if available
        var profile = GameManager.shared.getSideProfile()
        
        if let shapeView = self.shapeView {
            // Create profile from local shapeView state
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
        let crossSectionPoints = GameManager.shared.getCrossSectionPoints()

        // Parameters for mesh generation
        let longitudinalSamples = 60  // Along the length
        let circumferentialSamples = 32  // Around the circumference
        
        // Generate the base cross-section shape from splines
        let baseAirfoil = generateCrossSectionFromSpline(crossSectionPoints: crossSectionPoints, numSamples: circumferentialSamples)

        // Calculate floor width fraction (span at the bottom of the cross-section)
        // normalized Y ranges from ~-1 (top) to ~1 (bottom)
        var minXAtBottom: Float = 1.0
        var maxXAtBottom: Float = -1.0
        
        // Use a threshold for "bottom"
        let bottomThreshold: Float = 0.95
        
        for point in baseAirfoil {
            if point.y > bottomThreshold {
                if point.x < minXAtBottom { minXAtBottom = point.x }
                if point.x > maxXAtBottom { maxXAtBottom = point.x }
            }
        }
        
        // If no points found (sharp point?), default to a small fraction
        var floorFraction: CGFloat = 0.2
        if maxXAtBottom > minXAtBottom {
            let floorWidthNormalized = CGFloat(maxXAtBottom - minXAtBottom)
            // Normalized X is -1 to 1 (width 2). So fraction is width / 2.
            floorFraction = floorWidthNormalized / 2.0
        }

        var vertices: [SCNVector3] = []
        var indices: [Int32] = []

        // Get the X extent from the side view (profile)
        let startX = CGFloat(profile.topStart.x)
        let endX = CGFloat(profile.topEnd.x)

        // Generate vertices using NURBS-like interpolation
        for i in 0..<longitudinalSamples {
            let t = CGFloat(i) / CGFloat(longitudinalSamples - 1)
            let currentX = startX + t * (endX - startX)

            // Get cross-section data at this X position from side view logic
            guard let crossSection = getCrossSectionAtFromProfile(x: currentX, profile: profile) else { continue }

            // Get the width at this X position from top view planform
            let halfWidth = getWidthFromPlanform(atX: currentX, planform: planform, fraction: t)

            let centerY = crossSection.centerY
            let halfHeight = crossSection.halfHeight

            // Generate points around the circumference using the spline shape
            for j in 0..<circumferentialSamples {
                let sampleIdx = j
                let point = baseAirfoil[sampleIdx % baseAirfoil.count]
                
                // Map spline shape to physical dimensions
                let y = Float(point.x) * halfWidth
                let z = Float(centerY) - Float(point.y) * halfHeight
                
                vertices.append(SCNVector3(Float(currentX), y, z))
            }
        }

        // Generate wireframe indices
        let pointsPerSection = baseAirfoil.count
        
        for i in 0..<longitudinalSamples - 1 {
            for j in 0..<pointsPerSection {
                let nextJ = (j + 1) % pointsPerSection

                let current = Int32(i * pointsPerSection + j)
                let currentNext = Int32(i * pointsPerSection + nextJ)
                let next = Int32((i + 1) * pointsPerSection + j)

                // Circumferential lines (ring)
                indices.append(contentsOf: [current, currentNext])

                // Longitudinal lines (stringers)
                indices.append(contentsOf: [current, next])
            }
        }

        // Close the last circumferential ring
        for j in 0..<pointsPerSection {
            let nextJ = (j + 1) % pointsPerSection
            let current = Int32((longitudinalSamples - 1) * pointsPerSection + j)
            let currentNext = Int32((longitudinalSamples - 1) * pointsPerSection + nextJ)
            indices.append(contentsOf: [current, currentNext])
        }

        // Center the geometry
        let (centeredVertices, centerOffset) = centerVerticesAndGetOffset(vertices)

        // Create geometry
        let vertexSource = SCNGeometrySource(vertices: centeredVertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [vertexSource], elements: [element])

        // Apply teal wireframe material
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.cyan  // Teal/cyan color
        material.lightingModel = .constant  // Unlit for better wireframe visibility
        geometry.firstMaterial = material

        // Add to scene
        wireframeNode?.removeFromParentNode()
        wireframeNode = SCNNode(geometry: geometry)
        wireframeNode!.scale = SCNVector3(0.5, 0.5, 0.5)  // Scale aircraft to 50%
        scnScene.rootNode.addChildNode(wireframeNode!)

        // Add reference boxes
        addPayloadBox()
        addEngineBox(centerOffset: centerOffset, floorFraction: floorFraction)
        addPilotBox()
        addCoordinateAxes()
    }
    
    // Adapted from LiftingBodyEngine
    private func generateCrossSectionFromSpline(
        crossSectionPoints: CrossSectionPoints,
        numSamples: Int
    ) -> [(x: Float, y: Float)] {

        var points: [(x: Float, y: Float)] = []
        
        // Canvas dimensions from SplineCalculator
        let canvasHeight: CGFloat = 500.0
        let centerY: CGFloat = 250.0  // Centerline from SplineCalculator
        
        let topCGPoints = crossSectionPoints.topPoints.map { $0.toCGPoint() }
        let bottomCGPoints = crossSectionPoints.bottomPoints.map { $0.toCGPoint() }

        // Find X extent
        let allX = topCGPoints.map { $0.x } + bottomCGPoints.map { $0.x }
        let minX = allX.min() ?? 100.0
        let maxX = allX.max() ?? 700.0
        let xRange = maxX - minX

        // Top surface samples (Left to Right)
        let topCount = numSamples / 2
        for i in 0...topCount {
            let t = CGFloat(i) / CGFloat(topCount)
            let x = minX + t * xRange
            
            // Interpolate Y
            let yValue = interpolateSpline(points: topCGPoints, atX: x)
            
            // Normalize
            let normX = Float((x - minX) / xRange) * 2.0 - 1.0
            let normY = Float((yValue - centerY) / 250.0) // Assuming 250 is half-height
            
            points.append((x: normX, y: normY))
        }
        
        // Bottom surface samples (Right to Left)
        let bottomCount = numSamples / 2
        for i in 0...bottomCount {
            let t = CGFloat(i) / CGFloat(bottomCount)
            let x = maxX - t * xRange // Right to Left
            
            let yValue = interpolateSpline(points: bottomCGPoints, atX: x)
            
            let normX = Float((x - minX) / xRange) * 2.0 - 1.0
            let normY = Float((yValue - centerY) / 250.0)
            
            if i == 0 { continue } // Skip first point (same as last top point)
            
            points.append((x: normX, y: normY))
        }
        
        return points
    }
    
    // Helper for spline interpolation
    private func interpolateSpline(points: [CGPoint], atX targetX: CGFloat) -> CGFloat {
        var closestBefore: CGPoint?
        var closestAfter: CGPoint?

        for point in points {
            if point.x <= targetX {
                if closestBefore == nil || point.x > closestBefore!.x {
                    closestBefore = point
                }
            }
            if point.x >= targetX {
                if closestAfter == nil || point.x < closestAfter!.x {
                    closestAfter = point
                }
            }
        }

        if let before = closestBefore, let after = closestAfter {
            if abs(after.x - before.x) < 0.001 { return before.y }
            let t = (targetX - before.x) / (after.x - before.x)
            return before.y + t * (after.y - before.y)
        } else if let before = closestBefore {
            return before.y
        } else if let after = closestAfter {
            return after.y
        }
        return 250.0
    }
    
    private func getCrossSectionAtFromProfile(x: CGFloat, profile: SideProfileShape) -> (centerY: CGFloat, halfHeight: Float)? {
        // Evaluate Bezier using profile points directly
        // Top curve
        guard let topY = evaluateQuadraticBezier(
            p0: profile.topStart.toCGPoint(),
            p1: profile.topControl.toCGPoint(),
            p2: profile.topEnd.toCGPoint(),
            atX: x
        ) else { return nil }

        // Bottom curve
        var bottomY: CGFloat
        let frontEnd = profile.frontEnd.toCGPoint()
        let engineEnd = profile.engineEnd.toCGPoint()

        if x < frontEnd.x {
            bottomY = evaluateQuadraticBezier(
                p0: profile.frontStart.toCGPoint(),
                p1: profile.frontControl.toCGPoint(),
                p2: frontEnd,
                atX: x
            ) ?? profile.frontStart.toCGPoint().y
        } else if x <= engineEnd.x {
            bottomY = frontEnd.y
        } else {
            bottomY = evaluateQuadraticBezier(
                p0: engineEnd,
                p1: profile.exhaustControl.toCGPoint(),
                p2: profile.exhaustEnd.toCGPoint(),
                atX: x
            ) ?? profile.exhaustEnd.toCGPoint().y
        }

        let centerY = (topY + bottomY) / 2.0
        let halfHeight = Float(abs(topY - bottomY) / 2.0)

        return (centerY, halfHeight)
    }

    private func centerVerticesAndGetOffset(_ vertices: [SCNVector3]) -> ([SCNVector3], SCNVector3) {
        guard !vertices.isEmpty else { return (vertices, SCNVector3Zero) }

        var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
        var minY = Float.greatestFiniteMagnitude, maxY = -Float.greatestFiniteMagnitude
        var minZ = Float.greatestFiniteMagnitude, maxZ = -Float.greatestFiniteMagnitude

        for v in vertices {
            minX = min(minX, v.x); maxX = max(maxX, v.x)
            minY = min(minY, v.y); maxY = max(maxY, v.y)
            minZ = min(minZ, v.z); maxZ = max(maxZ, v.z)
        }

        let centerX = (minX + maxX) / 2.0
        let centerY = (minY + maxY) / 2.0
        let centerZ = (minZ + maxZ) / 2.0
        let offset = SCNVector3(centerX, centerY, centerZ)

        let centered = vertices.map { SCNVector3($0.x - centerX, $0.y - centerY, $0.z - centerZ) }
        return (centered, offset)
    }

    private func addPayloadBox() {
        // Payload box: 8m x 8m x 16m (Width x Height x Length)
        // Position in the payload region (30-60% of length)

        let box = SCNBox(width: 16.0, height: 8.0, length: 8.0, chamferRadius: 0.0)

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red
        material.emission.contents = UIColor.red.withAlphaComponent(0.3)
        material.fillMode = .lines  // Wireframe
        material.lightingModel = .constant
        box.firstMaterial = material

        payloadNode?.removeFromParentNode()
        payloadNode = SCNNode(geometry: box)
        payloadNode!.position = SCNVector3(0, 0, 0)  // Centered
        scnScene.rootNode.addChildNode(payloadNode!)
    }

    private func addEngineBox(centerOffset: SCNVector3, floorFraction: CGFloat) {
        // Get dimensions from design
        let profile = GameManager.shared.getSideProfile()
        let planform = GameManager.shared.getTopViewPlanform()

        let startX = CGFloat(profile.frontEnd.x)
        let engineLength = CGFloat(profile.engineLength)
        let midX = startX + engineLength / 2.0

        // Calculate width at engine midpoint
        // getWidthFromPlanform returns the MAX half-width of the fuselage at this X
        let maxHalfWidth = getWidthFromPlanform(atX: midX, planform: planform, fraction: 0.5)
        
        // Calculate the physical width at the floor (min Z)
        // floorFraction is the ratio of floor_width / max_width based on the cross-section shape
        let floorWidth = CGFloat(maxHalfWidth * 2.0) * floorFraction
        
        // User Requirement: 90% of the width at min Z
        let boxWidth = floorWidth * 0.9

        let boxHeight: CGFloat = 3.0

        // SCNBox(width, height, length) maps to (X, Y, Z) dimensions in SceneKit node space
        // In our mapping: X=Longitudinal, Y=Spanwise(Width), Z=Vertical(Height)
        // box.width = X size (Engine Length)
        // box.height = Y size (Engine Width)
        // box.length = Z size (Engine Height)
        let box = SCNBox(width: engineLength, height: boxWidth, length: boxHeight, chamferRadius: 0.0)

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.blue // Solid blue
        material.lightingModel = .constant
        box.firstMaterial = material

        engineNode?.removeFromParentNode()
        engineNode = SCNNode(geometry: box)
        
        // Position:
        // X: midX (center of engine along length)
        // Y: 0 (centerline)
        // Z: Sitting on the floor.
        // The floor of the mesh corresponds to profile.frontEnd.y (in model coordinates).
        // Since box origin is center, Z position = floorZ + height/2.
        let lineZ = CGFloat(profile.frontEnd.y)
        let zPos = lineZ + boxHeight / 2.0
        
        // Apply center offset to align with centered wireframe
        engineNode!.position = SCNVector3(
            Float(midX) - centerOffset.x,
            0 - centerOffset.y,
            Float(zPos) - centerOffset.z
        )

        // Add to wireframeNode to inherit scale (0.5)
        wireframeNode?.addChildNode(engineNode!)

        print("Engine box added: \(String(format: "%.1f", engineLength))m (X) × \(String(format: "%.1f", boxWidth))m (Y) × 3.0m (Z)")
    }

    private func addPilotBox() {
        // Pilot box: Cockpit/crew compartment
        // Dimensions: 8m wide × 4m tall × 4m long

        let box = SCNBox(width: 8.0, height: 4.0, length: 4.0, chamferRadius: 0.0)

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.yellow
        material.emission.contents = UIColor.yellow.withAlphaComponent(0.3)
        material.fillMode = .lines  // Wireframe
        material.lightingModel = .constant
        box.firstMaterial = material

        pilotNode?.removeFromParentNode()
        pilotNode = SCNNode(geometry: box)
        pilotNode!.position = SCNVector3(-35, 0, 0)  // Nose area
        scnScene.rootNode.addChildNode(pilotNode!)

        print("Pilot box added: 8m×4m×4m (W×H×L) at X=-35m in yellow wireframe")
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
        print("Coordinate axes added with length: \(axisLength)m")
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
        let fontSize: Float = 1.25 // Reduced from 5.0 (75% smaller)
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

    private func getCrossSectionAt(x: CGFloat, from shapeView: ShapeView) -> (centerY: CGFloat, halfHeight: Float)? {
        // Solve for top and bottom curves at position x

        // Top curve: quadratic bezier from topStart through topControl to topEnd
        guard let topY = evaluateQuadraticBezier(
            p0: shapeView.topStartModel,
            p1: shapeView.topControlModel,
            p2: shapeView.topEndModel,
            atX: x
        ) else { return nil }

        // Bottom curve: three segments (front, engine, exhaust)
        var bottomY: CGFloat

        if x < shapeView.frontEndModel.x {
            // Front curve
            bottomY = evaluateQuadraticBezier(
                p0: shapeView.frontStartModel,
                p1: shapeView.frontControlModel,
                p2: shapeView.frontEndModel,
                atX: x
            ) ?? shapeView.frontStartModel.y
        } else if x <= shapeView.engineEndModel.x {
            // Engine section (flat)
            bottomY = shapeView.frontEndModel.y
        } else {
            // Exhaust curve
            bottomY = evaluateQuadraticBezier(
                p0: shapeView.engineEndModel,
                p1: shapeView.exhaustControlModel,
                p2: shapeView.exhaustEndModel,
                atX: x
            ) ?? shapeView.exhaustEndModel.y
        }

        let centerY = (topY + bottomY) / 2.0
        let halfHeight = Float(abs(topY - bottomY) / 2.0)

        return (centerY, halfHeight)
    }

    private func getWidthFromPlanform(atX x: CGFloat, planform: TopViewPlanform, fraction: CGFloat) -> Float {
        // Use the top view planform to determine width at this X position
        // The planform defines the leading edge shape using Bezier curves

        // Left side curves (we'll mirror for right side)
        let noseTip = planform.noseTip.toCGPoint()
        let frontControl = planform.frontControlLeft.toCGPoint()
        let midLeft = planform.midLeft.toCGPoint()
        let rearControl = planform.rearControlLeft.toCGPoint()
        let tailLeft = planform.tailLeft.toCGPoint()

        // Evaluate the left side width at this X position
        var leftWidth: CGFloat = 0.0

        // Front section: nose to mid
        if x <= midLeft.x {
            if let y = evaluateQuadraticBezier(p0: noseTip, p1: frontControl, p2: midLeft, atX: x) {
                leftWidth = abs(y)  // Y is the lateral offset from centerline
            }
        }
        // Rear section: mid to tail
        else {
            if let y = evaluateQuadraticBezier(p0: midLeft, p1: rearControl, p2: tailLeft, atX: x) {
                leftWidth = abs(y)
            }
        }

        // Ensure minimum width for payload bay (8m total width = 4m half-width)
        if fraction >= 0.3 && fraction <= 0.6 {
            leftWidth = max(leftWidth, 4.0)
        }

        // The total width is 2x the left width (symmetric)
        // Return half-width for use in ellipse generation
        return Float(leftWidth)
    }

    private func getWidthAt(x: CGFloat, totalLength: CGFloat, fraction: CGFloat) -> Float {
        // Fallback method - use default taper
        // Payload region (30-60% of length) should be at least 8m half-width
        if fraction >= 0.3 && fraction <= 0.6 {
            return max(Float(maxHeight) / 2.0, 4.0)  // At least 8m total width (4m half-width)
        } else {
            // Taper toward nose and tail
            let distanceFromPayload = min(abs(fraction - 0.3), abs(fraction - 0.6))
            let taperFactor = 1.0 - Float(distanceFromPayload) * 2.5
            return max(2.0, Float(maxHeight) / 2.0 * taperFactor)
        }
    }

    private func evaluateQuadraticBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, atX x: CGFloat) -> CGFloat? {
        // Solve quadratic Bezier for parameter t where B(t).x = x
        // B(t) = (1-t)²·P0 + 2(1-t)t·P1 + t²·P2

        let a = p0.x - 2.0 * p1.x + p2.x
        let b = 2.0 * (p1.x - p0.x)
        let c = p0.x - x

        // Solve at² + bt + c = 0
        if abs(a) < 1e-6 {
            // Linear case
            if abs(b) < 1e-6 { return nil }
            let t = -c / b
            if t >= 0 && t <= 1 {
                return (1.0 - t) * (1.0 - t) * p0.y + 2.0 * (1.0 - t) * t * p1.y + t * t * p2.y
            }
            return nil
        }

        let discriminant = b * b - 4.0 * a * c
        if discriminant < 0 { return nil }

        let sqrtDisc = sqrt(discriminant)
        let t1 = (-b + sqrtDisc) / (2.0 * a)
        let t2 = (-b - sqrtDisc) / (2.0 * a)

        let t = (t1 >= 0 && t1 <= 1) ? t1 : t2
        if t < 0 || t > 1 { return nil }

        // Evaluate Y at this t
        return (1.0 - t) * (1.0 - t) * p0.y + 2.0 * (1.0 - t) * t * p1.y + t * t * p2.y
    }
}
