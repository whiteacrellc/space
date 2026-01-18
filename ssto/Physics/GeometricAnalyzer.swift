//
//  GeometricAnalyzer.swift
//  ssto
//
//  Extracts aerodynamically relevant geometry from aircraft design
//  for use in panel method aerodynamic calculations.
//

import Foundation
import SceneKit
import simd

// MARK: - Data Structures

/// Location of a panel on the aircraft surface
enum PanelLocation {
    case upperSurface    // Top skin
    case lowerSurface    // Bottom skin
    case noseCap         // Front 5% of length
    case tailSection     // Aft 10% of length
    case leadingEdge     // Forward-facing vertical surfaces
}

/// Represents a discretized surface panel for aerodynamic calculations
struct SurfacePanel {
    let vertices: [SIMD3<Float>]     // Panel corner points (3 or 4 vertices)
    let normal: SIMD3<Float>         // Outward normal vector (unit length)
    let centroid: SIMD3<Float>       // Panel geometric center
    let area: Double                 // Panel area (m²)
    let location: PanelLocation      // Surface region classification

    /// Longitudinal position (0 = nose, 1 = tail)
    var longitudinalPosition: Float {
        return centroid.x / (vertices.map { $0.x }.max() ?? 1.0)
    }
}

/// Complete aerodynamic geometry description
struct AerodynamicGeometry {
    let panels: [SurfacePanel]           // Discretized mesh panels
    let finenessRatio: Double            // λ = L/√(4V/π)
    let thicknessRatio: Double           // Average t/c
    let aspectRatio: Double              // AR = b²/S_ref
    let wettedArea: Double               // Total wetted surface area (m²)
    let planformArea: Double             // Reference area S_ref (m²)
    let wingspan: Double                 // Wingspan b (m)
    let volumeDistribution: [Double]     // A(x) at 20 stations for area rule
    let leadingEdgeSweep: Double         // Λ_LE (degrees)
    let noseRadius: Double               // Nose tip radius (m)
    let lengthToDiameter: Double         // L/D_max
    let maxCrossSectionArea: Double      // A_max (m²)
    let aircraftLength: Double           // Total length (m)
}

// MARK: - Geometric Analyzer

class GeometricAnalyzer {

    // MARK: - Main Entry Point

    /// Analyze aerodynamic geometry from current design
    static func analyzeAerodynamicGeometry(
        planform: TopViewPlanform,
        profile: SideProfileShape,
        crossSection: CrossSectionPoints
    ) -> AerodynamicGeometry {

        // 1. Extract surface panels from mesh geometry
        let panels = extractPanelsFromDesign(
            planform: planform,
            profile: profile,
            crossSection: crossSection
        )

        // 2. Calculate geometric properties
        let properties = analyzeGeometricProperties(
            panels: panels,
            planform: planform,
            profile: profile
        )

        // 3. Compute volume distribution for area rule
        let volumeDist = computeVolumeDistribution(
            planform: planform,
            profile: profile,
            crossSection: crossSection
        )

        // 4. Assemble complete geometry
        return AerodynamicGeometry(
            panels: panels,
            finenessRatio: properties.finenessRatio,
            thicknessRatio: properties.thicknessRatio,
            aspectRatio: properties.aspectRatio,
            wettedArea: properties.wettedArea,
            planformArea: properties.planformArea,
            wingspan: properties.wingspan,
            volumeDistribution: volumeDist,
            leadingEdgeSweep: properties.leadingEdgeSweep,
            noseRadius: properties.noseRadius,
            lengthToDiameter: properties.lengthToDiameter,
            maxCrossSectionArea: properties.maxCrossSectionArea,
            aircraftLength: planform.aircraftLength
        )
    }

    // MARK: - Panel Extraction

