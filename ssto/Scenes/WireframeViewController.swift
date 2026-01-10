import UIKit
import SceneKit

class WireframeViewController: UIViewController {

    var shapeView: SideProfileShapeView?  // Side profile (fuselage cross-section)
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
    private var volumeLabel: UILabel?
    private var dragCoefficientLabel: UILabel?
    private var lengthLabel: UILabel?
    private var wingAreaLabel: UILabel?
    private var wingSpanLabel: UILabel?
    private var dryMassLabel: UILabel?
    private var fuelCapacityLabel: UILabel?
    private var totalMassLabel: UILabel?
    private var infoContainerView: UIView?

    // Gesture tracking
    private var lastPanLocation: CGPoint = .zero
    private var cameraDistance: Float = 600.0
    private var cameraRotationX: Float = 0.3  // Vertical rotation (around X axis)
    private var cameraRotationY: Float = 0.0  // Horizontal rotation (around Y axis)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        setupHeader()
        setupInfoPanel()
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

            // Zoom buttons on the right
            zoomInButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            zoomInButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            zoomInButton.widthAnchor.constraint(equalToConstant: 40),
            zoomInButton.heightAnchor.constraint(equalToConstant: 40),

            zoomOutButton.trailingAnchor.constraint(equalTo: zoomInButton.leadingAnchor, constant: -10),
            zoomOutButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            zoomOutButton.widthAnchor.constraint(equalToConstant: 40),
            zoomOutButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func setupInfoPanel() {
        // Info container in lower left
        let container = UIView()
        container.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.8)
        container.layer.cornerRadius = 8
        view.addSubview(container)
        infoContainerView = container

        let fontSize: CGFloat = 12
        let spacing: CGFloat = 3

        // Length label
        lengthLabel = UILabel()
        lengthLabel?.text = "Length: 0.0 m"
        lengthLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        lengthLabel?.textColor = .cyan
        lengthLabel?.textAlignment = .left
        if let lengthLabel = lengthLabel {
            container.addSubview(lengthLabel)
        }

        // Wing Area label
        wingAreaLabel = UILabel()
        wingAreaLabel?.text = "Wing Area: 0.0 m²"
        wingAreaLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        wingAreaLabel?.textColor = .cyan
        wingAreaLabel?.textAlignment = .left
        if let wingAreaLabel = wingAreaLabel {
            container.addSubview(wingAreaLabel)
        }

        // Wing Span label
        wingSpanLabel = UILabel()
        wingSpanLabel?.text = "Wing Span: 0.0 m"
        wingSpanLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        wingSpanLabel?.textColor = .cyan
        wingSpanLabel?.textAlignment = .left
        if let wingSpanLabel = wingSpanLabel {
            container.addSubview(wingSpanLabel)
        }

        // Volume label
        volumeLabel = UILabel()
        volumeLabel?.text = "Volume: 0.0 m³"
        volumeLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        volumeLabel?.textColor = .yellow
        volumeLabel?.textAlignment = .left
        if let volumeLabel = volumeLabel {
            container.addSubview(volumeLabel)
        }

        // Dry Mass label
        dryMassLabel = UILabel()
        dryMassLabel?.text = "Dry Mass: 0 kg"
        dryMassLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        dryMassLabel?.textColor = .green
        dryMassLabel?.textAlignment = .left
        if let dryMassLabel = dryMassLabel {
            container.addSubview(dryMassLabel)
        }

        // Fuel Capacity label
        fuelCapacityLabel = UILabel()
        fuelCapacityLabel?.text = "Fuel Capacity: 0 kg"
        fuelCapacityLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        fuelCapacityLabel?.textColor = .green
        fuelCapacityLabel?.textAlignment = .left
        if let fuelCapacityLabel = fuelCapacityLabel {
            container.addSubview(fuelCapacityLabel)
        }

        // Total Mass label
        totalMassLabel = UILabel()
        totalMassLabel?.text = "Total Mass: 0 kg"
        totalMassLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        totalMassLabel?.textColor = .green
        totalMassLabel?.textAlignment = .left
        if let totalMassLabel = totalMassLabel {
            container.addSubview(totalMassLabel)
        }

