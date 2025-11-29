//
//  PropulsionEngines.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//
//  This file contains updated models for the four propulsion systems: Jet, Ramjet, Scramjet, and Rocket.
//  The APIs remain unchanged to ensure compatibility with the rest of the application.
//

import Foundation
import Darwin  // Added for exp and pow functions

// MARK: - Jet Engine (Updated for accuracy based on J58 data)

class JetEngine: PropulsionSystem {
    let name = "Jet"
    let machRange = 0.0...3.2  // J58 engine operates up to Mach 3.2
    let altitudeRange = 0.0...85000.0 // feet
    
    // Number of J58 engines (calculated based on aircraft needs)
    private var engineCount: Int = 2
    
    init(engineCount: Int = 2) {
        self.engineCount = engineCount
    }
    
    func getThrust(altitude: Double, speed: Double) -> Double {
        let mach = speed
        
        // More accurate thrust model based on SR-71 J58 data
        // Thrust decreases with altitude due to lower density, increases slightly with Mach due to ram effect
        
        // Base sea-level static thrust per engine ~145 kN dry, ~151 kN with afterburner (adjusted)
        let baseThrustPerEngine = 151000.0 // N, with AB
        
        // Density ratio
        let densityRatio = atmosphericDensity(at: altitude) / 1.225
        
        // Ram effect: thrust increases with Mach
        let ramFactor = 1.0 + 0.2 * mach * mach // Approximate quadratic increase
        
        // Altitude lapse: thrust ~ density^0.7 for turbojets
        let altitudeFactor = pow(densityRatio, 0.7)
        
        // Temperature effect: colder air at altitude helps, but simplify
        let tempFactor = 1.0 + (altitude / 100000.0) * 0.1 // Slight boost
        
        let thrustPerEngine = baseThrustPerEngine * altitudeFactor * ramFactor * tempFactor
        
        // Decay above Mach 3
        let highMachFactor = max(0.0, 1.0 - (mach - 3.0) * 2.0) // Sharp dropoff
        
        return thrustPerEngine * Double(engineCount) * highMachFactor
    }
    
    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let mach = speed
        
        // Base TSFC (thrust-specific fuel consumption) for J58 ~0.8 kg/(kN·h) dry, ~1.9 with AB
        let baseTSFC = 1.9 / 3600.0 // kg/(N·s) with AB
        
        // Fuel density for JP-7 ~800 kg/m³
        let fuelDensity = 800.0 // kg/m³
        
        // Adjust TSFC with Mach and altitude
        // TSFC increases with Mach in supersonic
        let machFactor = 1.0 + 0.5 * mach
        
        // TSFC decreases slightly with altitude due to colder air
        let altFactor = 1.0 - 0.0005 * altitude
        
        let effectiveTSFC = baseTSFC * machFactor * max(0.8, altFactor)
        
        let thrust = getThrust(altitude: altitude, speed: speed)
        
        // Mass flow rate (kg/s) = TSFC * thrust
        let fuelMassFlow = effectiveTSFC * thrust
        
        // Volume flow rate (liters/s)
        return (fuelMassFlow / fuelDensity) * 1000.0
    }
    
    func setEngineCount(_ count: Int) {
        engineCount = max(1, count)
    }
    
    func getEngineCount() -> Int {
        return engineCount
    }
}

// MARK: - Ramjet Engine (Updated for accuracy)

struct RamjetConstants {
    // Standard Atmosphere Model (ISA)
    static let T_SL: Double = 288.15     // Sea Level Temperature (K)
    static let P_SL: Double = 101325.0   // Sea Level Pressure (Pa)
    static let L: Double = 0.0065        // Tropospheric Lapse Rate (K/m)
    static let H_TROPO: Double = 11000.0 // Altitude limit of Troposphere (m)
    static let H_STRATO: Double = 20000.0 // Lower Stratosphere limit (m)
    static let G: Double = 9.80665       // Gravitational acceleration (m/s^2)
    
    // Gas Dynamics (Air)
    static let R_AIR: Double = 287.05    // Specific Gas Constant for Air (J/kg·K)
    static let GAMMA: Double = 1.4       // Ratio of Specific Heats (Cp/Cv)
    static let CP_AIR: Double = 1005.0   // Specific Heat at Constant Pressure (J/kg·K)
    
    // Fuel Properties (Hydrogen)
    static let H_C: Double = 1.2e8       // Heating Value of Hydrogen (J/kg) - approx 120 MJ/kg LHV
    