    /// Extract discretized surface panels from design geometry
    private static func extractPanelsFromDesign(
        planform: TopViewPlanform,
        profile: SideProfileShape,
        crossSection: CrossSectionPoints
    ) -> [SurfacePanel] {

        var panels: [SurfacePanel] = []

        // Generate mesh ribs similar to AircraftVolumeModel
        let numRibs = 40  // 40 longitudinal sections → ~1200 panels
        let numCircumPoints = 30  // Points around circumference

        let startX = min(planform.noseTip.x, profile.frontStart.x)
        let endX = max(planform.tailLeft.x, profile.exhaustEnd.x)

        let aircraftLengthMeters = planform.aircraftLength
        let canvasLength = endX - startX
        let metersPerUnit = aircraftLengthMeters / canvasLength

        // Generate unit cross-section shape
        let unitShape = generateUnitCrossSection(from: crossSection, steps: numCircumPoints)

        // Generate ribs
        var ribs: [[SIMD3<Float>]] = []
        var ribX: [Float] = []  // Store X positions for classification

        for i in 0...numRibs {
            let t = Double(i) / Double(numRibs)
            let x = startX + t * (endX - startX)

            // Get dimensions at this station
            let halfWidth = getPlanformWidth(at: x, planform: planform)
            let (zTop, zBottom) = getProfileHeight(at: x, profile: profile)

            let height = max(0.1, zTop - zBottom)
            let zCenter = (zTop + zBottom) / 2.0
            let validHalfWidth = max(0.1, halfWidth)

            // Scale unit cross-section to actual dimensions
            var rib: [SIMD3<Float>] = []
            for unitPoint in unitShape {
                let finalY = Double(unitPoint.x) * validHalfWidth
                let finalZ = zCenter + (Double(unitPoint.y) * height / 2.0)

                let scaledPoint = SIMD3<Float>(
                    Float(x * metersPerUnit),
                    Float(finalY * metersPerUnit),
                    Float(finalZ * metersPerUnit)
                )
                rib.append(scaledPoint)
            }
            ribs.append(rib)
            ribX.append(Float(x * metersPerUnit))
        }

        let totalLength = Float(aircraftLengthMeters)

        // Create panels between adjacent ribs
        for i in 0..<ribs.count - 1 {
            let rib1 = ribs[i]
            let rib2 = ribs[i + 1]
            let xPos = ribX[i]

            // Classify panel location based on longitudinal position
            let longitudinalFrac = xPos / totalLength
            let isNose = longitudinalFrac < 0.05
            let isTail = longitudinalFrac > 0.90

            for j in 0..<rib1.count {
                let nextJ = (j + 1) % rib1.count

                // Quadrilateral panel vertices
                let v0 = rib1[j]
                let v1 = rib1[nextJ]
                let v2 = rib2[nextJ]
                let v3 = rib2[j]

                // Panel centroid
                let centroid = (v0 + v1 + v2 + v3) * 0.25

                // Calculate normal (cross product of diagonals)
                let diag1 = v2 - v0
                let diag2 = v3 - v1
                var normal = simd_cross(diag1, diag2)
                let normLen = simd_length(normal)
                if normLen > 0.001 {
                    normal = simd_normalize(normal)
                } else {
                    normal = SIMD3<Float>(0, 0, 1)  // Fallback
                }

                // Ensure outward normal (for lifting body, normal.z component indicates upper/lower)
                // Upper surface: normal.z > 0, Lower surface: normal.z < 0

                // Calculate area (quadrilateral area = 1/2 * |diag1 × diag2|)
                let area = Double(normLen) * 0.5

                // Classify panel location
                var location: PanelLocation
                if isNose {
                    location = .noseCap
                } else if isTail {
                    location = .tailSection
                } else {
                    // Check if upper or lower surface based on normal z-component
                    if normal.z > 0.2 {
                        location = .upperSurface
                    } else if normal.z < -0.2 {
                        location = .lowerSurface
                    } else {
                        // Near-vertical panel (leading edge region)
                        location = .leadingEdge
                    }
                }

                let panel = SurfacePanel(
                    vertices: [v0, v1, v2, v3],
                    normal: normal,
                    centroid: centroid,
                    area: area,
                    location: location
                )

                panels.append(panel)
            }
        }

        return panels
    }

    // MARK: - Geometric Property Analysis

    private struct GeometricProperties {
        let finenessRatio: Double
        let thicknessRatio: Double
        let aspectRatio: Double
        let wettedArea: Double
        let planformArea: Double
        let wingspan: Double
        let leadingEdgeSweep: Double
        let noseRadius: Double
        let lengthToDiameter: Double
        let maxCrossSectionArea: Double
    }

