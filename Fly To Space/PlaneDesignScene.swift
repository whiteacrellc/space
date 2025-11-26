//
//  PlaneDesignScene.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/26/25.
//

import SpriteKit

class PlaneDesignScene: SKScene {
    // Cone parameters (3D space)
    private let coneHeight: CGFloat = 300.0
    private let coneRadius: CGFloat = 150.0  // radius at base

    // Cutting plane parameters
    private var planeAngleX: CGFloat = -3.0  // rotation around X axis (pitch)
    private var planeAngleY: CGFloat = 92.0 // rotation around Y axis (yaw) - 90° gives vertical plane
    private var planeOffsetZ: CGFloat = 0.0 // offset along X axis (along cone)

    // UI Elements
    private var angleXSlider: SliderControl?
    private var angleYSlider: SliderControl?
    private var offsetZSlider: SliderControl?

    private var shapePreview: SKShapeNode?
    private var coneWireframe: SKShapeNode?
    private var planeGrid: SKShapeNode?

    // Performance feedback labels
    private var dragFeedbackLabel: SKLabelNode?
    private var thermalFeedbackLabel: SKLabelNode?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupUI()
        updateVisualization()
        updatePerformanceFeedback()
    }

    private func setupUI() {
        // Title
        let titleLabel = SKLabelNode(text: "Aircraft Design")
        titleLabel.fontName = "AvenirNext-Bold"
        titleLabel.fontSize = 32
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 50)
        addChild(titleLabel)

        let subtitleLabel = SKLabelNode(text: "Adjust cutting plane to define leading edge shape")
        subtitleLabel.fontName = "AvenirNext-Medium"
        subtitleLabel.fontSize = 18
        subtitleLabel.fontColor = .cyan
        subtitleLabel.position = CGPoint(x: size.width / 2, y: size.height - 85)
        addChild(subtitleLabel)

        // Performance feedback (upper right)
        let feedbackX: CGFloat = size.width - 200
        let feedbackY: CGFloat = size.height - 50

        let feedbackTitleLabel = SKLabelNode(text: "Performance @ 70k ft, Mach 2.5")
        feedbackTitleLabel.fontName = "AvenirNext-Medium"
        feedbackTitleLabel.fontSize = 16
        feedbackTitleLabel.fontColor = .yellow
        feedbackTitleLabel.position = CGPoint(x: feedbackX, y: feedbackY)
        feedbackTitleLabel.horizontalAlignmentMode = .left
        addChild(feedbackTitleLabel)

        dragFeedbackLabel = SKLabelNode(text: "Drag Coeff: -")
        dragFeedbackLabel?.fontName = "AvenirNext-Regular"
        dragFeedbackLabel?.fontSize = 14
        dragFeedbackLabel?.fontColor = .white
        dragFeedbackLabel?.position = CGPoint(x: feedbackX, y: feedbackY - 25)
        dragFeedbackLabel?.horizontalAlignmentMode = .left
        if let label = dragFeedbackLabel {
            addChild(label)
        }

        thermalFeedbackLabel = SKLabelNode(text: "Temperature: -")
        thermalFeedbackLabel?.fontName = "AvenirNext-Regular"
        thermalFeedbackLabel?.fontSize = 14
        thermalFeedbackLabel?.fontColor = .white
        thermalFeedbackLabel?.position = CGPoint(x: feedbackX, y: feedbackY - 45)
        thermalFeedbackLabel?.horizontalAlignmentMode = .left
        if let label = thermalFeedbackLabel {
            addChild(label)
        }

        // Control panel (right side)
        let controlX: CGFloat = size.width - 280
        let startY: CGFloat = size.height - 150

        // Angle X slider (pitch)
        let angleXLabel = SKLabelNode(text: "Pitch Angle: -3°")
        angleXLabel.fontName = "AvenirNext-Regular"
        angleXLabel.fontSize = 16
        angleXLabel.fontColor = .white
        angleXLabel.position = CGPoint(x: controlX, y: startY)
        angleXLabel.name = "angleXLabel"
        addChild(angleXLabel)

        angleXSlider = SliderControl(
            position: CGPoint(x: controlX, y: startY - 30),
            width: 200,
            minValue: -45,
            maxValue: 45,
            initialValue: -3,
            name: "angleX"
        )
        if let slider = angleXSlider {
            addChild(slider)
        }

        // Angle Y slider (yaw)
        let angleYLabel = SKLabelNode(text: "Yaw Angle: 92°")
        angleYLabel.fontName = "AvenirNext-Regular"
        angleYLabel.fontSize = 16
        angleYLabel.fontColor = .white
        angleYLabel.position = CGPoint(x: controlX, y: startY - 90)
        angleYLabel.name = "angleYLabel"
        addChild(angleYLabel)

        angleYSlider = SliderControl(
            position: CGPoint(x: controlX, y: startY - 120),
            width: 200,
            minValue: 45,
            maxValue: 135,
            initialValue: 92,
            name: "angleY"
        )
        if let slider = angleYSlider {
            addChild(slider)
        }

        // Offset Z slider (along cone axis)
        let offsetZLabel = SKLabelNode(text: "Position: Midpoint")
        offsetZLabel.fontName = "AvenirNext-Regular"
        offsetZLabel.fontSize = 16
        offsetZLabel.fontColor = .white
        offsetZLabel.position = CGPoint(x: controlX, y: startY - 180)
        offsetZLabel.name = "offsetZLabel"
        addChild(offsetZLabel)

        offsetZSlider = SliderControl(
            position: CGPoint(x: controlX, y: startY - 210),
            width: 200,
            minValue: -150,
            maxValue: 150,
            initialValue: 0,
            name: "offsetZ"
        )
        if let slider = offsetZSlider {
            addChild(slider)
        }

        // Shape info
        let shapeLabel = SKLabelNode(text: "Shape: Triangle")
        shapeLabel.fontName = "AvenirNext-Medium"
        shapeLabel.fontSize = 18
        shapeLabel.fontColor = .green
        shapeLabel.position = CGPoint(x: controlX, y: startY - 280)
        shapeLabel.name = "shapeLabel"
        addChild(shapeLabel)

        // Buttons
        let backButton = createButton(text: "Back to Menu", position: CGPoint(x: 120, y: 40))
        backButton.name = "back"
        addChild(backButton)

        let saveButton = createButton(text: "Save Design", position: CGPoint(x: size.width - 120, y: 40))
        saveButton.name = "save"
        addChild(saveButton)
    }

    private func createButton(text: String, position: CGPoint) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: 200, height: 50), cornerRadius: 10)
        button.fillColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        button.strokeColor = .cyan
        button.lineWidth = 2
        button.position = position

        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Medium"
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        button.addChild(label)

        return button
    }

    private func updateVisualization() {
        // Remove old visualization
        shapePreview?.removeFromParent()
        coneWireframe?.removeFromParent()
        planeGrid?.removeFromParent()

        // Cone apex position: 3% from left, centered vertically
        let apexX = size.width * 0.03
        let apexY = size.height * 0.5

        // Draw cone wireframe
        coneWireframe = drawConeWireframe(apexPosition: CGPoint(x: apexX, y: apexY))
        if let wireframe = coneWireframe {
            addChild(wireframe)
        }

        // Draw cutting plane grid
        planeGrid = drawPlaneGrid(apexPosition: CGPoint(x: apexX, y: apexY))
        if let grid = planeGrid {
            addChild(grid)
        }

        // Calculate and draw intersection
        let intersectionPath = calculateIntersection(apexPosition: CGPoint(x: apexX, y: apexY))
        shapePreview = SKShapeNode(path: intersectionPath)
        shapePreview?.strokeColor = .cyan
        shapePreview?.lineWidth = 3
        shapePreview?.glowWidth = 2
        if let preview = shapePreview {
            addChild(preview)
        }

        // Update labels
        if let label = childNode(withName: "angleXLabel") as? SKLabelNode {
            label.text = "Pitch Angle: \(Int(planeAngleX))°"
        }
        if let label = childNode(withName: "angleYLabel") as? SKLabelNode {
            label.text = "Yaw Angle: \(Int(planeAngleY))°"
        }
        if let label = childNode(withName: "offsetZLabel") as? SKLabelNode {
            let position = planeOffsetZ + 150  // Relative to apex
            if position < 50 {
                label.text = "Position: Apex"
            } else if position > 250 {
                label.text = "Position: Base"
            } else if abs(position - 150) < 20 {
                label.text = "Position: Midpoint"
            } else {
                label.text = "Position: \(Int(position))"
            }
        }

        // Determine shape type
        let shapeType = determineShapeType()
        if let label = childNode(withName: "shapeLabel") as? SKLabelNode {
            label.text = "Shape: \(shapeType)"
        }
    }

    private func drawPlaneGrid(apexPosition: CGPoint) -> SKShapeNode {
        let node = SKShapeNode()

        // Red grid with 2px lines at 0.5 alpha
        let lineColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.5)
        let lineWidth: CGFloat = 2.0

        // Plane center position along cone axis
        let planeCenterX = coneHeight / 2 + planeOffsetZ

        // Plane grid size (large enough to cover cone)
        let gridSize: CGFloat = 400.0
        let gridDivisions = 10

        // Convert angles to radians
        let pitchRad = planeAngleX * .pi / 180.0
        let yawRad = planeAngleY * .pi / 180.0

        // Calculate plane basis vectors (local coordinate system on the plane)
        // Normal vector (perpendicular to plane)
        let nx = cos(yawRad) * cos(pitchRad)
        let ny = sin(yawRad) * cos(pitchRad)
        let nz = sin(pitchRad)

        // Two perpendicular vectors on the plane (tangent vectors)
        // u is perpendicular to normal in the XY plane
        let ux = -sin(yawRad)
        let uy = cos(yawRad)
        let uz: CGFloat = 0.0

        // v is perpendicular to both normal and u
        let vx = ny * uz - nz * uy
        let vy = nz * ux - nx * uz
        let vz = nx * uy - ny * ux

        // Draw grid lines parallel to u direction
        for i in -gridDivisions...gridDivisions {
            let t = CGFloat(i) / CGFloat(gridDivisions) * gridSize / 2
            let path = CGMutablePath()

            for j in -gridDivisions...gridDivisions {
                let s = CGFloat(j) / CGFloat(gridDivisions) * gridSize / 2

                // Point on plane in 3D
                let x3d = planeCenterX + s * ux + t * vx
                let y3d = s * uy + t * vy
                let z3d = s * uz + t * vz

                // Project to 2D screen
                let depth = y3d
                let perspectiveScale = 1.0 + depth * 0.001
                let screenX = apexPosition.x + x3d * perspectiveScale
                let screenY = apexPosition.y + z3d * perspectiveScale

                if j == -gridDivisions {
                    path.move(to: CGPoint(x: screenX, y: screenY))
                } else {
                    path.addLine(to: CGPoint(x: screenX, y: screenY))
                }
            }

            let lineNode = SKShapeNode(path: path)
            lineNode.strokeColor = lineColor
            lineNode.lineWidth = lineWidth
            node.addChild(lineNode)
        }

        // Draw grid lines parallel to v direction
        for j in -gridDivisions...gridDivisions {
            let s = CGFloat(j) / CGFloat(gridDivisions) * gridSize / 2
            let path = CGMutablePath()

            for i in -gridDivisions...gridDivisions {
                let t = CGFloat(i) / CGFloat(gridDivisions) * gridSize / 2

                // Point on plane in 3D
                let x3d = planeCenterX + s * ux + t * vx
                let y3d = s * uy + t * vy
                let z3d = s * uz + t * vz

                // Project to 2D screen
                let depth = y3d
                let perspectiveScale = 1.0 + depth * 0.001
                let screenX = apexPosition.x + x3d * perspectiveScale
                let screenY = apexPosition.y + z3d * perspectiveScale

                if i == -gridDivisions {
                    path.move(to: CGPoint(x: screenX, y: screenY))
                } else {
                    path.addLine(to: CGPoint(x: screenX, y: screenY))
                }
            }

            let lineNode = SKShapeNode(path: path)
            lineNode.strokeColor = lineColor
            lineNode.lineWidth = lineWidth
            node.addChild(lineNode)
        }

        return node
    }

    private func drawConeWireframe(apexPosition: CGPoint) -> SKShapeNode {
        let node = SKShapeNode()

        // Draw cone as a grid with white lines, 2px width, 0.5 alpha
        // Cone extends horizontally to the right from apex
        let lineColor = UIColor(white: 1.0, alpha: 0.5)
        let lineWidth: CGFloat = 2.0

        // Number of grid divisions
        let numCircles = 12  // Number of cross-section circles along cone length
        let numMeridians = 24  // Number of meridian lines from apex to base

        // Draw cross-section circles at different distances from apex
        for i in 0...numCircles {
            let distance = (CGFloat(i) / CGFloat(numCircles)) * coneHeight
            let radius = (distance / coneHeight) * coneRadius

            if radius > 0 {  // Skip the apex point
                let numPoints = 32  // Points per circle for smooth curve
                let circlePath = CGMutablePath()

                for j in 0...numPoints {
                    let angle = CGFloat(j) * 2 * .pi / CGFloat(numPoints)
                    // Point on circle: (distance, radius*cos(angle), radius*sin(angle))
                    // Project to 2D screen: x=distance (horizontal), y=sin(angle)*radius (vertical)
                    // Add slight perspective based on depth (cos component)
                    let depth = cos(angle) * radius
                    let perspectiveScale = 1.0 + depth * 0.001  // Subtle 3D effect

                    let screenX = apexPosition.x + distance * perspectiveScale
                    let screenY = apexPosition.y + sin(angle) * radius * perspectiveScale

                    if j == 0 {
                        circlePath.move(to: CGPoint(x: screenX, y: screenY))
                    } else {
                        circlePath.addLine(to: CGPoint(x: screenX, y: screenY))
                    }
                }

                let circleNode = SKShapeNode(path: circlePath)
                circleNode.strokeColor = lineColor
                circleNode.lineWidth = lineWidth
                node.addChild(circleNode)
            }
        }

        // Draw meridian lines from apex to base
        for i in 0..<numMeridians {
            let angle = CGFloat(i) * 2 * .pi / CGFloat(numMeridians)

            let meridianPath = CGMutablePath()
            meridianPath.move(to: apexPosition)  // Start at apex

            // Draw line from apex to base along this angle
            let numSteps = 20
            for j in 1...numSteps {
                let distance = (CGFloat(j) / CGFloat(numSteps)) * coneHeight
                let radius = (distance / coneHeight) * coneRadius

                let depth = cos(angle) * radius
                let perspectiveScale = 1.0 + depth * 0.001

                let screenX = apexPosition.x + distance * perspectiveScale
                let screenY = apexPosition.y + sin(angle) * radius * perspectiveScale

                meridianPath.addLine(to: CGPoint(x: screenX, y: screenY))
            }

            let meridianNode = SKShapeNode(path: meridianPath)
            meridianNode.strokeColor = lineColor
            meridianNode.lineWidth = lineWidth
            node.addChild(meridianNode)
        }

        return node
    }

    private func calculateIntersection(apexPosition: CGPoint) -> CGPath {
        let path = CGMutablePath()

        // Convert angles to radians
        let pitchRad = planeAngleX * .pi / 180.0
        let yawRad = planeAngleY * .pi / 180.0

        // Calculate plane normal vector from angles
        // For horizontal cone: X is along cone axis, Y is depth, Z is vertical
        let nx = cos(yawRad) * cos(pitchRad)
        let ny = sin(yawRad) * cos(pitchRad)
        let nz = sin(pitchRad)

        // Plane center position (same as grid)
        let planeX = coneHeight / 2 + planeOffsetZ

        // Calculate intersection curve by sampling points around the cone
        // Cone: at distance x along axis, radius r = (x/coneHeight) * coneRadius
        // Point on surface: (x, r*cos(θ), r*sin(θ))
        let numSamples = 100
        var points: [CGPoint] = []

        for i in 0..<numSamples {
            let theta = CGFloat(i) * 2 * .pi / CGFloat(numSamples)

            let cosTheta = cos(theta)
            let sinTheta = sin(theta)

            // Plane equation: nx*x + ny*y + nz*z = d
            // where d = nx * planeX (plane passes through (planeX, 0, 0))

            // Substitute cone equation into plane equation
            // y = r*cosθ, z = r*sinθ, r = (coneRadius/coneHeight)*x
            // nx*x + ny*(coneRadius/coneHeight)*x*cosθ + nz*(coneRadius/coneHeight)*x*sinθ = nx*planeX
            // x * (nx + ny*(coneRadius/coneHeight)*cosθ + nz*(coneRadius/coneHeight)*sinθ) = nx*planeX

            let denominator = nx + ny * (coneRadius / coneHeight) * cosTheta +
                            nz * (coneRadius / coneHeight) * sinTheta

            if abs(denominator) > 0.001 {
                let x = nx * planeX / denominator

                // Check if x is within cone bounds
                if x >= 0 && x <= coneHeight {
                    let r = (coneRadius / coneHeight) * x
                    let y = r * cosTheta
                    let z = r * sinTheta

                    // Project to 2D screen coordinates
                    let depth = y
                    let perspectiveScale = 1.0 + depth * 0.001

                    let screenX = apexPosition.x + x * perspectiveScale
                    let screenY = apexPosition.y + z * perspectiveScale

                    points.append(CGPoint(x: screenX, y: screenY))
                }
            }
        }

        // Create path from points
        if points.count > 0 {
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
            path.closeSubpath()
        }

        return path
    }

    private func determineShapeType() -> String {
        // Determine the type of conic section based on plane angle
        let pitchAbs = abs(planeAngleX)

        // Cone half-angle
        let coneAngle = atan(coneRadius / coneHeight) * 180.0 / .pi

        if pitchAbs < 5 {
            if abs(planeAngleY - 90) < 5 {
                return "Triangle"
            } else {
                return "Ellipse"
            }
        } else if pitchAbs < coneAngle - 5 {
            return "Ellipse"
        } else if abs(pitchAbs - coneAngle) < 5 {
            return "Parabola"
        } else {
            return "Hyperbola"
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)

        for node in touchedNodes {
            if let name = node.name {
                if name == "back" {
                    transitionToMenu()
                } else if name == "save" {
                    saveDesign()
                } else if name.hasPrefix("angleX") || name.hasPrefix("angleY") || name.hasPrefix("offsetZ") {
                    // Slider interaction handled by SliderControl
                }
            }
        }

        // Forward to sliders
        angleXSlider?.touchBegan(at: location, in: self)
        angleYSlider?.touchBegan(at: location, in: self)
        offsetZSlider?.touchBegan(at: location, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        var needsUpdate = false

        if let newValue = angleXSlider?.touchMoved(to: location, in: self) {
            planeAngleX = newValue
            needsUpdate = true
        }

        if let newValue = angleYSlider?.touchMoved(to: location, in: self) {
            planeAngleY = newValue
            needsUpdate = true
        }

        if let newValue = offsetZSlider?.touchMoved(to: location, in: self) {
            planeOffsetZ = newValue
            needsUpdate = true
        }

        if needsUpdate {
            updateVisualization()
            updatePerformanceFeedback()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        angleXSlider?.touchEnded()
        angleYSlider?.touchEnded()
        offsetZSlider?.touchEnded()
    }

    private func saveDesign() {
        // Create plane design from current parameters
        let design = PlaneDesign(
            pitchAngle: planeAngleX,
            yawAngle: planeAngleY,
            position: planeOffsetZ
        )

        // Save to game manager
        GameManager.shared.setPlaneDesign(design)

        // Show confirmation with design stats
        let savedLabel = SKLabelNode(text: "Design Saved!")
        savedLabel.fontName = "AvenirNext-Bold"
        savedLabel.fontSize = 24
        savedLabel.fontColor = .green
        savedLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 40)
        addChild(savedLabel)

        let scoreLabel = SKLabelNode(text: "Score: \(design.score())/100")
        scoreLabel.fontName = "AvenirNext-Medium"
        scoreLabel.fontSize = 18
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(scoreLabel)

        let tradeoffLabel = SKLabelNode(text: design.summary())
        tradeoffLabel.fontName = "AvenirNext-Regular"
        tradeoffLabel.fontSize = 16
        tradeoffLabel.fontColor = .cyan
        tradeoffLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 30)
        addChild(tradeoffLabel)

        // Fade out and transition
        let fadeOut = SKAction.fadeOut(withDuration: 1.0)
        let remove = SKAction.removeFromParent()
        savedLabel.run(SKAction.sequence([SKAction.wait(forDuration: 1.0), fadeOut, remove]))
        scoreLabel.run(SKAction.sequence([SKAction.wait(forDuration: 1.0), fadeOut, remove]))
        tradeoffLabel.run(SKAction.sequence([SKAction.wait(forDuration: 1.0), fadeOut, remove]))

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.transitionToMenu()
        }
    }

    private func updatePerformanceFeedback() {
        // Create design from current parameters
        let design = PlaneDesign(
            pitchAngle: planeAngleX,
            yawAngle: planeAngleY,
            position: planeOffsetZ
        )

        // Test conditions: 70,000 ft and Mach 2.5
        let testAltitudeFt = 70000.0
        let testMach = 2.5

        // Convert to SI units
        let testAltitudeM = testAltitudeFt * PhysicsConstants.feetToMeters
        let testVelocityMps = testMach * PhysicsConstants.speedOfSoundSeaLevel

        // Calculate drag coefficient using DragCalculator
        let dragCalc = DragCalculator(planeDesign: design)
        let dragForce = dragCalc.calculateDrag(altitude: testAltitudeM, velocity: testVelocityMps)

        // Calculate effective drag coefficient from drag force
        // F_drag = 0.5 * ρ * v² * C_d * A
        // We need atmospheric density at test altitude
        let rho = getAtmosphericDensity(altitudeM: testAltitudeM)
        let effectiveCd = (2.0 * dragForce) / (rho * testVelocityMps * testVelocityMps * PhysicsConstants.referenceArea)

        // Calculate temperature using ThermalModel
        let temperature = ThermalModel.calculateLeadingEdgeTemperature(
            altitude: testAltitudeM,
            velocity: testVelocityMps,
            planeDesign: design
        )
        let maxTemp = ThermalModel.getMaxTemperature(for: design)

        // Update labels
        dragFeedbackLabel?.text = "Drag Coeff: \(String(format: "%.3f", effectiveCd))"

        // Color-code temperature based on thermal limit
        let tempPercent = (temperature / maxTemp) * 100
        let tempColor: UIColor
        if tempPercent > 100 {
            tempColor = .red
        } else if tempPercent > 90 {
            tempColor = .orange
        } else {
            tempColor = .white
        }

        thermalFeedbackLabel?.text = "Temp: \(Int(temperature))°C / \(Int(maxTemp))°C (\(Int(tempPercent))%)"
        thermalFeedbackLabel?.fontColor = tempColor
    }

    private func getAtmosphericDensity(altitudeM: Double) -> Double {
        // Simplified ISA model for density calculation
        let T0 = 288.15 // Sea-level temperature (K)
        let rho0 = 1.225 // Sea-level density (kg/m³)
        let L = -0.0065 // Temperature lapse rate (K/m)
        let R = 287.05287 // Specific gas constant (J/kg·K)
        let g0 = 9.80665 // Gravitational acceleration (m/s²)
        let H_tropo = 11000.0 // Tropopause altitude (m)

        if altitudeM <= H_tropo {
            // Troposphere
            let T = T0 + L * altitudeM
            let exponent = (-g0 / (L * R)) - 1.0
            return rho0 * pow(T / T0, exponent)
        } else {
            // Stratosphere (isothermal)
            let T_tropo = T0 + L * H_tropo
            let rho_tropo = rho0 * pow(T_tropo / T0, (-g0 / (L * R)) - 1.0)
            let P_ratio = exp(-g0 * (altitudeM - H_tropo) / (R * T_tropo))
            return rho_tropo * P_ratio
        }
    }

    private func transitionToMenu() {
        let transition = SKTransition.fade(withDuration: 0.5)
        let menuScene = MenuScene(size: size)
        menuScene.scaleMode = .aspectFill
        view?.presentScene(menuScene, transition: transition)
    }
}