    // Engine Limits & Efficiencies
    static let T_0_MAX: Double = 2400.0  // Maximum allowable stagnation temperature (K) - Updated limit
    static let ETA_INLET: Double = 0.90  // Inlet efficiency (new)
    static let ETA_BURNER: Double = 0.95 // Combustion efficiency (new)
    static let ETA_NOZZLE: Double = 0.95 // Nozzle efficiency (new)
}

struct RamjetModel {
    
    let C = RamjetConstants.self // Alias for easier access
    
    /// Calculates ambient temperature (Ta) and pressure (Pa) based on the ISA model.
    ///
    /// - Parameters:
    ///    - h: Altitude in meters.
    ///
    /// - Returns: A tuple containing (Ta, Pa).
    func getISAProperties(altitude h: Double) -> (Ta: Double, Pa: Double) {
        
        if h <= C.H_TROPO {
            // Troposphere
            let Ta = C.T_SL - C.L * h
            let ratio = C.G / (C.L * C.R_AIR)
            let Pa = C.P_SL * pow(Ta / C.T_SL, ratio)
            return (Ta, Pa)
        } else {
            // Stratosphere (isothermal)
            let Ta_tropo = C.T_SL - C.L * C.H_TROPO
            let ratio = C.G / (C.L * C.R_AIR)
            let Pa_tropo = C.P_SL * pow(Ta_tropo / C.T_SL, ratio)
            let Ta = Ta_tropo
            let Pa = Pa_tropo * exp(-C.G * (h - C.H_TROPO) / (C.R_AIR * Ta))
            return (Ta, Pa)
        }
    }
    
    /// Calculates the specific net thrust (Net Thrust per unit Mass Flow Rate) of a
    /// hydrogen-fueled ramjet engine based on altitude and flight Mach number.
    ///
    /// Updated with component efficiencies for more accuracy.
    ///
    /// - Parameters:
    ///    - altitude: The flight altitude in meters (h).
    ///    - machNumber: The flight Mach number (M).
    ///
    /// - Returns: The specific net thrust in Newtons per kilogram of air per second (N·s/kg).
    func calculateSpecificThrust(altitude h: Double, machNumber M: Double) -> Double {
        
        // Input validation
        guard M > 1.5 else {
            return 0.0
        }
        
        // 1. ATMOSPHERIC MODEL
        let (Ta, Pa) = getISAProperties(altitude: h)
        
        // Air Speed (Va)
        let Va = M * sqrt(C.GAMMA * C.R_AIR * Ta)
        
        // 2. INLET COMPRESSION (Non-Isentropic)
        
        // Ideal Stagnation Temperature T02
        let T02_ideal = Ta * (1 + (C.GAMMA - 1) / 2.0 * pow(M, 2.0))
        
        // Actual T02 with inlet efficiency
        let T02 = Ta + C.ETA_INLET * (T02_ideal - Ta)
        
        // Ideal Pressure Ratio
        let pr_ideal = pow(T02_ideal / Ta, C.GAMMA / (C.GAMMA - 1))
        
        // Actual Pressure Ratio with efficiency
        let pr_actual = 1 + C.ETA_INLET * (pr_ideal - 1)
        let P02 = Pa * pr_actual
        
        // 3. COMBUSTION (Heat Addition)
        
        // Limit T03
        let T03 = min(C.T_0_MAX, T02 + 1200.0) // Realistic heat addition limit
        
        if T02 >= C.T_0_MAX {
            return 0.0
        }
        
        // Fuel-Air Ratio with burner efficiency
        let f = C.CP_AIR * (T03 - T02) / (C.ETA_BURNER * C.H_C)
        
        // 4. NOZZLE EXPANSION (Non-Ideal)
        
        let P03 = P02 // Assume isobaric combustion
        
        let pratio = Pa / P03
        guard pratio < 1.0 else {
            return 0.0
        }
        
        let VeSquared_ideal = 2.0 * C.CP_AIR * T03 * (1.0 - pow(pratio, (C.GAMMA - 1) / C.GAMMA))
        let VeSquared = C.ETA_NOZZLE * VeSquared_ideal
        guard VeSquared >= 0 else {
            return 0.0
        }
        
        let Ve = sqrt(VeSquared)
        
        // 5. SPECIFIC NET THRUST
        let specificNetThrust = (1.0 + f) * Ve - Va
        
        return max(0.0, specificNetThrust)
    }
}

class RamjetEngine: PropulsionSystem {
    let name = "Ramjet"
    let machRange = 2.5...5.5 // Adjusted for more accurate operational range
    let altitudeRange = 30000.0...90000.0 // feet, refined
    
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
        
        // Ram factor with smoother transition
        let ramFactor = 1.0 / (1.0 + exp(-(mach - 3.0) / 0.5)) // Sigmoid ramp
        
