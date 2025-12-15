import Foundation
import SceneKit
import CoreGraphics

/**
 A Swift module for calculating aerodynamic properties, specifically the Drag Coefficient (Cd),
 for an aircraft at various flight regimes.

 The calculation relies on a simplified International Standard Atmosphere (ISA) model to determine
 air density and speed of sound at the given altitude, and a piecewise function to estimate Cd
 based on the resultant Mach number and altitude.

 Assumptions:
 - Altitude is in meters (m).
 - Velocity is in meters per second (m/s).
 - The drag coefficient is estimated for a streamlined aircraft across different Mach regimes.
 */
class DragCalculator {

    // Aircraft characteristics
    private var projectedArea: Double = 0.0
    private let baselineDragCoefficient: Double
    private let planeDesign: PlaneDesign

    init(baselineDragCoefficient: Double = 0.045, // Streamlined Airfoil shape estimate
         planeDesign: PlaneDesign = PlaneDesign.defaultDesign) {
        self.baselineDragCoefficient = baselineDragCoefficient
        self.planeDesign = planeDesign
        self.projectedArea = calculateProjectedArea()
        print("DragCalculator initialized with Projected Frontal Area: \(String(format: "%.2f", projectedArea)) m²")
    }
    
    // MARK: - Drag Calculation
    
    /**
     Calculate drag force acting on the aircraft.

     Uses accurate Mach-dependent drag coefficients and atmospheric models.

     - Parameters:
       - altitude: Altitude in meters
       - velocity: Velocity in meters per second
     - Returns: Drag force in Newtons
     */
    func calculateDrag(altitude: Double, velocity: Double) -> Double {
        guard altitude >= 0, velocity >= 0 else {
            return 0.0
        }

        // Get atmospheric data from AtmosphereModel
        let density = AtmosphereModel.atmosphericDensity(at: altitude)
        let speedOfSound = AtmosphereModel.speedOfSound(at: altitude)

        // Calculate Mach number
        let mach = velocity / speedOfSound

        // Get drag coefficient for current conditions
        let cd = getDragCoefficient(Ma: mach, altitude_m: altitude)

        // Calculate drag force: F_drag = 0.5 * ρ * v² * C_d * A
        let dragForce = 0.5 * density * velocity * velocity * cd * projectedArea

        return dragForce
    }

    /**
     Get the drag coefficient at specified Mach number and altitude.

     - Parameters:
       - mach: Mach number
       - altitude: Altitude in meters
     - Returns: Drag coefficient (Cd)
     */
    func getCd(mach: Double, altitude: Double) -> Double {
        return getDragCoefficient(Ma: mach, altitude_m: altitude)
    }

    /**
     Estimates the Drag Coefficient (Cd) of a streamlined aircraft based on Mach number and altitude.

     Aircraft drag varies significantly across flight regimes, with transonic drag rise
     being particularly important for reaching orbit.

     - Parameters:
       - Ma: The Mach number (velocity / speed of sound).
       - altitude_m: Altitude in meters
     - Returns: The estimated Drag Coefficient (unitless).
     */
    private func getDragCoefficient(Ma: Double, altitude_m: Double) -> Double {
        var cd = baselineDragCoefficient

        if Ma < 0.8 {
            // Subsonic flow: Low drag for streamlined aircraft
            cd = baselineDragCoefficient * 1.0

        } else if Ma < 1.2 {
            // Transonic flow (0.8 <= Ma < 1.2): Dramatic drag rise
            // Wave drag begins, shock waves form
            let delta = Ma - 0.8
            let dragRiseMultiplier = 1.0 + delta * delta * 15.0
            cd = baselineDragCoefficient * dragRiseMultiplier

        } else if Ma < 5.0 {
            // Supersonic flow (Ma >= 1.2): High wave drag, decreases with Mach
            // Peak drag just past Mach 1, then gradually decreases
            let supersonicFactor = 1.2 / Ma
            let waveDragMultiplier = 5.0 + supersonicFactor * 4.0
            cd = baselineDragCoefficient * waveDragMultiplier

        } else {
            // Hypersonic flow (Ma >= 5.0): Drag Coefficient decreases asymptotically
            // At high Mach, wave drag coefficient decreases (roughly 1/M^2 trend),
            // but viscous interaction increases.
            // We model a decay from the supersonic level (~6.0) down to a high-speed floor (~2.5).
            let decay = exp(-(Ma - 5.0) / 10.0)
            cd = baselineDragCoefficient * (2.5 + 3.5 * decay)
        }

        // Altitude effects: rarefied flow at extreme altitudes
        cd *= getAltitudeFactor(altitude_m: altitude_m)

        // Apply plane design drag multiplier
        cd *= planeDesign.dragMultiplier()

        return cd
    }

