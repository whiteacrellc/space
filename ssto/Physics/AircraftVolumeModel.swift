//
//  AircraftVolumeModel.swift
//  ssto
//
//  Created by tom whittaker on 11/26/25.
//

import Foundation
import SceneKit
import CoreGraphics

/// Models aircraft volume, fuel capacity, and mass
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

    private static func cubicBezier(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t
        let x = uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x
        let y = uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y
        return CGPoint(x: x, y: y)
    }

    private static func getPlanformWidth(at x: Double, planform: TopViewPlanform) -> Double {
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

    private static func interpolatePlanformBezierY(x: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
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

    private static func solveQuadraticBezierY(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> Double {
        let u = 1 - t
        return u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
    }

    // MARK: - Legacy Engine/Mass Specifications (Restored for PlaneDesignScene compatibility)

    static let j58FuelConsumptionGPH = 8000.0
    static let j58FuelConsumptionLPS = 8000.0 * 3.78541 / 3600.0 
    static let j58ThrustN = 150000.0
    static let j58WeightKg = 2400.0

    static let jetFuelDensity = 80.0
    static let slushHydrogenDensity = 86.0
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

    static func calculateEngineCount(requiredThrust: Double) -> Int {
        let enginesNeeded = ceil(requiredThrust / j58ThrustN)
        return max(1, Int(enginesNeeded))
    }

    static func calculateJetFuelVolume(fuelMassKg: Double) -> Double {
        return fuelMassKg / jetFuelDensity
    }

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
        let engineMass = Double(engineCount) * j58WeightKg
        let airframeMass = (propellantMass + tankMass + engineMass) * 0.25
        return tankMass + engineMass + airframeMass
    }

    static func calculateAircraftMass(
        jetFuelKg: Double,
        hydrogenFuelKg: Double,
        methaneFuelKg: Double,
        engineCount: Int
    ) -> (dryMass: Double, propellantMass: Double, totalMass: Double) {
        let totalPropellant = jetFuelKg + hydrogenFuelKg + methaneFuelKg
        let structuralMass = calculateStructuralMass(
            propellantMass: totalPropellant,
            engineCount: engineCount
        )
        let totalMass = structuralMass + totalPropellant
        return (structuralMass, totalPropellant, totalMass)
    }

    static func j58FuelConsumptionRate(engineCount: Int) -> Double {
        return Double(engineCount) * j58FuelConsumptionLPS
    }

    static func j58TotalThrust(engineCount: Int, altitude: Double, mach: Double) -> Double {
        let baseThrust = Double(engineCount) * j58ThrustN
        let altitudeFeet = altitude
        let densityFactor = exp(-altitudeFeet / 30000.0)
        let machFactor: Double
        if mach <= 3.2 {
            machFactor = 1.0
        } else {
            machFactor = max(0.1, 1.0 - (mach - 3.2) * 0.3)
        }
        return baseThrust * densityFactor * machFactor
    }

    static func calculateReferenceArea(wingspan: Double, height: Double) -> Double {
        return wingspan * height * 0.7
    }

    static func generateAircraftConfiguration(
        jetFuelKg: Double,
        hydrogenFuelKg: Double,
        methaneFuelKg: Double,
        requiredThrust: Double
    ) -> AircraftConfiguration {
        let engineCount = calculateEngineCount(requiredThrust: requiredThrust)
        let jetFuelVolume = calculateJetFuelVolume(fuelMassKg: jetFuelKg)
        let hydrogenVolume = calculateHydrogenVolume(fuelMassKg: hydrogenFuelKg)
        let methaneVolume = calculateMethaneVolume(fuelMassKg: methaneFuelKg)
        let totalPropellantVolume = jetFuelVolume + hydrogenVolume + methaneVolume
        let dimensions = calculateAircraftDimensions(totalPropellantVolume: totalPropellantVolume)
        let masses = calculateAircraftMass(
            jetFuelKg: jetFuelKg,
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
            jetFuelVolume: jetFuelVolume,
            hydrogenVolume: hydrogenVolume,
            methaneVolume: methaneVolume,
            dryMass: masses.dryMass,
            propellantMass: masses.propellantMass,
            totalMass: masses.totalMass,
            referenceArea: referenceArea
        )
    }
}

// MARK: - Legacy Configuration Struct

struct AircraftConfiguration: Codable {
    let engineCount: Int
    let length: Double
    let wingspan: Double
    let height: Double
    let jetFuelVolume: Double
    let hydrogenVolume: Double
    let methaneVolume: Double
    let dryMass: Double
    let propellantMass: Double
    let totalMass: Double
    let referenceArea: Double

    var totalVolume: Double {
        return jetFuelVolume + hydrogenVolume + methaneVolume
    }
    var jetFuelMassKg: Double {
        return jetFuelVolume * AircraftVolumeModel.jetFuelDensity
    }
    var hydrogenMassKg: Double {
        return hydrogenVolume * AircraftVolumeModel.slushHydrogenDensity
    }
    var methaneMassKg: Double {
        return methaneVolume * AircraftVolumeModel.liquidMethaneDensity
    }
    var totalFuelMassKg: Double {
        return jetFuelMassKg + hydrogenMassKg + methaneMassKg
    }
}
