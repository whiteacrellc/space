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
        planeAngle: Double,
        flatTopPct: Double = 70,
        heightFactor: Double = 10,
        slopeCurve: Double = 1.5
    ) -> SCNGeometry {

        // Convert angles to radians
        let alpha = Float(coneAngle) * (Float.pi / 180.0)
        let beta = Float(planeAngle) * (Float.pi / 180.0)

        // Define cross-sections along the length
        let sections = generateCrossSections(
            coneAngle: alpha,
            planeAngle: beta
        )

        // Generate mesh from cross-sections using NURBS-like interpolation
        return generateMeshFromSections(sections: sections)
    }

    // MARK: - NACA Airfoil Generation

    /// Generate NACA 4-digit airfoil coordinates
    /// Uses NACA 0012 (symmetric, 12% thickness) as base profile
    static func generateNACA4DigitAirfoil(
        thickness: Float,  // Maximum thickness as percentage of chord (e.g., 0.12 for 12%)
        numPoints: Int = 50
    ) -> [AirfoilPoint] {

        var points: [AirfoilPoint] = []

        // Generate upper surface (0 to 1)
        for i in 0...numPoints {
            let x = Float(i) / Float(numPoints)

            // NACA symmetric airfoil thickness distribution
            // yt = 5*t*(0.2969*sqrt(x) - 0.1260*x - 0.3516*x^2 + 0.2843*x^3 - 0.1015*x^4)
            let t = thickness
            let yt = 5.0 * t * (
                0.2969 * sqrt(x) -
                0.1260 * x -
                0.3516 * x * x +
                0.2843 * x * x * x -
                0.1015 * x * x * x * x
            )

            points.append(AirfoilPoint(x: x, y: yt))
        }

        // Generate lower surface (1 to 0) - symmetric so just negate y
        for i in (0..<numPoints).reversed() {
            let x = Float(i) / Float(numPoints)
            let t = thickness
            let yt = 5.0 * t * (
                0.2969 * sqrt(x) -
                0.1260 * x -
                0.3516 * x * x +
                0.2843 * x * x * x -
                0.1015 * x * x * x * x
            )

            points.append(AirfoilPoint(x: x, y: -yt))
        }

        return points
    }

    // MARK: - Cross-Section Generation

    /// Generate cross-sections along the aircraft length
    /// Leading edge defined by cone-plane intersection at z=0
    /// Apex at (0,0,0), symmetric in y
    static func generateCrossSections(
        coneAngle: Float,
        planeAngle: Float
    ) -> [AirfoilSection] {

        var sections: [AirfoilSection] = []

        let numSections = 60

        // Leading edge is at z=0, defined by cone-plane intersection
        // Cone equation: y² + z² = (x * tan(α))²
        // At z=0: y = ± x * tan(α)
        // This gives us the width at each x position

        // Calculate x range: apex at origin, extend back to create 100m+ length
        // and ensure 300m+ width at widest point
        let xEnd = aircraftLength  // Extend to 100m from apex

        for i in 0...numSections {
            let t = Float(i) / Float(numSections)  // 0 to 1

            // x goes from apex (0) backward to -xEnd
            // This gives leading edge from nose (0,0,0) backward
            let x = t * xEnd

            // Calculate half-width at this x from cone-plane intersection
            // y = x * tan(coneAngle)
            let halfWidth = x * tan(coneAngle)

            // Ensure minimum dimensions for payload and max width
            let actualHalfWidth: Float
            if halfWidth < maxWidth / 2.0 {
                actualHalfWidth = halfWidth
            } else {
                actualHalfWidth = maxWidth / 2.0  // Cap at max width
            }

            // Calculate height using NACA airfoil thickness
            // Height is maximum at center and tapers toward edges
            let maxHeight = calculateHeightAtPosition(x: x, halfWidth: actualHalfWidth)

            // Thickness ratio for NACA airfoil (scaled to provide proper height)
            let thicknessRatio = min(0.15, maxHeight / max(actualHalfWidth * 2.0, 1.0))

            // Create airfoil section
            let section = AirfoilSection(
                centerX: x,
                centerY: 0,
                centerZ: 0,  // Leading edge at z=0
                chord: actualHalfWidth * 2.0,  // Full width (span)
                thickness: thicknessRatio,
                scale: 1.0
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

        let circumferentialPoints = 40  // Points around each cross-section

        // Generate vertices for each cross-section
        for (sectionIdx, section) in sections.enumerated() {
            let airfoil = generateNACA4DigitAirfoil(thickness: section.thickness)

            // Sample airfoil points evenly around the profile
            for i in 0..<circumferentialPoints {
                let t = Float(i) / Float(circumferentialPoints)
                let airfoilIdx = Int(t * Float(airfoil.count - 1))
                let point = airfoil[airfoilIdx]

                // Scale airfoil to section dimensions
                // Leading edge is at z=0
                // Airfoil chord extends in y direction (spanwise)
                // Airfoil thickness extends in z direction (vertical/height)

                let spanPos = (point.x - 0.5) * section.chord     // -chord/2 to +chord/2 (spanwise)
                let heightPos = point.y * section.chord           // Scaled height

                // Position in 3D space:
                // X = longitudinal (backward from apex at origin)
                // Y = lateral/spanwise (symmetric)
                // Z = vertical/height (leading edge at z=0)
                let vertex = SCNVector3(
                    section.centerX,           // Longitudinal position
                    spanPos,                   // Spanwise position (symmetric ±y)
                    heightPos                  // Height (from leading edge at z=0)
                )

                vertices.append(vertex)
            }
        }

        // Generate indices to connect cross-sections
        for sectionIdx in 0..<(sections.count - 1) {
            let currentRingStart = sectionIdx * circumferentialPoints
            let nextRingStart = (sectionIdx + 1) * circumferentialPoints

            for i in 0..<circumferentialPoints {
                let i1 = currentRingStart + i
                let i2 = currentRingStart + (i + 1) % circumferentialPoints
                let i3 = nextRingStart + i
                let i4 = nextRingStart + (i + 1) % circumferentialPoints

                // Create two triangles for each quad
                indices.append(contentsOf: [
                    Int32(i1), Int32(i2), Int32(i3),
                    Int32(i2), Int32(i4), Int32(i3)
                ])
            }
        }

        // Calculate normals
        normals = calculateNormals(vertices: vertices, indices: indices)

        // Close the nose (first section at apex x=0)
        let noseCenterIdx = Int32(vertices.count)
        vertices.append(SCNVector3(0, 0, 0))  // Apex at origin
        normals.append(SCNVector3(-1, 0, 0))

        for i in 0..<circumferentialPoints {
            let i1 = i
            let i2 = (i + 1) % circumferentialPoints
            indices.append(contentsOf: [
                noseCenterIdx, Int32(i2), Int32(i1)
            ])
        }

        // Close the tail (last section at x=100m)
        let tailCenterIdx = Int32(vertices.count)
        let lastRingStart = (sections.count - 1) * circumferentialPoints
        vertices.append(SCNVector3(sections.last!.centerX, 0, 0))  // Centerline
        normals.append(SCNVector3(1, 0, 0))

        for i in 0..<circumferentialPoints {
            let i1 = lastRingStart + i
            let i2 = lastRingStart + (i + 1) % circumferentialPoints
            indices.append(contentsOf: [
                tailCenterIdx, Int32(i1), Int32(i2)
            ])
        }

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