    /**
     Calculate altitude correction factor for drag coefficient.
     At extreme altitudes, rarefied flow changes drag characteristics.

     - Parameter altitude_m: Altitude in meters
     - Returns: Correction factor (0.0 to 1.0+)
     */
    private func getAltitudeFactor(altitude_m: Double) -> Double {
        if altitude_m < 15000 {
            // Dense atmosphere: normal drag
            return 1.0
        } else if altitude_m < 30000 {
            // Upper atmosphere: slight decrease
            let transitionFactor = (altitude_m - 15000) / 15000
            return 1.0 - transitionFactor * 0.05
        } else if altitude_m < 60000 {
            // Very high altitude: rarefied flow begins
            let rarefiedFactor = (altitude_m - 30000) / 30000
            return 0.95 - rarefiedFactor * 0.2
        } else {
            // Near-vacuum: minimal drag
            return 0.75 * exp(-(altitude_m - 60000) / 30000)
        }
    }
    
    /**
     Get diagnostic information about current flight regime.

     - Parameters:
       - velocity: Velocity in meters per second
       - altitude: Altitude in meters
     - Returns: String describing the current regime
     */
    func getDragRegime(velocity: Double, altitude: Double) -> String {
        let speedOfSound = AtmosphereModel.speedOfSound(at: altitude)
        let mach = velocity / speedOfSound

        let regime: String
        if mach < 0.8 {
            regime = "Subsonic"
        } else if mach < 1.2 {
            regime = "Transonic (High Drag)"
        } else if mach < 5.0 {
            regime = "Supersonic"
        } else {
            regime = "Hypersonic"
        }

        let altitudeKm = altitude / 1000.0
        return "\(regime) at \(String(format: "%.1f", altitudeKm)) km"
    }
    
    // MARK: - Wireframe & Projected Area Calculation
    
