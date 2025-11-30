//
//  SplineCalculator.swift
//  ssto
//
//  Created by tom whittaker on 11/28/25.
//


import SwiftUI

// MARK: - Math Helpers for Spline Calculation

/// A structure to handle the mathematical conversion of "Knot" points into smooth Cubic Bezier curves.
struct SplineCalculator {
    
    static func calculateControlPoints(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, alpha: CGFloat = 0.5) -> (CGPoint, CGPoint) {
        
        let d1 = distance(p1, p0)
        let d2 = distance(p2, p1)
        let d3 = distance(p3, p2)
        
        let safeD1 = max(d1, 0.0001)
        let safeD2 = max(d2, 0.0001)
        let safeD3 = max(d3, 0.0001)
        
        let m1 = (p2 - p1) + (p1 - p0) * (safeD2 / safeD1)
        let m2 = (p2 - p1) + (p3 - p2) * (safeD2 / safeD3)
        
        let cp1 = p1 + m1 * (0.2)
        let cp2 = p2 - m2 * (0.2)
        
        return (cp1, cp2)
    }
    
    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}

// Extension to allow basic point math
extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

// MARK: - Data Model

struct ControlPoint: Identifiable, Equatable {
    let id = UUID()
    var location: CGPoint
    var isFixedX: Bool = false
}

class AircraftDesignModel: ObservableObject {
    @Published var topPoints: [ControlPoint]
    @Published var bottomPoints: [ControlPoint]
    
    let canvasWidth: CGFloat = 800
    let canvasHeight: CGFloat = 500
    
    init() {
        // Load from GameManager
        let savedPoints = GameManager.shared.getCrossSectionPoints()
        
        self.topPoints = savedPoints.topPoints.map { point in
            ControlPoint(location: point.toCGPoint(), isFixedX: point.isFixedX)
        }
        
        self.bottomPoints = savedPoints.bottomPoints.map { point in
            ControlPoint(location: point.toCGPoint(), isFixedX: point.isFixedX)
        }
    }
    
    func saveToGameManager() {
        let topSerializable = topPoints.map { point in
            SerializablePoint(from: point.location, isFixedX: point.isFixedX)
        }
        
        let bottomSerializable = bottomPoints.map { point in
            SerializablePoint(from: point.location, isFixedX: point.isFixedX)
        }
        
        let points = CrossSectionPoints(topPoints: topSerializable, bottomPoints: bottomSerializable)
        GameManager.shared.setCrossSectionPoints(points)
    }
    
    func computeLiftAndDrag() -> (lift: Double, drag: Double) {
        let combined = topPoints.map { $0.location } + (bottomPoints.reversed().map { $0.location }) // Assume non-symmetric for general case; adjust if symmetric
        
        var XB = combined.map { Double($0.x) }
        var YB = combined.map { Double(250 - $0.y) } // Flip y for positive up (aerodynamic convention)
        
        // Normalize to unit chord
        let minX = XB.min() ?? 0
        let maxX = XB.max() ?? 1
        let chord = maxX - minX
        for i in 0..<XB.count {
            XB[i] = (XB[i] - minX) / chord
            YB[i] = YB[i] / chord
        }
        
        let AoA: Double = 30.0
        let AoAR = AoA * .pi / 180.0
        
        let numPts = XB.count
        let numPan = numPts - 1
        
        // Check and flip direction if necessary
        var edge = [Double](repeating: 0, count: numPan)
        for i in 0..<numPan {
            edge[i] = (XB[i+1] - XB[i]) * (YB[i+1] + YB[i])
        }
        let sumEdge = edge.reduce(0, +)
        if sumEdge < 0 {
            XB.reverse()
            YB.reverse()
        }
        
        // Compute geometric quantities
        var S = [Double](repeating: 0, count: numPan)
        var phi = [Double](repeating: 0, count: numPan)
        for i in 0..<numPan {
            let dx = XB[i+1] - XB[i]
            let dy = YB[i+1] - YB[i]
            S[i] = sqrt(dx*dx + dy*dy)
            phi[i] = atan2(dy, dx)
            if phi[i] < 0 {
                phi[i] += 2 * .pi
            }
        }
        
        let delta = phi.map { $0 + .pi / 2 }
        var beta = delta.map { $0 - AoAR }
        beta = beta.map { $0 > 2 * .pi ? $0 - 2 * .pi : $0 }
        
        // Newtonian approximation for Cp
        var Cp = [Double](repeating: 0, count: numPan)
        for i in 0..<numPan {
            let cosBeta = cos(beta[i])
            if cosBeta < 0 {
                Cp[i] = pow(cosBeta, 2) // Subsonic approximation (Cp max =1)
            }
        }
        
        // Compute CN and CA
        var CN = [Double](repeating: 0, count: numPan)
        var CA = [Double](repeating: 0, count: numPan)
        for i in 0..<numPan {
            CN[i] = -Cp[i] * S[i] * sin(beta[i])
            CA[i] = -Cp[i] * S[i] * cos(beta[i])
        }
        
        // Compute Cl and Cd
        var CL: Double = 0
        var CD: Double = 0
        for i in 0..<numPan {
            CL += CN[i] * cos(AoAR) - CA[i] * sin(AoAR)
            CD += CN[i] * sin(AoAR) + CA[i] * cos(AoAR)
        }
        
        // Physical conditions
        let rho: Double = 0.46 // kg/m³ at 30K feet
        let a: Double = 303.0 // speed of sound m/s
        let V = 0.5 * a // Mach 0.5
        let q = 0.5 * rho * V * V
        let refArea: Double = 18.0 // m² (planform area)
        
        let lift = q * refArea * CL
        let drag = q * refArea * CD
        
        return (lift, drag)
    }
}

