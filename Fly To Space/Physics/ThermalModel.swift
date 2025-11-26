//
//  ThermalModel.swift
//  Fly To Space
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
    /// Uses the recovery temperature formula for high-speed flight
    ///
    /// - Parameters:
    ///   - altitude: Altitude in meters
    ///   - velocity: Velocity in m/s
    ///   - planeDesign: Aircraft design parameters (affects heating rate)
    /// - Returns: Leading edge temperature in Celsius
    static func calculateLeadingEdgeTemperature(altitude: Double, velocity: Double, planeDesign: PlaneDesign = PlaneDesign.defaultDesign) -> Double {
        // Get atmospheric temperature at altitude
        let ambientTemp = getAtmosphericTemperature(altitude: altitude)

        // Calculate Mach number
        let speedOfSound = calculateSpeedOfSound(temperatureK: ambientTemp)
        let mach = velocity / speedOfSound

        // Recovery temperature formula
        // T_recovery = T_ambient * (1 + r * (γ-1)/2 * M^2)
        // where r is recovery factor (≈ 0.9 for turbulent boundary layer)
        let recoveryFactor = 0.9
        let gamma = 1.4 // ratio of specific heats for air

        let temperatureRatio = 1.0 + recoveryFactor * ((gamma - 1.0) / 2.0) * mach * mach
        var recoveryTemperatureK = ambientTemp * temperatureRatio

        // Apply plane design heating rate multiplier
        // Sharper leading edges heat up faster
        let heatingMultiplier = planeDesign.heatingRateMultiplier()
        let deltaT = recoveryTemperatureK - ambientTemp
        recoveryTemperatureK = ambientTemp + deltaT * heatingMultiplier

        // Convert to Celsius
        return recoveryTemperatureK - 273.15
    }

    /// Get atmospheric temperature at altitude in Kelvin
    private static func getAtmosphericTemperature(altitude: Double) -> Double {
        let temperatureK: Double

        if altitude < 11000 {
            // Troposphere: linear temperature decrease
            temperatureK = 288.15 - 0.0065 * altitude
        } else if altitude < 20000 {
            // Lower stratosphere: constant temperature
            temperatureK = 216.65
        } else {
            // Upper stratosphere: temperature increases slightly
            temperatureK = 216.65 + 0.001 * (altitude - 20000)
        }

        return max(180.0, temperatureK) // Minimum realistic temperature
    }

    /// Calculate speed of sound at given temperature
    private static func calculateSpeedOfSound(temperatureK: Double) -> Double {
        // a = sqrt(γ * R * T)
        return sqrt(1.4 * 287.0 * temperatureK)
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
