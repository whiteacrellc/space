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
    static let baseSustainedTemperature = 550.0 // °C (warning threshold)

    // Ambient temperature at sea level
    private static let seaLevelTemperatureC = 15.0 // °C

    /// Get maximum temperature limit for a given plane design
    static func getMaxTemperature(for design: PlaneDesign) -> Double {
        return baseMaxLeadingEdgeTemperature * design.thermalLimitMultiplier()
    }

    /// Get sustained temperature threshold for a given plane design
    static func getSustainedTemperature(for design: PlaneDesign) -> Double {
        return baseSustainedTemperature * design.thermalLimitMultiplier()
    }

    /// Calculate leading edge temperature due to aerodynamic heating
    /// Uses the recovery temperature formula for high-speed flight, refined with radiative cooling.
    ///
    /// - Parameters:
    ///   - altitude: Altitude in meters
    ///   - velocity: Velocity in m/s
    ///   - planeDesign: Aircraft design parameters (affects heating rate)
    /// - Returns: Leading edge temperature in Celsius
    static func calculateLeadingEdgeTemperature(altitude: Double, velocity: Double, planeDesign: PlaneDesign = PlaneDesign.defaultDesign) -> Double {
        // Get atmospheric temperature at altitude from the shared model
        let ambientTemp = AtmosphereModel.temperature(at: altitude)

        // Calculate Mach number
        let speedOfSound = AtmosphereModel.speedOfSound(at: altitude)
        let mach = velocity / speedOfSound
        
        // Avoid singularities at zero speed
        if velocity < 1.0 { return ambientTemp - 273.15 }

        // Recovery temperature formula (Adiabatic Wall Temperature)
        // T_recovery = T_ambient * (1 + r * (γ-1)/2 * M^2)
        // where r is recovery factor (≈ 0.9 for turbulent boundary layer)
        let recoveryFactor = 0.9
        let gamma = 1.4 // ratio of specific heats for air

        let temperatureRatio = 1.0 + recoveryFactor * ((gamma - 1.0) / 2.0) * mach * mach
        let adiabaticWallTempK = ambientTemp * temperatureRatio

        // Apply plane design heating rate multiplier (geometric concentration)
        // Sharper leading edges heat up faster, effectively increasing the convection coefficient's impact
        // or the stagnation point temperature factor.
        // For simplicity, we apply it as a modifier to the recovery factor delta.
        let heatingMultiplier = planeDesign.heatingRateMultiplier()
        let effectiveAdiabaticWallTempK = ambientTemp + (adiabaticWallTempK - ambientTemp) * heatingMultiplier
        
        // Stefan-Boltzmann Radiative Equilibrium:
        // Q_aero = Q_rad
        // h * (T_aw - T_w) = epsilon * sigma * T_w^4
        //
        // This requires an estimate of h (convective heat transfer coefficient).
        // Approximation for stagnation point heat transfer (Sutton-Graves):
        // q_dot = k * sqrt(rho / R_nose) * V^3
        // h = q_dot / (T_aw - T_w)
        //
        // Simplifying for this simulation:
        // We iterate to find T_w where Q_in == Q_out
        
        let density = AtmosphereModel.atmosphericDensity(at: altitude)
        // Approximate nose radius (m) - sharper is smaller
        let noseRadius = 0.1 / heatingMultiplier 
        // Sutton-Graves constant (approx for earth atmosphere)
        let k_sutton = 1.7415e-4 
        
        let q_aero_approx = k_sutton * sqrt(density / noseRadius) * pow(velocity, 3.0)
        
        // If q is small, T_w ~= T_aw
        if q_aero_approx < 1.0 {
             return effectiveAdiabaticWallTempK - 273.15
        }
        
        // Iterative solution for T_wall
        // epsilon * sigma * T_w^4 = q_aero_approx * (1 - T_w/T_aw) ?? 
        // Actually, Sutton-Graves gives q directly assuming cold wall? 
        // A better balance equation:
        // h * (T_aw - T_w) = sigma * epsilon * T_w^4
        // Estimate h from the q formula: h ~= q_sutton / (T_aw - T_ambient) roughly
        
        let sigma = 5.670374419e-8
        let epsilon = 0.8 // Emissivity of thermal protection system
        
        // Initial guess
        var t_wall = effectiveAdiabaticWallTempK
        let h_est = q_aero_approx / max(1.0, (effectiveAdiabaticWallTempK - ambientTemp))
        
        // Newton-Raphson
        for _ in 0..<5 {
            let f = h_est * (effectiveAdiabaticWallTempK - t_wall) - sigma * epsilon * pow(t_wall, 4.0)
            let df = -h_est - 4.0 * sigma * epsilon * pow(t_wall, 3.0)
            let dt = f / df
            t_wall = t_wall - dt
            if abs(dt) < 0.1 { break }
        }

        return t_wall - 273.15
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

    // Private helpers removed in favor of AtmosphereModel


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
