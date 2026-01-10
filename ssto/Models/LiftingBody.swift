import SwiftUI
import SceneKit
import ModelIO
import SceneKit.ModelIO

// MARK: - Geometry Engine

/// Represents a 2D airfoil cross-section
struct AirfoilSection {
    let centerX: Float      // Longitudinal position along aircraft
    let centerY: Float      // Vertical position (centerline Z)
    let centerZ: Float      // Lateral position (usually 0)
    let chord: Float        // Width (Span) at this section
    let thickness: Float    // Not used (legacy)
    let scale: Float        // Height at centerline
}

/// Represents a point on an airfoil profile
struct AirfoilPoint {
    let x: Float  // Normalized width (-1 to 1 or 0 to 1)
    let y: Float  // Normalized height (-1 to 1 or 0 to 1)
}

class LiftingBodyEngine {

    // MARK: - Geometry Generation Entry Point

    /// Generates the lifting body geometry based on the current design in GameManager.
    /// This integrates Top View (width), Side View (height/profile), and Cross-Section (shape) designs.
    static func generateGeometry() -> SCNGeometry {
        let topView = GameManager.shared.getTopViewPlanform()
        let sideProfile = GameManager.shared.getSideProfile()
        let crossSection = GameManager.shared.getCrossSectionPoints()
        
        return generateGeometryFromDesign(
            planform: topView,
            profile: sideProfile,
            crossSectionPoints: crossSection
        )
    }

    /// Legacy entry point (kept for compatibility if needed, but redirects to new logic if possible)
    static func generateGeometry(
        coneAngle: Double,
        sweepAngle: Double,
        tiltAngle: Double,
        flatTopPct: Double = 70,
        heightFactor: Double = 10,
        slopeCurve: Double = 1.5
    ) -> SCNGeometry {
        // Fallback to the new design system
        return generateGeometry()
    }

    // MARK: - Core Generation Logic

    static func generateGeometryFromDesign(
        planform: TopViewPlanform,
        profile: SideProfileShape,
        crossSectionPoints: CrossSectionPoints
    ) -> SCNGeometry {
        
        // 1. Generate Cross Sections along the length
        let sections = generateCrossSectionsFromDesign(planform: planform, profile: profile)
        
        // 2. Generate Base Airfoil Shape (normalized)
        let baseAirfoil = generateCrossSectionFromSpline(crossSectionPoints: crossSectionPoints)
        
        // 3. Generate 3D Mesh
        return generateMeshFromSections(sections: sections, baseAirfoil: baseAirfoil)
    }

    // MARK: - Cross-Section Analysis

    /// Generates sections along the aircraft length by sampling the Top and Side designs
    static func generateCrossSectionsFromDesign(
        planform: TopViewPlanform,
        profile: SideProfileShape
    ) -> [AirfoilSection] {
        
        var sections: [AirfoilSection] = []
        let numSections = 60
        
        // --- Coordinate System Setup ---
        // Top View: noseTip.x to tailLeft.x corresponds to 0 to aircraftLength (meters)
        let noseX = CGFloat(planform.noseTip.x)
        let tailX = CGFloat(planform.tailLeft.x)
        let canvasLength = tailX - noseX
        let realLength = CGFloat(planform.aircraftLength)
        let scaleToMeters = realLength / max(1.0, canvasLength)
        
        // Side View: Coordinates are in same canvas space (0-800 usually)
        // We need to map X in Top View to X in Side View
        let sideNoseX = CGFloat(profile.frontStart.x)
        let sideTailX = CGFloat(profile.exhaustEnd.x)
        let sideViewLength = sideTailX - sideNoseX
        
        for i in 0...numSections {
            let t = CGFloat(i) / CGFloat(numSections)
            
            // Current X in "Real World" (Meters)
            let currentRealX = t * realLength
            
            // Current X in Top View Canvas
            let topViewX = noseX + (t * canvasLength)
            
            // 1. Calculate Width (Span) from Top View
            let halfWidthCanvas = getTopViewWidthAt(x: topViewX, planform: planform)
            let widthMeters = (halfWidthCanvas * scaleToMeters) * 2.0 // Total span
            
            // 2. Calculate Height and Vertical Position from Side View
            // Map 't' to Side View X
            let sideViewX = sideNoseX + (t * sideViewLength)
            
            let (topY, bottomY) = getSideProfileYAt(x: sideViewX, profile: profile)
            
            // Height in Canvas Units
            let heightCanvas = abs(topY - bottomY)
            let heightMeters = heightCanvas * scaleToMeters
            
            // Center Y (Vertical Position) in Canvas Units
            // For 3D model, we typically center the fuselage vertically or align bottom
            // Let's use the average Y relative to the Nose Y
            let centerYCanvas = (topY + bottomY) / 2.0
            let noseYCanvas = CGFloat(profile.frontStart.y)
            let centerYMeters = (centerYCanvas - noseYCanvas) * scaleToMeters
            
            // Create Section
            let section = AirfoilSection(
                centerX: Float(currentRealX),
                centerY: Float(centerYMeters), // Vertical offset
                centerZ: 0,                    // Lateral offset (0 for symmetric)
                chord: Float(widthMeters),     // Full Width
                thickness: 1.0,                // Ratio, effectively ignored as we use Scale
                scale: Float(heightMeters)     // Full Height
            )
            
            sections.append(section)
        }
        
        return sections
    }
    
