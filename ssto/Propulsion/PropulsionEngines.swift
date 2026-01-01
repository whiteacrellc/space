//
//  PropulsionEngines.swift
//  ssto
//
//  Created by tom whittaker on 11/25/25.
//
//  This file contains updated models for the propulsion systems: Ejector-Ramjet, Ramjet, Scramjet, and Rocket.
//

import Foundation
import Darwin

// MARK: - Ejector-Ramjet Engine

struct EjectorRamjetConstants {
    // Similar constants to Ramjet but optimized for higher Mach/Altitude
    static let T_SL: Double = 288.15
    static let P_SL: Double = 101325.0
    static let L: Double = 0.0065
    static let H_TROPO: Double = 11000.0
    static let G: Double = 9.80665
    
    static let R_AIR: Double = 287.05
    static let GAMMA: Double = 1.4
    static let CP_AIR: Double = 1005.0
    
    static let H_C: Double = 1.2e8 // Hydrogen
    
    static let T_0_MAX: Double = 2600.0  // Higher thermal limit
    static let ETA_INLET: Double = 0.85
    static let ETA_BURNER: Double = 0.92
    static let ETA_NOZZLE: Double = 0.94
}

struct EjectorRamjetModel {
    let C = EjectorRamjetConstants.self
    
    func getISAProperties(altitude h: Double) -> (Ta: Double, Pa: Double) {
        if h <= C.H_TROPO {
            let Ta = C.T_SL - C.L * h
            let ratio = C.G / (C.L * C.R_AIR)
            let Pa = C.P_SL * pow(Ta / C.T_SL, ratio)
            return (Ta, Pa)
        } else {
            let Ta_tropo = C.T_SL - C.L * C.H_TROPO
            let ratio = C.G / (C.L * C.R_AIR)
            let Pa_tropo = C.P_SL * pow(Ta_tropo / C.T_SL, ratio)
            let Ta = Ta_tropo
            let Pa = Pa_tropo * exp(-C.G * (h - C.H_TROPO) / (C.R_AIR * Ta))
            return (Ta, Pa)
        }
    }
    
    func calculateSpecificThrust(altitude h: Double, machNumber M: Double) -> Double {
        guard M > 1.0 else { return 0.0 }
        
        let (Ta, Pa) = getISAProperties(altitude: h)
        let Va = M * sqrt(C.GAMMA * C.R_AIR * Ta)
        
        let T02_ideal = Ta * (1 + (C.GAMMA - 1) / 2.0 * pow(M, 2.0))
        let T02 = Ta + C.ETA_INLET * (T02_ideal - Ta)
        
        let pr_ideal = pow(T02_ideal / Ta, C.GAMMA / (C.GAMMA - 1))
        let pr_actual = 1 + C.ETA_INLET * (pr_ideal - 1)
        let P02 = Pa * pr_actual
        
        let T03 = min(C.T_0_MAX, T02 + 1300.0)
        
        if T02 >= C.T_0_MAX { return 0.0 }
        
        let f = C.CP_AIR * (T03 - T02) / (C.ETA_BURNER * C.H_C)
        let P03 = P02 
        
        let pratio = Pa / P03
        guard pratio < 1.0 else { return 0.0 }
        
        let VeSquared = 2.0 * C.ETA_NOZZLE * C.CP_AIR * T03 * (1.0 - pow(pratio, (C.GAMMA - 1) / C.GAMMA))
        guard VeSquared >= 0 else { return 0.0 }
        
        let Ve = sqrt(VeSquared)
        let specificNetThrust = (1.0 + f) * Ve - Va
        
        return max(0.0, specificNetThrust)
    }
}

class EjectorRamjetEngine: PropulsionSystem {
    let name = "Ejector-Ramjet"
    let machRange = 3.0...10.0
    let altitudeRange = 50000.0...150000.0 // feet
    
    private let airMassFlowRate = 60.0 // Higher mass flow
    private let model = EjectorRamjetModel()
    
    func getThrust(altitude: Double, speed: Double) -> Double {
        let mach = speed
        let altitudeMeters = altitude * PhysicsConstants.feetToMeters
        
        let specificThrust = model.calculateSpecificThrust(altitude: altitudeMeters, machNumber: mach)
        let thrust = specificThrust * airMassFlowRate
        
        // Performance curve shaping
        let ramFactor = 1.0 / (1.0 + exp(-(mach - 3.5) / 0.5))
        return thrust * ramFactor
    }
    
    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let mach = speed
        let altitudeMeters = altitude * PhysicsConstants.feetToMeters
        
