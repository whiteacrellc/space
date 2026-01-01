import UIKit

class TopViewShapeView: UIView {
    var noseTipModel = CGPoint.zero  // Fixed at (0, 0) in model space (centerline y=0)
    var frontControlLeftModel = CGPoint.zero
    var midLeftModel = CGPoint.zero
    var rearControlLeftModel = CGPoint.zero
    var tailLeftModel = CGPoint.zero
    var tailRightModel = CGPoint.zero
    var rearControlRightModel = CGPoint.zero
    var midRightModel = CGPoint.zero
    var frontControlRightModel = CGPoint.zero

    // Wing parameters
    var wingStartPosition: CGFloat = 0.67  // Fraction of fuselage length (0.0 to 1.0)
    var wingSpan: CGFloat = 150.0          // Wing half-span from centerline

    // Canvas dimensions
    var canvasWidth: CGFloat = 0
    var canvasHeight: CGFloat = 0

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard canvasWidth > 0 && canvasHeight > 0 else { return }

        // Mirror points for right side
        frontControlRightModel = CGPoint(x: frontControlLeftModel.x, y: -frontControlLeftModel.y)
        midRightModel = CGPoint(x: midLeftModel.x, y: -midLeftModel.y)
        rearControlRightModel = CGPoint(x: rearControlLeftModel.x, y: -rearControlLeftModel.y)
        tailRightModel = CGPoint(x: tailLeftModel.x, y: -tailLeftModel.y)

        // Convert model coordinates to view coordinates
        let nt = modelToView(noseTipModel)
        let fcl = modelToView(frontControlLeftModel)
        let ml = modelToView(midLeftModel)
        let rcl = modelToView(rearControlLeftModel)
        let tl = modelToView(tailLeftModel)
        let tr = modelToView(tailRightModel)
        let rcr = modelToView(rearControlRightModel)
        let mr = modelToView(midRightModel)
        let fcr = modelToView(frontControlRightModel)

        let path = UIBezierPath()
        path.move(to: nt)
        path.addQuadCurve(to: ml, controlPoint: fcl)
        path.addQuadCurve(to: tl, controlPoint: rcl)
        path.addLine(to: tr)
        path.addQuadCurve(to: mr, controlPoint: rcr)
        path.addQuadCurve(to: nt, controlPoint: fcr)

        // Fill with gradient-like color
        UIColor(red: 0.3, green: 0.4, blue: 0.7, alpha: 0.6).setFill()
        path.fill()

        // Stroke outline
        UIColor.white.setStroke()
        path.lineWidth = 2
        path.stroke()

