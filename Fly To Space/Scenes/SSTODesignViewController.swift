// SSTODesignViewController.swift
// A UIViewController for a landscape iOS app allowing users to design the x,z shape of an SSTO plane.
// The user can modify the top, front, and back (exhaust) curves via draggable control points,
// and adjust the engine length using a slider.

import UIKit

class DraggableControlPoint: UIView {
    var onMoved: ((CGPoint) -> Void)?
    var isConstrainedToVertical: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.cornerRadius = frame.width / 2
        layer.borderWidth = 1
        layer.borderColor = UIColor.black.cgColor
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: superview)
        var newCenter = center
        if isConstrainedToVertical {
            newCenter.y += translation.y
        } else {
            newCenter.x += translation.x
            newCenter.y += translation.y
        }
        center = newCenter
        gesture.setTranslation(.zero, in: superview)
        onMoved?(center)
    }
}

class GridBackgroundView: UIView {
    var spacing: CGFloat = 50

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Draw grid
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.1).cgColor)
        context.setLineWidth(1)

        // Vertical lines
        var x: CGFloat = 0
        while x <= rect.width {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }

        // Horizontal lines
        var y: CGFloat = 0
        while y <= rect.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }

        context.strokePath()

        // Draw centerline
        context.setStrokeColor(UIColor.red.withAlphaComponent(0.5).cgColor)
        context.setLineDash(phase: 0, lengths: [5, 5])
        let centerY = rect.height / 2
        context.move(to: CGPoint(x: 0, y: centerY))
        context.addLine(to: CGPoint(x: rect.width, y: centerY))
        context.strokePath()
    }
}

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
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("← Done", for: .normal)
        doneButton.setTitleColor(.yellow, for: .normal)
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        doneButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        doneButton.layer.cornerRadius = 8
        doneButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        headerView.addSubview(doneButton)

        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "SSTO Fuselage Designer"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)

        // Layout
        headerView.translatesAutoresizingMaskIntoConstraints = false
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),

            doneButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
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

        // Layout
        footerView.translatesAutoresizingMaskIntoConstraints = false
        engineLengthLabel.translatesAutoresizingMaskIntoConstraints = false
        engineLengthSlider.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 60),

            engineLengthLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 20),
            engineLengthLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),

            engineLengthSlider.leadingAnchor.constraint(equalTo: engineLengthLabel.trailingAnchor, constant: 20),
            engineLengthSlider.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -20),
            engineLengthSlider.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
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
        // Initialize shape model coordinates (model space: origin at bottom-left)
        // Front bottom curve starts at same position as top curve
        let startX: CGFloat = 50
        let startY: CGFloat = canvasHeight / 2  // Centerline

        shapeView.topStartModel = CGPoint(x: startX, y: startY)
        shapeView.frontStartModel = CGPoint(x: startX, y: startY)  // Same as top start

        shapeView.frontControlModel = CGPoint(x: 150, y: startY - 80)
        shapeView.frontEndModel = CGPoint(x: 250, y: startY - 100)

        shapeView.engineLength = 240
        shapeView.engineEndModel = CGPoint(x: 250 + shapeView.engineLength, y: startY - 90)

        shapeView.exhaustControlModel = CGPoint(x: 650, y: startY - 60)
        shapeView.exhaustEndModel = CGPoint(x: canvasWidth - 50, y: startY)

        shapeView.topControlModel = CGPoint(x: 400, y: startY + 100)
        shapeView.topEndModel = CGPoint(x: canvasWidth - 50, y: startY)
    }

    private func setupControlPoints() {
        let pointSize = CGSize(width: 14, height: 14)

        // Front control point
        frontControlView = createControlPoint(size: pointSize, constrained: false)
        frontControlView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)
            self.shapeView.frontControlModel = modelPoint
            self.shapeView.setNeedsDisplay()
        }

        // Front end point (vertically constrained)
        frontEndView = createControlPoint(size: pointSize, constrained: true)
        frontEndView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)
            self.shapeView.frontEndModel.y = modelPoint.y
            self.frontEndView.center.x = self.modelToCanvas(self.shapeView.frontEndModel).x
            self.shapeView.setNeedsDisplay()
        }

        // Engine end point (vertically constrained)
        engineEndView = createControlPoint(size: pointSize, constrained: true)
        engineEndView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)
            self.shapeView.engineEndModel.y = modelPoint.y
            self.engineEndView.center.x = self.modelToCanvas(self.shapeView.engineEndModel).x
            self.shapeView.setNeedsDisplay()
        }

        // Exhaust control point
        exhaustControlView = createControlPoint(size: pointSize, constrained: false)
        exhaustControlView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)
            self.shapeView.exhaustControlModel = modelPoint
            self.shapeView.setNeedsDisplay()
        }

        // Top control point
        topControlView = createControlPoint(size: pointSize, constrained: false)
        topControlView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)
            self.shapeView.topControlModel = modelPoint
            self.shapeView.setNeedsDisplay()
        }

        // Top end point (vertically constrained)
        topEndView = createControlPoint(size: pointSize, constrained: true)
        topEndView.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)
            self.shapeView.topEndModel.y = modelPoint.y
            self.shapeView.exhaustEndModel.y = modelPoint.y  // Keep exhaust end same as top end
            self.topEndView.center.x = self.modelToCanvas(self.shapeView.topEndModel).x
            self.shapeView.setNeedsDisplay()
        }
    }

    private func createControlPoint(size: CGSize, constrained: Bool) -> DraggableControlPoint {
        let point = DraggableControlPoint(frame: CGRect(origin: .zero, size: size))
        point.isConstrainedToVertical = constrained
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
            updateControlPointPositions()
            shapeView.setNeedsDisplay()
        } else {
            slider.value = Float(shapeView.engineEndModel.x - shapeView.frontEndModel.x)
        }
    }

    @objc private func doneButtonTapped() {
        dismiss(animated: true, completion: nil)
    }
}
