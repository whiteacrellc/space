//
//  ScramjetEngine.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

// MARK: - Scramjet Constants
struct ScramjetConstants {
    // Standard Atmosphere Model (ISA)
    static let T_SL: Double = 288.15     // Sea Level Temperature (K)
    static let P_SL: Double = 101325.0   // Sea Level Pressure (Pa)
    static let L: Double = 0.0065        // Tropospheric Lapse Rate (K/m)
    static let H_TROPO: Double = 11000.0 // Altitude limit of Troposphere (m)
    static let H_ISOTHERMAL: Double = 20000.0 // Max altitude for this simplified model (m)
    static let G: Double = 9.80665       // Gravitational acceleration (m/s^2)

    // Gas Dynamics (Air)
    static let R_AIR: Double = 287.05    // Specific Gas Constant for Air (J/kg·K)
    static let GAMMA: Double = 1.4       // Ratio of Specific Heats (Cp/Cv)
    static let CP_AIR: Double = 1005.0   // Specific Heat at Constant Pressure (J/kg·K)

    // Fuel Properties (Hydrogen)
    static let H_C: Double = 1.2e8       // Heating Value of Hydrogen (J/kg) - approx 120 MJ/kg LHV

    // Engine Limits & Scramjet Efficiencies (Typical values for M > 5 operation)
    static let T_0_MAX: Double = 2500.0  // Maximum allowable stagnation temperature (K) - Higher limit for modern materials
    static let ETA_BURNER: Double = 0.90 // Combustion efficiency (Lower than ramjet due to supersonic flow)
    static let SIGMA_BURNER: Double = 0.95 // Burner stagnation pressure recovery (due to friction/heating losses)
}

// MARK: - Scramjet Model Structure
struct ScramjetModel {

    let C = ScramjetConstants.self // Alias for easier access

    /// Calculates ambient temperature (Ta) and pressure (Pa) based on the ISA model,
    /// covering the Troposphere (0-11km) and Isothermal Stratosphere (11-20km).
    ///
    /// - Parameters:
    ///    - h: Altitude in meters.
    ///
    /// - Returns: A tuple containing (Ta, Pa).
    private func getISAProperties(altitude h: Double) -> (Ta: Double, Pa: Double) {

        // Capped altitude check for this simplified model
        guard h <= C.H_ISOTHERMAL else {
            return getISAProperties(altitude: C.H_ISOTHERMAL)
        }

        // 1. TROPOSPHERE (0 - 11 km)
        if h <= C.H_TROPO {
            let Ta = C.T_SL - C.L * h
            let ratio = C.G / (C.L * C.R_AIR)
            let Pa = C.P_SL * pow(Ta / C.T_SL, ratio)
            return (Ta, Pa)
        }

        // 2. ISOTHERMAL STRATOSPHERE (11 km - 20 km)
        else {
            // Calculate properties at 11 km (Tropopause)
            let T_11km = C.T_SL - C.L * C.H_TROPO
            let ratio = C.G / (C.L * C.R_AIR)
            let P_11km = C.P_SL * pow(T_11km / C.T_SL, ratio)

            let Ta = T_11km // Temperature is constant
            let exponent = -C.G * (h - C.H_TROPO) / (C.R_AIR * Ta)
            let Pa = P_11km * exp(exponent)

            return (Ta, Pa)
        }
    }

    /// Calculates the Scramjet Inlet Stagnation Pressure Recovery factor (sigma_inlet).
    /// This factor models shock losses in the supersonic inlet, which are severe at high Mach.
    ///
    /// - Parameters:
    ///    - M: The flight Mach number.
    ///
    /// - Returns: The stagnation pressure recovery ratio (P02/P01).
    private func calculateInletPressureRecovery(machNumber M: Double) -> Double {
        // Simple empirical model showing the recovery peaking around M=7

        if M < 4.0 {
            return 0.1 // Assume very poor performance below M=4
        }

        // Max recovery of 50%, with a parabolic drop-off from the peak Mach (M=7.0)
        let maxRecovery = 0.50
        let peakMach = 7.0
        let lossFactor = 0.025 * pow(M - peakMach, 2)

        var sigma = maxRecovery - lossFactor

        // Cap the recovery and enforce a minimum
        sigma = max(0.05, min(1.0, sigma))

        return sigma
    }

