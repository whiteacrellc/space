//
//  SSTODesignViewController.swift
//  ssto
//
//  A UIViewController for designing the side profile (X-Z cross-section) of an SSTO aircraft.
//  The design consists of three main curve sections:
//    1. Inlet curve: Funnels air into the engine (quadratic Bezier with 3 control points)
//    2. Engine section: Parallel bottom line with adjustable length and position
//    3. Nozzle curve: Exhaust section shaped like half a rocket nozzle (quadratic Bezier)
//    4. Top curve: Defines the upper fuselage profile and aircraft height
//

import UIKit

// MARK: - Shape Canvas View

/// Custom view that renders the aircraft side profile using Bezier curves
class SideProfileShapeView: UIView {

    // MARK: - Model Coordinates (origin at bottom-left, Y increases upward)

    // Inlet curve (bottom front) - funnels air into engine
    var inletStart = CGPoint.zero      // Fixed at centerline (nose)
    var inletControl = CGPoint.zero    // Control point for inlet curve shape
    var inletEnd = CGPoint.zero        // Engine start position

    // Engine section (parallel bottom line)
    var engineStart = CGPoint.zero     // Same as inletEnd
    var engineEnd = CGPoint.zero       // Calculated from engineStart + engineLength

    // Nozzle curve (bottom rear) - exhaust section
    var nozzleControl = CGPoint.zero   // Control point for nozzle curve shape
    var nozzleEnd = CGPoint.zero       // Fixed at centerline (tail)

    // Top curve - defines upper fuselage profile
    var topStart = CGPoint.zero        // Fixed at nose (same as inletStart)
    var topControl = CGPoint.zero      // Control point for top curve (defines max height)
    var topEnd = CGPoint.zero          // Fixed at tail (same as nozzleEnd)

    // Parameters
    var engineLength: CGFloat = 125.0
    var maxHeight: CGFloat = 120.0
    var aircraftLengthMeters: CGFloat = 70.0  // Actual aircraft length in meters

    // Canvas dimensions (model space)
    let canvasWidth: CGFloat = 800.0
    let canvasHeight: CGFloat = 400.0

    // View scale factor (for fitting large aircraft)
    var viewScale: CGFloat = 1.0