// MARK: - Shapes

struct InterpolatedSplineShape: Shape {
    var points: [CGPoint]
    var closed: Bool = false
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }
        
        path.move(to: points[0])
        
        for i in 0..<points.count - 1 {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            
            let (cp1, cp2) = SplineCalculator.calculateControlPoints(p0: p0, p1: p1, p2: p2, p3: p3)
            
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        
        if closed {
            path.closeSubpath()
        }
        
        return path
    }
}

struct ControlPolygonShape: Shape {
    var points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        return path
    }
}

// MARK: - Views

struct LiftingBodyDesigner: View {
    // Add environment dismiss action to handle closing the view
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var model = AircraftDesignModel()
    @State private var showControlPolygon = true
    @State private var symmetricMode = false
    @State private var lift: Double = 43000
    @State private var drag: Double = 28500
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                // Done Button to save and return
                Button(action: {
                    model.saveToGameManager()
                    dismiss()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("Done")
                    }
                    .foregroundColor(.yellow)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Text("Lifting Body Designer")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Toggle("Mirror", isOn: $symmetricMode)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    .foregroundColor(.white)
                    .font(.caption)
                    .labelsHidden()
                
                Toggle("Hull", isOn: $showControlPolygon)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .foregroundColor(.white)
                    .font(.caption)
                    .labelsHidden()
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Lift: \(Int(lift)) N")
                    Text("Drag: \(Int(drag)) N")
                }
                .foregroundColor(.yellow)
                .font(.caption)
            }
            .padding()
            .background(Color(red: 0.1, green: 0.1, blue: 0.15))
            
            // Canvas
            GeometryReader { geometry in
                ZStack {
                    // 1. Engineering Grid Background
                    GridBackground()
                    
                    // 2. The Aircraft Shape (Filled)
                    let combinedPoints = model.topPoints.map { $0.location } +
                    (symmetricMode ?
                     model.topPoints.reversed().map { CGPoint(x: $0.location.x, y: 500 - ($0.location.y - 250)) } :
                        model.bottomPoints.reversed().map { $0.location })
                    
                    InterpolatedSplineShape(points: combinedPoints, closed: true)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                            startPoint: .top,
                            endPoint: .bottom))
                        .overlay(
                            InterpolatedSplineShape(points: combinedPoints, closed: true)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(radius: 10)
                    
                    // 3. Control Polygon
                    if showControlPolygon {
                        ControlPolygonShape(points: model.topPoints.map { $0.location })
                            .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        
                        if !symmetricMode {
                            ControlPolygonShape(points: model.bottomPoints.map { $0.location })
                                .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        }
                    }
                    
                    // 4. Interactive Control Points
                    ForEach(Array(model.topPoints.enumerated()), id: \.element.id) { index, point in
                        ControlPointView(point: point) { newLocation in
                            updatePoint(index: index, location: newLocation, isTop: true)
                        }
                    }
                    
                    if !symmetricMode {
                        ForEach(Array(model.bottomPoints.enumerated()), id: \.element.id) { index, point in
                            if index != 0 && index != model.bottomPoints.count - 1 {
                                ControlPointView(point: point) { newLocation in
                                    updatePoint(index: index, location: newLocation, isTop: false)
                                }
                            }
                        }
                    }
                }
                .background(Color(red: 0.05, green: 0.05, blue: 0.1))
                .clipped()
            }
            
            // Footer Info
            HStack {
                Text("Drag points to shape the fuselage cross-section.")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(10)
            .background(Color(red: 0.1, green: 0.1, blue: 0.15))
        }
        .edgesIgnoringSafeArea(.all)
        .statusBar(hidden: true)
        .onAppear {
            (lift, drag) = model.computeLiftAndDrag()
        }
    }
    
    func updatePoint(index: Int, location: CGPoint, isTop: Bool) {
        if isTop {
            var newPoint = model.topPoints[index]
            if newPoint.isFixedX {
                newPoint.location.y = location.y
            } else {
                newPoint.location = location
            }
            model.topPoints[index] = newPoint
            
            if index == 0 {
                model.bottomPoints[0].location = newPoint.location
            }
            if index == model.topPoints.count - 1 {
                model.bottomPoints[model.bottomPoints.count - 1].location = newPoint.location
            }
            
        } else {
            var newPoint = model.bottomPoints[index]
            newPoint.location = location
            model.bottomPoints[index] = newPoint
        }
        
        // Update lift and drag dynamically
        (lift, drag) = model.computeLiftAndDrag()
    }
}

// MARK: - Subviews

struct ControlPointView: View {
    var point: ControlPoint
    var onDrag: (CGPoint) -> Void
    @State private var isDragging = false
    
    var body: some View {
        Circle()
            .fill(isDragging ? Color.yellow : Color.white)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(Color.black, lineWidth: 1))
            .shadow(radius: 3)
            .position(point.location)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        onDrag(value.location)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
}

struct GridBackground: View {
    let spacing: CGFloat = 50
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: 0, to: size.width, by: spacing) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, to: size.height, by: spacing) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(Color.white.opacity(0.1)), lineWidth: 1)
            
            var centerPath = Path()
            centerPath.move(to: CGPoint(x: 0, y: 250))
            centerPath.addLine(to: CGPoint(x: size.width, y: 250))
            context.stroke(centerPath, with: .color(Color.red.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
    }
}
