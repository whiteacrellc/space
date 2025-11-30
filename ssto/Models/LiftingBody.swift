import SwiftUI
import SceneKit
import ModelIO
import SceneKit.ModelIO

// MARK: - Geometry Engine

/// Represents a 2D airfoil cross-section
struct AirfoilSection {
    let centerX: Float      // Longitudinal position along aircraft
    let centerY: Float      // Vertical position
    let centerZ: Float      // Lateral position
    let chord: Float        // Chord length of this section
    let thickness: Float    // Maximum thickness ratio (as fraction of chord)
    let scale: Float        // Overall scaling factor
}

/// Represents a point on an airfoil profile
struct AirfoilPoint {
    let x: Float  // Chordwise position (0 to 1)
    let y: Float  // Vertical offset from chord line
}

class LiftingBodyEngine {

    // MARK: - Aircraft Dimensions
    static let aircraftLength: Float = 100.0  // meters minimum length
    static let maxWidth: Float = 300.0        // meters at widest point

    // MARK: - Payload Box Constraints
    static let payloadWidth: Float = 8.0    // meters
    static let payloadHeight: Float = 8.0   // meters
    static let payloadLength: Float = 16.0  // meters

    /// Generates the lifting body geometry based on the provided parameters.
    static func generateGeometry(
        coneAngle: Double,
        sweepAngle: Double,
        tiltAngle: Double,
        flatTopPct: Double = 70,
        heightFactor: Double = 10,
        slopeCurve: Double = 1.5
    ) -> SCNGeometry {

        // Convert angles to radians
        let alpha = Float(coneAngle) * (Float.pi / 180.0)
        let sweepRad = Float(sweepAngle) * (Float.pi / 180.0)
        let tiltRad = Float(tiltAngle) * (Float.pi / 180.0)

        print("Generating geometry: coneAngle=\(coneAngle)°, sweepAngle=\(sweepAngle)°, tiltAngle=\(tiltAngle)°")

        // Define cross-sections along the length
        let sections = generateCrossSections(
            coneAngle: alpha,
            sweepAngle: sweepRad,
            tiltAngle: tiltRad
        )

        // Generate mesh from cross-sections using NURBS-like interpolation
        return generateMeshFromSections(sections: sections)
    }

    // MARK: - Spline Cross-Section Generation

    /// Generate cross-section profile from spline control points
    /// Uses the spline shape defined in the LiftingBodyDesigner
    static func generateCrossSectionFromSpline(
        crossSectionPoints: CrossSectionPoints,
        numSamples: Int = 60
    ) -> [AirfoilPoint] {

        var points: [AirfoilPoint] = []

        // Canvas dimensions from SplineCalculator
        let canvasHeight: CGFloat = 500.0
        let centerY: CGFloat = 250.0  // Centerline from SplineCalculator

        // Convert SerializablePoints to CGPoints
        let topCGPoints = crossSectionPoints.topPoints.map { $0.toCGPoint() }
        let bottomCGPoints = crossSectionPoints.bottomPoints.map { $0.toCGPoint() }

        // Find X extent
        let allX = topCGPoints.map { $0.x } + bottomCGPoints.map { $0.x }
        let minX = allX.min() ?? 100.0
        let maxX = allX.max() ?? 700.0
        let xRange = maxX - minX

        // Sample the top spline
        var topSamples: [(x: Float, y: Float)] = []
        for i in 0..<numSamples {
            let t = CGFloat(i) / CGFloat(numSamples - 1)
            let x = minX + t * xRange

            // Find closest point on top spline
            let yValue = interpolateSpline(points: topCGPoints, atX: x)

            // Normalize: x from 0 to 1, y centered around 0
            let normalizedX = Float((x - minX) / xRange)
            let normalizedY = Float((yValue - centerY) / canvasHeight) * 2.0  // Scale to reasonable range

            topSamples.append((x: normalizedX, y: normalizedY))
        }

        // Sample the bottom spline
        var bottomSamples: [(x: Float, y: Float)] = []
        for i in 0..<numSamples {
            let t = CGFloat(i) / CGFloat(numSamples - 1)
            let x = minX + t * xRange

            // Find closest point on bottom spline
            let yValue = interpolateSpline(points: bottomCGPoints, atX: x)

            // Normalize: x from 0 to 1, y centered around 0
            let normalizedX = Float((x - minX) / xRange)
            let normalizedY = Float((yValue - centerY) / canvasHeight) * 2.0  // Scale to reasonable range

            bottomSamples.append((x: normalizedX, y: normalizedY))
        }

        // Create closed contour: top surface (LE to TE) then bottom surface (TE to LE)
        for sample in topSamples {
            points.append(AirfoilPoint(x: sample.x, y: sample.y))
        }

        for sample in bottomSamples.reversed() {
            points.append(AirfoilPoint(x: sample.x, y: sample.y))
        }

        return points
    }