        let specificThrust = model.calculateSpecificThrust(altitude: altitudeMeters, machNumber: mach)
        guard specificThrust > 0 else { return 0.0 }
        
        let Ta = model.getISAProperties(altitude: altitudeMeters).Ta
        let T02_ideal = Ta * (1 + (EjectorRamjetConstants.GAMMA - 1) / 2.0 * pow(mach, 2.0))
        let T02 = Ta + EjectorRamjetConstants.ETA_INLET * (T02_ideal - Ta)
        let T03 = min(EjectorRamjetConstants.T_0_MAX, T02 + 1300.0)
        let f = EjectorRamjetConstants.CP_AIR * (T03 - T02) / (EjectorRamjetConstants.ETA_BURNER * EjectorRamjetConstants.H_C)
        
        let fuelMassFlow = airMassFlowRate * f
        return (fuelMassFlow / AircraftVolumeModel.slushHydrogenDensity) * 1000.0
    }
}

// MARK: - Ramjet Engine (Updated)

struct RamjetConstants {
    static let T_SL: Double = 288.15
    static let P_SL: Double = 101325.0
    static let L: Double = 0.0065
    static let H_TROPO: Double = 11000.0
    static let G: Double = 9.80665
    
    static let R_AIR: Double = 287.05
    static let GAMMA: Double = 1.4
    static let CP_AIR: Double = 1005.0
    
    static let H_C: Double = 1.2e8
    
    static let T_0_MAX: Double = 2400.0
    static let ETA_INLET: Double = 0.90
    static let ETA_BURNER: Double = 0.95
    static let ETA_NOZZLE: Double = 0.95
}

struct RamjetModel {
    let C = RamjetConstants.self
    
    func getISAProperties(altitude h: Double) -> (Ta: Double, Pa: Double) {
        if h <= C.H_TROPO {
            let Ta = C.T_SL - C.L * h
            let ratio = C.G / (C.L * C.R_AIR)
            let Pa = C.P_SL * pow(Ta / C.T_SL, ratio)
            return (Ta, Pa)
        } else {
            let Ta_tropo = C.T_SL - C.L * C.H_TROPO
            let ratio = C.G / (C.L * C.R_AIR)
            let Pa_tropo = C.P_SL * pow(Ta_tropo / C.T_SL, ratio)
            let Ta = Ta_tropo
            let Pa = Pa_tropo * exp(-C.G * (h - C.H_TROPO) / (C.R_AIR * Ta))
            return (Ta, Pa)
        }
    }
    
    func calculateSpecificThrust(altitude h: Double, machNumber M: Double) -> Double {
        guard M > 1.5 else { return 0.0 }
        
        let (Ta, Pa) = getISAProperties(altitude: h)
        let Va = M * sqrt(C.GAMMA * C.R_AIR * Ta)
        
        let T02_ideal = Ta * (1 + (C.GAMMA - 1) / 2.0 * pow(M, 2.0))
        let T02 = Ta + C.ETA_INLET * (T02_ideal - Ta)
        
        let pr_ideal = pow(T02_ideal / Ta, C.GAMMA / (C.GAMMA - 1))
        let pr_actual = 1 + C.ETA_INLET * (pr_ideal - 1)
        let P02 = Pa * pr_actual
        
        let T03 = min(C.T_0_MAX, T02 + 1200.0)
        
        if T02 >= C.T_0_MAX { return 0.0 }
        
        let f = C.CP_AIR * (T03 - T02) / (C.ETA_BURNER * C.H_C)
        let P03 = P02
        
        let pratio = Pa / P03
        guard pratio < 1.0 else { return 0.0 }
        
        let VeSquared = 2.0 * C.ETA_NOZZLE * C.CP_AIR * T03 * (1.0 - pow(pratio, (C.GAMMA - 1) / C.GAMMA))
        guard VeSquared >= 0 else { return 0.0 }
        
        let Ve = sqrt(VeSquared)
        let specificNetThrust = (1.0 + f) * Ve - Va
        
        return max(0.0, specificNetThrust)
    }
}

class RamjetEngine: PropulsionSystem {
    let name = "Ramjet"
    let machRange = 2.0...8.0 // Updated
    let altitudeRange = 60000.0...120000.0 // Updated
    
    private let airMassFlowRate = 50.0
    private let model = RamjetModel()
    
