//
//  ThermalModel.swift
//  ssto
//
//  Created by tom whittaker on 11/26/25.
//

import Foundation

class ThermalModel {

    // Aircraft thermal limits (baseline for default design)
    static let baseMaxLeadingEdgeTemperature = 600.0 // °C
    static let maxSafeTemp = 600.0 // °C (User required constant)
    static let baseSustainedTemperature = 550.0 // °C (warning threshold)

    // Ambient temperature at sea level
    private static let seaLevelTemperatureC = 15.0 // °C
    private static let stefanBoltzmann = 5.67e-8
    private static let emissivity = 0.85
    private static let noseRadius = 0.1 // meters, baseline

    /// Get maximum temperature limit for a given plane design
    static func getMaxTemperature(for design: PlaneDesign) -> Double {
        return maxSafeTemp * design.thermalLimitMultiplier()
    }

    /// Get sustained temperature threshold for a given plane design
    static func getSustainedTemperature(for design: PlaneDesign) -> Double {
        return baseSustainedTemperature * design.thermalLimitMultiplier()
    }
    
    /// Calculate leading edge temperature (Convenience method for Feet/Mach)
    /// - Parameters:
    ///   - altitude: Altitude in Feet
    ///   - speed: Speed in Mach
    /// - Returns: Temperature in Celsius
    static func calculateTemperature(altitude: Double, speed: Double) -> Double {
        let altitudeMeters = altitude * PhysicsConstants.feetToMeters
        let speedOfSound = AtmosphereModel.speedOfSound(at: altitudeMeters)
        let velocityMps = speed * speedOfSound
        
        return calculateLeadingEdgeTemperature(altitude: altitudeMeters, velocity: velocityMps)
    }

    /// Calculate leading edge temperature due to aerodynamic heating
    /// Uses the Sutton-Graves correlation for stagnation point heat flux and balances with radiative cooling.
    ///
    /// - Parameters:
    ///   - altitude: Altitude in meters
    ///   - velocity: Velocity in m/s
    ///   - planeDesign: Aircraft design parameters (affects heating rate)
    /// - Returns: Leading edge temperature in Celsius
    static func calculateLeadingEdgeTemperature(altitude: Double, velocity: Double, planeDesign: PlaneDesign = PlaneDesign.defaultDesign) -> Double {
        // Get atmospheric conditions
        let ambientTempK = AtmosphereModel.temperature(at: altitude)
        let density = AtmosphereModel.atmosphericDensity(at: altitude)

        // Sutton-Graves approximation for convective heat flux (Stagnation Point)
        // q_dot = k * sqrt(rho / R_n) * V^3
        // k approx 1.74e-4 for Earth atmosphere (metric units)
        let k_sutton = 1.74e-4
        let heatingMultiplier = planeDesign.heatingRateMultiplier() // 1.0 for default, higher for sharp nose
        let effectiveRadius = noseRadius / heatingMultiplier // Sharp nose = small radius = high heat
        
        let q_aero = k_sutton * sqrt(density / effectiveRadius) * pow(velocity, 3)
        
        // Radiative Cooling: q_rad = epsilon * sigma * (T_wall^4 - T_ambient^4)
        // Equilibrium: q_aero = q_rad
        // T_wall^4 = (q_aero / (epsilon * sigma)) + T_ambient^4
        // T_wall = ( ... )^0.25
        
        let t_ambient_4 = pow(ambientTempK, 4)
        let t_wall_4 = (q_aero / (emissivity * stefanBoltzmann)) + t_ambient_4
        let t_wall_K = pow(t_wall_4, 0.25)
        
        // Safety clamp: Adiabatic wall temperature is the theoretical max limit
        // (if no radiation occurred). T_wall cannot exceed T_adiabatic.
        // T_adiabatic ~ T_ambient * (1 + 0.2 * M^2)
        let speedOfSound = AtmosphereModel.speedOfSound(at: altitude)
        let mach = velocity / max(1.0, speedOfSound)
        let t_adiabatic_K = ambientTempK * (1.0 + 0.2 * mach * mach)
        
        let finalTempK = min(t_wall_K, t_adiabatic_K)

        // Convert to Celsius
        return finalTempK - 273.15
    }

    /// Get thermal limit for a specific material type
    static func getMaterialLimit(materialName: String) -> Double {
        switch materialName {
        case "Aluminum": return 150.0
        case "Titanium": return 500.0
        case "Inconel": return 700.0
        case "Carbon-Carbon": return 1600.0
        default: return baseMaxLeadingEdgeTemperature
        }
    }

    /// Check if current flight conditions exceed thermal limits
    ///
    /// - Parameters:
    ///   - altitude: Altitude in meters
    ///   - velocity: Velocity in m/s
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Tuple of (isOverLimit, temperature, margin)
    static func checkThermalLimits(altitude: Double, velocity: Double, planeDesign: PlaneDesign = PlaneDesign.defaultDesign) -> (exceeded: Bool, temperature: Double, margin: Double) {
        let temperature = calculateLeadingEdgeTemperature(altitude: altitude, velocity: velocity, planeDesign: planeDesign)
        let maxTemp = getMaxTemperature(for: planeDesign)
        let margin = maxTemp - temperature
        let exceeded = temperature > maxTemp

        return (exceeded, temperature, margin)
    }

    /// Get thermal regime description
    static func getThermalRegime(temperature: Double, planeDesign: PlaneDesign = PlaneDesign.defaultDesign) -> String {
        let sustainedTemp = getSustainedTemperature(for: planeDesign)
        let maxTemp = getMaxTemperature(for: planeDesign)

        if temperature < 100 {
            return "Cool"
        } else if temperature < 300 {
            return "Warm"
        } else if temperature < sustainedTemp {
            return "Hot"
        } else if temperature < maxTemp {
            return "Critical"
        } else {
            return "OVERHEAT!"
        }
    }

    /// Calculate maximum safe velocity for given altitude
    /// This helps players plan trajectories that stay within thermal limits
    ///
    /// - Parameters:
    ///   - altitude: Altitude in meters
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Maximum safe velocity in m/s
    static func getMaxSafeVelocity(altitude: Double, planeDesign: PlaneDesign = PlaneDesign.defaultDesign) -> Double {
        let maxTemp = getMaxTemperature(for: planeDesign)

        // Binary search to find max velocity that keeps temp at limit
        var low = 0.0
        var high = 10000.0 // 10 km/s max search

        for _ in 0..<20 { // 20 iterations for convergence
            let mid = (low + high) / 2.0
            let temp = calculateLeadingEdgeTemperature(altitude: altitude, velocity: mid, planeDesign: planeDesign)

            if temp < maxTemp {
                low = mid
            } else {
                high = mid
            }
        }

        return low
    }

    /// Calculate thermal stress factor (0.0 to 1.0+)
    /// Values > 1.0 indicate structural damage risk
    static func getThermalStressFactor(temperature: Double, planeDesign: PlaneDesign = PlaneDesign.defaultDesign) -> Double {
        let maxTemp = getMaxTemperature(for: planeDesign)
        return temperature / maxTemp
    }
}