        // Draw wings
        drawWings()
    }

    private func drawWings() {
        // Calculate wing start X position based on fuselage length
        let fuselageLength = tailLeftModel.x - noseTipModel.x
        let wingStartX = noseTipModel.x + (fuselageLength * wingStartPosition)

        // Calculate fuselage width at wing start position (leading edge)
        let fuselageWidthAtStart = getFuselageWidthAt(x: wingStartX)

        // Calculate fuselage width at tail (trailing edge)
        let wingTrailingX = tailLeftModel.x
        let fuselageWidthAtEnd = getFuselageWidthAt(x: wingTrailingX)

        // Wing leading edge - matches fuselage width exactly (no extension)
        let wingLeadingEdgeLeft = CGPoint(x: wingStartX, y: -fuselageWidthAtStart)
        let wingLeadingEdgeRight = CGPoint(x: wingStartX, y: fuselageWidthAtStart)

        // Wing trailing edge - extends beyond fuselage by wingSpan
        let wingTrailingEdgeLeft = CGPoint(x: wingTrailingX, y: -(fuselageWidthAtEnd + wingSpan))
        let wingTrailingEdgeRight = CGPoint(x: wingTrailingX, y: (fuselageWidthAtEnd + wingSpan))

        // Wing root at trailing edge (where wing meets fuselage at tail)
        let wingRootRearLeft = CGPoint(x: wingTrailingX, y: -fuselageWidthAtEnd)
        let wingRootRearRight = CGPoint(x: wingTrailingX, y: fuselageWidthAtEnd)

        // Convert to view coordinates
        let wlLeading = modelToView(wingLeadingEdgeLeft)
        let wrLeading = modelToView(wingLeadingEdgeRight)
        let wlTrailing = modelToView(wingTrailingEdgeLeft)
        let wrTrailing = modelToView(wingTrailingEdgeRight)
        let rootRearLeft = modelToView(wingRootRearLeft)
        let rootRearRight = modelToView(wingRootRearRight)

        // Draw left wing (triangular shape)
        let leftWingPath = UIBezierPath()
        leftWingPath.move(to: wlLeading)        // Leading edge at fuselage
        leftWingPath.addLine(to: wlTrailing)     // Trailing edge tip
        leftWingPath.addLine(to: rootRearLeft)   // Back to fuselage at tail
        leftWingPath.close()

        // Draw right wing (triangular shape)
        let rightWingPath = UIBezierPath()
        rightWingPath.move(to: wrLeading)        // Leading edge at fuselage
        rightWingPath.addLine(to: wrTrailing)     // Trailing edge tip
        rightWingPath.addLine(to: rootRearRight)  // Back to fuselage at tail
        rightWingPath.close()

        // Fill wings with semi-transparent green
        UIColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 0.5).setFill()
        leftWingPath.fill()
        rightWingPath.fill()

        // Stroke wing outlines
        UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0).setStroke()
        leftWingPath.lineWidth = 2
        rightWingPath.lineWidth = 2
        leftWingPath.stroke()
        rightWingPath.stroke()
    }

    // Calculate fuselage width at a given X position by interpolating the curve
    private func getFuselageWidthAt(x: CGFloat) -> CGFloat {
        // The fuselage shape is defined by quadratic Bezier curves
        // We need to find the Y value (width) at the given X position

        // Find which segment the X position falls into
        if x <= frontControlLeftModel.x {
            // Between nose and front control (first curve segment)
            return interpolateBezierY(x: x,
                                     p0: noseTipModel,
                                     p1: frontControlLeftModel,
                                     p2: midLeftModel)
        } else if x <= rearControlLeftModel.x {
            // Between front control and rear control (second curve segment)
            return interpolateBezierY(x: x,
                                     p0: frontControlLeftModel,
                                     p1: midLeftModel,
                                     p2: rearControlLeftModel)
        } else {
            // Between rear control and tail (third curve segment)
            return interpolateBezierY(x: x,
                                     p0: midLeftModel,
                                     p1: rearControlLeftModel,
                                     p2: tailLeftModel)
        }
    }

    // Interpolate Y value on a quadratic Bezier curve at a given X position
    private func interpolateBezierY(x: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
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
        return abs(y) // Return absolute value since we're calculating width from centerline
    }

    func modelToView(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x, y: (canvasHeight / 2) - point.y)  // y=0 at center, positive up (but for width, positive right)
    }

    func viewToModel(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x, y: (canvasHeight / 2) - point.y)
    }
}

class TopViewDesignViewController: UIViewController, UITextFieldDelegate {
    private let headerView = UIView()
    private let footerView = UIView()
    private let canvasContainerView = UIView()
    private let gridBackground = GridBackgroundView()
    private let shapeView = TopViewShapeView()

    private var frontControlLeftView: DraggableControlPoint!
    private var midLeftView: DraggableControlPoint!
    private var rearControlLeftView: DraggableControlPoint!

    private let noseShapeLabel = UILabel()

    // Wing control sliders
    private let wingPositionSlider = UISlider()
    private let wingPositionLabel = UILabel()
    private let wingSpanSlider = UISlider()
    private let wingSpanLabel = UILabel()

    // Length and area displays
    private let lengthTextField = UITextField()
    private let lengthLabel = UILabel()
    private let wingAreaLabel = UILabel()
    private var aircraftLength: CGFloat = 70.0  // meters

    // Canvas dimensions
    private let canvasWidth: CGFloat = 800
    private let canvasHeight: CGFloat = 400

