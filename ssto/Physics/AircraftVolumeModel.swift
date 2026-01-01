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