    // MARK: - Interpolation Helpers

    /// Interpolates the Top View Planform to get half-width at a given X
    static func getTopViewWidthAt(x: CGFloat, planform: TopViewPlanform) -> CGFloat {
        // Extract points
        let pNose = planform.noseTip.toCGPoint()
        let pFrontCtrl = planform.frontControlLeft.toCGPoint()
        let pMid = planform.midLeft.toCGPoint()
        let pRearCtrl = planform.rearControlLeft.toCGPoint()
        let pTail = planform.tailLeft.toCGPoint()
        
        // Determine segment
        if x < pNose.x { return 0 } // Ahead of nose
        
        // Wing Logic: The planform drawing *includes* the wings if the tail point is wide
        // But in TopViewShapeView, wings are drawn separately.
        // Let's look at TopViewShapeView logic:
        // getFuselageWidthAt only considers fuselage.
        // If we want the mesh to include wings, we must add them here or generate separate wing geometry.
        // For a "Lifting Body", the fuselage IS the wing.
        // But TopViewShapeView draws "Fuselage" then "Wings".
        // The Planform curve defines the FUSELAGE width.
        // The Wing parameters define the WING width.
        // We should merge them: Max(Fuselage, Wing) at X.
        
        // 1. Fuselage Width
        var fuselageWidth: CGFloat = 0
        if x <= pMid.x {
            fuselageWidth = solveBezierY(x: x, p0: pNose, p1: pFrontCtrl, p2: pMid)
        } else if x <= pTail.x {
            fuselageWidth = solveBezierY(x: x, p0: pMid, p1: pRearCtrl, p2: pTail)
        }
        
        // 2. Wing Width
        // Wing Start: planform.wingStartPosition (0.0-1.0 of fuselage length)
        // Wing Span: planform.wingSpan
        let fuselageLen = pTail.x - pNose.x
        let wingStartX = pNose.x + (fuselageLen * CGFloat(planform.wingStartPosition))
        let wingEndX = pTail.x
        
        var wingWidth: CGFloat = 0
        if x >= wingStartX && x <= wingEndX {
            // Simple triangular wing
            let t = (x - wingStartX) / (wingEndX - wingStartX)
            let maxWingSpan = CGFloat(planform.wingSpan) // Extension beyond fuselage
            // However, we need to know the fuselage width at the tail to know where the wing ends
            // In TopViewShapeView: wingTrailingEdge = fuselageWidthAtEnd + wingSpan
            // We assume linear growth from 0 at start to Max at end?
            
            // Wing Leading Edge is at wingStartX.
            // Wing Trailing Edge is at wingEndX.
            // Wing Tip is at (wingEndX, fuselageWidthAtEnd + wingSpan)
            // Leading Edge of Wing: Line from (wingStartX, fuselageWidthAtStart) to (wingEndX, fuselageWidthAtEnd + wingSpan)
            
            // Let's verify TopViewShapeView:
            // leftWingPath.move(to: wlLeading) // Leading Edge at Fuselage
            // leftWingPath.addLine(to: wlTrailing) // Trailing Edge Tip
            
            // So width increases linearly from FuselageWidth(Start) to (FuselageWidth(End) + Span)
            
            let fuselageWidthAtStart = getFuselageWidthOnly(x: wingStartX, planform: planform)
            let fuselageWidthAtEnd = getFuselageWidthOnly(x: wingEndX, planform: planform)
            
            let wingTipWidth = fuselageWidthAtEnd + maxWingSpan
            
            wingWidth = fuselageWidthAtStart + (wingTipWidth - fuselageWidthAtStart) * t
        }
        
        return max(fuselageWidth, wingWidth)
    }
    
    static func getFuselageWidthOnly(x: CGFloat, planform: TopViewPlanform) -> CGFloat {
        let pNose = planform.noseTip.toCGPoint()
        let pFrontCtrl = planform.frontControlLeft.toCGPoint()
        let pMid = planform.midLeft.toCGPoint()
        let pRearCtrl = planform.rearControlLeft.toCGPoint()
        let pTail = planform.tailLeft.toCGPoint()
        
        if x < pNose.x { return 0 }
        if x > pTail.x { return abs(pTail.y) } // Clamp to tail width
        
        if x <= pMid.x {
            return solveBezierY(x: x, p0: pNose, p1: pFrontCtrl, p2: pMid)
        } else {
            return solveBezierY(x: x, p0: pMid, p1: pRearCtrl, p2: pTail)
        }
    }
    
