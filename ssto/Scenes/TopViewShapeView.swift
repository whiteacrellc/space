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
        // Save the current design to GameManager
        let planform = TopViewPlanform(
            noseTip: SerializablePoint(from: shapeView.noseTipModel, isFixedX: true),
            frontControlLeft: SerializablePoint(from: shapeView.frontControlLeftModel, isFixedX: false),
            midLeft: SerializablePoint(from: shapeView.midLeftModel, isFixedX: false),
            rearControlLeft: SerializablePoint(from: shapeView.rearControlLeftModel, isFixedX: false),
            tailLeft: SerializablePoint(from: shapeView.tailLeftModel, isFixedX: false)
        )
        GameManager.shared.setTopViewPlanform(planform)

        dismiss(animated: true, completion: nil)
    }

    @objc private func sideViewButtonTapped() {
        // Save the current design to GameManager before transitioning
        let planform = TopViewPlanform(
            noseTip: SerializablePoint(from: shapeView.noseTipModel, isFixedX: true),
            frontControlLeft: SerializablePoint(from: shapeView.frontControlLeftModel, isFixedX: false),
            midLeft: SerializablePoint(from: shapeView.midLeftModel, isFixedX: false),
            rearControlLeft: SerializablePoint(from: shapeView.rearControlLeftModel, isFixedX: false),
            tailLeft: SerializablePoint(from: shapeView.tailLeftModel, isFixedX: false)
        )
        GameManager.shared.setTopViewPlanform(planform)

        let sideViewController = SSTODesignViewController()
        sideViewController.modalPresentationStyle = .fullScreen
        present(sideViewController, animated: true, completion: nil)
    }
}