    /// Simple linear interpolation to find Y value at a given X on a spline
    static func interpolateSpline(points: [CGPoint], atX targetX: CGFloat) -> CGFloat {
        // Find the two points that bracket targetX
        var closestBefore: CGPoint?
        var closestAfter: CGPoint?

        for point in points {
            if point.x <= targetX {
                if closestBefore == nil || point.x > closestBefore!.x {
                    closestBefore = point
                }
            }
            if point.x >= targetX {
                if closestAfter == nil || point.x < closestAfter!.x {
                    closestAfter = point
                }
            }
        }

        // Linear interpolation
        if let before = closestBefore, let after = closestAfter {
            if abs(after.x - before.x) < 0.001 {
                return before.y
            }
            let t = (targetX - before.x) / (after.x - before.x)
            return before.y + t * (after.y - before.y)
        } else if let before = closestBefore {
            return before.y
        } else if let after = closestAfter {
            return after.y
        }

        return 250.0  // Default centerline
    }

    // MARK: - Cross-Section Generation

    /// Generate cross-sections along the aircraft length
    /// Leading edge defined by cone-plane intersection
    /// Apex at (0,0,0), symmetric in y
    static func generateCrossSections(
        coneAngle: Float,
        sweepAngle: Float,
        tiltAngle: Float
    ) -> [AirfoilSection] {

        var sections: [AirfoilSection] = []

        let numSections = 60

        // Calculate plane normal vector from sweep and tilt angles
        // This matches the design screen's cone-plane intersection calculation
        let nx = cos(sweepAngle) * cos(tiltAngle)
        let ny = sin(sweepAngle) * cos(tiltAngle)
        let nz = sin(tiltAngle)

        // Plane passes through the midpoint of the cone by default
        // This can be adjusted with the position parameter in the future
        let planeX = aircraftLength / 2.0

        // Sample the cone-plane intersection to get the actual leading edge curve
        // The intersection creates the planform shape (triangle, ellipse, etc.)
        var leadingEdgePoints: [(x: Float, y: Float, z: Float)] = []
        let numSamples = 200

        for i in 0..<numSamples {
            let theta = Float(i) * 2.0 * Float.pi / Float(numSamples)
            let cosTheta = cos(theta)
            let sinTheta = sin(theta)

            // Solve for x where plane intersects cone surface at this angle
            // Plane: nx*x + ny*y + nz*z = nx*planeX
            // Cone: y = r*cos(θ), z = r*sin(θ), r = x*tan(coneAngle)
            let denominator = nx + ny * tan(coneAngle) * cosTheta + nz * tan(coneAngle) * sinTheta

            if abs(denominator) > 0.001 {
                let x = nx * planeX / denominator
                if x >= 0 && x <= aircraftLength {
                    let r = x * tan(coneAngle)
                    let y = r * cosTheta
                    let z = r * sinTheta
                    leadingEdgePoints.append((x: x, y: y, z: z))
                }
            }
        }

        if leadingEdgePoints.isEmpty {
            print("ERROR: No leading edge points found!")
            return sections
        }

        // Find the x-extent of the intersection
        let minX = leadingEdgePoints.map { $0.x }.min() ?? 0
        let maxX = leadingEdgePoints.map { $0.x }.max() ?? aircraftLength

        print("Cone-plane intersection: minX=\(minX), maxX=\(maxX), range=\(maxX - minX)")
        print("Leading edge points: \(leadingEdgePoints.count)")

        // Now create sections along the x-axis
        for i in 0...numSections {
            let t = Float(i) / Float(numSections)  // 0 to 1
            let x = minX + t * (maxX - minX)

            // Find all leading edge points at this x position
            let tolerance: Float = (maxX - minX) / Float(numSections * 2)
            let pointsAtX = leadingEdgePoints.filter { abs($0.x - x) < tolerance }

            if pointsAtX.isEmpty {
                continue
            }

            // Calculate the span (width in Y direction) at this X from leading edge
            let yValues = pointsAtX.map { $0.y }
            let halfSpan = max(abs(yValues.min() ?? 0), abs(yValues.max() ?? 0))

            // Ensure minimum span to fit cargo box (8m width needed at payload region)
            let payloadStart: Float = 30.0
            let payloadEnd: Float = 50.0
            var requiredHalfSpan = halfSpan

            if x >= payloadStart && x <= payloadEnd {
                // Payload region needs at least 4m half-span (8m total)
                requiredHalfSpan = max(halfSpan, 8.0)
            }

            // Cap at max width
            let actualHalfSpan = min(requiredHalfSpan, maxWidth / 2.0)

            // Calculate maximum height at centerline for this X position
            // Payload region needs 8m height, taper elsewhere
            var centerlineHeight: Float
            if x >= payloadStart && x <= payloadEnd {
                // Payload region: ensure 8m height for cargo box
                centerlineHeight = 10.0  // A bit more than 8m for clearance
            } else if x < payloadStart {
                // Forward taper
                let t = x / payloadStart
                centerlineHeight = 1.0 + (10.0 - 1.0) * t
            } else {
                // Aft taper
                let dist = x - payloadEnd
                let totalAftDist = maxX - payloadEnd
                let t = 1.0 - (dist / totalAftDist)
                centerlineHeight = 1.0 + (10.0 - 1.0) * t
            }

            // Store section data
            // chord = span (Y width), thickness = not used (we'll use airfoil design directly)
            // scale = centerline height
            let section = AirfoilSection(
                centerX: x,
                centerY: 0,
                centerZ: 0,  // Centerline at Z=0
                chord: actualHalfSpan * 2.0,  // Full span width
                thickness: 0.12,  // Not used anymore
                scale: centerlineHeight  // Maximum height at centerline
            )

            sections.append(section)
        }

        return sections
    }