    // Visual styling
    private let shapeColor = UIColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 0.7)
    private let outlineColor = UIColor.white
    private let guideLineColor = UIColor.white.withAlphaComponent(0.25)
    private let engineLineColor = UIColor.yellow.withAlphaComponent(0.6)

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Convert model coordinates to view coordinates
        let inletStartView = modelToView(inletStart)
        let inletControlView = modelToView(inletControl)
        let inletEndView = modelToView(inletEnd)
        let engineEndView = modelToView(engineEnd)
        let nozzleControlView = modelToView(nozzleControl)
        let nozzleEndView = modelToView(nozzleEnd)
        let topStartView = modelToView(topStart)
        let topControlView = modelToView(topControl)
        let topEndView = modelToView(topEnd)

        // Draw Bezier control guide lines (dashed)
        drawGuideLines(context: context, inletStart: inletStartView, inletControl: inletControlView, inletEnd: inletEndView,
                      engineEnd: engineEndView, nozzleControl: nozzleControlView, nozzleEnd: nozzleEndView,
                      topStart: topStartView, topControl: topControlView, topEnd: topEndView)

        // Draw engine section indicator
        drawEngineSection(context: context, engineStart: inletEndView, engineEnd: engineEndView)

        // Draw payload and pilot boxes
        drawPayloadAndPilotBoxes(context: context)

        // Draw main aircraft shape
        drawMainShape(inletStart: inletStartView, inletControl: inletControlView, inletEnd: inletEndView,
                     engineEnd: engineEndView, nozzleControl: nozzleControlView, nozzleEnd: nozzleEndView,
                     topStart: topStartView, topControl: topControlView, topEnd: topEndView)
    }

    private func drawGuideLines(context: CGContext, inletStart: CGPoint, inletControl: CGPoint,
                               inletEnd: CGPoint, engineEnd: CGPoint, nozzleControl: CGPoint,
                               nozzleEnd: CGPoint, topStart: CGPoint, topControl: CGPoint,
                               topEnd: CGPoint) {
        let guidePath = UIBezierPath()

        // Inlet curve guides
        guidePath.move(to: inletStart)
        guidePath.addLine(to: inletControl)
        guidePath.move(to: inletEnd)
        guidePath.addLine(to: inletControl)

        // Nozzle curve guides
        guidePath.move(to: engineEnd)
        guidePath.addLine(to: nozzleControl)
        guidePath.move(to: nozzleEnd)
        guidePath.addLine(to: nozzleControl)

        // Top curve guides
        guidePath.move(to: topStart)
        guidePath.addLine(to: topControl)
        guidePath.move(to: topEnd)
        guidePath.addLine(to: topControl)

        guideLineColor.setStroke()
        guidePath.lineWidth = 1.0
        guidePath.setLineDash([4, 4], count: 2, phase: 0)
        guidePath.stroke()
    }

    private func drawEngineSection(context: CGContext, engineStart: CGPoint, engineEnd: CGPoint) {
        // Draw engine section with highlighted color
        let enginePath = UIBezierPath()
        enginePath.move(to: engineStart)
        enginePath.addLine(to: engineEnd)

        engineLineColor.setStroke()
        enginePath.lineWidth = 4.0
        enginePath.stroke()

        // Draw vertical markers at engine boundaries
        let markerHeight: CGFloat = 10.0
        context.saveGState()
        context.setStrokeColor(engineLineColor.cgColor)
        context.setLineWidth(2.0)

        // Start marker
        context.move(to: CGPoint(x: engineStart.x, y: engineStart.y - markerHeight))
        context.addLine(to: CGPoint(x: engineStart.x, y: engineStart.y + markerHeight))

        // End marker
        context.move(to: CGPoint(x: engineEnd.x, y: engineEnd.y - markerHeight))
        context.addLine(to: CGPoint(x: engineEnd.x, y: engineEnd.y + markerHeight))

        context.strokePath()
        context.restoreGState()
    }

    private func drawMainShape(inletStart: CGPoint, inletControl: CGPoint, inletEnd: CGPoint,
                              engineEnd: CGPoint, nozzleControl: CGPoint, nozzleEnd: CGPoint,
                              topStart: CGPoint, topControl: CGPoint, topEnd: CGPoint) {
        let shapePath = UIBezierPath()

        // Start at inlet start (nose bottom)
        shapePath.move(to: inletStart)

        // Inlet curve (funnel air into engine)
        shapePath.addQuadCurve(to: inletEnd, controlPoint: inletControl)

        // Engine section (straight line)
        shapePath.addLine(to: engineEnd)

        // Nozzle curve (exhaust)
        shapePath.addQuadCurve(to: nozzleEnd, controlPoint: nozzleControl)

        // Tail to top
        shapePath.addLine(to: topEnd)

        // Top curve back to nose
        shapePath.addQuadCurve(to: topStart, controlPoint: topControl)

        // Close the shape
        shapePath.close()

        // Fill with shape color
        shapeColor.setFill()
        shapePath.fill()

        // Stroke outline
        outlineColor.setStroke()
        shapePath.lineWidth = 2.5
        shapePath.stroke()
    }

    private func drawPayloadAndPilotBoxes(context: CGContext) {
        // Dimensions in meters (3m × 3m × length)
        let pilotLength: CGFloat = 5.0   // 5m long
        let pilotHeight: CGFloat = 3.0   // 3m high
        let payloadLength: CGFloat = 20.0 // 20m long
        let payloadHeight: CGFloat = 3.0  // 3m high

        // Get correct scale based on actual aircraft length
        let metersPerUnit = calculateMetersPerUnit()
        let unitsPerMeter = 1.0 / metersPerUnit

        // Convert to canvas units
        let pilotLengthCanvas = pilotLength * unitsPerMeter
        let pilotHeightCanvas = pilotHeight * unitsPerMeter
        let payloadLengthCanvas = payloadLength * unitsPerMeter
        let payloadHeightCanvas = payloadHeight * unitsPerMeter

        // Calculate the middle of the aircraft (between nose and tail)
        let aircraftMiddleX = (inletStart.x + nozzleEnd.x) / 2.0

        // Center the payload box at the middle of the aircraft
        let payloadStartX = aircraftMiddleX - (payloadLengthCanvas / 2.0)

        // Position payload box lower - center it vertically on the centerline
        let payloadCenterY = inletStart.y - (payloadHeightCanvas / 2.0)
        let payloadBoxModel = CGRect(
            x: payloadStartX,
            y: payloadCenterY,
            width: payloadLengthCanvas,
            height: payloadHeightCanvas
        )

        // Pilot box in front of payload, right edge aligned with left edge of payload
        let pilotStartX = payloadStartX - pilotLengthCanvas

        // Position pilot box at same vertical level as payload
        let pilotCenterY = inletStart.y - (pilotHeightCanvas / 2.0)
        let pilotBoxModel = CGRect(
            x: pilotStartX,
            y: pilotCenterY,
            width: pilotLengthCanvas,
            height: pilotHeightCanvas
        )

        // Convert to view coordinates
        let pilotTopLeft = modelToView(CGPoint(x: pilotBoxModel.minX, y: pilotBoxModel.maxY))
        let pilotBottomRight = modelToView(CGPoint(x: pilotBoxModel.maxX, y: pilotBoxModel.minY))
        let pilotBoxView = CGRect(
            x: pilotTopLeft.x,
            y: pilotTopLeft.y,
            width: pilotBottomRight.x - pilotTopLeft.x,
            height: pilotBottomRight.y - pilotTopLeft.y
        )

        let payloadTopLeft = modelToView(CGPoint(x: payloadBoxModel.minX, y: payloadBoxModel.maxY))
        let payloadBottomRight = modelToView(CGPoint(x: payloadBoxModel.maxX, y: payloadBoxModel.minY))
        let payloadBoxView = CGRect(
            x: payloadTopLeft.x,
            y: payloadTopLeft.y,
            width: payloadBottomRight.x - payloadTopLeft.x,
            height: payloadBottomRight.y - payloadTopLeft.y
        )

        // Draw pilot box
        context.setStrokeColor(UIColor.green.withAlphaComponent(0.8).cgColor)
        context.setFillColor(UIColor.green.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(2.0)
        context.addRect(pilotBoxView)
        context.drawPath(using: .fillStroke)

        // Draw payload box
        context.setStrokeColor(UIColor.orange.withAlphaComponent(0.8).cgColor)
        context.setFillColor(UIColor.orange.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(2.0)
        context.addRect(payloadBoxView)
        context.drawPath(using: .fillStroke)

        // Add labels
        let pilotLabel = "Pilot\n5m × 3m"
        let payloadLabel = "Cargo\n20m × 3m"

        let labelFont = UIFont.systemFont(ofSize: 10, weight: .medium)
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.white
        ]

        // Pilot label
        let pilotLabelPoint = CGPoint(
            x: pilotBoxView.midX - 20,
            y: pilotBoxView.midY - 10
        )
        (pilotLabel as NSString).draw(at: pilotLabelPoint, withAttributes: labelAttributes)

        // Payload label
        let payloadLabelPoint = CGPoint(
            x: payloadBoxView.midX - 20,
            y: payloadBoxView.midY - 10
        )
        (payloadLabel as NSString).draw(at: payloadLabelPoint, withAttributes: labelAttributes)

        // Draw minimum length indicator in lower right
        let minLength: CGFloat = 30.0  // 30m minimum (ensures pilot + cargo boxes fit: 5m + 20m = 25m)
        let minLengthText = String(format: "Min Length: %.0fm", minLength)

        let minLengthFont = UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        let minLengthAttributes: [NSAttributedString.Key: Any] = [
            .font: minLengthFont,
            .foregroundColor: UIColor.yellow
        ]

        // Position in lower right corner (view coordinates)
        let textSize = (minLengthText as NSString).size(withAttributes: minLengthAttributes)
        let minLengthPoint = CGPoint(
            x: bounds.width - textSize.width - 10,
            y: bounds.height - textSize.height - 5
        )
        (minLengthText as NSString).draw(at: minLengthPoint, withAttributes: minLengthAttributes)
    }

    // MARK: - Coordinate Conversion

    /// Calculate the correct meters-per-canvas-unit ratio based on actual aircraft length
    private func calculateMetersPerUnit() -> CGFloat {
        let aircraftLengthCanvas = nozzleEnd.x - inletStart.x
        guard aircraftLengthCanvas > 0 else { return 70.0 / canvasWidth }
        return aircraftLengthMeters / aircraftLengthCanvas
    }

    /// Convert from model coordinates (origin bottom-left, Y up) to view coordinates (origin top-left, Y down)
    func modelToView(_ point: CGPoint) -> CGPoint {
        let scaledX = point.x * viewScale
        let scaledY = point.y * viewScale
        let scaledHeight = canvasHeight * viewScale
        return CGPoint(x: scaledX, y: scaledHeight - scaledY)
    }

    /// Convert from view coordinates to model coordinates
    func viewToModel(_ point: CGPoint) -> CGPoint {
        let scaledHeight = canvasHeight * viewScale
        let modelX = point.x / viewScale
        let modelY = (scaledHeight - point.y) / viewScale
        return CGPoint(x: modelX, y: modelY)
    }
}