    /// Interpolates the Side View Profile to get Top and Bottom Y values at a given X
    static func getSideProfileYAt(x: CGFloat, profile: SideProfileShape) -> (top: CGFloat, bottom: CGFloat) {
        // --- Top Curve ---
        let topY = solveBezierY(
            x: x,
            p0: profile.topStart.toCGPoint(),
            p1: profile.topControl.toCGPoint(),
            p2: profile.topEnd.toCGPoint()
        )
        
        // --- Bottom Curve ---
        let inletEndX = CGFloat(profile.frontEnd.x)
        let engineEndX = CGFloat(profile.engineEnd.x)
        
        var bottomY: CGFloat = 0
        
        if x <= inletEndX {
            // Inlet Curve
            bottomY = solveBezierY(
                x: x,
                p0: profile.frontStart.toCGPoint(),
                p1: profile.frontControl.toCGPoint(),
                p2: profile.frontEnd.toCGPoint()
            )
        } else if x <= engineEndX {
            // Engine Section (Linear)
            let t = (x - inletEndX) / max(1.0, (engineEndX - inletEndX))
            let y1 = CGFloat(profile.frontEnd.y)
            let y2 = CGFloat(profile.engineEnd.y)
            bottomY = y1 + (y2 - y1) * t
        } else {
            // Nozzle Curve
            bottomY = solveBezierY(
                x: x,
                p0: profile.engineEnd.toCGPoint(),
                p1: profile.exhaustControl.toCGPoint(),
                p2: profile.exhaustEnd.toCGPoint()
            )
        }
        
        return (topY, bottomY)
    }
    
    /// Solves for Y on a quadratic Bezier curve given X
    static func solveBezierY(x: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        let x0 = p0.x
        let x1 = p1.x
        let x2 = p2.x
        
        if x <= x0 { return abs(p0.y) }
        if x >= x2 { return abs(p2.y) }
        
        // x(t) = (1-t)^2*x0 + 2(1-t)t*x1 + t^2*x2
        // At^2 + Bt + C = 0
        let A = x0 - 2*x1 + x2
        let B = 2*x1 - 2*x0
        let C = x0 - x
        
        var t: CGFloat = 0.5
        
        if abs(A) < 0.001 {
            if abs(B) > 0.001 { t = -C / B }
        } else {
            let delta = B*B - 4*A*C
            if delta >= 0 {
                let sqrtDelta = sqrt(delta)
                let t1 = (-B + sqrtDelta) / (2*A)
                let t2 = (-B - sqrtDelta) / (2*A)
                if t1 >= 0 && t1 <= 1 { t = t1 }
                else if t2 >= 0 && t2 <= 1 { t = t2 }
            }
        }
        
        t = max(0, min(1, t))
        let y = pow(1-t, 2)*p0.y + 2*(1-t)*t*p1.y + t*t*p2.y
        return abs(y)
    }

    // MARK: - Spline Cross-Section Generation

    /// Generate normalized cross-section shape from spline points
    static func generateCrossSectionFromSpline(
        crossSectionPoints: CrossSectionPoints,
        numSamples: Int = 30
    ) -> [AirfoilPoint] {

        var points: [AirfoilPoint] = []
        let topCG = crossSectionPoints.topPoints.map { $0.toCGPoint() }
        let bottomCG = crossSectionPoints.bottomPoints.map { $0.toCGPoint() }
        
        let minX = topCG.first?.x ?? 0
        let maxX = topCG.last?.x ?? 800
        let width = max(1.0, maxX - minX)
        let centerY: CGFloat = 250
        
        // Find scale factor (max height of the drawn spline)
        var maxSplineHeight: CGFloat = 1.0
        for i in 0...20 {
            let x = minX + (CGFloat(i)/20.0) * width
            let ty = interpolateSplineY(x: x, points: topCG)
            let by = interpolateSplineY(x: x, points: bottomCG)
            maxSplineHeight = max(maxSplineHeight, abs(ty - by))
        }
        
        // 2. Generate Top Surface
        for i in 0..<numSamples {
            let t = CGFloat(i) / CGFloat(numSamples - 1)
            let x = minX + t * width
            let y = interpolateSplineY(x: x, points: topCG)
            
            let nx = Float((t - 0.5)) // -0.5 to 0.5
            let ny = Float((y - centerY) / maxSplineHeight)
            points.append(AirfoilPoint(x: nx, y: ny))
        }
        
        // 3. Generate Bottom Surface (Reversed)
        for i in (0..<numSamples).reversed() {
            let t = CGFloat(i) / CGFloat(numSamples - 1)
            let x = minX + t * width
            let y = interpolateSplineY(x: x, points: bottomCG)
            
            let nx = Float((t - 0.5))
            let ny = Float((y - centerY) / maxSplineHeight)
            points.append(AirfoilPoint(x: nx, y: ny))
        }
        
        return points
    }
    