        return thrust * ramFactor
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
        
        // Accurate f from model
        let Ta = model.getISAProperties(altitude: altitudeMeters).Ta
        let T02_ideal = Ta * (1 + (RamjetConstants.GAMMA - 1) / 2.0 * pow(mach, 2.0))
        let T02 = Ta + RamjetConstants.ETA_INLET * (T02_ideal - Ta)
        let T03 = min(RamjetConstants.T_0_MAX, T02 + 1200.0)
        let f = RamjetConstants.CP_AIR * (T03 - T02) / (RamjetConstants.ETA_BURNER * RamjetConstants.H_C)
        
        let fuelMassFlow = airMassFlowRate * f // kg/s
        
        // Convert to liters/second
        let fuelVolumeLPS = fuelMassFlow / AircraftVolumeModel.slushHydrogenDensity * 1000.0
        
        return fuelVolumeLPS
    }
}

// MARK: - Scramjet Engine (Updated for accuracy)

struct ScramjetConstants {
    // Standard Atmosphere Model (ISA)
    static let T_SL: Double = 288.15     // Sea Level Temperature (K)
    static let P_SL: Double = 101325.0   // Sea Level Pressure (Pa)
    static let L: Double = 0.0065        // Tropospheric Lapse Rate (K/m)
    static let H_TROPO: Double = 11000.0 // Altitude limit of Troposphere (m)
    static let H_ISOTHERMAL: Double = 20000.0 // Max altitude for this simplified model (m)
    static let H_STRATOPAUSE: Double = 32000.0 // Upper limit for improved model (m)
    static let G: Double = 9.80665       // Gravitational acceleration (m/s^2)
    
    // Gas Dynamics (Air)
    static let R_AIR: Double = 287.05    // Specific Gas Constant for Air (J/kg·K)
    static let GAMMA: Double = 1.4       // Ratio of Specific Heats (Cp/Cv)
    static let CP_AIR: Double = 1005.0   // Specific Heat at Constant Pressure (J/kg·K)
    
    // Fuel Properties (Hydrogen)
    static let H_C: Double = 1.2e8       // Heating Value of Hydrogen (J/kg) - approx 120 MJ/kg LHV
    
    // Engine Limits & Scramjet Efficiencies (Typical values for M > 5 operation)
    static let T_0_MAX: Double = 2800.0  // Maximum allowable stagnation temperature (K) - Updated for advanced materials
    static let ETA_BURNER: Double = 0.85 // Combustion efficiency (Adjusted lower for supersonic challenges)
    static let SIGMA_BURNER: Double = 0.92 // Burner stagnation pressure recovery (Incorporating more losses)
}

struct ScramjetModel {
    
    let C = ScramjetConstants.self // Alias for easier access
    
    /// Calculates ambient temperature (Ta) and pressure (Pa) based on an extended ISA model,
    /// covering Troposphere (0-11km), Isothermal Stratosphere (11-20km), and upper Stratosphere (20-32km).
    ///
    /// - Parameters:
    ///    - h: Altitude in meters.
    ///
    /// - Returns: A tuple containing (Ta, Pa).
    func getISAProperties(altitude h: Double) -> (Ta: Double, Pa: Double) {
        
        // Capped altitude check for this model
        let cappedH = min(h, C.H_STRATOPAUSE)
        
        // 1. TROPOSPHERE (0 - 11 km)
        if cappedH <= C.H_TROPO {
            let Ta = C.T_SL - C.L * cappedH
            let ratio = C.G / (C.L * C.R_AIR)
            let Pa = C.P_SL * pow(Ta / C.T_SL, ratio)
            return (Ta, Pa)
        }
        
        // 2. ISOTHERMAL STRATOSPHERE (11 km - 20 km)
        else if cappedH <= C.H_ISOTHERMAL {
            // Properties at 11 km (Tropopause)
            let T_11km = C.T_SL - C.L * C.H_TROPO
            let ratio = C.G / (C.L * C.R_AIR)
            let P_11km = C.P_SL * pow(T_11km / C.T_SL, ratio)
            
            let Ta = T_11km // Constant temperature
            let exponent = -C.G * (cappedH - C.H_TROPO) / (C.R_AIR * Ta)
            let Pa = P_11km * exp(exponent)
            
            return (Ta, Pa)
        }
        
        // 3. UPPER STRATOSPHERE (20 km - 32 km) - Temperature increases linearly
        else {
            // Properties at 20 km
            let T_20km = C.T_SL - C.L * C.H_TROPO // ~216.65 K
            let ratio = C.G / (C.L * C.R_AIR)
            let P_20km = C.P_SL * pow(T_20km / C.T_SL, ratio) * exp(-C.G * (C.H_ISOTHERMAL - C.H_TROPO) / (C.R_AIR * T_20km))
            
            // Lapse rate in upper stratosphere ~ +0.001 K/m (warming)
            let L_upper = -0.001 // Negative lapse for increasing temp
            let Ta = T_20km - L_upper * (cappedH - C.H_ISOTHERMAL)
            let exponent = C.G / (L_upper * C.R_AIR)
            let Pa = P_20km * pow(Ta / T_20km, exponent)
            
            return (Ta, Pa)
        }
    }
    