        // Drag coefficient label
        dragCoefficientLabel = UILabel()
        dragCoefficientLabel?.text = "Cd (M0.5, 50kft): 0.000"
        dragCoefficientLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        dragCoefficientLabel?.textColor = .orange
        dragCoefficientLabel?.textAlignment = .left
        if let dragCoefficientLabel = dragCoefficientLabel {
            container.addSubview(dragCoefficientLabel)
        }

        // Layout
        container.translatesAutoresizingMaskIntoConstraints = false
        lengthLabel?.translatesAutoresizingMaskIntoConstraints = false
        wingAreaLabel?.translatesAutoresizingMaskIntoConstraints = false
        wingSpanLabel?.translatesAutoresizingMaskIntoConstraints = false
        volumeLabel?.translatesAutoresizingMaskIntoConstraints = false
        dryMassLabel?.translatesAutoresizingMaskIntoConstraints = false
        fuelCapacityLabel?.translatesAutoresizingMaskIntoConstraints = false
        totalMassLabel?.translatesAutoresizingMaskIntoConstraints = false
        dragCoefficientLabel?.translatesAutoresizingMaskIntoConstraints = false

        var constraints = [
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            container.heightAnchor.constraint(equalToConstant: 180)
        ]

        if let lengthLabel = lengthLabel {
            constraints.append(contentsOf: [
                lengthLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                lengthLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
                lengthLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
            ])
        }

        if let wingAreaLabel = wingAreaLabel {
            constraints.append(contentsOf: [
                wingAreaLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                wingAreaLabel.topAnchor.constraint(equalTo: lengthLabel!.bottomAnchor, constant: spacing),
                wingAreaLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
            ])
        }

        if let wingSpanLabel = wingSpanLabel {
            constraints.append(contentsOf: [
                wingSpanLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                wingSpanLabel.topAnchor.constraint(equalTo: wingAreaLabel!.bottomAnchor, constant: spacing),
                wingSpanLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
            ])
        }

        if let volumeLabel = volumeLabel {
            constraints.append(contentsOf: [
                volumeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                volumeLabel.topAnchor.constraint(equalTo: wingSpanLabel!.bottomAnchor, constant: spacing),
                volumeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
            ])
        }

        if let dryMassLabel = dryMassLabel {
            constraints.append(contentsOf: [
                dryMassLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                dryMassLabel.topAnchor.constraint(equalTo: volumeLabel!.bottomAnchor, constant: spacing),
                dryMassLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
            ])
        }

        if let fuelCapacityLabel = fuelCapacityLabel {
            constraints.append(contentsOf: [
                fuelCapacityLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                fuelCapacityLabel.topAnchor.constraint(equalTo: dryMassLabel!.bottomAnchor, constant: spacing),
                fuelCapacityLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
            ])
        }

        if let totalMassLabel = totalMassLabel {
            constraints.append(contentsOf: [
                totalMassLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                totalMassLabel.topAnchor.constraint(equalTo: fuelCapacityLabel!.bottomAnchor, constant: spacing),
                totalMassLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
            ])
        }