    /// Calculate height at longitudinal position x
    /// Height accommodates payload in center section
    static func calculateHeightAtPosition(
        x: Float,
        halfWidth: Float
    ) -> Float {

        // Payload region (middle section) needs 8m height
        let payloadStart: Float = 30.0  // Start payload region at x=30m
        let payloadEnd: Float = 50.0    // End payload region at x=50m

        var height: Float

        if x >= payloadStart && x <= payloadEnd {
            // Payload region - constant height to fit 8m payload
            height = payloadHeight
        } else if x < payloadStart {
            // Forward section - taper from payload height to thinner nose
            if x < 0.1 {
                // Very nose - minimal height
                height = 0.3
            } else {
                let t = x / payloadStart
                // Smooth taper
                height = 0.3 + (payloadHeight - 0.3) * pow(t, 1.2)
            }
        } else {
            // Aft section - taper from payload height to thinner tail
            let dist = x - payloadEnd
            let totalAftDist = aircraftLength - payloadEnd
            let t = 1.0 - (dist / totalAftDist)
            // Smooth taper to trailing edge
            height = 0.5 + (payloadHeight - 0.5) * pow(t, 1.5)
        }

        // Also scale height based on width (narrower = thinner)
        // Near leading edge (small width), reduce height
        let widthFactor = min(1.0, halfWidth / 50.0)  // Full height at 50m+ half-width
        height *= widthFactor

        return max(0.3, height)
    }