    /// Calculates the Scramjet Inlet Stagnation Pressure Recovery factor (sigma_inlet).
    /// Improved empirical model incorporating multiple oblique shocks and boundary layer effects.
    ///
    /// - Parameters:
    ///    - M: The flight Mach number.
    ///
    /// - Returns: The stagnation pressure recovery ratio (P02/P01).
    private func calculateInletPressureRecovery(machNumber M: Double) -> Double {
        // Enhanced model: recovery decreases more realistically at extreme Mach
        
        if M < 4.0 {
            return 0.05 // Poor performance below M=4
        }
        
        // Empirical fit: sigma = 1 / (1 + 0.1*(M-1)^1.5) or similar
        let loss = 0.02 * pow(M, 1.8) // Increased losses at higher Mach due to stronger shocks
        var sigma = 0.95 * exp(-loss) // Max theoretical 95% at low supersonic
        
        // Additional viscous losses
        sigma *= 0.98
        
        // Cap between 0.01 and 0.95
        sigma = max(0.01, min(0.95, sigma))
        
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
        guard M >= 4.5 else { // Lowered threshold slightly for transition
            return 0.0
        }
        
        // 1. ATMOSPHERIC MODEL
        let (Ta, Pa) = getISAProperties(altitude: h)
        
        // Air Speed (Va)
        let Va = M * sqrt(C.GAMMA * C.R_AIR * Ta)
        
        // 2. INLET COMPRESSION (Non-Isentropic/Real Scramjet Inlet)
        
        // Stagnation Temperature T02 (Ideal/Isentropic)
        let T02 = Ta * (1 + (C.GAMMA - 1) / 2.0 * pow(M, 2.0))
        
        // Ideal Ram Stagnation Pressure Ratio (P01/Pa)
        let idealPratio = pow(1 + (C.GAMMA - 1) / 2.0 * pow(M, 2.0), C.GAMMA / (C.GAMMA - 1))
        
        // Actual Inlet Pressure Recovery Factor (sigma_inlet = P02 / P01)
        let sigma_inlet = calculateInletPressureRecovery(machNumber: M)
        
        // Actual Stagnation Pressure P02 (after real compression)
        let P02 = Pa * idealPratio * sigma_inlet
        
        // 3. COMBUSTION (Heat Addition - Supersonic)
        
        // T03 is limited by the material maximum temperature (T0_MAX)
        let T03 = min(C.T_0_MAX, T02 + 1500.0) // Limit heat addition for realism
        
        // Check if feasible
        if T02 >= C.T_0_MAX {
            return 0.0 // Too hot
        }
        
        // Calculate the Fuel-Air Ratio (f) required to reach T03, accounting for burner efficiency
        // f = Cp * (T03 - T02) / (Eta_b * Hc)
        let f = C.CP_AIR * (T03 - T02) / (C.ETA_BURNER * C.H_C)
        
        // 4. NOZZLE EXPANSION (Non-Ideal Expansion)
        
        // Stagnation Pressure P03 (after non-ideal combustor)
        // P03 = P02 * sigma_burner (accounts for pressure losses in the combustor)
        let P03 = P02 * C.SIGMA_BURNER
        
        // Calculate exit velocity (Ve) using the energy equation with nozzle efficiency
        let eta_nozzle = 0.95 // Added nozzle efficiency
        let pratio = Pa / P03
        
        guard pratio < 1.0 else {
            return 0.0 // No expansion
        }
        
        let VeSquared = 2.0 * eta_nozzle * C.CP_AIR * T03 * (1.0 - pow(pratio, (C.GAMMA - 1) / C.GAMMA))
        
        guard VeSquared >= 0 else {
            return 0.0
        }
        
        let Ve = sqrt(VeSquared)
        
        // 5. SPECIFIC NET THRUST
        
        // Specific Net Thrust (F/m_dot) = (1 + f) * Ve - Va + (Pe - Pa)*Ae/m_dot (but simplify, assume adapted)
        let specificNetThrust = (1.0 + f) * Ve - Va
        
        return max(0.0, specificNetThrust) // Ensure non-negative
    }
}