// MARK: - SliderControl

class SliderControl: SKNode {
    private let track: SKShapeNode
    private let thumb: SKShapeNode
    private let width: CGFloat
    private let minValue: CGFloat
    private let maxValue: CGFloat
    private var currentValue: CGFloat
    private var isDragging = false

    init(position: CGPoint, width: CGFloat, minValue: CGFloat, maxValue: CGFloat, initialValue: CGFloat, name: String) {
        self.width = width
        self.minValue = minValue
        self.maxValue = maxValue
        self.currentValue = initialValue

        // Create track
        track = SKShapeNode(rectOf: CGSize(width: width, height: 4), cornerRadius: 2)
        track.fillColor = UIColor(white: 0.3, alpha: 1.0)
        track.strokeColor = .clear

        // Create thumb
        thumb = SKShapeNode(circleOfRadius: 10)
        thumb.fillColor = .cyan
        thumb.strokeColor = .white
        thumb.lineWidth = 2

        super.init()

        self.position = position
        self.name = name

        addChild(track)
        addChild(thumb)

        updateThumbPosition()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateThumbPosition() {
        let normalizedValue = (currentValue - minValue) / (maxValue - minValue)
        let thumbX = -width / 2 + normalizedValue * width
        thumb.position = CGPoint(x: thumbX, y: 0)
    }

    func touchBegan(at location: CGPoint, in scene: SKScene) {
        let localLocation = scene.convert(location, to: self)
        if thumb.contains(localLocation) || track.contains(localLocation) {
            isDragging = true
            updateValue(from: localLocation)
        }
    }

    func touchMoved(to location: CGPoint, in scene: SKScene) -> CGFloat? {
        if isDragging {
            let localLocation = scene.convert(location, to: self)
            updateValue(from: localLocation)
            return currentValue
        }
        return nil
    }

    func touchEnded() {
        isDragging = false
    }

    private func updateValue(from localLocation: CGPoint) {
        let x = max(-width / 2, min(width / 2, localLocation.x))
        let normalizedValue = (x + width / 2) / width
        currentValue = minValue + normalizedValue * (maxValue - minValue)
        updateThumbPosition()
    }
}
