//
//  DraggableControlPoint.swift
//  ssto
//
//  Created by tom whittaker on 11/29/25.
//

import UIKit

class DraggableControlPoint: UIView {
    var onMoved: ((CGPoint) -> Void)?
    var isConstrainedToVertical: Bool = false
    var isConstrainedToHorizontal: Bool = false
    var offset: CGFloat = 0.0  // Offset for placing the control point outside the shape

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
        } else if isConstrainedToHorizontal {
            newCenter.x += translation.x
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
    }

    func modelToView(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x, y: (canvasHeight / 2) - point.y)  // y=0 at center, positive up (but for width, positive right)
    }

    func viewToModel(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: point.x, y: (canvasHeight / 2) - point.y)
    }
}

class TopViewDesignViewController: UIViewController {
    private let headerView = UIView()
    private let footerView = UIView()
    private let canvasContainerView = UIView()
    private let gridBackground = GridBackgroundView()
    private let shapeView = TopViewShapeView()

    private var frontControlLeftView: DraggableControlPoint!
    private var midLeftView: DraggableControlPoint!
    private var rearControlLeftView: DraggableControlPoint!

    private let noseShapeLabel = UILabel()

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
        titleLabel.text = "SSTO Top View Designer"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)

        // Side View button
        let sideViewButton = UIButton(type: .system)
        sideViewButton.setTitle("Side View", for: .normal)
        sideViewButton.setTitleColor(.cyan, for: .normal)
        sideViewButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        sideViewButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        sideViewButton.layer.cornerRadius = 8
        sideViewButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        sideViewButton.addTarget(self, action: #selector(sideViewButtonTapped), for: .touchUpInside)
        headerView.addSubview(sideViewButton)

        // Layout
        headerView.translatesAutoresizingMaskIntoConstraints = false
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        sideViewButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),

            doneButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

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
        noseShapeLabel.font = UIFont.systemFont(ofSize: 14)
        noseShapeLabel.textColor = .white
        footerView.addSubview(noseShapeLabel)

        // Layout
        footerView.translatesAutoresizingMaskIntoConstraints = false
        noseShapeLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 60),

            noseShapeLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 20),
            noseShapeLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
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

        // Update control point positions
        updateControlPointPositions()
    }

    private func setupShapeModel() {
        // Model space: x from 0 (nose) to canvasWidth, y=0 centerline, positive right, negative left
        shapeView.noseTipModel = CGPoint(x: 50, y: 0)  // Slightly offset for visibility
        shapeView.midLeftModel = CGPoint(x: 300, y: -100)
        shapeView.tailLeftModel = CGPoint(x: canvasWidth - 50, y: -50)
        shapeView.frontControlLeftModel = CGPoint(x: 150, y: -30)
        shapeView.rearControlLeftModel = CGPoint(x: 500, y: -80)
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
        dismiss(animated: true, completion: nil)
    }

    @objc private func sideViewButtonTapped() {
        let sideViewController = SSTODesignViewController()
        sideViewController.modalPresentationStyle = .fullScreen
        present(sideViewController, animated: true, completion: nil)
    }
}