class ScramjetEngine: PropulsionSystem {
    let name = "Scramjet"
    let machRange = 5.0...12.0 // Adjusted for more realistic operational range
    let altitudeRange = 70000.0...150000.0 // feet, tightened for accuracy
    
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
        
        // Activation factor with smoother transition
        let activationFactor = 1.0 / (1.0 + exp(-(mach - 5.5) / 0.5)) // Sigmoid for smooth ramp
        
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
        
        // More accurate fuel-air ratio calculation from model
        let Ta = model.getISAProperties(altitude: altitudeMeters).Ta
        let T02 = Ta * (1 + (ScramjetConstants.GAMMA - 1) / 2.0 * pow(mach, 2.0))
        let T03 = min(ScramjetConstants.T_0_MAX, T02 + 1500.0)
        let f = ScramjetConstants.CP_AIR * (T03 - T02) / (ScramjetConstants.ETA_BURNER * ScramjetConstants.H_C)
        
        let fuelMassFlow = airMassFlowRate * f // kg/s
        
        // Convert to liters/second (liquid hydrogen density ~70 kg/m³, but use slush ~86 kg/m³)
        let fuelVolumeLPS = fuelMassFlow / AircraftVolumeModel.slushHydrogenDensity * 1000.0
        
        return fuelVolumeLPS
    }
}

// MARK: - Rocket Engine (Updated for accuracy based on Merlin 1D data)

class RocketEngine: PropulsionSystem {
    let name = "Rocket"
    let machRange = 0.0...30.0 // Can operate at any speed
    let altitudeRange = 0.0...400000.0 // To orbit and beyond
    
    // Rocket propellant characteristics
    // Uses liquid oxygen (LOX) as oxidizer with kerosene-type fuel (RP-1)
    // Typical oxidizer-to-fuel ratio: 2.36:1 by mass (updated from searches)
    private let oxidizerToFuelRatio = 2.36
    
    // Base sea-level values based on typical LOX/RP-1 engine (e.g., similar to Merlin 1D)
    private let seaLevelThrust = 845000.0 // 845 kN
    private let seaLevelIsp = 282.0 // seconds
    private let vacuumIsp = 311.0 // seconds
    
    // Atmospheric pressure at sea level (Pa)
    private let P0 = 101325.0
    
    func getThrust(altitude: Double, speed: Double) -> Double {
        // Calculate atmospheric pressure using simplified exponential model
        let scaleHeight = 8500.0 // meters
        let altitudeMeters = altitude * 0.3048 // Convert feet to meters
        let Patm = P0 * exp(-altitudeMeters / scaleHeight)
        
        // Nozzle expansion ratio effect: thrust increases as back pressure decreases
        // Vacuum thrust = seaLevelThrust * (vacuumIsp / seaLevelIsp)
        // Effective thrust = vacuumThrust - Ae * Patm (where Ae is exit area)
        // But simplify using Isp interpolation
        let ispFactor = (vacuumIsp - seaLevelIsp) * (1.0 - Patm / P0) + seaLevelIsp
        let thrustFactor = ispFactor / seaLevelIsp
        
        return seaLevelThrust * thrustFactor
    }
    
    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let thrust = getThrust(altitude: altitude, speed: speed)
        
        // Mass flow rate m_dot = thrust / (Isp * g0)
        // But since consumption is in liters/second of total propellant
        
        // First, get effective Isp
        let scaleHeight = 8500.0 // meters
        let altitudeMeters = altitude * 0.3048
        let Patm = P0 * exp(-altitudeMeters / scaleHeight)
        let isp = (vacuumIsp - seaLevelIsp) * (1.0 - Patm / P0) + seaLevelIsp
        
        // g0 = 9.80665 m/s²
        let g0 = 9.80665
        
        // Mass flow rate (kg/s) = thrust (N) / (Isp * g0)
        let m_dot = thrust / (isp * g0)
        
        // Total propellant density: approximate weighted average
        // RP-1 density ~810 kg/m³, LOX ~1140 kg/m³
        // Mass fraction: fuel = 1/(1+O/F), oxidizer = O/F/(1+O/F)
        let fuelFraction = 1.0 / (1.0 + oxidizerToFuelRatio)
        let oxidizerFraction = oxidizerToFuelRatio / (1.0 + oxidizerToFuelRatio)
        let avgDensity = (fuelFraction * 810.0) + (oxidizerFraction * 1140.0) // kg/m³
        
        // Volume flow rate (liters/s) = (m_dot / avgDensity) * 1000
        return (m_dot / avgDensity) * 1000.0
    }
}