    /// Calculate the Projected Frontal Area using the wireframe approximation method.
    /// This replicates the logic from WireframeViewController to generate the mesh,
    /// then calculates the area of forward-facing surfaces (Cosine Projection).
    private func calculateProjectedArea() -> Double {
        // 1. Get Data from GameManager
        let profile = GameManager.shared.getSideProfile()
        let planform = GameManager.shared.getTopViewPlanform()
        let crossSection = GameManager.shared.getCrossSectionPoints()
        
        // 2. Prepare Unit Cross Section (Normalized to [-1, 1] range)
        let unitShape = generateUnitCrossSection(from: crossSection, steps: 5)
        
        // 3. Generate Mesh Points
        var meshPoints: [[SCNVector3]] = []
        let numRibs = 40
        
        // Determine X bounds
        let startX = min(planform.noseTip.x, profile.frontStart.x)
        let endX = max(planform.tailLeft.x, profile.exhaustEnd.x)
        
        // Conversion factor from canvas units to meters
        // Aircraft length is defined in TopViewPlanform
        let aircraftLengthMeters = planform.aircraftLength
        let canvasLength = endX - startX
        let metersPerUnit = aircraftLengthMeters / canvasLength
        
        for i in 0...numRibs {
            let t = Double(i) / Double(numRibs)
            let x = startX + t * (endX - startX)
            
            // Get Dimensions at X
            let halfWidth = getPlanformWidth(at: x, planform: planform)
            let (zTop, zBottom) = getProfileHeight(at: x, profile: profile)
            
            let height = max(0.1, zTop - zBottom)
            let zCenter = (zTop + zBottom) / 2.0
            let validHalfWidth = max(0.1, halfWidth)
            
            var ribPoints: [SCNVector3] = []
            for unitPoint in unitShape {
                let finalY = unitPoint.x * validHalfWidth
                let finalZ = zCenter + (unitPoint.y * height / 2.0)
                
                // Scale to meters immediately for accurate area
                ribPoints.append(SCNVector3(
                    Float(x * metersPerUnit),
                    Float(finalY * metersPerUnit),
                    Float(finalZ * metersPerUnit)
                ))
            }
            meshPoints.append(ribPoints)
        }
        
        // 4. Calculate Projected Frontal Area
        // Sum of (Area * Normal.x) for all forward-facing triangles
        // Flow direction is assumed -X (aircraft moving +X), so forward faces have Normal.x > 0
        
        var totalProjectedArea: Double = 0.0
        
        for i in 0..<meshPoints.count - 1 {
            let currentRib = meshPoints[i]
            let nextRib = meshPoints[i+1]
            
            // Iterate around the rib loop
            for j in 0..<currentRib.count {
                let currentIdx = j
                let nextIdx = (j + 1) % currentRib.count
                
                // Quad vertices
                let p0 = currentRib[currentIdx]
                let p1 = nextRib[currentIdx]
                let p2 = nextRib[nextIdx]
                let p3 = currentRib[nextIdx]
                
                // Decompose into two triangles: (p0, p1, p2) and (p0, p2, p3)
                // Ensure counter-clockwise winding (looking from outside)
                // Ribs are generated sequentially along X.
                // p0->p3 is along current rib. p1->p2 is along next rib.
                // p0->p1 is along stringer.
                
                totalProjectedArea += calculateTriangleProjectedArea(v0: p0, v1: p1, v2: p2)
                totalProjectedArea += calculateTriangleProjectedArea(v0: p0, v1: p2, v2: p3)
            }
        }
        
        // The mesh is hollow (no end caps), but for a closed fuselage, the caps are usually negligible
        // or effectively zero if tapered to a point.
        // We take the absolute value as a safeguard, but strictly we summed N.x * Area
        return abs(totalProjectedArea)
    }
    
    private func calculateTriangleProjectedArea(v0: SCNVector3, v1: SCNVector3, v2: SCNVector3) -> Double {
        // Calculate Normal
        // Edge vectors
        let e1 = SCNVector3(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z)
        let e2 = SCNVector3(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z)
        
        // Cross product: N = e1 x e2
        let normal = SCNVector3(
            e1.y * e2.z - e1.z * e2.y,
            e1.z * e2.x - e1.x * e2.z,
            e1.x * e2.y - e1.y * e2.x
        )
        
        // Area of triangle = 0.5 * |N|
        // Projected Area = Area * (UnitNormal . X_axis)
        //                = 0.5 * |N| * (N.x / |N|)
        //                = 0.5 * N.x
        
        // We only want forward-facing surfaces (Normal.x > 0)
        if normal.x > 0 {
            return Double(0.5 * normal.x)
        }
        return 0.0
    }
    
    // MARK: - Geometry Helpers (Ported from WireframeViewController)

    private func generateUnitCrossSection(from crossSection: CrossSectionPoints, steps: Int) -> [CGPoint] {
        var unitShape: [CGPoint] = []
        let topCurve = interpolateSpline(points: crossSection.topPoints.map { $0.toCGPoint() }, steps: steps)
        let bottomCurve = interpolateSpline(points: crossSection.bottomPoints.map { $0.toCGPoint() }, steps: steps).reversed()

        let allPoints = topCurve + bottomCurve
        let minX = allPoints.map { $0.x }.min() ?? 0
        let maxX = allPoints.map { $0.x }.max() ?? 1
        let minY = allPoints.map { $0.y }.min() ?? 0
        let maxY = allPoints.map { $0.y }.max() ?? 1

        let rangeX = max(maxX - minX, 1)
        let rangeY = max(maxY - minY, 1)
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        for point in topCurve {
            let normalizedX = (point.x - centerX) / rangeX * 2.0
            let normalizedY = (point.y - centerY) / rangeY * 2.0
            unitShape.append(CGPoint(x: normalizedX, y: normalizedY))
        }
        for point in bottomCurve {
            let normalizedX = (point.x - centerX) / rangeX * 2.0
            let normalizedY = (point.y - centerY) / rangeY * 2.0
            unitShape.append(CGPoint(x: normalizedX, y: normalizedY))
        }
        return unitShape
    }

