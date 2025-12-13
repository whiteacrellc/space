// SSTODesignViewController.swift
// A UIViewController for a landscape iOS app allowing users to design the x,z shape of an SSTO plane.
// The user can modify the top, front, and back (exhaust) curves via draggable control points,
// and adjust the engine length using a slider.

import UIKit

class ShapeView: UIView {
    var frontStartModel = CGPoint.zero  // Fixed position - same as top start
    var frontControlModel = CGPoint.zero
    var frontEndModel = CGPoint.zero
    var engineEndModel = CGPoint.zero
    var exhaustControlModel = CGPoint.zero
    var exhaustEndModel = CGPoint.zero
    var topStartModel = CGPoint.zero    // Fixed position
    var topControlModel = CGPoint.zero
    var topEndModel = CGPoint.zero
    var engineLength: CGFloat = 0

    // Canvas dimensions
    var canvasWidth: CGFloat = 0
    var canvasHeight: CGFloat = 0

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard canvasWidth > 0 && canvasHeight > 0 else { return }

        // Convert model coordinates (origin at bottom-left) to view coordinates (origin at top-left)
        let fs = modelToView(frontStartModel)
        let fc = modelToView(frontControlModel)
        let fe = modelToView(frontEndModel)
        let ee = modelToView(engineEndModel)
        let ec = modelToView(exhaustControlModel)
        let ex = modelToView(exhaustEndModel)
        let ts = modelToView(topStartModel)
        let tc = modelToView(topControlModel)
        let te = modelToView(topEndModel)

        // Draw control point guide lines (dashed lines showing bezier structure)
        let guidePath = UIBezierPath()

        // Front curve guides
        guidePath.move(to: fs)
        guidePath.addLine(to: fc)
        guidePath.move(to: fe)
        guidePath.addLine(to: fc)

        // Exhaust curve guides
        guidePath.move(to: ee)
        guidePath.addLine(to: ec)
        guidePath.move(to: ex)
        guidePath.addLine(to: ec)

        // Top curve guides
        guidePath.move(to: ts)
        guidePath.addLine(to: tc)
        guidePath.move(to: te)
        guidePath.addLine(to: tc)

        UIColor.white.withAlphaComponent(0.3).setStroke()
        guidePath.lineWidth = 1
        guidePath.setLineDash([3, 3], count: 2, phase: 0)
        guidePath.stroke()

        // Draw main shape
        let path = UIBezierPath()
        path.move(to: fs)
        path.addQuadCurve(to: fe, controlPoint: fc)
        path.addLine(to: ee)
        path.addQuadCurve(to: ex, controlPoint: ec)
        path.addLine(to: te)
        path.addQuadCurve(to: ts, controlPoint: tc)
        path.close()

        // Fill with gradient-like color
        UIColor(red: 0.3, green: 0.4, blue: 0.7, alpha: 0.6).setFill()
        path.fill()

        // Stroke outline
        UIColor.white.setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    func modelToView(_ point: CGPoint) -> CGPoint {
        // Model space: origin at bottom-left, Y increases upward
        // View space: origin at top-left, Y increases downward
        return CGPoint(x: point.x, y: canvasHeight - point.y)
    }

    func viewToModel(_ point: CGPoint) -> CGPoint {
        // Convert view coordinates back to model coordinates
        return CGPoint(x: point.x, y: canvasHeight - point.y)
    }
}

class SSTODesignViewController: UIViewController {
    private let headerView = UIView()
    private let footerView = UIView()
    private let canvasContainerView = UIView()
    private let gridBackground = GridBackgroundView()
    private let shapeView = ShapeView()

    private var frontControlView: DraggableControlPoint!
    private var frontEndView: DraggableControlPoint!
    private var engineEndView: DraggableControlPoint!
    private var exhaustControlView: DraggableControlPoint!
    private var topControlView: DraggableControlPoint!
    private var topEndView: DraggableControlPoint!

    private let engineLengthSlider = UISlider()
    private let engineLengthLabel = UILabel()
    private let maxHeightSlider = UISlider()
    private let maxHeightLabel = UILabel()