    /// Calculates the specific net thrust (Net Thrust per unit Mass Flow Rate) of a
    /// hydrogen-fueled scramjet engine based on altitude and flight Mach number.
    ///
    /// - Parameters:
    ///    - altitude: The flight altitude in meters (h).
    ///    - machNumber: The flight Mach number (M).
    ///
    /// - Returns: The specific net thrust in Newtons per kilogram of air per second (N·s/kg).
    func calculateSpecificThrust(altitude h: Double, machNumber M: Double) -> Double {

        // Input validation for scramjet operation
        guard M >= 5.0 else {
            return 0.0 // Scramjets are typically effective at high-Mach flight (M >= 5.0)
        }

        // 1. ATMOSPHERIC MODEL
        let (Ta, Pa) = getISAProperties(altitude: h)

        // Air Speed (Va)
        let Va = M * sqrt(C.GAMMA * C.R_AIR * Ta)

        // 2. INLET COMPRESSION (Non-Isentropic/Real Scramjet Inlet)

        // Stagnation Temperature T02 (Ideal/Isentropic)
        let T02 = Ta * (1 + (C.GAMMA - 1) / 2.0 * pow(M, 2))

        // Ideal Ram Stagnation Pressure Ratio (P01/Pa)
        let idealPratio = pow(1 + (C.GAMMA - 1) / 2.0 * pow(M, 2), C.GAMMA / (C.GAMMA - 1))

        // Actual Inlet Pressure Recovery Factor (sigma_inlet = P02 / P01)
        let sigma_inlet = calculateInletPressureRecovery(machNumber: M)

        // Actual Stagnation Pressure P02 (after real compression)
        let P02 = Pa * idealPratio * sigma_inlet

        // 3. COMBUSTION (Heat Addition - Supersonic)

        // T03 is limited by the material maximum temperature (T0_MAX)
        let T03 = C.T_0_MAX

        // Check if T02 already exceeds T0_MAX (Hyper-sonic speeds)
        if T02 >= C.T_0_MAX {
            return 0.0 // Engine is running too hot for fuel addition
        }

        // Calculate the Fuel-Air Ratio (f) required to reach T03, accounting for burner efficiency
        // f = Cp * (T03 - T02) / (Eta_b * Hc)
        let f = C.CP_AIR * (T03 - T02) / (C.ETA_BURNER * C.H_C)

        // 4. NOZZLE EXPANSION (Non-Ideal Expansion)

        // Stagnation Pressure P03 (after non-ideal combustor)
        // P03 = P02 * sigma_burner (accounts for pressure losses in the combustor)
        let P03 = P02 * C.SIGMA_BURNER

        // Calculate exit velocity (Ve) using the energy equation
        // Ve^2 = 2 * Cp * T03 * (1 - (Pa/P03)^((GAMMA-1)/GAMMA))
        let pratio = Pa / P03

        guard pratio < 1.0 else {
            return 0.0 // Nozzle expansion failed
        }

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

class ScramjetEngine: PropulsionSystem {
    let name = "Scramjet"
    let machRange = 6.0...15.0
    let altitudeRange = 80000.0...200000.0 // feet

    // Air mass flow rate (kg/s) - typical for scramjet
    private let airMassFlowRate = 40.0

    // Scramjet physics model
    private let model = ScramjetModel()

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

        // Needs high Mach to start supersonic combustion
        // Activation threshold around Mach 5-6
        let activationFactor = max(0, min(1.0, (mach - 5.0) / 1.0))

        return thrust * activationFactor
    }

    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let mach = speed

        // Convert altitude from feet to meters
        let altitudeMeters = altitude * PhysicsConstants.feetToMeters

        // Calculate specific thrust to determine operation
        let specificThrust = model.calculateSpecificThrust(
            altitude: altitudeMeters,
            machNumber: mach
        )

        // If no thrust, no fuel consumption
        guard specificThrust > 0 else {
            return 0.0
        }

        // Scramjets are more efficient at hypersonic speeds
        // Fuel-air ratio around 0.02-0.03 at optimal conditions
        let fuelAirRatio = 0.025
        let fuelMassFlow = airMassFlowRate * fuelAirRatio // kg/s

        // Convert to liters/second (slush hydrogen density: 86 kg/m³)
        let fuelVolumeLPS = fuelMassFlow / AircraftVolumeModel.slushHydrogenDensity * 1000.0

        return fuelVolumeLPS
    }
}