    private func interpolateSpline(points: [CGPoint], steps: Int) -> [CGPoint] {
        guard points.count >= 2 else { return points }
        var result: [CGPoint] = []
        for i in 0..<points.count - 1 {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            let (cp1, cp2) = SplineCalculator.calculateControlPoints(p0: p0, p1: p1, p2: p2, p3: p3)
            for t in 0..<steps {
                let u = CGFloat(t) / CGFloat(steps)
                result.append(cubicBezier(t: u, p0: p1, p1: cp1, p2: cp2, p3: p2))
            }
        }
        result.append(points.last!)
        return result
    }

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

    private func getPlanformWidth(at x: Double, planform: TopViewPlanform) -> Double {
        let noseTip = planform.noseTip.toCGPoint()
        let frontControlLeft = planform.frontControlLeft.toCGPoint()
        let midLeft = planform.midLeft.toCGPoint()
        let rearControlLeft = planform.rearControlLeft.toCGPoint()
        let tailLeft = planform.tailLeft.toCGPoint()

        if x <= midLeft.x {
            let y = interpolatePlanformBezierY(x: CGFloat(x), p0: noseTip, p1: frontControlLeft, p2: midLeft)
            return abs(y)
        } else if x <= tailLeft.x {
            let y = interpolatePlanformBezierY(x: CGFloat(x), p0: midLeft, p1: rearControlLeft, p2: tailLeft)
            return abs(y)
        } else {
            return abs(tailLeft.y)
        }
    }

    private func interpolatePlanformBezierY(x: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        var tMin: CGFloat = 0.0
        var tMax: CGFloat = 1.0
        var t: CGFloat = 0.5
        for _ in 0..<20 {
            let currentX = (1-t)*(1-t)*p0.x + 2*(1-t)*t*p1.x + t*t*p2.x
            if abs(currentX - x) < 0.1 { break }
            if currentX < x { tMin = t } else { tMax = t }
            t = (tMin + tMax) / 2
        }
        return (1-t)*(1-t)*p0.y + 2*(1-t)*t*p1.y + t*t*p2.y
    }

    private func getProfileHeight(at x: Double, profile: SideProfileShape) -> (Double, Double) {
        let bottomZ: Double
        let frontStart = profile.frontStart.toCGPoint()
        let frontControl = profile.frontControl.toCGPoint()
        let frontEnd = profile.frontEnd.toCGPoint()
        let engineEnd = profile.engineEnd.toCGPoint()
        let exhaustControl = profile.exhaustControl.toCGPoint()
        let exhaustEnd = profile.exhaustEnd.toCGPoint()

        if x <= frontEnd.x {
            let t = (x - frontStart.x) / (frontEnd.x - frontStart.x)
            bottomZ = solveQuadraticBezierY(t: max(0, min(1, t)), p0: frontStart, p1: frontControl, p2: frontEnd)
        } else if x <= engineEnd.x {
            bottomZ = frontEnd.y
        } else {
            let t = (x - engineEnd.x) / (exhaustEnd.x - engineEnd.x)
            bottomZ = solveQuadraticBezierY(t: max(0, min(1, t)), p0: engineEnd, p1: exhaustControl, p2: exhaustEnd)
        }

        let topStart = profile.topStart.toCGPoint()
        let topControl = profile.topControl.toCGPoint()
        let topEnd = profile.topEnd.toCGPoint()
        let tTop = (x - topStart.x) / (topEnd.x - topStart.x)
        let topZ = solveQuadraticBezierY(t: max(0, min(1, tTop)), p0: topStart, p1: topControl, p2: topEnd)

        return (topZ, bottomZ)
    }

    private func solveQuadraticBezierY(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> Double {
        let u = 1 - t
        return u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
    }
}