    // Canvas dimensions
    private let canvasWidth: CGFloat = 800
    private let canvasHeight: CGFloat = 400

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
        var doneConfig = UIButton.Configuration.filled()
        doneConfig.title = "← Done"
        doneConfig.baseForegroundColor = .yellow
        doneConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.1)
        doneConfig.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        doneConfig.cornerStyle = .medium

        let doneButton = UIButton(configuration: doneConfig)
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        headerView.addSubview(doneButton)

        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "SSTO Fuselage Designer"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)

        // 3D View button
        var threeDConfig = UIButton.Configuration.filled()
        threeDConfig.title = "3D View →"
        threeDConfig.baseForegroundColor = .cyan
        threeDConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.1)
        threeDConfig.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        threeDConfig.cornerStyle = .medium
        
        let threeDButton = UIButton(configuration: threeDConfig)
        threeDButton.addTarget(self, action: #selector(show3DView), for: .touchUpInside)
        headerView.addSubview(threeDButton)

        // Layout
        headerView.translatesAutoresizingMaskIntoConstraints = false
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        threeDButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),

            doneButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            threeDButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            threeDButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
    }

    @objc private func show3DView() {
        let wireframeVC = WireframeViewController()
        wireframeVC.shapeView = self.shapeView
        wireframeVC.maxHeight = CGFloat(self.maxHeightSlider.value)
        wireframeVC.modalPresentationStyle = .fullScreen
        self.present(wireframeVC, animated: true, completion: nil)
    }

    private func setupFooter() {
        footerView.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        view.addSubview(footerView)

        // Engine length label
        engineLengthLabel.text = "Engine Length"
        engineLengthLabel.font = UIFont.systemFont(ofSize: 14)
        engineLengthLabel.textColor = .white
        footerView.addSubview(engineLengthLabel)

        // Engine length slider
        engineLengthSlider.minimumValue = 100
        engineLengthSlider.maximumValue = 400
        engineLengthSlider.value = 240
        engineLengthSlider.minimumTrackTintColor = .yellow
        engineLengthSlider.addTarget(self, action: #selector(engineLengthChanged), for: .valueChanged)
        footerView.addSubview(engineLengthSlider)

        // Max height label
        maxHeightLabel.text = "Max Height"
        maxHeightLabel.font = UIFont.systemFont(ofSize: 14)
        maxHeightLabel.textColor = .white
        footerView.addSubview(maxHeightLabel)

        // Max height slider
        maxHeightSlider.minimumValue = 50
        maxHeightSlider.maximumValue = 150
        maxHeightSlider.value = 120
        maxHeightSlider.minimumTrackTintColor = .cyan
        maxHeightSlider.addTarget(self, action: #selector(maxHeightChanged), for: .valueChanged)
        footerView.addSubview(maxHeightSlider)

        // Layout
        footerView.translatesAutoresizingMaskIntoConstraints = false
        engineLengthLabel.translatesAutoresizingMaskIntoConstraints = false
        engineLengthSlider.translatesAutoresizingMaskIntoConstraints = false
        maxHeightLabel.translatesAutoresizingMaskIntoConstraints = false
        maxHeightSlider.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 60),

            // Engine length controls on left half
            engineLengthLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 20),
            engineLengthLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),

            engineLengthSlider.leadingAnchor.constraint(equalTo: engineLengthLabel.trailingAnchor, constant: 10),
            engineLengthSlider.trailingAnchor.constraint(equalTo: footerView.centerXAnchor, constant: -20),
            engineLengthSlider.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),

            // Max height controls on right half
            maxHeightLabel.leadingAnchor.constraint(equalTo: footerView.centerXAnchor, constant: 20),
            maxHeightLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),

            maxHeightSlider.leadingAnchor.constraint(equalTo: maxHeightLabel.trailingAnchor, constant: 10),
            maxHeightSlider.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -20),
            maxHeightSlider.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
        ])
    }

    private func setupCanvas() {
        // Canvas container
        canvasContainerView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        view.addSubview(canvasContainerView)

        // Grid background
        gridBackground.backgroundColor = .clear
        gridBackground.spacing = 50
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

        // Update control point positions if needed
        updateControlPointPositions()
    }

    private func setupShapeModel() {
        // Load existing profile from GameManager if available
        let profile = GameManager.shared.getSideProfile()
        let startY: CGFloat = canvasHeight / 2  // Centerline

        // Convert SerializablePoint to CGPoint - the profile stores Y relative to bottom (200 = centerline)
        // We need to convert to view space where startY is the centerline
        // In UIKit: Y increases downward, so startY - offset = above centerline, startY + offset = below centerline
        let centerlineInModel: CGFloat = 200.0  // From the default profile

        shapeView.frontStartModel = CGPoint(x: CGFloat(profile.frontStart.x),
                                           y: startY + (CGFloat(profile.frontStart.y) - centerlineInModel))
        shapeView.frontControlModel = CGPoint(x: CGFloat(profile.frontControl.x),
                                             y: startY + (CGFloat(profile.frontControl.y) - centerlineInModel))
        shapeView.frontEndModel = CGPoint(x: CGFloat(profile.frontEnd.x),
                                         y: startY + (CGFloat(profile.frontEnd.y) - centerlineInModel))
        shapeView.engineEndModel = CGPoint(x: CGFloat(profile.engineEnd.x),
                                          y: startY + (CGFloat(profile.engineEnd.y) - centerlineInModel))
        shapeView.exhaustControlModel = CGPoint(x: CGFloat(profile.exhaustControl.x),
                                               y: startY + (CGFloat(profile.exhaustControl.y) - centerlineInModel))
        shapeView.exhaustEndModel = CGPoint(x: CGFloat(profile.exhaustEnd.x),
                                           y: startY + (CGFloat(profile.exhaustEnd.y) - centerlineInModel))
        shapeView.topStartModel = CGPoint(x: CGFloat(profile.topStart.x),
                                         y: startY + (CGFloat(profile.topStart.y) - centerlineInModel))
        shapeView.topControlModel = CGPoint(x: CGFloat(profile.topControl.x),
                                           y: startY + (CGFloat(profile.topControl.y) - centerlineInModel))
        shapeView.topEndModel = CGPoint(x: CGFloat(profile.topEnd.x),
                                       y: startY + (CGFloat(profile.topEnd.y) - centerlineInModel))

        shapeView.engineLength = CGFloat(profile.engineLength)

        // Update slider values
        engineLengthSlider.value = Float(profile.engineLength)
        maxHeightSlider.value = Float(profile.maxHeight)
        engineLengthLabel.text = String(format: "Engine Length: %.0f", profile.engineLength)
        maxHeightLabel.text = String(format: "Max Height: %.0f", profile.maxHeight)
    }

    private func setupControlPoints() {
        let pointSize = CGSize(width: 14, height: 14)

        // Front control point (free movement)
        frontControlView = createControlPoint(size: pointSize, verticalOnly: false, horizontalOnly: false)
        frontControlView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)
            self.shapeView.frontControlModel = modelPoint
            self.shapeView.setNeedsDisplay()
        }

        // Front end point (horizontal movement only - moves engine start position)
        frontEndView = createControlPoint(size: pointSize, verticalOnly: false, horizontalOnly: true)
        frontEndView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)
            self.shapeView.frontEndModel.x = modelPoint.x

            // Update engine end position to maintain length
            self.shapeView.engineEndModel.x = self.shapeView.frontEndModel.x + self.shapeView.engineLength

            // Keep engine parallel (same Y as front end)
            self.shapeView.engineEndModel.y = self.shapeView.frontEndModel.y

            self.frontEndView.center.y = self.modelToCanvas(self.shapeView.frontEndModel).y
            self.updateControlPointPositions()
            self.shapeView.setNeedsDisplay()
        }

        // Engine end point (vertical movement only - adjusts engine height, stays parallel)
        engineEndView = createControlPoint(size: pointSize, verticalOnly: true, horizontalOnly: false)
        engineEndView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)

            // Store the current max height before changing engine line
            let oldEngineLineY = self.shapeView.frontEndModel.y
            let maxHeight = self.shapeView.topControlModel.y - oldEngineLineY

            // Update both front end and engine end to same Y (keep parallel)
            self.shapeView.frontEndModel.y = modelPoint.y
            self.shapeView.engineEndModel.y = modelPoint.y

            // Maintain the same max height relative to the new engine line position
            self.shapeView.topControlModel.y = self.shapeView.frontEndModel.y + maxHeight

            // Keep X position of engine end
            self.engineEndView.center.x = self.modelToCanvas(self.shapeView.engineEndModel).x
            self.frontEndView.center.y = self.modelToCanvas(self.shapeView.frontEndModel).y

            self.updateControlPointPositions()
            self.shapeView.setNeedsDisplay()
        }

        // Exhaust control point (free movement)
        exhaustControlView = createControlPoint(size: pointSize, verticalOnly: false, horizontalOnly: false)
        exhaustControlView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)
            self.shapeView.exhaustControlModel = modelPoint
            self.shapeView.setNeedsDisplay()
        }

        // Top control point (free movement)
        topControlView = createControlPoint(size: pointSize, verticalOnly: false, horizontalOnly: false)
        topControlView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)
            self.shapeView.topControlModel = modelPoint

            // Update the max height slider to match the new position
            let engineLineY = self.shapeView.frontEndModel.y
            let currentHeight = self.shapeView.topControlModel.y - engineLineY
            self.maxHeightSlider.value = Float(currentHeight)

            self.shapeView.setNeedsDisplay()
        }

        // Top end point (vertically constrained)
        topEndView = createControlPoint(size: pointSize, verticalOnly: true, horizontalOnly: false)
        topEndView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)
            self.shapeView.topEndModel.y = modelPoint.y
            self.shapeView.exhaustEndModel.y = modelPoint.y  // Keep exhaust end same as top end
            self.topEndView.center.x = self.modelToCanvas(self.shapeView.topEndModel).x
            self.shapeView.setNeedsDisplay()
        }
    }

    private func createControlPoint(size: CGSize, verticalOnly: Bool, horizontalOnly: Bool) -> DraggableControlPoint {
        let point = DraggableControlPoint(frame: CGRect(origin: .zero, size: size))
        point.isConstrainedToVertical = verticalOnly
        point.isConstrainedToHorizontal = horizontalOnly
        view.addSubview(point)
        return point
    }

    private func updateControlPointPositions() {
        frontControlView?.center = modelToCanvas(shapeView.frontControlModel)
        frontEndView?.center = modelToCanvas(shapeView.frontEndModel)
        engineEndView?.center = modelToCanvas(shapeView.engineEndModel)
        exhaustControlView?.center = modelToCanvas(shapeView.exhaustControlModel)
        topControlView?.center = modelToCanvas(shapeView.topControlModel)
        topEndView?.center = modelToCanvas(shapeView.topEndModel)
    }

    private func modelToCanvas(_ modelPoint: CGPoint) -> CGPoint {
        // Convert model coordinates to view coordinates in the canvas
        let viewPoint = shapeView.modelToView(modelPoint)
        return CGPoint(x: shapeView.frame.origin.x + viewPoint.x,
                      y: shapeView.frame.origin.y + viewPoint.y)
    }

    private func canvasToModel(_ canvasPoint: CGPoint) -> CGPoint {
        // Convert canvas view coordinates to model coordinates
        let viewPoint = CGPoint(x: canvasPoint.x - shapeView.frame.origin.x,
                               y: canvasPoint.y - shapeView.frame.origin.y)
        return shapeView.viewToModel(viewPoint)
    }

    @objc private func engineLengthChanged(_ slider: UISlider) {
        shapeView.engineLength = CGFloat(slider.value)
        let newEngineEndX = shapeView.frontEndModel.x + shapeView.engineLength

        // Ensure engine doesn't extend too far
        let maxX = canvasWidth - 200  // Leave space for exhaust
        if newEngineEndX < maxX {
            shapeView.engineEndModel.x = newEngineEndX
            // Keep engine parallel (same Y as front end)
            shapeView.engineEndModel.y = shapeView.frontEndModel.y
            updateControlPointPositions()
            shapeView.setNeedsDisplay()
        } else {
            slider.value = Float(shapeView.engineEndModel.x - shapeView.frontEndModel.x)
        }
    }

    @objc private func maxHeightChanged(_ slider: UISlider) {
        let maxHeight = CGFloat(slider.value)

        // Calculate the engine line Y position (same as frontEndModel.y or engineEndModel.y)
        let engineLineY = shapeView.frontEndModel.y

        // Update top control point Y to be maxHeight above the engine line
        shapeView.topControlModel.y = engineLineY + maxHeight

        updateControlPointPositions()
        shapeView.setNeedsDisplay()
    }

    @objc private func doneButtonTapped() {
        // Save the current design to GameManager
        let profile = SideProfileShape(
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
            maxHeight: Double(maxHeightSlider.value)
        )
        GameManager.shared.setSideProfile(profile)

        dismiss(animated: true, completion: nil)
    }
}
