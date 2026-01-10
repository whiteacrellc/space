//
//  AircraftVolumeModel.swift
//  ssto
//
//  Created by tom whittaker on 11/26/25.
//

import Foundation
import SceneKit
import CoreGraphics

/// Models aircraft volume, fuel capacity, and mass based on Ejector-Ramjet and Rocket propulsion
class AircraftVolumeModel {
    
    // MARK: - Volume Calculation from Wireframe
    
    /// Calculate the total internal volume of the aircraft based on the current design (GameManager)
    /// Returns volume in cubic meters (m³)
    static func calculateInternalVolume() -> Double {
        // 1. Get Data from GameManager
        let profile = GameManager.shared.getSideProfile()
        let planform = GameManager.shared.getTopViewPlanform()
        let crossSection = GameManager.shared.getCrossSectionPoints()
        
        // 2. Prepare Unit Cross Section
        let unitShape = generateUnitCrossSection(from: crossSection, steps: 5)
        
        // 3. Generate Mesh Points
        var meshPoints: [[SCNVector3]] = []
        let numRibs = 40
        
        let startX = min(planform.noseTip.x, profile.frontStart.x)
        let endX = max(planform.tailLeft.x, profile.exhaustEnd.x)
        
        // Convert canvas units to meters
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
                
                // Store in meters directly
                ribPoints.append(SCNVector3(
                    Float(x * metersPerUnit),
                    Float(finalY * metersPerUnit),
                    Float(finalZ * metersPerUnit)
                ))
            }
            meshPoints.append(ribPoints)
        }
        
        // 4. Calculate Volume via Integration
        var totalVolume: Double = 0.0
        
        for i in 0..<meshPoints.count - 1 {
            let section1 = meshPoints[i]
            let section2 = meshPoints[i + 1]
            
            let area1 = calculateCrossSectionArea(section: section1)
            let area2 = calculateCrossSectionArea(section: section2)
            
            let avgArea = (area1 + area2) / 2.0
            let dx = abs(Double(section2[0].x - section1[0].x))
            
            totalVolume += avgArea * dx
        }
        
        return totalVolume
    }

    /// Surface area breakdown by region
    struct SurfaceAreaBreakdown {
        let noseCap: Double         // First 5% of length - 30 kg/m²
        let leadingEdges: Double    // Next 15% of length, side-facing - 30 kg/m²
        let topSurface: Double      // Upper skin - 8 kg/m²
        let bottomSurface: Double   // Lower fuselage - 12 kg/m²
        let engineInlet: Double     // Inlet region - 15 kg/m²
        let total: Double
    }

    /// Calculate wetted surface area from 3D mesh geometry
    /// Returns area breakdown by region in square meters (m²)
    static func calculateWettedSurfaceArea() -> SurfaceAreaBreakdown {
        // 1. Get design data
        let profile = GameManager.shared.getSideProfile()
        let planform = GameManager.shared.getTopViewPlanform()
        let crossSection = GameManager.shared.getCrossSectionPoints()

        // 2. Generate unit cross section (reuse existing logic)
        let unitShape = generateUnitCrossSection(from: crossSection, steps: 5)

        // 3. Generate mesh ribs along aircraft length (40 ribs, same as volume calc)
        var meshRibs: [[SCNVector3]] = []
        let numRibs = 40

        let startX = min(planform.noseTip.x, profile.frontStart.x)
        let endX = max(planform.tailLeft.x, profile.exhaustEnd.x)

        // Convert canvas units to meters
        let aircraftLengthMeters = planform.aircraftLength
        let canvasLength = endX - startX
        let metersPerUnit = aircraftLengthMeters / canvasLength

        for i in 0...numRibs {
            let t = Double(i) / Double(numRibs)
            let x = startX + t * (endX - startX)

            // Get width and height at this station
            let halfWidth = getPlanformWidth(at: x, planform: planform)
            let (zTop, zBottom) = getProfileHeight(at: x, profile: profile)

            let height = max(0.1, zTop - zBottom)
            let zCenter = (zTop + zBottom) / 2.0
            let validHalfWidth = max(0.1, halfWidth)

            // Scale unit cross-section to actual dimensions
            var rib: [SCNVector3] = []
            for unitPoint in unitShape {
                let finalY = unitPoint.x * validHalfWidth
                let finalZ = zCenter + (unitPoint.y * height / 2.0)

                // Store in meters
                let scaledPoint = SCNVector3(
                    Float(x * metersPerUnit),
                    Float(finalY * metersPerUnit),
                    Float(finalZ * metersPerUnit)
                )
                rib.append(scaledPoint)
            }
            meshRibs.append(rib)
        }

        // 4. Calculate surface area between adjacent ribs with region classification
        var noseCapArea: Double = 0.0
        var leadingEdgeArea: Double = 0.0
        var topSurfaceArea: Double = 0.0
        var bottomSurfaceArea: Double = 0.0
        var engineInletArea: Double = 0.0

        // Get aircraft length for region boundaries
        let minX = Double(meshRibs.first?.first?.x ?? 0.0)
        let maxX = Double(meshRibs.last?.first?.x ?? Float(aircraftLengthMeters))
        let lengthRange = maxX - minX

        for i in 0..<meshRibs.count - 1 {
            let (noseArea, leadingArea, topArea, bottomArea, inletArea) = calculateRibSegmentAreaByRegion(
                rib1: meshRibs[i],
                rib2: meshRibs[i + 1],
                minX: Double(minX),
                lengthRange: lengthRange
            )
            noseCapArea += noseArea
            leadingEdgeArea += leadingArea
            topSurfaceArea += topArea
            bottomSurfaceArea += bottomArea
            engineInletArea += inletArea
        }

        let totalArea = noseCapArea + leadingEdgeArea + topSurfaceArea + bottomSurfaceArea + engineInletArea

        print("\n=== Surface Area Breakdown ===")
        print("Nose cap (0-5%):      \(String(format: "%6.1f", noseCapArea)) m² @ 30 kg/m²")
        print("Leading edges (5-20%):\(String(format: "%6.1f", leadingEdgeArea)) m² @ 30 kg/m²")
        print("Top surface:          \(String(format: "%6.1f", topSurfaceArea)) m² @ 8 kg/m²")
        print("Bottom surface:       \(String(format: "%6.1f", bottomSurfaceArea)) m² @ 12 kg/m²")
        print("Engine inlet:         \(String(format: "%6.1f", engineInletArea)) m² @ 15 kg/m²")
        print("------------------------------")
        print("Total:                \(String(format: "%6.1f", totalArea)) m²")
        print("==============================\n")

        return SurfaceAreaBreakdown(
            noseCap: noseCapArea,
            leadingEdges: leadingEdgeArea,
            topSurface: topSurfaceArea,
            bottomSurface: bottomSurfaceArea,
            engineInlet: engineInletArea,
            total: totalArea
        )
    }

    /// Calculate surface area for a rib segment, classified by region
    /// Returns (noseCapArea, leadingEdgeArea, topArea, bottomArea, inletArea)
    private static func calculateRibSegmentAreaByRegion(
        rib1: [SCNVector3],
        rib2: [SCNVector3],
        minX: Double,
        lengthRange: Double
    ) -> (Double, Double, Double, Double, Double) {
        guard rib1.count == rib2.count, rib1.count >= 2 else { return (0, 0, 0, 0, 0) }

        var noseCapArea: Double = 0.0
        var leadingEdgeArea: Double = 0.0
        var topSurfaceArea: Double = 0.0
        var bottomSurfaceArea: Double = 0.0
        var engineInletArea: Double = 0.0

        for j in 0..<rib1.count {
            let k = (j + 1) % rib1.count

            // Form quadrilateral between ribs, split into 2 triangles
            let v0 = rib1[j]
            let v1 = rib1[k]
            let v2 = rib2[k]
            let v3 = rib2[j]

            // Process first triangle
            let area1 = triangleArea(v0: v0, v1: v1, v2: v2)
            let (region1, _) = classifyTriangle(v0: v0, v1: v1, v2: v2, minX: minX, lengthRange: lengthRange)
            addAreaToRegion(area: area1, region: region1,
                           noseCapArea: &noseCapArea, leadingEdgeArea: &leadingEdgeArea,
                           topSurfaceArea: &topSurfaceArea, bottomSurfaceArea: &bottomSurfaceArea,
                           engineInletArea: &engineInletArea)

            // Process second triangle
            let area2 = triangleArea(v0: v0, v1: v2, v2: v3)
            let (region2, _) = classifyTriangle(v0: v0, v1: v2, v2: v3, minX: minX, lengthRange: lengthRange)
            addAreaToRegion(area: area2, region: region2,
                           noseCapArea: &noseCapArea, leadingEdgeArea: &leadingEdgeArea,
                           topSurfaceArea: &topSurfaceArea, bottomSurfaceArea: &bottomSurfaceArea,
                           engineInletArea: &engineInletArea)
        }

        return (noseCapArea, leadingEdgeArea, topSurfaceArea, bottomSurfaceArea, engineInletArea)
    }

    /// Classify a triangle into a region based on position and normal
    private enum SurfaceRegion {
        case noseCap
        case leadingEdge
        case topSurface
        case bottomSurface
        case engineInlet
    }

    private static func classifyTriangle(
        v0: SCNVector3,
        v1: SCNVector3,
        v2: SCNVector3,
        minX: Double,
        lengthRange: Double
    ) -> (SurfaceRegion, SCNVector3) {
        // Calculate triangle centroid
        let centroidX = (Double(v0.x) + Double(v1.x) + Double(v2.x)) / 3.0
        let centroidY = (Double(v0.y) + Double(v1.y) + Double(v2.y)) / 3.0
        let centroidZ = (Double(v0.z) + Double(v1.z) + Double(v2.z)) / 3.0

        // Calculate normal vector (cross product)
        let e1 = SCNVector3(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z)
        let e2 = SCNVector3(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z)
        let normal = SCNVector3(
            e1.y * e2.z - e1.z * e2.y,
            e1.z * e2.x - e1.x * e2.z,
            e1.x * e2.y - e1.y * e2.x
        )

        // Normalize
        let mag = sqrt(Double(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z))
        let normalizedNormal = SCNVector3(
            Float(Double(normal.x) / mag),
            Float(Double(normal.y) / mag),
            Float(Double(normal.z) / mag)
        )

        // Calculate position along length (0.0 = front, 1.0 = back)
        let xPosition = (centroidX - minX) / lengthRange

        // Region boundaries
        let noseCapEnd = 0.05        // First 5% is nose cap
        let leadingEdgeEnd = 0.20    // Next 15% (5-20%) is leading edge
        let inletStart = 0.15        // Engine inlet starts at 15%
        let inletEnd = 0.35          // Engine inlet ends at 35%

        // Classify by position and orientation
        if xPosition < noseCapEnd {
            // Nose cap region (first 5%)
            return (.noseCap, normalizedNormal)
        } else if xPosition < leadingEdgeEnd {
            // Leading edge region (5-20%)
            // Only side-facing surfaces (significant Y component in normal)
            if abs(Double(normalizedNormal.y)) > 0.3 {
                return (.leadingEdge, normalizedNormal)
            }
            // Fall through to top/bottom classification
        }

        // Check for engine inlet (on bottom surface, 15-35% of length)
        if xPosition >= inletStart && xPosition <= inletEnd && Double(normalizedNormal.z) < -0.3 {
            return (.engineInlet, normalizedNormal)
        }

        // Classify remaining surfaces by orientation
        if Double(normalizedNormal.z) > 0.0 {
            // Normal points up - top surface
            return (.topSurface, normalizedNormal)
        } else {
            // Normal points down - bottom surface
            return (.bottomSurface, normalizedNormal)
        }
    }

    private static func addAreaToRegion(
        area: Double,
        region: SurfaceRegion,
        noseCapArea: inout Double,
        leadingEdgeArea: inout Double,
        topSurfaceArea: inout Double,
        bottomSurfaceArea: inout Double,
        engineInletArea: inout Double
    ) {
        switch region {
        case .noseCap:
            noseCapArea += area
        case .leadingEdge:
            leadingEdgeArea += area
        case .topSurface:
            topSurfaceArea += area
        case .bottomSurface:
            bottomSurfaceArea += area
        case .engineInlet:
            engineInletArea += area
        }
    }

    private static func triangleArea(v0: SCNVector3, v1: SCNVector3, v2: SCNVector3) -> Double {
        // Calculate triangle area using cross product
        let e1 = SCNVector3(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z)
        let e2 = SCNVector3(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z)

        let cross = SCNVector3(
            e1.y * e2.z - e1.z * e2.y,
            e1.z * e2.x - e1.x * e2.z,
            e1.x * e2.y - e1.y * e2.x
        )

        let magnitude = sqrt(Double(cross.x * cross.x + cross.y * cross.y + cross.z * cross.z))
        return 0.5 * magnitude
    }

    // MARK: - Geometry Helpers
    
    private static func calculateCrossSectionArea(section: [SCNVector3]) -> Double {
        guard section.count >= 3 else { return 0.0 }
        var area: Double = 0.0
        // Use Y-Z plane for cross-section
        for i in 0..<section.count {
            let j = (i + 1) % section.count
            let yi = Double(section[i].y)
            let zi = Double(section[i].z)
            let yj = Double(section[j].y)
            let zj = Double(section[j].z)
            area += yi * zj - yj * zi
        }
        return abs(area / 2.0)
    }

    // MARK: - Ejector-Ramjet Engine Specifications

    /// Thrust per Ejector-Ramjet engine (Newtons) - estimated for this class
    static let ejectorRamjetThrustN = 200000.0 // 200 kN

    /// Ejector-Ramjet engine dry weight (kg)
    static let ejectorRamjetWeightKg = 3000.0

    private static func getProfileHeight(at x: Double, profile: SideProfileShape) -> (Double, Double) {
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

    /// Slush hydrogen density (kg/m³) - for ramjet and scramjet
    static let slushHydrogenDensity = 86.0

    static let j58FuelConsumptionGPH = 8000.0
    static let j58FuelConsumptionLPS = 8000.0 * 3.78541 / 3600.0
    static let j58ThrustN = 150000.0
    static let j58WeightKg = 2400.0

    static let jetFuelDensity = 80.0
    static let liquidMethaneDensity = 422.0
    static let loxDensity = 1141.0

    static let raptorIspVacuum = 380.0
    static let raptorTotalMassFlow = 850.0
    static let raptorMethaneFraction = 0.25
    static let raptorLoxFraction = 0.75
    static let raptorMethaneMassFlow = raptorTotalMassFlow * raptorMethaneFraction
    static let raptorLoxMassFlow = raptorTotalMassFlow * raptorLoxFraction
    static let raptorMixtureRatio = raptorLoxFraction / raptorMethaneFraction
    static let tankStructureFraction = 0.15

    // MARK: - Volume and Mass Calculations

    /// Calculate number of Ejector-Ramjet engines needed for required thrust
    static func calculateEngineCount(requiredThrust: Double) -> Int {
        let enginesNeeded = ceil(requiredThrust / ejectorRamjetThrustN)
        return max(1, Int(enginesNeeded))
    }

    /// Calculate slush hydrogen volume (m³) for ramjet/scramjet
    static func calculateHydrogenVolume(fuelMassKg: Double) -> Double {
        return fuelMassKg / slushHydrogenDensity
    }

    static func calculateMethaneVolume(fuelMassKg: Double) -> Double {
        return fuelMassKg / liquidMethaneDensity
    }

    static func raptorThrust(altitude: Double) -> Double {
        let g0 = 9.80665
        let altitudeFeet = altitude
        let ispEffective: Double
        if altitudeFeet < 50000 {
            ispEffective = raptorIspVacuum * 0.75
        } else if altitudeFeet < 150000 {
            let fraction = (altitudeFeet - 50000) / 100000
            ispEffective = raptorIspVacuum * (0.75 + 0.25 * fraction)
        } else {
            ispEffective = raptorIspVacuum
        }
        return ispEffective * g0 * raptorTotalMassFlow
    }

    static func calculateAircraftDimensions(totalPropellantVolume: Double) -> (length: Double, wingspan: Double, height: Double) {
        let totalVolume = totalPropellantVolume / 0.4
        let wingspan = pow(totalVolume / 0.54, 1.0/3.0)
        let length = 3.0 * wingspan
        let height = 0.3 * wingspan
        return (length, wingspan, height)
    }

    static func calculateStructuralMass(propellantMass: Double, engineCount: Int) -> Double {
        let tankMass = propellantMass * tankStructureFraction

        // Engine mass
        let engineMass = Double(engineCount) * ejectorRamjetWeightKg

        // Airframe (empirical: ~20% of total loaded mass)
        let airframeMass = (propellantMass + tankMass + engineMass) * 0.25
        return tankMass + engineMass + airframeMass
    }

    static func calculateAircraftMass(
        hydrogenFuelKg: Double,
        methaneFuelKg: Double,
        engineCount: Int
    ) -> (dryMass: Double, propellantMass: Double, totalMass: Double) {

        // Only fuel mass - no oxidizer mass needed
        let totalPropellant = hydrogenFuelKg + methaneFuelKg

        let structuralMass = calculateStructuralMass(
            propellantMass: totalPropellant,
            engineCount: engineCount
        )
        let totalMass = structuralMass + totalPropellant
        return (structuralMass, totalPropellant, totalMass)
    }

    /// Calculate reference area based on aircraft dimensions (m²)
    static func calculateReferenceArea(wingspan: Double, height: Double) -> Double {
        return wingspan * height * 0.7
    }

    static func generateAircraftConfiguration(
        hydrogenFuelKg: Double,
        methaneFuelKg: Double,
        requiredThrust: Double
    ) -> AircraftConfiguration {
        let engineCount = calculateEngineCount(requiredThrust: requiredThrust)

        // Calculate volumes
        let hydrogenVolume = calculateHydrogenVolume(fuelMassKg: hydrogenFuelKg)
        let methaneVolume = calculateMethaneVolume(fuelMassKg: methaneFuelKg)
        let totalPropellantVolume = hydrogenVolume + methaneVolume

        // Calculate dimensions
        let dimensions = calculateAircraftDimensions(totalPropellantVolume: totalPropellantVolume)
        let masses = calculateAircraftMass(
            hydrogenFuelKg: hydrogenFuelKg,
            methaneFuelKg: methaneFuelKg,
            engineCount: engineCount
        )
        let referenceArea = calculateReferenceArea(
            wingspan: dimensions.wingspan,
            height: dimensions.height
        )
        return AircraftConfiguration(
            engineCount: engineCount,
            length: dimensions.length,
            wingspan: dimensions.wingspan,
            height: dimensions.height,
            hydrogenVolume: hydrogenVolume,
            methaneVolume: methaneVolume,
            dryMass: masses.dryMass,
            propellantMass: masses.propellantMass,
            totalMass: masses.totalMass,
            referenceArea: referenceArea
        )
    }

    // MARK: - Helper Functions

    private static func generateUnitCrossSection(from crossSection: CrossSectionPoints, steps: Int) -> [CGPoint] {
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

    private static func interpolateSpline(points: [CGPoint], steps: Int) -> [CGPoint] {
        var result: [CGPoint] = []
        guard points.count >= 3 else { return points }

        for i in 0..<(points.count - 2) / 2 {
            let p0 = points[i * 2]
            let p1 = points[i * 2 + 1]
            let p2 = points[i * 2 + 2]

            for j in 0...steps {
                let t = Double(j) / Double(steps)
                let x = (1 - t) * (1 - t) * p0.x + 2 * (1 - t) * t * p1.x + t * t * p2.x
                let y = (1 - t) * (1 - t) * p0.y + 2 * (1 - t) * t * p1.y + t * t * p2.y
                result.append(CGPoint(x: x, y: y))
            }
        }
        return result
    }

    private static func getPlanformWidth(at x: Double, planform: TopViewPlanform) -> Double {
        let noseTip = planform.noseTip.toCGPoint()
        let frontControlLeft = planform.frontControlLeft.toCGPoint()
        let midLeft = planform.midLeft.toCGPoint()
        let rearControlLeft = planform.rearControlLeft.toCGPoint()
        let tailLeft = planform.tailLeft.toCGPoint()

        if x < noseTip.x {
            return 0.0
        }

        if x <= midLeft.x {
            let segmentLength = midLeft.x - noseTip.x
            if segmentLength <= 0 { return 0.0 }
            let t = (x - noseTip.x) / segmentLength
            return solveQuadraticBezierY(t: t, p0: noseTip, p1: frontControlLeft, p2: midLeft)
        }

        if x <= tailLeft.x {
            let segmentLength = tailLeft.x - midLeft.x
            if segmentLength <= 0 { return midLeft.y }
            let t = (x - midLeft.x) / segmentLength
            return solveQuadraticBezierY(t: t, p0: midLeft, p1: rearControlLeft, p2: tailLeft)
        }

        return 0.0
    }

    private static func solveQuadraticBezierY(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> Double {
        let u = 1 - t
        return u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
    }
}

// MARK: - Legacy Configuration Struct

struct AircraftConfiguration: Codable {
    let engineCount: Int
    let length: Double
    let wingspan: Double
    let height: Double

    // Volumes (cubic meters)
    let hydrogenVolume: Double     // For ramjet/scramjet (Mach 3-8)
    let methaneVolume: Double      // For rocket (Mach 8+, vacuum)

    // Masses (kg)
    let dryMass: Double
    let propellantMass: Double
    let totalMass: Double
    let referenceArea: Double

    var totalVolume: Double {
        return hydrogenVolume + methaneVolume
    }
    var hydrogenMassKg: Double {
        return hydrogenVolume * AircraftVolumeModel.slushHydrogenDensity
    }
    var methaneMassKg: Double {
        return methaneVolume * AircraftVolumeModel.liquidMethaneDensity
    }
    var totalFuelMassKg: Double {
        return hydrogenMassKg + methaneMassKg
    }

    func summary() -> String {
        return """
        Aircraft Configuration:
        - Engines: \(engineCount) × Ejector-Ramjet
        - Dimensions: L=\(String(format: "%.1f", length))m, W=\(String(format: "%.1f", wingspan))m, H=\(String(format: "%.1f", height))m
        - Dry Mass: \(String(format: "%.0f", dryMass))kg
        - Slush H₂: \(String(format: "%.0f", hydrogenMassKg))kg (\(String(format: "%.1f", hydrogenVolume))m³)
        - LCH₄: \(String(format: "%.0f", methaneMassKg))kg (\(String(format: "%.1f", methaneVolume))m³)
        - Total Mass: \(String(format: "%.0f", totalMass))kg
        - Reference Area: \(String(format: "%.1f", referenceArea))m²
        - Raptor Thrust: ~\(String(format: "%.0f", AircraftVolumeModel.raptorThrust(altitude: 200000)/1000))kN @ 200k ft
        Note: LOX collected during flight, stored in freed fuel volume
        """
    }
}
