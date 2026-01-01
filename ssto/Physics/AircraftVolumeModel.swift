//
//  AircraftVolumeModel.swift
//  ssto
//
//  Created by tom whittaker on 11/26/25.
//

import Foundation

/// Models aircraft volume, fuel capacity, and mass based on Ejector-Ramjet and Rocket propulsion
class AircraftVolumeModel {

    // MARK: - Ejector-Ramjet Engine Specifications

    /// Thrust per Ejector-Ramjet engine (Newtons) - estimated for this class
    static let ejectorRamjetThrustN = 200000.0 // 200 kN

    /// Ejector-Ramjet engine dry weight (kg)
    static let ejectorRamjetWeightKg = 3000.0

    // MARK: - Fuel Properties

    /// Slush hydrogen density (kg/m³) - for ramjet and scramjet
    static let slushHydrogenDensity = 86.0

    /// Liquid methane density (kg/m³) - for rocket (Raptor-like engine)
    static let liquidMethaneDensity = 422.0

    /// LOX density (kg/m³) - collected during flight
    static let loxDensity = 1141.0

    // Note: Oxygen for rocket mode is collected during flight and stored
    // in volume freed by spent fuel - no additional mass or volume needed

    // MARK: - Raptor Engine Specifications (SpaceX Starship)

    /// Raptor engine specific impulse in vacuum (seconds)
    static let raptorIspVacuum = 380.0

    /// Total propellant mass flow rate (kg/s)
    static let raptorTotalMassFlow = 850.0

    /// Methane fraction of total propellant mass (25%)
    static let raptorMethaneFraction = 0.25

    /// LOX fraction of total propellant mass (75%)
    static let raptorLoxFraction = 0.75

    /// Methane mass flow rate (kg/s)
    static let raptorMethaneMassFlow = raptorTotalMassFlow * raptorMethaneFraction // 212.5 kg/s

    /// LOX mass flow rate (kg/s) - collected during flight
    static let raptorLoxMassFlow = raptorTotalMassFlow * raptorLoxFraction // 637.5 kg/s

    /// Mixture ratio (LOX/Methane)
    static let raptorMixtureRatio = raptorLoxFraction / raptorMethaneFraction // 3.0

    // MARK: - Tank Structure

    /// Tank structural mass as fraction of propellant mass
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

    /// Calculate liquid methane volume (m³) for rocket
    static func calculateMethaneVolume(fuelMassKg: Double) -> Double {
        return fuelMassKg / liquidMethaneDensity
    }

    /// Calculate Raptor engine thrust (N) using Tsiolkovsky equation
    /// F = Isp * g0 * mass_flow_rate
    static func raptorThrust(altitude: Double) -> Double {
        let g0 = 9.80665 // Standard gravity (m/s²)

        // ISP varies with altitude (vacuum vs sea level)
        let altitudeFeet = altitude
        let ispEffective: Double
        if altitudeFeet < 50000 {
            // Sea level to 50k ft: reduced ISP
            ispEffective = raptorIspVacuum * 0.75 // ~285s at sea level
        } else if altitudeFeet < 150000 {
            // 50k to 150k ft: transitioning to vacuum
            let fraction = (altitudeFeet - 50000) / 100000
            ispEffective = raptorIspVacuum * (0.75 + 0.25 * fraction)
        } else {
            // Above 150k ft: vacuum performance
            ispEffective = raptorIspVacuum
        }

        return ispEffective * g0 * raptorTotalMassFlow
    }

    /// Calculate total aircraft dimensions based on fuel/oxidizer volume
    static func calculateAircraftDimensions(totalPropellantVolume: Double) -> (length: Double, wingspan: Double, height: Double) {
        // Assume lifting body design: length ≈ 3x wingspan, height ≈ 0.3x wingspan
        // Volume = k * length * wingspan * height for lifting body
        // Assuming propellant takes up ~40% of total aircraft volume

        let totalVolume = totalPropellantVolume / 0.4

        // For lifting body: V ≈ 0.6 * L * W * H (aerodynamic shape factor)
        // With L = 3W, H = 0.3W: V ≈ 0.6 * 3W * W * 0.3W = 0.54W³
        let wingspan = pow(totalVolume / 0.54, 1.0/3.0)
        let length = 3.0 * wingspan
        let height = 0.3 * wingspan

        return (length, wingspan, height)
    }

    /// Calculate structural mass based on propellant and tanks
    static func calculateStructuralMass(propellantMass: Double, engineCount: Int) -> Double {
        // Tank structure
        let tankMass = propellantMass * tankStructureFraction

        // Engine mass
        let engineMass = Double(engineCount) * ejectorRamjetWeightKg

        // Airframe (empirical: ~20% of total loaded mass)
        let airframeMass = (propellantMass + tankMass + engineMass) * 0.25

        return tankMass + engineMass + airframeMass
    }

    /// Calculate complete aircraft mass breakdown
    /// Note: No oxidizer mass needed - oxygen collected during flight
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
        // Frontal area approximation for lifting body
        return wingspan * height * 0.7 // Shape factor
    }

    /// Generate complete aircraft configuration
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

        // Calculate masses
        let masses = calculateAircraftMass(
            hydrogenFuelKg: hydrogenFuelKg,
            methaneFuelKg: methaneFuelKg,
            engineCount: engineCount
        )

        // Calculate reference area
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

// MARK: - Aircraft Configuration

struct AircraftConfiguration: Codable {
    let engineCount: Int

    // Dimensions (meters)
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

    // Aerodynamics
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