    func getThrust(altitude: Double, speed: Double) -> Double {
        let mach = speed
        let altitudeMeters = altitude * PhysicsConstants.feetToMeters
        
        let specificThrust = model.calculateSpecificThrust(altitude: altitudeMeters, machNumber: mach)
        let thrust = specificThrust * airMassFlowRate
        
        let ramFactor = 1.0 / (1.0 + exp(-(mach - 2.5) / 0.5))
        return thrust * ramFactor
    }
    
    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let mach = speed
        let altitudeMeters = altitude * PhysicsConstants.feetToMeters
        
        let specificThrust = model.calculateSpecificThrust(altitude: altitudeMeters, machNumber: mach)
        guard specificThrust > 0 else { return 0.0 }
        
        let Ta = model.getISAProperties(altitude: altitudeMeters).Ta
        let T02_ideal = Ta * (1 + (RamjetConstants.GAMMA - 1) / 2.0 * pow(mach, 2.0))
        let T02 = Ta + RamjetConstants.ETA_INLET * (T02_ideal - Ta)
        let T03 = min(RamjetConstants.T_0_MAX, T02 + 1200.0)
        let f = RamjetConstants.CP_AIR * (T03 - T02) / (RamjetConstants.ETA_BURNER * RamjetConstants.H_C)
        
        let fuelMassFlow = airMassFlowRate * f
        return (fuelMassFlow / AircraftVolumeModel.slushHydrogenDensity) * 1000.0
    }
}

// MARK: - Scramjet Engine (Updated)

struct ScramjetConstants {
    static let T_SL: Double = 288.15
    static let P_SL: Double = 101325.0
    static let L: Double = 0.0065
    static let H_TROPO: Double = 11000.0
    static let H_ISOTHERMAL: Double = 20000.0
    static let H_STRATOPAUSE: Double = 32000.0
    static let G: Double = 9.80665
    
    static let R_AIR: Double = 287.05
    static let GAMMA: Double = 1.4
    static let CP_AIR: Double = 1005.0
    
    static let H_C: Double = 1.2e8
    
    static let T_0_MAX: Double = 2800.0
    static let ETA_BURNER: Double = 0.85
    static let SIGMA_BURNER: Double = 0.92
}

struct ScramjetModel {
    let C = ScramjetConstants.self
    
    func getISAProperties(altitude h: Double) -> (Ta: Double, Pa: Double) {
        let cappedH = min(h, C.H_STRATOPAUSE)
        
        if cappedH <= C.H_TROPO {
            let Ta = C.T_SL - C.L * cappedH
            let ratio = C.G / (C.L * C.R_AIR)
            let Pa = C.P_SL * pow(Ta / C.T_SL, ratio)
            return (Ta, Pa)
        } else if cappedH <= C.H_ISOTHERMAL {
            let T_11km = C.T_SL - C.L * C.H_TROPO
            let ratio = C.G / (C.L * C.R_AIR)
            let P_11km = C.P_SL * pow(T_11km / C.T_SL, ratio)
            
            let Ta = T_11km
            let exponent = -C.G * (cappedH - C.H_TROPO) / (C.R_AIR * Ta)
            let Pa = P_11km * exp(exponent)
            return (Ta, Pa)
        } else {
            let T_20km = C.T_SL - C.L * C.H_TROPO
            let ratio = C.G / (C.L * C.R_AIR)
            let P_20km = C.P_SL * pow(T_20km / C.T_SL, ratio) * exp(-C.G * (C.H_ISOTHERMAL - C.H_TROPO) / (C.R_AIR * T_20km))
            
            let L_upper = -0.001
            let Ta = T_20km - L_upper * (cappedH - C.H_ISOTHERMAL)
            let exponent = C.G / (L_upper * C.R_AIR)
            let Pa = P_20km * pow(Ta / T_20km, exponent)
            return (Ta, Pa)
        }
    }
    
    private func calculateInletPressureRecovery(machNumber M: Double) -> Double {
        if M < 4.0 { return 0.05 }
        let loss = 0.02 * pow(M, 1.8)
        var sigma = 0.95 * exp(-loss)
        sigma *= 0.98
        return max(0.01, min(0.95, sigma))
    }
    