    /// Calculate geometric parameters from panels
    private static func analyzeGeometricProperties(
        panels: [SurfacePanel],
        planform: TopViewPlanform,
        profile: SideProfileShape
    ) -> GeometricProperties {

        let length = planform.aircraftLength

        // 1. Wetted Area (sum of all panel areas)
        let wettedArea = panels.reduce(0.0) { $0 + $1.area }

        // 2. Planform Area (projection onto XY plane - integrate only upper surfaces)
        var planformArea: Double = 0.0
        for panel in panels where panel.location == .upperSurface || panel.location == .noseCap {
            // Project panel area onto XY plane
            let projectedArea = panel.area * Double(abs(panel.normal.z))
            planformArea += projectedArea
        }

        // 3. Wingspan (maximum Y extent)
        var maxY: Float = 0.0
        for panel in panels {
            for vertex in panel.vertices {
                maxY = max(maxY, abs(vertex.y))
            }
        }
        let wingspan = Double(maxY) * 2.0  // Total span

        // 4. Aspect Ratio AR = b²/S
        let aspectRatio = (wingspan * wingspan) / max(1.0, planformArea)

        // 5. Volume (use AircraftVolumeModel calculation)
        let volume = AircraftVolumeModel.calculateInternalVolume()

        // 6. Fineness Ratio λ = L / √(4V/π)
        let equivalentDiameter = sqrt(4.0 * volume / .pi)
        let finenessRatio = length / max(0.1, equivalentDiameter)

        // 7. Thickness-to-Chord Ratio (average at several stations)
        var thicknessRatios: [Double] = []
        for longitudinalFrac in [0.25, 0.50, 0.75] {
            let targetX = Float(longitudinalFrac * length)

            // Find panels near this X station
            var maxHeight: Float = 0.0
            var maxWidth: Float = 0.0

            for panel in panels {
                if abs(panel.centroid.x - targetX) < Float(length * 0.05) {
                    maxHeight = max(maxHeight, abs(panel.centroid.z))
                    maxWidth = max(maxWidth, abs(panel.centroid.y))
                }
            }

            if maxWidth > 0.1 {
                let tc = Double(maxHeight * 2.0) / Double(maxWidth * 2.0)
                thicknessRatios.append(tc)
            }
        }
        let thicknessRatio = thicknessRatios.isEmpty ? 0.10 : thicknessRatios.reduce(0.0, +) / Double(thicknessRatios.count)

        // 8. Leading Edge Sweep (from planform geometry)
        let noseX = planform.noseTip.x
        let midX = planform.midLeft.x
        let midY = abs(planform.midLeft.y)
        let sweepAngle = atan2(midY, max(0.1, midX - noseX)) * 180.0 / .pi

        // 9. Nose Radius (approximate from front-most panels)
        var noseRadii: [Float] = []
        for panel in panels where panel.location == .noseCap {
            for vertex in panel.vertices {
                let radius = sqrt(vertex.y * vertex.y + vertex.z * vertex.z)
                noseRadii.append(radius)
            }
        }
        let noseRadius = noseRadii.isEmpty ? 0.5 : Double(noseRadii.reduce(0.0, +) / Float(noseRadii.count))

        // 10. Maximum Cross-Section Area (from volume distribution)
        let volumeDist = computeVolumeDistribution(planform: planform, profile: profile, crossSection: GameManager.shared.getCrossSectionPoints())
        let maxCrossSectionArea = volumeDist.max() ?? 1.0

        // 11. Length-to-Diameter Ratio
        let maxDiameter = sqrt(maxCrossSectionArea / .pi) * 2.0
        let lengthToDiameter = length / max(0.1, maxDiameter)

        return GeometricProperties(
            finenessRatio: finenessRatio,
            thicknessRatio: thicknessRatio,
            aspectRatio: aspectRatio,
            wettedArea: wettedArea,
            planformArea: planformArea,
            wingspan: wingspan,
            leadingEdgeSweep: sweepAngle,
            noseRadius: noseRadius,
            lengthToDiameter: lengthToDiameter,
            maxCrossSectionArea: maxCrossSectionArea
        )
    }