    // MARK: - Mesh Generation with NURBS-like Interpolation

    /// Generate mesh from cross-sections using smooth interpolation
    static func generateMeshFromSections(sections: [AirfoilSection]) -> SCNGeometry {

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []

        // Retrieve cross-section spline points from GameManager
        let crossSectionPoints = GameManager.shared.getCrossSectionPoints()

        let spanwisePoints = 40   // Points across the span (Y direction)
        let airfoilPoints = 30    // Points defining cross-section profile (for Z direction)

        // Generate the base cross-section shape once (this defines vertical profile)
        let baseAirfoil = generateCrossSectionFromSpline(crossSectionPoints: crossSectionPoints, numSamples: airfoilPoints)

        print("Using custom spline cross-section with \(crossSectionPoints.topPoints.count) top points, \(crossSectionPoints.bottomPoints.count) bottom points")

        // Generate vertices for each longitudinal cross-section
        for (_, section) in sections.enumerated() {
            // At this X position, create vertices across the span
            // The height tapers from centerline to wingtips

            let halfSpan = section.chord / 2.0  // Maximum Y extent at this X station
            let centerlineHeight = section.scale  // Maximum height at Y=0
            let wingtipHeight: Float = 0.25  // Height at maximum Y (wingtips)

            for spanIdx in 0..<spanwisePoints {
                // Spanwise position from -halfSpan to +halfSpan
                let spanFraction = Float(spanIdx) / Float(spanwisePoints - 1)  // 0 to 1
                let yPos = (spanFraction - 0.5) * section.chord  // -halfSpan to +halfSpan

                // Calculate height scaling at this spanwise position
                // Taper from centerlineHeight at Y=0 to wingtipHeight at Y=±halfSpan
                let spanRatio = abs(yPos) / halfSpan  // 0 at center, 1 at tips
                let heightAtThisY = centerlineHeight * (1.0 - spanRatio) + wingtipHeight * spanRatio

                // For each spanwise position, create airfoil profile in Z direction
                for airfoilIdx in 0..<airfoilPoints {
                    let t = Float(airfoilIdx) / Float(airfoilPoints - 1)  // 0 to 1

                    // Sample airfoil at this chordwise position
                    let sampleIdx = Int(t * Float(baseAirfoil.count - 1))
                    let airfoilPoint = baseAirfoil[min(sampleIdx, baseAirfoil.count - 1)]

                    // Scale airfoil y-coordinate to actual height at this spanwise position
                    let zPos = section.centerZ + airfoilPoint.y * heightAtThisY

                    let vertex = SCNVector3(
                        section.centerX,  // Longitudinal (along fuselage)
                        yPos,              // Spanwise (width)
                        zPos               // Vertical (height from airfoil, tapered)
                    )

                    vertices.append(vertex)
                }
            }
        }

        // Generate indices to connect the grid
        let pointsPerSection = spanwisePoints * airfoilPoints

        for sectionIdx in 0..<(sections.count - 1) {
            let currentSectionStart = sectionIdx * pointsPerSection
            let nextSectionStart = (sectionIdx + 1) * pointsPerSection

            // Connect vertices between adjacent sections
            for spanIdx in 0..<(spanwisePoints - 1) {
                for airfoilIdx in 0..<(airfoilPoints - 1) {
                    // Four corners of current quad
                    let i0 = currentSectionStart + spanIdx * airfoilPoints + airfoilIdx
                    let i1 = currentSectionStart + spanIdx * airfoilPoints + (airfoilIdx + 1)
                    let i2 = currentSectionStart + (spanIdx + 1) * airfoilPoints + airfoilIdx
                    let i3 = currentSectionStart + (spanIdx + 1) * airfoilPoints + (airfoilIdx + 1)

                    // Four corners of next section's quad
                    let i4 = nextSectionStart + spanIdx * airfoilPoints + airfoilIdx
                    let i5 = nextSectionStart + spanIdx * airfoilPoints + (airfoilIdx + 1)
                    let i6 = nextSectionStart + (spanIdx + 1) * airfoilPoints + airfoilIdx

                    // Connect current section to next section (longitudinal quads)
                    indices.append(contentsOf: [
                        Int32(i0), Int32(i4), Int32(i1),
                        Int32(i1), Int32(i4), Int32(i5)
                    ])

                    // Side faces (connect spanwise)
                    indices.append(contentsOf: [
                        Int32(i0), Int32(i2), Int32(i4),
                        Int32(i2), Int32(i6), Int32(i4)
                    ])

                    // Top/bottom faces (connect along airfoil)
                    indices.append(contentsOf: [
                        Int32(i0), Int32(i1), Int32(i2),
                        Int32(i1), Int32(i3), Int32(i2)
                    ])
                }
            }

            // Close the edges (spanwise edges at each airfoil endpoint)
            for spanIdx in 0..<(spanwisePoints - 1) {
                // Close front edge (airfoilIdx = 0)
                let i0 = currentSectionStart + spanIdx * airfoilPoints
                let i1 = currentSectionStart + (spanIdx + 1) * airfoilPoints
                let i2 = nextSectionStart + spanIdx * airfoilPoints
                let i3 = nextSectionStart + (spanIdx + 1) * airfoilPoints

                indices.append(contentsOf: [
                    Int32(i0), Int32(i2), Int32(i1),
                    Int32(i1), Int32(i2), Int32(i3)
                ])

                // Close back edge (airfoilIdx = airfoilPoints-1)
                let j0 = currentSectionStart + spanIdx * airfoilPoints + (airfoilPoints - 1)
                let j1 = currentSectionStart + (spanIdx + 1) * airfoilPoints + (airfoilPoints - 1)
                let j2 = nextSectionStart + spanIdx * airfoilPoints + (airfoilPoints - 1)
                let j3 = nextSectionStart + (spanIdx + 1) * airfoilPoints + (airfoilPoints - 1)

                indices.append(contentsOf: [
                    Int32(j0), Int32(j1), Int32(j2),
                    Int32(j1), Int32(j3), Int32(j2)
                ])
            }
        }

        // Calculate normals
        normals = calculateNormals(vertices: vertices, indices: indices)

        // Create geometry
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<Int32>.size
        )