        if let dragCoefficientLabel = dragCoefficientLabel {
            constraints.append(contentsOf: [
                dragCoefficientLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                dragCoefficientLabel.topAnchor.constraint(equalTo: totalMassLabel!.bottomAnchor, constant: spacing),
                dragCoefficientLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12)
            ])
        }

        NSLayoutConstraint.activate(constraints)
    }

    @objc private func doneButtonTapped() {
        dismiss(animated: true, completion: nil)
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
            // Convert view model coordinates to saved model coordinates
            // This matches the logic in SSTODesignViewController.saveToGameManager()
            let canvasHeight: CGFloat = 400.0  // Standard canvas height from SSTODesignViewController
            let viewCenterY: CGFloat = canvasHeight / 2  // Centerline in view space (200)
            let centerlineY: CGFloat = 200.0  // Centerline in saved model space

            // Helper to convert from view model coordinates to saved model coordinates
            func convertToSerializable(_ point: CGPoint, isFixedX: Bool) -> SerializablePoint {
                let offsetFromCenterline = point.y - viewCenterY
                let savedY = centerlineY + offsetFromCenterline
                return SerializablePoint(x: Double(point.x), y: Double(savedY), isFixedX: isFixedX)
            }

            profile = SideProfileShape(
                frontStart: convertToSerializable(shapeView.inletStart, isFixedX: true),
                frontControl: convertToSerializable(shapeView.inletControl, isFixedX: false),
                frontEnd: convertToSerializable(shapeView.inletEnd, isFixedX: false),
                engineEnd: convertToSerializable(shapeView.engineEnd, isFixedX: false),
                exhaustControl: convertToSerializable(shapeView.nozzleControl, isFixedX: false),
                exhaustEnd: convertToSerializable(shapeView.nozzleEnd, isFixedX: true),
                topStart: convertToSerializable(shapeView.topStart, isFixedX: true),
                topControl: convertToSerializable(shapeView.topControl, isFixedX: false),
                topEnd: convertToSerializable(shapeView.topEnd, isFixedX: true),
                engineLength: Double(shapeView.engineLength),
                maxHeight: Double(shapeView.maxHeight)
            )
        }
        
        let planform = GameManager.shared.getTopViewPlanform()
        let crossSection = GameManager.shared.getCrossSectionPoints()
        
        // 2. Prepare Unit Cross Section (Normalized to [-1, 1] range)
        // This gives us the shape of the rib (e.g., airfoil/fuselage section)
        let unitShape = generateUnitCrossSection(from: crossSection, steps: 5)  // Doubled for more Y-axis detail

        // 3. Generate Mesh Points
        var meshPoints: [[SCNVector3]] = []
        let numRibs = 40  // Halved for fewer X-axis lines
        
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

        // Calculate and display all aircraft dimensions
        calculateAndDisplayDimensions(meshPoints: meshPoints, planform: planform, profile: profile)
    }

    private func calculateAndDisplayDimensions(meshPoints: [[SCNVector3]], planform: TopViewPlanform, profile: SideProfileShape) {
        // Get aircraft length in meters from planform
        let aircraftLengthMeters = planform.aircraftLength

        // Calculate canvas units to meters conversion
        let startX = min(planform.noseTip.x, profile.frontStart.x)
        let endX = max(planform.tailLeft.x, profile.exhaustEnd.x)
        let aircraftLengthCanvas = endX - startX
        let metersPerUnit = aircraftLengthMeters / aircraftLengthCanvas

        // Calculate volume by integrating cross-sectional areas
        var totalVolume: Double = 0.0

        for i in 0..<meshPoints.count - 1 {
            // Get cross-sections at adjacent ribs
            let section1 = meshPoints[i]
            let section2 = meshPoints[i + 1]

            // Calculate cross-sectional area using shoelace formula
            let area1 = calculateCrossSectionArea(section: section1)
            let area2 = calculateCrossSectionArea(section: section2)

            // Average area for this segment
            let avgArea = (area1 + area2) / 2.0

            // Distance between sections in canvas units
            let dx = abs(Double(section2[0].x - section1[0].x))

            // Volume of this segment (in canvas units cubed)
            let segmentVolume = avgArea * dx

            totalVolume += segmentVolume
        }

        // Convert from canvas units³ to meters³
        let conversionFactor = metersPerUnit * metersPerUnit * metersPerUnit
        let volumeInMeters = totalVolume * conversionFactor

        // Calculate wing area (same logic as in TopViewShapeView)
        let fuselageLength = planform.tailLeft.x - planform.noseTip.x
        let wingStartX = planform.noseTip.x + (fuselageLength * planform.wingStartPosition)
        let wingTrailingX = planform.tailLeft.x
        let wingChordCanvas = wingTrailingX - wingStartX
        let wingSpanCanvas = planform.wingSpan
        let wingChordMeters = wingChordCanvas * metersPerUnit
        let wingSpanMeters = wingSpanCanvas * metersPerUnit
        let totalWingArea = wingChordMeters * wingSpanMeters

        // Calculate wing span (total span, both sides)
        let totalWingSpan = wingSpanMeters * 2.0

        // Calculate mass - now dynamic based on flight plan and design
        let flightPlan = GameManager.shared.getFlightPlan()
        let planeDesign = GameManager.shared.getPlaneDesign()

        let dryMassKg = PhysicsConstants.calculateDryMass(
            volumeM3: volumeInMeters,
            waypoints: flightPlan.waypoints,
            planeDesign: planeDesign,
            maxTemperature: 800.0 // Estimated
        )

        let fuelDensityKgPerLiter = 0.08  // From PhysicsConstants
        let volumeInLiters = volumeInMeters * 1000.0  // Convert m³ to liters
        let fuelCapacityKg = volumeInLiters * fuelDensityKgPerLiter
        let totalMassKg = dryMassKg + fuelCapacityKg

        // Calculate drag coefficient
        let dragCalculator = DragCalculator(planeDesign: planeDesign)
        let mach = 0.5
        let altitudeFeet = 50000.0
        let altitudeMeters = altitudeFeet * 0.3048  // Convert feet to meters
        let cd = dragCalculator.getCd(mach: mach, altitude: altitudeMeters)

        // Update all labels
        DispatchQueue.main.async { [weak self] in
            self?.lengthLabel?.text = String(format: "Length: %.1f m", aircraftLengthMeters)
            self?.wingAreaLabel?.text = String(format: "Wing Area: %.1f m²", totalWingArea)
            self?.wingSpanLabel?.text = String(format: "Wing Span: %.1f m", totalWingSpan)
            self?.volumeLabel?.text = String(format: "Volume: %.1f m³", volumeInMeters)
            self?.dryMassLabel?.text = String(format: "Dry Mass: %d kg", Int(dryMassKg))
            self?.fuelCapacityLabel?.text = String(format: "Fuel Capacity: %d kg", Int(fuelCapacityKg))
            self?.totalMassLabel?.text = String(format: "Total Mass: %d kg", Int(totalMassKg))
            self?.dragCoefficientLabel?.text = String(format: "Cd (M0.5, 50kft): %.3f", cd)
        }
    }

    /// Calculate cross-sectional area using shoelace formula (2D polygon area)
    private func calculateCrossSectionArea(section: [SCNVector3]) -> Double {
        guard section.count >= 3 else { return 0.0 }

        var area: Double = 0.0

        // Use Y-Z plane for cross-section (X is along length)
        for i in 0..<section.count {
            let j = (i + 1) % section.count
            let yi = Double(section[i].y)
            let zi = Double(section[i].z)
            let yj = Double(section[j].y)
            let zj = Double(section[j].z)

            area += yi * zj - yj * zi
        }

        return abs(area / 2.0)
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
        // The planform is defined by quadratic Bezier curves (matching TopViewShapeView)
        // Curve 1: noseTip -> midLeft (control: frontControlLeft)
        // Curve 2: midLeft -> tailLeft (control: rearControlLeft)

        let noseTip = planform.noseTip.toCGPoint()
        let frontControlLeft = planform.frontControlLeft.toCGPoint()
        let midLeft = planform.midLeft.toCGPoint()
        let rearControlLeft = planform.rearControlLeft.toCGPoint()
        let tailLeft = planform.tailLeft.toCGPoint()

        // Determine which curve segment contains x
        if x <= midLeft.x {
            // First curve: noseTip -> midLeft
            let y = interpolatePlanformBezierY(x: CGFloat(x),
                                              p0: noseTip,
                                              p1: frontControlLeft,
                                              p2: midLeft)
            return abs(y)
        } else if x <= tailLeft.x {
            // Second curve: midLeft -> tailLeft
            let y = interpolatePlanformBezierY(x: CGFloat(x),
                                              p0: midLeft,
                                              p1: rearControlLeft,
                                              p2: tailLeft)
            return abs(y)
        } else {
            // Beyond tail
            return abs(tailLeft.y)
        }
    }

    // Interpolate Y value on a quadratic Bezier curve at a given X position
    private func interpolatePlanformBezierY(x: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        // For quadratic Bezier: P(t) = (1-t)^2 * p0 + 2(1-t)t * p1 + t^2 * p2
        // We need to find t such that P(t).x = x, then return P(t).y

        // Use binary search to find t that gives us the desired x
        var tMin: CGFloat = 0.0
        var tMax: CGFloat = 1.0
        var t: CGFloat = 0.5

        for _ in 0..<20 { // 20 iterations should give good precision
            let currentX = (1-t)*(1-t)*p0.x + 2*(1-t)*t*p1.x + t*t*p2.x

            if abs(currentX - x) < 0.1 {
                break
            }

            if currentX < x {
                tMin = t
            } else {
                tMax = t
            }
            t = (tMin + tMax) / 2
        }

        // Calculate Y at this t value
        let y = (1-t)*(1-t)*p0.y + 2*(1-t)*t*p1.y + t*t*p2.y
        return y
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
        // Payload box (Cargo): 20m long × 3m wide × 3m tall
        // Position centered in the middle of aircraft

        // Dimensions in meters
        let boxLengthMeters: CGFloat = 20.0
        let boxWidthMeters: CGFloat = 3.0
        let boxHeightMeters: CGFloat = 3.0

        // Scale factor: canvas units per meter (canvas is ~800 units for ~70 meters)
        let canvasWidth: CGFloat = 800.0
        let aircraftLengthMeters: CGFloat = 70.0
        let scale = canvasWidth / aircraftLengthMeters  // ~11.43 units per meter

        // Convert to canvas units
        let boxLength = boxLengthMeters * scale
        let boxWidth = boxWidthMeters * scale
        let boxHeight = boxHeightMeters * scale

        let box = SCNBox(width: boxLength, height: boxWidth, length: boxHeight, chamferRadius: 0.0)

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.orange.withAlphaComponent(0.8)
        material.fillMode = .fill  // Solid
        material.lightingModel = .constant
        material.isDoubleSided = true
        box.firstMaterial = material

        payloadNode?.removeFromParentNode()
        payloadNode = SCNNode(geometry: box)

        // Position centered at middle of aircraft
        let midX = (CGFloat(profile.frontStart.x) + CGFloat(profile.exhaustEnd.x)) / 2.0

        // The centerline in side profile is at inletStart.y, which becomes Z in 3D
        let centerlineZ = CGFloat(profile.frontStart.y)

        payloadNode!.position = SCNVector3(
            Float(midX) - centerOffset.x,         // X: centered longitudinally
            0 - centerOffset.y,                    // Y: centered spanwise (width)
            Float(centerlineZ) - centerOffset.z    // Z: centered on aircraft centerline
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
        // Pilot box: 5m long × 3m wide × 3m tall
        // Positioned in front of payload box with right edge aligned

        // Dimensions in meters
        let boxLengthMeters: CGFloat = 5.0
        let boxWidthMeters: CGFloat = 3.0
        let boxHeightMeters: CGFloat = 3.0
        let payloadLengthMeters: CGFloat = 20.0

        // Scale factor: canvas units per meter (canvas is ~800 units for ~70 meters)
        let canvasWidth: CGFloat = 800.0
        let aircraftLengthMeters: CGFloat = 70.0
        let scale = canvasWidth / aircraftLengthMeters  // ~11.43 units per meter

        // Convert to canvas units
        let boxLength = boxLengthMeters * scale
        let boxWidth = boxWidthMeters * scale
        let boxHeight = boxHeightMeters * scale
        let payloadLength = payloadLengthMeters * scale

        let box = SCNBox(width: boxLength, height: boxWidth, length: boxHeight, chamferRadius: 0.0)

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.green.withAlphaComponent(0.8)
        material.fillMode = .fill  // Solid
        material.lightingModel = .constant
        material.isDoubleSided = true
        box.firstMaterial = material

        pilotNode?.removeFromParentNode()
        pilotNode = SCNNode(geometry: box)

        // Calculate payload position (middle of aircraft)
        let midX = (CGFloat(profile.frontStart.x) + CGFloat(profile.exhaustEnd.x)) / 2.0
        let payloadStartX = midX - payloadLength / 2.0

        // Position pilot box so right edge aligns with left edge of payload
        let pilotCenterX = payloadStartX - boxLength / 2.0

        // The centerline in side profile is at inletStart.y, which becomes Z in 3D
        let centerlineZ = CGFloat(profile.frontStart.y)

        pilotNode!.position = SCNVector3(
            Float(pilotCenterX) - centerOffset.x,     // X: in front of payload
            0 - centerOffset.y,                        // Y: centered spanwise (width)
            Float(centerlineZ) - centerOffset.z        // Z: centered on aircraft centerline
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