    func calculateSpecificThrust(altitude h: Double, machNumber M: Double) -> Double {
        guard M >= 4.5 else { return 0.0 }
        
        let (Ta, Pa) = getISAProperties(altitude: h)
        let Va = M * sqrt(C.GAMMA * C.R_AIR * Ta)
        
        let T02 = Ta * (1 + (C.GAMMA - 1) / 2.0 * pow(M, 2.0))
        let idealPratio = pow(1 + (C.GAMMA - 1) / 2.0 * pow(M, 2.0), C.GAMMA / (C.GAMMA - 1))
        
        let sigma_inlet = calculateInletPressureRecovery(machNumber: M)
        let P02 = Pa * idealPratio * sigma_inlet
        
        let T03 = min(C.T_0_MAX, T02 + 1500.0)
        
        if T02 >= C.T_0_MAX { return 0.0 }
        
        let f = C.CP_AIR * (T03 - T02) / (C.ETA_BURNER * C.H_C)
        let P03 = P02 * C.SIGMA_BURNER
        
        let eta_nozzle = 0.95
        let pratio = Pa / P03
        guard pratio < 1.0 else { return 0.0 }
        
        let VeSquared = 2.0 * eta_nozzle * C.CP_AIR * T03 * (1.0 - pow(pratio, (C.GAMMA - 1) / C.GAMMA))
        guard VeSquared >= 0 else { return 0.0 }
        
        let Ve = sqrt(VeSquared)
        let specificNetThrust = (1.0 + f) * Ve - Va
        
        return max(0.0, specificNetThrust)
    }
}

class ScramjetEngine: PropulsionSystem {
    let name = "Scramjet"
    let machRange = 5.0...15.0 // Updated
    let altitudeRange = 90000.0...200000.0 // Updated
    
    private let airMassFlowRate = 40.0
    private let model = ScramjetModel()
    
    func getThrust(altitude: Double, speed: Double) -> Double {
        let mach = speed
        let altitudeMeters = altitude * PhysicsConstants.feetToMeters
        
        let specificThrust = model.calculateSpecificThrust(altitude: altitudeMeters, machNumber: mach)
        let thrust = specificThrust * airMassFlowRate
        
        let activationFactor = 1.0 / (1.0 + exp(-(mach - 5.0) / 0.5))
        return thrust * activationFactor
    }
    
    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let mach = speed
        let altitudeMeters = altitude * PhysicsConstants.feetToMeters
        
        let specificThrust = model.calculateSpecificThrust(altitude: altitudeMeters, machNumber: mach)
        guard specificThrust > 0 else { return 0.0 }
        
        let Ta = model.getISAProperties(altitude: altitudeMeters).Ta
        let T02 = Ta * (1 + (ScramjetConstants.GAMMA - 1) / 2.0 * pow(mach, 2.0))
        let T03 = min(ScramjetConstants.T_0_MAX, T02 + 1500.0)
        let f = ScramjetConstants.CP_AIR * (T03 - T02) / (ScramjetConstants.ETA_BURNER * ScramjetConstants.H_C)
        
        let fuelMassFlow = airMassFlowRate * f
        return (fuelMassFlow / AircraftVolumeModel.slushHydrogenDensity) * 1000.0
    }
}

// MARK: - Rocket Engine

class RocketEngine: PropulsionSystem {
    let name = "Rocket"
    let machRange = 0.0...30.0
    let altitudeRange = 0.0...400000.0
    
    private let oxidizerToFuelRatio = 2.36
    private let seaLevelThrust = 845000.0
    private let seaLevelIsp = 300.0
    private let vacuumIsp = 345.0
    private let P0 = 101325.0
    
    func getThrust(altitude: Double, speed: Double) -> Double {
        let scaleHeight = 8500.0
        let altitudeMeters = altitude * 0.3048
        let Patm = P0 * exp(-altitudeMeters / scaleHeight)
        
        let ispFactor = (vacuumIsp - seaLevelIsp) * (1.0 - Patm / P0) + seaLevelIsp
        let thrustFactor = ispFactor / seaLevelIsp
        
        return seaLevelThrust * thrustFactor
    }
    
    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let thrust = getThrust(altitude: altitude, speed: speed)
        
        let scaleHeight = 8500.0
        let altitudeMeters = altitude * 0.3048
        let Patm = P0 * exp(-altitudeMeters / scaleHeight)
        let isp = (vacuumIsp - seaLevelIsp) * (1.0 - Patm / P0) + seaLevelIsp
        
        let g0 = 9.80665
        let m_dot = thrust / (isp * g0)
        
        let fuelFraction = 1.0 / (1.0 + oxidizerToFuelRatio)
        let oxidizerFraction = oxidizerToFuelRatio / (1.0 + oxidizerToFuelRatio)
        let avgDensity = (fuelFraction * 810.0) + (oxidizerFraction * 1140.0)
        
        return (m_dot / avgDensity) * 1000.0
    }
}