    // Offset for control points
    private let controlOffset: CGFloat = 30.0

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)

        setupHeader()
        setupFooter()
        setupCanvas()
        setupShapeModel()
        setupControlPoints()
    }

    private func setupHeader() {
        headerView.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        view.addSubview(headerView)

        // Done button
        var doneButtonConfig = UIButton.Configuration.plain()
        doneButtonConfig.title = "← Done"
        doneButtonConfig.baseForegroundColor = .yellow
        doneButtonConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            return outgoing
        }
        doneButtonConfig.background.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        doneButtonConfig.background.cornerRadius = 8
        doneButtonConfig.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        let doneButton = UIButton(configuration: doneButtonConfig, primaryAction: UIAction(handler: { _ in self.doneButtonTapped() }))
        headerView.addSubview(doneButton)

        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "SSTO Top View Designer"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)

        // Side View button
        var sideViewButtonConfig = UIButton.Configuration.plain()
        sideViewButtonConfig.title = "Side View"
        sideViewButtonConfig.baseForegroundColor = .cyan
        sideViewButtonConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            return outgoing
        }
        sideViewButtonConfig.background.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        sideViewButtonConfig.background.cornerRadius = 8
        sideViewButtonConfig.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        let sideViewButton = UIButton(configuration: sideViewButtonConfig, primaryAction: UIAction(handler: { _ in self.sideViewButtonTapped() }))
        headerView.addSubview(sideViewButton)

        // Length input (upper left)
        lengthLabel.text = "Length (m):"
        lengthLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        lengthLabel.textColor = .white
        headerView.addSubview(lengthLabel)

        lengthTextField.text = "70.0"
        lengthTextField.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        lengthTextField.textColor = .yellow
        lengthTextField.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        lengthTextField.textAlignment = .center
        lengthTextField.keyboardType = .decimalPad
        lengthTextField.borderStyle = .roundedRect
        lengthTextField.delegate = self
        lengthTextField.addTarget(self, action: #selector(lengthChanged), for: .editingChanged)
        headerView.addSubview(lengthTextField)

        // Wing area display
        wingAreaLabel.text = "Wing Area: 0.0 m²"
        wingAreaLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        wingAreaLabel.textColor = .cyan
        headerView.addSubview(wingAreaLabel)

        // Layout
        headerView.translatesAutoresizingMaskIntoConstraints = false
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        sideViewButton.translatesAutoresizingMaskIntoConstraints = false
        lengthLabel.translatesAutoresizingMaskIntoConstraints = false
        lengthTextField.translatesAutoresizingMaskIntoConstraints = false
        wingAreaLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),

            doneButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            // Length controls in upper left (after done button)
            lengthLabel.leadingAnchor.constraint(equalTo: doneButton.trailingAnchor, constant: 30),
            lengthLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),

            lengthTextField.leadingAnchor.constraint(equalTo: lengthLabel.trailingAnchor, constant: 5),
            lengthTextField.centerYAnchor.constraint(equalTo: lengthLabel.centerYAnchor),
            lengthTextField.widthAnchor.constraint(equalToConstant: 60),

            wingAreaLabel.leadingAnchor.constraint(equalTo: lengthLabel.leadingAnchor),
            wingAreaLabel.topAnchor.constraint(equalTo: lengthLabel.bottomAnchor, constant: 4),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            sideViewButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            sideViewButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
    }

    private func setupFooter() {
        footerView.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        view.addSubview(footerView)

        // Nose shape label
        noseShapeLabel.text = "Adjust nose with controls"
        noseShapeLabel.font = UIFont.systemFont(ofSize: 12)
        noseShapeLabel.textColor = .white
        footerView.addSubview(noseShapeLabel)

        // Wing position slider
        wingPositionLabel.text = "Wing Start: 67%"
        wingPositionLabel.font = UIFont.systemFont(ofSize: 12)
        wingPositionLabel.textColor = .cyan
        wingPositionLabel.textAlignment = .left
        footerView.addSubview(wingPositionLabel)

        wingPositionSlider.minimumValue = 0.3
        wingPositionSlider.maximumValue = 0.9
        wingPositionSlider.value = 0.67
        wingPositionSlider.minimumTrackTintColor = .cyan
        wingPositionSlider.addTarget(self, action: #selector(wingPositionChanged(_:)), for: .valueChanged)
        footerView.addSubview(wingPositionSlider)

        // Wing span slider
        wingSpanLabel.text = "Wing Span: 150"
        wingSpanLabel.font = UIFont.systemFont(ofSize: 12)
        wingSpanLabel.textColor = .green
        wingSpanLabel.textAlignment = .left
        footerView.addSubview(wingSpanLabel)

        wingSpanSlider.minimumValue = 40
        wingSpanSlider.maximumValue = 150
        wingSpanSlider.value = 150
        wingSpanSlider.minimumTrackTintColor = .green
        wingSpanSlider.addTarget(self, action: #selector(wingSpanChanged(_:)), for: .valueChanged)
        footerView.addSubview(wingSpanSlider)

        // Layout
        footerView.translatesAutoresizingMaskIntoConstraints = false
        noseShapeLabel.translatesAutoresizingMaskIntoConstraints = false
        wingPositionLabel.translatesAutoresizingMaskIntoConstraints = false
        wingPositionSlider.translatesAutoresizingMaskIntoConstraints = false
        wingSpanLabel.translatesAutoresizingMaskIntoConstraints = false
        wingSpanSlider.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 80),

            noseShapeLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 20),
            noseShapeLabel.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 10),

            wingPositionLabel.leadingAnchor.constraint(equalTo: noseShapeLabel.trailingAnchor, constant: 30),
            wingPositionLabel.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 10),
            wingPositionLabel.widthAnchor.constraint(equalToConstant: 120),

            wingPositionSlider.leadingAnchor.constraint(equalTo: wingPositionLabel.leadingAnchor),
            wingPositionSlider.topAnchor.constraint(equalTo: wingPositionLabel.bottomAnchor, constant: 5),
            wingPositionSlider.widthAnchor.constraint(equalToConstant: 200),

            wingSpanLabel.leadingAnchor.constraint(equalTo: wingPositionSlider.trailingAnchor, constant: 30),
            wingSpanLabel.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 10),
            wingSpanLabel.widthAnchor.constraint(equalToConstant: 120),

            wingSpanSlider.leadingAnchor.constraint(equalTo: wingSpanLabel.leadingAnchor),
            wingSpanSlider.topAnchor.constraint(equalTo: wingSpanLabel.bottomAnchor, constant: 5),
            wingSpanSlider.widthAnchor.constraint(equalToConstant: 200)
        ])
    }

    @objc private func wingPositionChanged(_ slider: UISlider) {
        shapeView.wingStartPosition = CGFloat(slider.value)
        wingPositionLabel.text = String(format: "Wing Start: %.0f%%", slider.value * 100)
        updateWingArea()
        shapeView.setNeedsDisplay()
    }

    @objc private func wingSpanChanged(_ slider: UISlider) {
        shapeView.wingSpan = CGFloat(slider.value)
        wingSpanLabel.text = String(format: "Wing Span: %.0f", slider.value)
        updateWingArea()
        shapeView.setNeedsDisplay()
    }

    @objc private func lengthChanged() {
        if let text = lengthTextField.text, let length = Double(text), length > 0 {
            aircraftLength = CGFloat(length)
            updateWingArea()
        }
    }

    private func updateWingArea() {
        // Calculate wing area in square meters
        // Convert canvas units to meters
        let metersPerUnit = aircraftLength / canvasWidth

        // Calculate wing start and end X positions in canvas units
        let fuselageLength = shapeView.tailLeftModel.x - shapeView.noseTipModel.x
        let wingStartX = shapeView.noseTipModel.x + (fuselageLength * shapeView.wingStartPosition)
        let wingTrailingX = shapeView.tailLeftModel.x

        // Wing chord length in canvas units
        let wingChordCanvas = wingTrailingX - wingStartX

        // Wing span in canvas units (this is the extension beyond fuselage at trailing edge)
        let wingSpanCanvas = shapeView.wingSpan

        // Convert to meters
        let wingChordMeters = wingChordCanvas * metersPerUnit
        let wingSpanMeters = wingSpanCanvas * metersPerUnit

        // Each wing is a triangle: Area = 0.5 * base * height
        // Total area for both wings = 2 * (0.5 * chord * span) = chord * span
        let totalWingArea = wingChordMeters * wingSpanMeters

        wingAreaLabel.text = String(format: "Wing Area: %.1f m²", totalWingArea)
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func setupCanvas() {
        // Canvas container
        canvasContainerView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        view.addSubview(canvasContainerView)

        // Grid background
        gridBackground.backgroundColor = .clear
        gridBackground.spacing = 50
        gridBackground.showCenterline = true
        canvasContainerView.addSubview(gridBackground)

        // Shape view
        shapeView.backgroundColor = .clear
        shapeView.canvasWidth = canvasWidth
        shapeView.canvasHeight = canvasHeight
        canvasContainerView.addSubview(shapeView)

        // Layout
        canvasContainerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            canvasContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            canvasContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasContainerView.bottomAnchor.constraint(equalTo: footerView.topAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Center the canvas in the container
        let containerBounds = canvasContainerView.bounds
        let canvasX = (containerBounds.width - canvasWidth) / 2
        let canvasY = (containerBounds.height - canvasHeight) / 2
        let canvasFrame = CGRect(x: canvasX, y: canvasY, width: canvasWidth, height: canvasHeight)

        gridBackground.frame = canvasFrame
        shapeView.frame = canvasFrame

        // Update control point positions
        updateControlPointPositions()
    }

    private func setupShapeModel() {
        // Load existing planform from GameManager if available
        let planform = GameManager.shared.getTopViewPlanform()

        // Model space: x from 0 (nose) to canvasWidth, y=0 centerline, positive right, negative left
        shapeView.noseTipModel = planform.noseTip.toCGPoint()
        shapeView.midLeftModel = planform.midLeft.toCGPoint()
        shapeView.tailLeftModel = planform.tailLeft.toCGPoint()
        shapeView.frontControlLeftModel = planform.frontControlLeft.toCGPoint()
        shapeView.rearControlLeftModel = planform.rearControlLeft.toCGPoint()

        // Load wing parameters
        shapeView.wingStartPosition = CGFloat(planform.wingStartPosition)
        shapeView.wingSpan = CGFloat(planform.wingSpan)
        aircraftLength = CGFloat(planform.aircraftLength)

        // Update slider values and text fields
        wingPositionSlider.value = Float(planform.wingStartPosition)
        wingSpanSlider.value = Float(planform.wingSpan)
        wingPositionLabel.text = String(format: "Wing Start: %.0f%%", planform.wingStartPosition * 100)
        wingSpanLabel.text = String(format: "Wing Span: %.0f", planform.wingSpan)
        lengthTextField.text = String(format: "%.1f", planform.aircraftLength)

        // Calculate and display initial wing area
        updateWingArea()
    }

    private func setupControlPoints() {
        let pointSize = CGSize(width: 14, height: 14)

        // Front control left (for nose shape, offset left)
        frontControlLeftView = createControlPoint(size: pointSize, constrained: false, offset: -controlOffset)
        frontControlLeftView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let adjustedCenter = CGPoint(x: newCenter.x + self.controlOffset, y: newCenter.y)  // Offset left
            let modelPoint = self.canvasToModel(adjustedCenter)
            self.shapeView.frontControlLeftModel = modelPoint
            self.shapeView.setNeedsDisplay()
        }

        // Mid left (vertically constrained, offset left)
        midLeftView = createControlPoint(size: pointSize, constrained: true, offset: -controlOffset)
        midLeftView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let adjustedCenter = CGPoint(x: newCenter.x + self.controlOffset, y: newCenter.y)
            let modelPoint = self.canvasToModel(adjustedCenter)
            self.shapeView.midLeftModel.y = modelPoint.y
            self.midLeftView.center.x = self.modelToCanvas(self.shapeView.midLeftModel).x - self.controlOffset
            self.shapeView.setNeedsDisplay()
        }

        // Rear control left (offset left)
        rearControlLeftView = createControlPoint(size: pointSize, constrained: false, offset: -controlOffset)
        rearControlLeftView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let adjustedCenter = CGPoint(x: newCenter.x + self.controlOffset, y: newCenter.y)
            let modelPoint = self.canvasToModel(adjustedCenter)
            self.shapeView.rearControlLeftModel = modelPoint
            self.shapeView.setNeedsDisplay()
        }
    }

    private func createControlPoint(size: CGSize, constrained: Bool, offset: CGFloat) -> DraggableControlPoint {
        let point = DraggableControlPoint(frame: CGRect(origin: .zero, size: size))
        point.isConstrainedToVertical = constrained
        point.offset = offset
        view.addSubview(point)
        return point
    }

    private func updateControlPointPositions() {
        if let frontControlLeftView = frontControlLeftView {
            var pos = modelToCanvas(shapeView.frontControlLeftModel)
            pos.x += frontControlLeftView.offset
            frontControlLeftView.center = pos
        }
        if let midLeftView = midLeftView {
            var pos = modelToCanvas(shapeView.midLeftModel)
            pos.x += midLeftView.offset
            midLeftView.center = pos
        }
        if let rearControlLeftView = rearControlLeftView {
            var pos = modelToCanvas(shapeView.rearControlLeftModel)
            pos.x += rearControlLeftView.offset
            rearControlLeftView.center = pos
        }
    }

    private func modelToCanvas(_ modelPoint: CGPoint) -> CGPoint {
        let viewPoint = shapeView.modelToView(modelPoint)
        return CGPoint(x: shapeView.frame.origin.x + viewPoint.x,
                       y: shapeView.frame.origin.y + viewPoint.y)
    }

    private func canvasToModel(_ canvasPoint: CGPoint) -> CGPoint {
        let viewPoint = CGPoint(x: canvasPoint.x - shapeView.frame.origin.x,
                                y: canvasPoint.y - shapeView.frame.origin.y)
        return shapeView.viewToModel(viewPoint)
    }

    @objc private func doneButtonTapped() {
        // Save the current design to GameManager
        let planform = TopViewPlanform(
            noseTip: SerializablePoint(from: shapeView.noseTipModel, isFixedX: true),
            frontControlLeft: SerializablePoint(from: shapeView.frontControlLeftModel, isFixedX: false),
            midLeft: SerializablePoint(from: shapeView.midLeftModel, isFixedX: false),
            rearControlLeft: SerializablePoint(from: shapeView.rearControlLeftModel, isFixedX: false),
            tailLeft: SerializablePoint(from: shapeView.tailLeftModel, isFixedX: false),
            wingStartPosition: Double(shapeView.wingStartPosition),
            wingSpan: Double(shapeView.wingSpan),
            aircraftLength: Double(aircraftLength)
        )
        GameManager.shared.setTopViewPlanform(planform)

        // Log the settings for default value reference
        print("========== TOP VIEW SETTINGS ==========")
        print("noseTip: SerializablePoint(x: \(planform.noseTip.x), y: \(planform.noseTip.y), isFixedX: true)")
        print("frontControlLeft: SerializablePoint(x: \(planform.frontControlLeft.x), y: \(planform.frontControlLeft.y), isFixedX: false)")
        print("midLeft: SerializablePoint(x: \(planform.midLeft.x), y: \(planform.midLeft.y), isFixedX: false)")
        print("rearControlLeft: SerializablePoint(x: \(planform.rearControlLeft.x), y: \(planform.rearControlLeft.y), isFixedX: false)")
        print("tailLeft: SerializablePoint(x: \(planform.tailLeft.x), y: \(planform.tailLeft.y), isFixedX: false)")
        print("wingStartPosition: \(planform.wingStartPosition)")
        print("wingSpan: \(planform.wingSpan)")
        print("aircraftLength: \(planform.aircraftLength)")
        print("=======================================")

        dismiss(animated: true, completion: nil)
    }

    @objc private func sideViewButtonTapped() {
        // Save the current design to GameManager before transitioning
        let planform = TopViewPlanform(
            noseTip: SerializablePoint(from: shapeView.noseTipModel, isFixedX: true),
            frontControlLeft: SerializablePoint(from: shapeView.frontControlLeftModel, isFixedX: false),
            midLeft: SerializablePoint(from: shapeView.midLeftModel, isFixedX: false),
            rearControlLeft: SerializablePoint(from: shapeView.rearControlLeftModel, isFixedX: false),
            tailLeft: SerializablePoint(from: shapeView.tailLeftModel, isFixedX: false),
            wingStartPosition: Double(shapeView.wingStartPosition),
            wingSpan: Double(shapeView.wingSpan),
            aircraftLength: Double(aircraftLength)
        )
        GameManager.shared.setTopViewPlanform(planform)

        let sideViewController = SSTODesignViewController()
        sideViewController.modalPresentationStyle = .fullScreen
        present(sideViewController, animated: true, completion: nil)
    }
}