// MARK: - Main View Controller

class SSTODesignViewController: UIViewController {

    // MARK: - UI Components

    private let headerView = UIView()
    private let footerView = UIView()
    private let canvasContainerView = UIView()
    private let gridBackground = GridBackgroundView()
    private let shapeView = SideProfileShapeView()

    // Control points
    private var noseControlPoint: DraggableControlPoint!
    private var inletControlPoint: DraggableControlPoint!
    private var inletEndPoint: DraggableControlPoint!
    private var engineEndPoint: DraggableControlPoint!
    private var nozzleControlPoint: DraggableControlPoint!
    private var nozzleEndPoint: DraggableControlPoint!
    private var topControlPoint: DraggableControlPoint!

    // Sliders and labels
    private let engineLengthSlider = UISlider()
    private let engineLengthValueLabel = UILabel()
    private let maxHeightSlider = UISlider()
    private let maxHeightValueLabel = UILabel()
    private let aircraftLengthSlider = UISlider()
    private let aircraftLengthValueLabel = UILabel()

    // Real-time feedback labels
    private let enginePositionLabel = UILabel()

    // Constants
    private let canvasWidth: CGFloat = 800.0
    private let canvasHeight: CGFloat = 400.0
    private let centerlineY: CGFloat = 200.0  // Y-coordinate of centerline in model space

    // Cache actual aircraft length from TopViewPlanform
    private var actualAircraftLengthMeters: CGFloat = 70.0