        return SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
    }

    /// Calculate vertex normals from triangle data
    static func calculateNormals(vertices: [SCNVector3], indices: [Int32]) -> [SCNVector3] {
        var normals = [SCNVector3](repeating: SCNVector3(0, 0, 0), count: vertices.count)

        // Accumulate face normals
        for i in stride(from: 0, to: indices.count, by: 3) {
            let i0 = Int(indices[i])
            let i1 = Int(indices[i + 1])
            let i2 = Int(indices[i + 2])

            let v0 = vertices[i0]
            let v1 = vertices[i1]
            let v2 = vertices[i2]

            // Calculate face normal
            let edge1 = SCNVector3(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z)
            let edge2 = SCNVector3(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z)

            let normal = SCNVector3(
                edge1.y * edge2.z - edge1.z * edge2.y,
                edge1.z * edge2.x - edge1.x * edge2.z,
                edge1.x * edge2.y - edge1.y * edge2.x
            )

            // Accumulate to vertices
            normals[i0] = SCNVector3(
                normals[i0].x + normal.x,
                normals[i0].y + normal.y,
                normals[i0].z + normal.z
            )
            normals[i1] = SCNVector3(
                normals[i1].x + normal.x,
                normals[i1].y + normal.y,
                normals[i1].z + normal.z
            )
            normals[i2] = SCNVector3(
                normals[i2].x + normal.x,
                normals[i2].y + normal.y,
                normals[i2].z + normal.z
            )
        }

        // Normalize
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