    static func interpolateSplineY(x: CGFloat, points: [CGPoint]) -> CGFloat {
        if points.isEmpty { return 250 }
        if points.count == 1 { return points[0].y }
        
        for i in 0..<(points.count - 1) {
            let p0 = points[i]
            let p1 = points[i+1]
            if x >= p0.x && x <= p1.x {
                let t = (x - p0.x) / (p1.x - p0.x)
                return p0.y + t * (p1.y - p0.y)
            }
        }
        return points.last?.y ?? 250
    }

    // MARK: - Mesh Generation

    static func generateMeshFromSections(sections: [AirfoilSection], baseAirfoil: [AirfoilPoint]) -> SCNGeometry {

        var vertices: [SCNVector3] = []
        var indices: [Int32] = []
        
        // Generate vertices
        for section in sections {
            let chord = section.chord // Width
            let heightScale = section.scale // Height
            
            for point in baseAirfoil {
                // point.x is -0.5 to 0.5
                // point.y is normalized height (-0.5 to 0.5 approx)
                
                let x = section.centerX
                let y = point.x * chord
                let z = section.centerY + (point.y * heightScale)
                
                vertices.append(SCNVector3(x, y, z))
            }
        }
        
        // Generate Indices
        let pointsPerSection = baseAirfoil.count
        
        for i in 0..<(sections.count - 1) {
            let currentOffset = i * pointsPerSection
            let nextOffset = (i + 1) * pointsPerSection
            
            for j in 0..<(pointsPerSection - 1) {
                let p0 = Int32(currentOffset + j)
                let p1 = Int32(currentOffset + j + 1)
                let p2 = Int32(nextOffset + j)
                let p3 = Int32(nextOffset + j + 1)
                
                // Top Triangle
                indices.append(contentsOf: [p0, p2, p1])
                // Bottom Triangle
                indices.append(contentsOf: [p1, p2, p3])
            }
            
            // Close the loop
            let p0 = Int32(currentOffset + pointsPerSection - 1)
            let p1 = Int32(currentOffset + 0)
            let p2 = Int32(nextOffset + pointsPerSection - 1)
            let p3 = Int32(nextOffset + 0)
            
            indices.append(contentsOf: [p0, p2, p1])
            indices.append(contentsOf: [p1, p2, p3])
        }
        
        let normals = calculateNormals(vertices: vertices, indices: indices)
        
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        
        let geo = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red: 0.7, green: 0.7, blue: 0.8, alpha: 1.0)
        mat.metalness.contents = 0.5
        mat.roughness.contents = 0.3
        mat.isDoubleSided = true // Important for single-layer meshes
        geo.materials = [mat]
        
        return geo
    }

    static func calculateNormals(vertices: [SCNVector3], indices: [Int32]) -> [SCNVector3] {
        var normals = [SCNVector3](repeating: SCNVector3(0, 0, 0), count: vertices.count)

        for i in stride(from: 0, to: indices.count, by: 3) {
            let i0 = Int(indices[i])
            let i1 = Int(indices[i + 1])
            let i2 = Int(indices[i + 2])

            if i0 >= vertices.count || i1 >= vertices.count || i2 >= vertices.count { continue }

            let v0 = vertices[i0]
            let v1 = vertices[i1]
            let v2 = vertices[i2]

            let edge1 = SCNVector3(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z)
            let edge2 = SCNVector3(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z)

            let normal = SCNVector3(
                edge1.y * edge2.z - edge1.z * edge2.y,
                edge1.z * edge2.x - edge1.x * edge2.z,
                edge1.x * edge2.y - edge1.y * edge2.x
            )

            normals[i0] = SCNVector3(normals[i0].x + normal.x, normals[i0].y + normal.y, normals[i0].z + normal.z)
            normals[i1] = SCNVector3(normals[i1].x + normal.x, normals[i1].y + normal.y, normals[i1].z + normal.z)
            normals[i2] = SCNVector3(normals[i2].x + normal.x, normals[i2].y + normal.y, normals[i2].z + normal.z)
        }

        for i in 0..<normals.count {
            let n = normals[i]
            let length = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
            if length > 0.001 {
                normals[i] = SCNVector3(n.x / length, n.y / length, n.z / length)
            } else {
                normals[i] = SCNVector3(0, 1, 0)
            }
        }

        return normals
    }
}