//
//  RamjetEngine.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

// MARK: - Constants
struct RamjetConstants {
    // Standard Atmosphere Model (ISA)
    static let T_SL: Double = 288.15     // Sea Level Temperature (K)
    static let P_SL: Double = 101325.0   // Sea Level Pressure (Pa)
    static let L: Double = 0.0065        // Tropospheric Lapse Rate (K/m)
    static let H_TROPO: Double = 11000.0 // Altitude limit of Troposphere (m)
    static let G: Double = 9.80665       // Gravitational acceleration (m/s^2)

    // Gas Dynamics (Air)
    static let R_AIR: Double = 287.05    // Specific Gas Constant for Air (J/kg·K)
    static let GAMMA: Double = 1.4       // Ratio of Specific Heats (Cp/Cv)
    static let CP_AIR: Double = 1005.0   // Specific Heat at Constant Pressure (J/kg·K)

    // Fuel Properties (Hydrogen)
    static let H_C: Double = 1.2e8       // Heating Value of Hydrogen (J/kg) - approx 120 MJ/kg LHV

    // Engine Limits
    static let T_0_MAX: Double = 2200.0  // Maximum allowable stagnation temperature (K) - Material limit
}

// MARK: - Ramjet Model Structure
struct RamjetModel {

    /// Calculates the specific net thrust (Net Thrust per unit Mass Flow Rate) of a
    /// hydrogen-fueled ramjet engine based on altitude and flight Mach number.
    ///
    /// The model uses the Ideal Brayton Cycle for Ramjets, standard ISA for atmosphere,
    /// and assumes perfect combustion and expansion (Pe = Pa).
    ///
    /// - Parameters:
    ///    - altitude: The flight altitude in meters (h).
    ///    - machNumber: The flight Mach number (M).
    ///
    /// - Returns: The specific net thrust in Newtons per kilogram of air per second (N·s/kg).
    func calculateSpecificThrust(altitude h: Double, machNumber M: Double) -> Double {

        let C = RamjetConstants.self // Alias for easier access

        // Input validation for basic ramjet operation (typically M > 1.5)
        guard M > 1.0 else {
            return 0.0 // Ramjet operation is not feasible or efficient at low speeds
        }

        // 1. ATMOSPHERIC MODEL (ISA - Troposphere only)

        var Ta: Double // Ambient Temperature (K)
        var Pa: Double // Ambient Pressure (Pa)

        if h <= C.H_TROPO {
            // Troposphere (0 - 11 km)
            Ta = C.T_SL - C.L * h
            let ratio = C.G / (C.L * C.R_AIR)
            Pa = C.P_SL * pow(Ta / C.T_SL, ratio)
        } else {
            // Stratosphere (isothermal layer above 11km)
            Ta = C.T_SL - C.L * C.H_TROPO // Temperature at tropopause
            let ratio = C.G / (C.L * C.R_AIR)
            let P_tropo = C.P_SL * pow(Ta / C.T_SL, ratio)
            // Isothermal pressure decay
            Pa = P_tropo * exp(-C.G * (h - C.H_TROPO) / (C.R_AIR * Ta))
        }

        // Air Speed (Va)
        let Va = M * sqrt(C.GAMMA * C.R_AIR * Ta)

        // 2. INLET COMPRESSION (Isentropic/Ideal Ram)

        // Stagnation Temperature T02 (after ideal compression)
        let T02 = Ta * (1 + (C.GAMMA - 1) / 2.0 * pow(M, 2))

        // Stagnation Pressure P02 (after ideal compression - ignoring inlet losses)
        let pressureRatio = pow(1 + (C.GAMMA - 1) / 2.0 * pow(M, 2), C.GAMMA / (C.GAMMA - 1))
        let P02 = Pa * pressureRatio

        // 3. COMBUSTION (Heat Addition)

        // T03 is limited by the material maximum temperature (T0_MAX)
        let T03 = C.T_0_MAX

        // Calculate the Fuel-Air Ratio (f) required to reach T03
        let f = C.CP_AIR * (T03 - T02) / C.H_C

        // Check if T02 already exceeds T0_MAX
        if T02 > C.T_0_MAX {
            return 0.0 // Engine is not operable under these conditions
        }

        // 4. NOZZLE EXPANSION (Ideal Expansion)

        // Assuming ideal expansion to ambient pressure (Pe = Pa).
        let P03 = P02

        // Calculate exit velocity (Ve) using the energy equation (isentropic nozzle)
        let pratio = Pa / P03
        let VeSquared = 2.0 * C.CP_AIR * T03 * (1.0 - pow(pratio, (C.GAMMA - 1) / C.GAMMA))

        guard VeSquared >= 0 else {
            return 0.0
        }

        let Ve = sqrt(VeSquared)

        // 5. SPECIFIC NET THRUST

        // Specific Net Thrust (F/m_dot) = (1 + f) * Ve - Va
        let specificNetThrust = (1.0 + f) * Ve - Va

        return specificNetThrust
    }
}

class RamjetEngine: PropulsionSystem {
    let name = "Ramjet"
    let machRange = 3.0...6.0
    let altitudeRange = 40000.0...100000.0 // feet

    // Air mass flow rate (kg/s) - typical for this class of ramjet
    private let airMassFlowRate = 50.0

    // Ramjet physics model
    private let model = RamjetModel()

    func getThrust(altitude: Double, speed: Double) -> Double {
        let mach = speed

        // Convert altitude from feet to meters
        let altitudeMeters = altitude * PhysicsConstants.feetToMeters

        // Calculate specific thrust using physics model
        let specificThrust = model.calculateSpecificThrust(
            altitude: altitudeMeters,
            machNumber: mach
        )

        // Convert to actual thrust using mass flow rate
        let thrust = specificThrust * airMassFlowRate

        // Ramjet needs speed to function (ram compression)
        // Gradually ramps up between Mach 2.5 and 3.0
        let ramFactor = max(0, min(1.0, (mach - 2.5) / 0.5))

        return thrust * ramFactor
    }

    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let mach = speed

        // Convert altitude from feet to meters
        let altitudeMeters = altitude * PhysicsConstants.feetToMeters

        // Calculate specific thrust to determine fuel-air ratio
        let specificThrust = model.calculateSpecificThrust(
            altitude: altitudeMeters,
            machNumber: mach
        )

        // If no thrust, no fuel consumption
        guard specificThrust > 0 else {
            return 0.0
        }

        // Approximate fuel consumption based on fuel-air ratio
        // f ≈ Cp * (T03 - T02) / Hc
        // For typical ramjet operation, f is around 0.02-0.04
        let fuelAirRatio = 0.03 // Approximate average
        let fuelMassFlow = airMassFlowRate * fuelAirRatio // kg/s

        // Convert to liters/second (slush hydrogen density: 86 kg/m³)
        let fuelVolumeLPS = fuelMassFlow / AircraftVolumeModel.slushHydrogenDensity * 1000.0

        return fuelVolumeLPS
    }
}