    // MARK: - Volume Distribution (Area Rule)

    /// Compute cross-sectional area distribution A(x) for area rule analysis
    static func computeVolumeDistribution(
        planform: TopViewPlanform,
        profile: SideProfileShape,
        crossSection: CrossSectionPoints
    ) -> [Double] {

        let numStations = 20
        var areaDistribution: [Double] = []

        let startX = min(planform.noseTip.x, profile.frontStart.x)
        let endX = max(planform.tailLeft.x, profile.exhaustEnd.x)
        let aircraftLengthMeters = planform.aircraftLength
        let canvasLength = endX - startX
        let metersPerUnit = aircraftLengthMeters / canvasLength

        let unitShape = generateUnitCrossSection(from: crossSection, steps: 10)

        for i in 0...numStations {
            let t = Double(i) / Double(numStations)
            let x = startX + t * (endX - startX)

            // Get dimensions at this station
            let halfWidth = getPlanformWidth(at: x, planform: planform)
            let (zTop, zBottom) = getProfileHeight(at: x, profile: profile)

            let height = max(0.1, zTop - zBottom)
            let validHalfWidth = max(0.1, halfWidth)

            // Scale unit cross-section
            var sectionPoints: [SIMD2<Float>] = []
            for unitPoint in unitShape {
                let y = Float(Double(unitPoint.x) * validHalfWidth * metersPerUnit)
                let z = Float(Double(unitPoint.y) * height * 0.5 * metersPerUnit)
                sectionPoints.append(SIMD2<Float>(y, z))
            }

            // Calculate cross-sectional area using shoelace formula
            var area: Double = 0.0
            for j in 0..<sectionPoints.count {
                let p1 = sectionPoints[j]
                let p2 = sectionPoints[(j + 1) % sectionPoints.count]
                area += Double(p1.x * p2.y - p2.x * p1.y)
            }
            area = abs(area) * 0.5

            areaDistribution.append(area)
        }

        return areaDistribution
    }

    // MARK: - Helper Functions (Similar to AircraftVolumeModel)

    /// Generate unit cross-section from spline points
    private static func generateUnitCrossSection(from crossSection: CrossSectionPoints, steps: Int) -> [SCNVector3] {
        var points: [SCNVector3] = []

        let topCG = crossSection.topPoints.map { $0.toCGPoint() }
        let bottomCG = crossSection.bottomPoints.map { $0.toCGPoint() }

        let minX = topCG.first?.x ?? 0
        let maxX = topCG.last?.x ?? 800
        let width = max(1.0, maxX - minX)
        let centerY: CGFloat = 250

        // Top surface
        for i in 0..<steps {
            let t = CGFloat(i) / CGFloat(steps - 1)
            let x = minX + t * width
            let y = interpolateSplineY(x: x, points: topCG)

            let nx = Float((t - 0.5) * 2.0)  // -1 to 1
            let ny = Float((y - centerY) / width)
            points.append(SCNVector3(nx, ny, 0))
        }

        // Bottom surface (reversed)
        for i in (0..<steps).reversed() {
            let t = CGFloat(i) / CGFloat(steps - 1)
            let x = minX + t * width
            let y = interpolateSplineY(x: x, points: bottomCG)

            let nx = Float((t - 0.5) * 2.0)
            let ny = Float((y - centerY) / width)
            points.append(SCNVector3(nx, ny, 0))
        }

        return points
    }

    /// Interpolate spline Y coordinate
    private static func interpolateSplineY(x: CGFloat, points: [CGPoint]) -> CGFloat {
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

    /// Get planform width at X
    private static func getPlanformWidth(at x: Double, planform: TopViewPlanform) -> Double {
        // Use LiftingBodyEngine's logic
        return Double(LiftingBodyEngine.getTopViewWidthAt(x: CGFloat(x), planform: planform))
    }

    /// Get profile height at X
    private static func getProfileHeight(at x: Double, profile: SideProfileShape) -> (top: Double, bottom: Double) {
        let (top, bottom) = LiftingBodyEngine.getSideProfileYAt(x: CGFloat(x), profile: profile)
        return (Double(top), Double(bottom))
    }
}