    // MARK: - Lifecycle

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0)

        setupHeader()
        setupFooter()
        setupCanvas()
        loadDesignFromGameManager()
        setupControlPoints()
        updateAllViews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutCanvas()
        updateControlPointPositions()
    }

    // MARK: - Setup Methods

    private func setupHeader() {
        headerView.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1.0)
        view.addSubview(headerView)

        // Done button
        let doneButton = createHeaderButton(title: "← Back", color: .yellow)
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)
        headerView.addSubview(doneButton)

        // Reset button
        let resetButton = createHeaderButton(title: "Reset", color: .red)
        resetButton.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
        headerView.addSubview(resetButton)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Side Profile Designer"
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Design inlet, engine, and nozzle curves"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = UIColor.cyan.withAlphaComponent(0.8)
        subtitleLabel.textAlignment = .center
        headerView.addSubview(subtitleLabel)

        // Save button
        let saveButton = createHeaderButton(title: "Save", color: .green)
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        headerView.addSubview(saveButton)

        // Load button
        let loadButton = createHeaderButton(title: "Load", color: .orange)
        loadButton.addTarget(self, action: #selector(loadButtonTapped), for: .touchUpInside)
        headerView.addSubview(loadButton)

        // 3D View button
        let threeDButton = createHeaderButton(title: "3D View →", color: .cyan)
        threeDButton.addTarget(self, action: #selector(show3DView), for: .touchUpInside)
        headerView.addSubview(threeDButton)

        // Layout
        headerView.translatesAutoresizingMaskIntoConstraints = false
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        loadButton.translatesAutoresizingMaskIntoConstraints = false
        threeDButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 70),

            doneButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            resetButton.leadingAnchor.constraint(equalTo: doneButton.trailingAnchor, constant: 10),
            resetButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 15),

            subtitleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            saveButton.trailingAnchor.constraint(equalTo: threeDButton.leadingAnchor, constant: -10),
            saveButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            loadButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -10),
            loadButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            threeDButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            threeDButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
    }

    private func createHeaderButton(title: String, color: UIColor) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseForegroundColor = color
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.12)
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        config.cornerStyle = .medium

        let button = UIButton(configuration: config)
        return button
    }

    private func setupFooter() {
        footerView.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.18, alpha: 1.0)
        view.addSubview(footerView)

        // Engine length controls (left side)
        let engineLengthLabel = createFooterLabel(text: "Engine Length:")
        engineLengthValueLabel.text = "125"
        engineLengthValueLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        engineLengthValueLabel.textColor = .yellow
        engineLengthValueLabel.textAlignment = .right

        engineLengthSlider.minimumValue = 50
        engineLengthSlider.maximumValue = 200
        engineLengthSlider.value = 119
        engineLengthSlider.minimumTrackTintColor = .yellow
        engineLengthSlider.maximumTrackTintColor = UIColor.gray.withAlphaComponent(0.3)
        engineLengthSlider.addTarget(self, action: #selector(engineLengthChanged), for: .valueChanged)

        // Max height controls (center-left)
        let maxHeightLabel = createFooterLabel(text: "Max Height:")
        maxHeightValueLabel.text = "120"
        maxHeightValueLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        maxHeightValueLabel.textColor = .cyan
        maxHeightValueLabel.textAlignment = .right

        maxHeightSlider.minimumValue = 50
        maxHeightSlider.maximumValue = 180
        maxHeightSlider.value = 158
        maxHeightSlider.minimumTrackTintColor = .cyan
        maxHeightSlider.maximumTrackTintColor = UIColor.gray.withAlphaComponent(0.3)
        maxHeightSlider.addTarget(self, action: #selector(maxHeightChanged), for: .valueChanged)

        // Aircraft length controls (center-right)
        let aircraftLengthLabel = createFooterLabel(text: "Aircraft Length:")
        aircraftLengthValueLabel.text = "70"
        aircraftLengthValueLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        aircraftLengthValueLabel.textColor = .orange
        aircraftLengthValueLabel.textAlignment = .right

        aircraftLengthSlider.minimumValue = 30
        aircraftLengthSlider.maximumValue = 1000
        aircraftLengthSlider.value = 70
        aircraftLengthSlider.minimumTrackTintColor = .orange
        aircraftLengthSlider.maximumTrackTintColor = UIColor.gray.withAlphaComponent(0.3)
        aircraftLengthSlider.addTarget(self, action: #selector(aircraftLengthChanged), for: .valueChanged)

        // Engine position feedback (right side)
        enginePositionLabel.text = "Engine: 250 → 490"
        enginePositionLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        enginePositionLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        enginePositionLabel.textAlignment = .right

        // Add to footer
        footerView.addSubview(engineLengthLabel)
        footerView.addSubview(engineLengthValueLabel)
        footerView.addSubview(engineLengthSlider)
        footerView.addSubview(maxHeightLabel)
        footerView.addSubview(maxHeightValueLabel)
        footerView.addSubview(maxHeightSlider)
        footerView.addSubview(aircraftLengthLabel)
        footerView.addSubview(aircraftLengthValueLabel)
        footerView.addSubview(aircraftLengthSlider)
        footerView.addSubview(enginePositionLabel)

        // Layout
        footerView.translatesAutoresizingMaskIntoConstraints = false
        engineLengthLabel.translatesAutoresizingMaskIntoConstraints = false
        engineLengthValueLabel.translatesAutoresizingMaskIntoConstraints = false
        engineLengthSlider.translatesAutoresizingMaskIntoConstraints = false
        maxHeightLabel.translatesAutoresizingMaskIntoConstraints = false
        maxHeightValueLabel.translatesAutoresizingMaskIntoConstraints = false
        maxHeightSlider.translatesAutoresizingMaskIntoConstraints = false
        aircraftLengthLabel.translatesAutoresizingMaskIntoConstraints = false
        aircraftLengthValueLabel.translatesAutoresizingMaskIntoConstraints = false
        aircraftLengthSlider.translatesAutoresizingMaskIntoConstraints = false
        enginePositionLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerView.heightAnchor.constraint(equalToConstant: 70),

            // Engine length (left)
            engineLengthLabel.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 20),
            engineLengthLabel.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 12),

            engineLengthValueLabel.leadingAnchor.constraint(equalTo: engineLengthLabel.trailingAnchor, constant: 8),
            engineLengthValueLabel.centerYAnchor.constraint(equalTo: engineLengthLabel.centerYAnchor),
            engineLengthValueLabel.widthAnchor.constraint(equalToConstant: 40),

            engineLengthSlider.leadingAnchor.constraint(equalTo: footerView.leadingAnchor, constant: 20),
            engineLengthSlider.topAnchor.constraint(equalTo: engineLengthLabel.bottomAnchor, constant: 8),
            engineLengthSlider.widthAnchor.constraint(equalToConstant: 180),

            // Max height (center-left)
            maxHeightLabel.leadingAnchor.constraint(equalTo: engineLengthSlider.trailingAnchor, constant: 30),
            maxHeightLabel.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 12),

            maxHeightValueLabel.leadingAnchor.constraint(equalTo: maxHeightLabel.trailingAnchor, constant: 8),
            maxHeightValueLabel.centerYAnchor.constraint(equalTo: maxHeightLabel.centerYAnchor),
            maxHeightValueLabel.widthAnchor.constraint(equalToConstant: 40),

            maxHeightSlider.leadingAnchor.constraint(equalTo: engineLengthSlider.trailingAnchor, constant: 30),
            maxHeightSlider.topAnchor.constraint(equalTo: maxHeightLabel.bottomAnchor, constant: 8),
            maxHeightSlider.widthAnchor.constraint(equalToConstant: 180),

            // Aircraft length (center-right)
            aircraftLengthLabel.leadingAnchor.constraint(equalTo: maxHeightSlider.trailingAnchor, constant: 30),
            aircraftLengthLabel.topAnchor.constraint(equalTo: footerView.topAnchor, constant: 12),

            aircraftLengthValueLabel.leadingAnchor.constraint(equalTo: aircraftLengthLabel.trailingAnchor, constant: 8),
            aircraftLengthValueLabel.centerYAnchor.constraint(equalTo: aircraftLengthLabel.centerYAnchor),
            aircraftLengthValueLabel.widthAnchor.constraint(equalToConstant: 40),

            aircraftLengthSlider.leadingAnchor.constraint(equalTo: maxHeightSlider.trailingAnchor, constant: 30),
            aircraftLengthSlider.topAnchor.constraint(equalTo: aircraftLengthLabel.bottomAnchor, constant: 8),
            aircraftLengthSlider.widthAnchor.constraint(equalToConstant: 180),

            // Engine position (right side)
            enginePositionLabel.trailingAnchor.constraint(equalTo: footerView.trailingAnchor, constant: -20),
            enginePositionLabel.centerYAnchor.constraint(equalTo: footerView.centerYAnchor)
        ])
    }

    private func createFooterLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        return label
    }

    private func setupCanvas() {
        canvasContainerView.backgroundColor = .clear
        view.addSubview(canvasContainerView)

        // Grid background
        gridBackground.backgroundColor = .clear
        gridBackground.spacing = 50
        gridBackground.showCenterline = true
        canvasContainerView.addSubview(gridBackground)

        // Shape view
        shapeView.backgroundColor = .clear
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

    private func layoutCanvas() {
        let containerBounds = canvasContainerView.bounds
        let canvasX = (containerBounds.width - canvasWidth) / 2
        let canvasY = (containerBounds.height - canvasHeight) / 2
        let canvasFrame = CGRect(x: canvasX, y: canvasY, width: canvasWidth, height: canvasHeight)

        gridBackground.frame = canvasFrame
        shapeView.frame = canvasFrame
    }

    private func loadDesignFromGameManager() {
        let profile = GameManager.shared.getSideProfile()
        let viewCenterY = canvasHeight / 2

        // Helper to convert from saved model coordinates to view model coordinates
        func convertPoint(_ savedPoint: SerializablePoint) -> CGPoint {
            let offsetFromCenterline = CGFloat(savedPoint.y) - centerlineY
            return CGPoint(x: CGFloat(savedPoint.x), y: viewCenterY + offsetFromCenterline)
        }

        // Load all points
        shapeView.inletStart = convertPoint(profile.frontStart)
        shapeView.inletControl = convertPoint(profile.frontControl)
        shapeView.inletEnd = convertPoint(profile.frontEnd)
        shapeView.engineEnd = convertPoint(profile.engineEnd)
        shapeView.nozzleControl = convertPoint(profile.exhaustControl)
        shapeView.nozzleEnd = convertPoint(profile.exhaustEnd)
        shapeView.topStart = convertPoint(profile.topStart)
        shapeView.topControl = convertPoint(profile.topControl)
        shapeView.topEnd = convertPoint(profile.topEnd)

        shapeView.engineStart = shapeView.inletEnd

        // Ensure nose and tail points are consistent
        shapeView.topStart = shapeView.inletStart  // Nose: top and bottom meet
        shapeView.topEnd = shapeView.nozzleEnd     // Tail: top and bottom meet
        shapeView.engineLength = CGFloat(profile.engineLength)
        shapeView.maxHeight = CGFloat(profile.maxHeight)

        // Get actual aircraft length from planform (single source of truth)
        let planform = GameManager.shared.getTopViewPlanform()
        actualAircraftLengthMeters = CGFloat(planform.aircraftLength)
        shapeView.aircraftLengthMeters = actualAircraftLengthMeters

        // Update UI controls
        engineLengthSlider.value = Float(profile.engineLength)
        maxHeightSlider.value = Float(profile.maxHeight)
        aircraftLengthSlider.value = Float(actualAircraftLengthMeters)
        engineLengthValueLabel.text = String(format: "%.0f", profile.engineLength)
        maxHeightValueLabel.text = String(format: "%.0f", profile.maxHeight)
        aircraftLengthValueLabel.text = String(format: "%.0f", actualAircraftLengthMeters)

        // Update max engine length constraint
        updateMaxEngineLength()
    }

    private func setupControlPoints() {
        let pointSize = CGSize(width: 16, height: 16)

        // Nose control point (vertical only - adjusts front of aircraft)
        // Both inlet and top curves start at the same point (the nose)
        noseControlPoint = createControlPoint(size: pointSize, color: .magenta,
                                             verticalOnly: true, horizontalOnly: false)
        noseControlPoint.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)

            // Update both inlet start and top start Y positions (they meet at the nose)
            self.shapeView.inletStart.y = modelPoint.y
            self.shapeView.topStart.y = modelPoint.y

            // Keep X positions
            self.noseControlPoint.center.x = self.modelToCanvas(self.shapeView.inletStart).x

            self.updateControlPointPositions()
            self.shapeView.setNeedsDisplay()
            self.adjustViewToFitAircraft()
        }

        // Inlet control point (free movement for inlet curve shape)
        inletControlPoint = createControlPoint(size: pointSize, color: .green,
                                              verticalOnly: false, horizontalOnly: false)
        inletControlPoint.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            self.shapeView.inletControl = self.canvasToModel(newCenter)
            self.shapeView.setNeedsDisplay()
        }

        // Inlet end point (horizontal only - adjusts engine start position)
        inletEndPoint = createControlPoint(size: pointSize, color: .yellow,
                                          verticalOnly: false, horizontalOnly: true)
        inletEndPoint.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)

            // Update engine start (inlet end)
            self.shapeView.inletEnd.x = modelPoint.x
            self.shapeView.engineStart = self.shapeView.inletEnd

            // Update engine end to maintain length
            self.shapeView.engineEnd.x = self.shapeView.inletEnd.x + self.shapeView.engineLength
            self.shapeView.engineEnd.y = self.shapeView.inletEnd.y

            // Keep vertical alignment
            self.inletEndPoint.center.y = self.modelToCanvas(self.shapeView.inletEnd).y

            self.updateEnginePositionLabel()
            self.updateControlPointPositions()
            self.shapeView.setNeedsDisplay()
        }

        // Engine end point (vertical only - adjusts engine baseline height)
        engineEndPoint = createControlPoint(size: pointSize, color: .yellow,
                                           verticalOnly: true, horizontalOnly: false)
        engineEndPoint.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)

            // Store current max height
            let currentMaxHeight = self.shapeView.topControl.y - self.shapeView.inletEnd.y

            // Update both engine points to new Y (keep parallel to centerline)
            self.shapeView.inletEnd.y = modelPoint.y
            self.shapeView.engineStart.y = modelPoint.y
            self.shapeView.engineEnd.y = modelPoint.y

            // Maintain max height relative to new engine baseline
            self.shapeView.topControl.y = self.shapeView.inletEnd.y + currentMaxHeight

            // Keep X positions
            self.engineEndPoint.center.x = self.modelToCanvas(self.shapeView.engineEnd).x
            self.inletEndPoint.center.y = self.modelToCanvas(self.shapeView.inletEnd).y

            self.updateControlPointPositions()
            self.shapeView.setNeedsDisplay()
        }

        // Nozzle control point (free movement for nozzle curve shape)
        nozzleControlPoint = createControlPoint(size: pointSize, color: .orange,
                                               verticalOnly: false, horizontalOnly: false)
        nozzleControlPoint.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            self.shapeView.nozzleControl = self.canvasToModel(newCenter)
            self.shapeView.setNeedsDisplay()
        }

        // Nozzle end point (vertical only - adjusts rear tail height)
        // Both nozzle and top curves end at the same point (the tail)
        nozzleEndPoint = createControlPoint(size: pointSize, color: .red,
                                           verticalOnly: true, horizontalOnly: false)
        nozzleEndPoint.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            let modelPoint = self.canvasToModel(newCenter)

            // Update both nozzle end and top end Y positions (they meet at the tail)
            self.shapeView.nozzleEnd.y = modelPoint.y
            self.shapeView.topEnd.y = modelPoint.y

            // Keep X positions
            self.nozzleEndPoint.center.x = self.modelToCanvas(self.shapeView.nozzleEnd).x

            self.updateControlPointPositions()
            self.shapeView.setNeedsDisplay()
            self.adjustViewToFitAircraft()
        }

        // Top control point (free movement - controls top curve and max height)
        topControlPoint = createControlPoint(size: pointSize, color: .cyan,
                                            verticalOnly: false, horizontalOnly: false)
        topControlPoint.onMoved = { [weak self] newCenter in
            guard let self = self else { return }
            self.shapeView.topControl = self.canvasToModel(newCenter)

            // Update max height slider to reflect new height
            let engineBaseline = self.shapeView.inletEnd.y
            let newMaxHeight = self.shapeView.topControl.y - engineBaseline
            self.maxHeightSlider.value = Float(newMaxHeight)
            self.maxHeightValueLabel.text = String(format: "%.0f", newMaxHeight)

            self.shapeView.setNeedsDisplay()
            self.adjustViewToFitAircraft()
        }
    }

    private func createControlPoint(size: CGSize, color: UIColor,
                                   verticalOnly: Bool, horizontalOnly: Bool) -> DraggableControlPoint {
        let point = DraggableControlPoint(frame: CGRect(origin: .zero, size: size))
        point.backgroundColor = color
        point.isConstrainedToVertical = verticalOnly
        point.isConstrainedToHorizontal = horizontalOnly
        view.addSubview(point)
        return point
    }

    private func updateControlPointPositions() {
        noseControlPoint?.center = modelToCanvas(shapeView.inletStart)
        inletControlPoint?.center = modelToCanvas(shapeView.inletControl)
        inletEndPoint?.center = modelToCanvas(shapeView.inletEnd)
        engineEndPoint?.center = modelToCanvas(shapeView.engineEnd)
        nozzleControlPoint?.center = modelToCanvas(shapeView.nozzleControl)
        nozzleEndPoint?.center = modelToCanvas(shapeView.nozzleEnd)
        topControlPoint?.center = modelToCanvas(shapeView.topControl)
    }

    private func updateAllViews() {
        updateControlPointPositions()
        updateEnginePositionLabel()
        shapeView.setNeedsDisplay()
    }

    private func updateEnginePositionLabel() {
        let startX = Int(shapeView.inletEnd.x)
        let endX = Int(shapeView.engineEnd.x)
        enginePositionLabel.text = "Engine: \(startX) → \(endX)"
    }

    private func updateMaxEngineLength() {
        // Calculate aircraft length in canvas units
        let aircraftLengthCanvas = shapeView.nozzleEnd.x - shapeView.inletStart.x

        // Max engine length is the smaller of 100 units or half the aircraft length
        let halfAircraftLength = aircraftLengthCanvas / 2.0
        let maxEngineLength = min(100.0, halfAircraftLength)

        // Update slider maximum value
        engineLengthSlider.maximumValue = Float(maxEngineLength)

        // If current engine length exceeds new max, clamp it
        if shapeView.engineLength > maxEngineLength {
            shapeView.engineLength = maxEngineLength
            shapeView.engineEnd.x = shapeView.inletEnd.x + maxEngineLength
            engineLengthSlider.value = Float(maxEngineLength)
            engineLengthValueLabel.text = String(format: "%.0f", maxEngineLength)
            updateControlPointPositions()
            shapeView.setNeedsDisplay()
        }
    }

    private func adjustViewToFitAircraft() {
        // Calculate bounds of the aircraft in model space
        let minX = shapeView.inletStart.x
        let maxX = shapeView.nozzleEnd.x

        // Find min and max Y across all control points
        let allYValues: [CGFloat] = [
            shapeView.inletStart.y,
            shapeView.inletControl.y,
            shapeView.inletEnd.y,
            shapeView.engineEnd.y,
            shapeView.nozzleControl.y,
            shapeView.nozzleEnd.y,
            shapeView.topStart.y,
            shapeView.topControl.y,
            shapeView.topEnd.y
        ]
        let minY = allYValues.min() ?? 0
        let maxY = allYValues.max() ?? canvasHeight

        let aircraftWidth = maxX - minX
        let aircraftHeight = maxY - minY

        // Add 10% padding
        let paddingFactor: CGFloat = 1.1

        // Calculate scale factors to fit in canvas
        let scaleX = canvasWidth / (aircraftWidth * paddingFactor)
        let scaleY = canvasHeight / (aircraftHeight * paddingFactor)

        // Use the smaller scale to ensure everything fits
        let newScale = min(scaleX, scaleY, 1.0)  // Don't zoom in past 1.0

        shapeView.viewScale = newScale

        // Update control point positions with new scale
        updateControlPointPositions()
        shapeView.setNeedsDisplay()
    }

    // MARK: - Coordinate Conversion

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

    // MARK: - Actions

    @objc private func engineLengthChanged(_ slider: UISlider) {
        let newLength = CGFloat(slider.value)
        shapeView.engineLength = newLength

        // Update engine end position
        let maxX = canvasWidth - 200  // Leave space for nozzle
        let newEngineEndX = shapeView.inletEnd.x + newLength

        if newEngineEndX < maxX {
            shapeView.engineEnd.x = newEngineEndX
            shapeView.engineEnd.y = shapeView.inletEnd.y
            engineLengthValueLabel.text = String(format: "%.0f", newLength)
            updateEnginePositionLabel()
            updateControlPointPositions()
            shapeView.setNeedsDisplay()
            adjustViewToFitAircraft()  // Adjust view to center and fit the aircraft
        } else {
            // Revert slider if exceeds bounds
            slider.value = Float(shapeView.engineEnd.x - shapeView.inletEnd.x)
        }
    }

    @objc private func maxHeightChanged(_ slider: UISlider) {
        let newMaxHeight = CGFloat(slider.value)
        shapeView.maxHeight = newMaxHeight

        // Update top control point Y to be maxHeight above engine baseline
        let engineBaseline = shapeView.inletEnd.y
        shapeView.topControl.y = engineBaseline + newMaxHeight

        maxHeightValueLabel.text = String(format: "%.0f", newMaxHeight)
        updateControlPointPositions()
        shapeView.setNeedsDisplay()
        adjustViewToFitAircraft()  // Adjust view to center and fit the aircraft
    }

    @objc private func aircraftLengthChanged(_ slider: UISlider) {
        let newLengthMeters = CGFloat(slider.value)

        // Calculate current aircraft length using actual scale
        let currentLengthCanvas = shapeView.nozzleEnd.x - shapeView.inletStart.x
        let currentMetersPerUnit = actualAircraftLengthMeters / currentLengthCanvas
        let currentLengthMetersCalculated = currentLengthCanvas * currentMetersPerUnit

        // Calculate scale factor
        let scaleFactor = newLengthMeters / currentLengthMetersCalculated

        // Update cached length
        actualAircraftLengthMeters = newLengthMeters
        shapeView.aircraftLengthMeters = newLengthMeters

        // Scale relative to (nose X, canvas center Y)
        let originX = shapeView.inletStart.x
        let originY = canvasHeight / 2.0

        // Helper function to scale a point relative to origin
        func scalePoint(_ point: CGPoint) -> CGPoint {
            let offset = CGPoint(x: point.x - originX, y: point.y - originY)
            let scaledOffset = CGPoint(x: offset.x * scaleFactor, y: offset.y * scaleFactor)
            return CGPoint(x: originX + scaledOffset.x, y: originY + scaledOffset.y)
        }

        // Scale all control points
        shapeView.inletStart = scalePoint(shapeView.inletStart)
        shapeView.topStart = shapeView.inletStart  // topStart equals inletStart (nose point)
        shapeView.inletControl = scalePoint(shapeView.inletControl)
        shapeView.inletEnd = scalePoint(shapeView.inletEnd)
        shapeView.engineStart = shapeView.inletEnd  // engineStart equals inletEnd
        shapeView.engineEnd = scalePoint(shapeView.engineEnd)
        shapeView.nozzleControl = scalePoint(shapeView.nozzleControl)
        shapeView.nozzleEnd = scalePoint(shapeView.nozzleEnd)
        shapeView.topControl = scalePoint(shapeView.topControl)
        shapeView.topEnd = shapeView.nozzleEnd  // topEnd equals nozzleEnd (tail point)

        // Update engine length to reflect scaled distance
        shapeView.engineLength = shapeView.engineEnd.x - shapeView.inletEnd.x

        // Update max height to reflect scaled height
        let engineBaseline = shapeView.inletEnd.y
        shapeView.maxHeight = shapeView.topControl.y - engineBaseline

        // Update sliders to reflect new values
        engineLengthSlider.value = Float(shapeView.engineLength)
        maxHeightSlider.value = Float(shapeView.maxHeight)
        engineLengthValueLabel.text = String(format: "%.0f", shapeView.engineLength)
        maxHeightValueLabel.text = String(format: "%.0f", shapeView.maxHeight)
        aircraftLengthValueLabel.text = String(format: "%.0f", newLengthMeters)

        updateEnginePositionLabel()
        adjustViewToFitAircraft()  // Adjust view to fit the scaled aircraft

        // Update max engine length constraint based on new aircraft length
        updateMaxEngineLength()
    }

    @objc private func show3DView() {
        let wireframeVC = WireframeViewController()
        wireframeVC.shapeView = self.shapeView
        wireframeVC.maxHeight = CGFloat(self.maxHeightSlider.value)
        wireframeVC.modalPresentationStyle = .fullScreen
        self.present(wireframeVC, animated: true, completion: nil)
    }

    @objc private func doneButtonTapped() {
        saveToGameManager()
        dismiss(animated: true, completion: nil)
    }

    @objc private func resetButtonTapped() {
        // Load default profile
        let profile = SideProfileShape.defaultProfile
        let viewCenterY = canvasHeight / 2

        // Helper to convert from saved model coordinates to view model coordinates
        func convertPoint(_ savedPoint: SerializablePoint) -> CGPoint {
            let offsetFromCenterline = CGFloat(savedPoint.y) - centerlineY
            return CGPoint(x: CGFloat(savedPoint.x), y: viewCenterY + offsetFromCenterline)
        }

        // Load all points from default profile
        shapeView.inletStart = convertPoint(profile.frontStart)
        shapeView.inletControl = convertPoint(profile.frontControl)
        shapeView.inletEnd = convertPoint(profile.frontEnd)
        shapeView.engineEnd = convertPoint(profile.engineEnd)
        shapeView.nozzleControl = convertPoint(profile.exhaustControl)
        shapeView.nozzleEnd = convertPoint(profile.exhaustEnd)
        shapeView.topStart = convertPoint(profile.topStart)
        shapeView.topControl = convertPoint(profile.topControl)
        shapeView.topEnd = convertPoint(profile.topEnd)

        shapeView.engineStart = shapeView.inletEnd

        // Ensure nose and tail points are consistent
        shapeView.topStart = shapeView.inletStart  // Nose: top and bottom meet
        shapeView.topEnd = shapeView.nozzleEnd     // Tail: top and bottom meet
        shapeView.engineLength = CGFloat(profile.engineLength)
        shapeView.maxHeight = CGFloat(profile.maxHeight)

        // Reset aircraft length to default (70m)
        actualAircraftLengthMeters = 70.0
        shapeView.aircraftLengthMeters = actualAircraftLengthMeters

        // Update UI controls
        engineLengthSlider.value = Float(profile.engineLength)
        maxHeightSlider.value = Float(profile.maxHeight)
        aircraftLengthSlider.value = Float(actualAircraftLengthMeters)
        engineLengthValueLabel.text = String(format: "%.0f", profile.engineLength)
        maxHeightValueLabel.text = String(format: "%.0f", profile.maxHeight)
        aircraftLengthValueLabel.text = String(format: "%.0f", actualAircraftLengthMeters)

        // Update control points and refresh view
        updateControlPointPositions()
        shapeView.setNeedsDisplay()
        adjustViewToFitAircraft()

        // Update max engine length constraint
        updateMaxEngineLength()
    }

    @objc private func saveButtonTapped() {
        // First save current design to GameManager
        saveToGameManager()

        let alert = UIAlertController(
            title: "Save Design",
            message: "Enter a name for your design",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Design Name"
            textField.autocapitalizationType = .words
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty else {
                self?.showAlert(title: "Error", message: "Please enter a valid name")
                return
            }

            // Check if design already exists
            if GameManager.shared.getSavedDesignNames().contains(name) {
                self?.confirmOverwrite(name: name)
            } else {
                self?.performSave(name: name)
            }
        })

        present(alert, animated: true)
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

    private func confirmOverwrite(name: String) {
        let alert = UIAlertController(
            title: "Design Exists",
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

    private func performLoad(name: String) {
        if GameManager.shared.loadDesign(name: name) {
            // Reload the design from GameManager
            loadDesignFromGameManager()
            setupControlPoints()
            updateAllViews()
            showAlert(title: "Success", message: "Design '\(name)' loaded successfully")
        } else {
            showAlert(title: "Error", message: "Failed to load design")
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Save to GameManager

    private func saveToGameManager() {
        let viewCenterY = canvasHeight / 2

        // Helper to convert from view model coordinates to saved model coordinates
        func convertToSerializable(_ point: CGPoint, isFixedX: Bool) -> SerializablePoint {
            let offsetFromCenterline = point.y - viewCenterY
            let savedY = centerlineY + offsetFromCenterline
            return SerializablePoint(x: Double(point.x), y: Double(savedY), isFixedX: isFixedX)
        }

        let profile = SideProfileShape(
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
            maxHeight: Double(maxHeightSlider.value)
        )

        GameManager.shared.setSideProfile(profile)

        print("========== SIDE PROFILE SAVED ==========")
        print("Inlet: (\(Int(shapeView.inletStart.x)), \(Int(shapeView.inletControl.x)), \(Int(shapeView.inletEnd.x)))")
        print("Engine: \(Int(shapeView.inletEnd.x)) → \(Int(shapeView.engineEnd.x)) (length: \(Int(shapeView.engineLength)))")
        print("Nozzle: (\(Int(shapeView.engineEnd.x)), \(Int(shapeView.nozzleControl.x)), \(Int(shapeView.nozzleEnd.x)))")
        print("Max Height: \(Int(maxHeightSlider.value))")
        print("========================================")
    }
}
