//
//  ThermalModel.swift
//  ssto
//
//  Thermal model for SSTO aircraft with active fuel cooling
//
//  ACTIVE COOLING SYSTEM:
//  The aircraft uses regenerative cooling by routing fuel through the leading edge
//  structure before it reaches the engines. This is similar to systems used in:
//  - SR-71 Blackbird (fuel used to cool hydraulic fluid and inlet structures)
//  - X-15 (liquid oxygen used for cooling)
//  - Space Shuttle (liquid hydrogen cooling for leading edges)
//
//  Heat Balance Equation:
//  q_aero = q_radiation + q_fuel_cooling
//
//  Where:
//  - q_aero: Aerodynamic heating (Sutton-Graves correlation)
//  - q_radiation: Passive radiative cooling (Stefan-Boltzmann)
//  - q_fuel_cooling: Active cooling via fuel flow = m_dot * c_p * ΔT * efficiency
//
//  Fuel Properties:
//  - Jet fuel (Jet-A): c_p = 2,000 J/(kg·K)
//  - Liquid hydrogen: c_p = 14,300 J/(kg·K) - 7x more effective!
//
//  Maximum fuel temperature rise: 200°C (to prevent coking/boiling)
//  Cooling efficiency: 150% (advanced heat exchanger with extended surface area)
//

import Foundation

class ThermalModel {

    // Aircraft thermal limits (baseline for default design)
    static let baseMaxLeadingEdgeTemperature = 1700.0 // °C
    static let maxSafeTemp = 1700.0 // °C (User required constant)
    static let baseSustainedTemperature = 1600.0 // °C (warning threshold)

    // Ambient temperature at sea level
    private static let seaLevelTemperatureC = 15.0 // °C
    private static let stefanBoltzmann = 5.67e-8
    private static let emissivity = 0.85
    private static let noseRadius = 0.1 // meters, baseline

    // Active cooling parameters
    private static let fuelSpecificHeat = 2000.0 // J/(kg·K) for jet fuel (Jet-A)
    private static let hydrogenSpecificHeat = 14300.0 // J/(kg·K) for liquid hydrogen
    private static let fuelMaxTemperatureRise = 200.0 // °C - max allowed fuel temperature increase
    private static let coolingEfficiency = 1.5 // 150% efficiency - advanced heat exchanger design with extended surface area

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
    ///   - fuelFlowRate: Fuel mass flow rate through leading edge cooling in kg/s (0 = no active cooling)
    ///   - useHydrogen: If true, uses hydrogen fuel properties; otherwise uses jet fuel
    /// - Returns: Leading edge temperature in Celsius
    static func calculateLeadingEdgeTemperature(altitude: Double, velocity: Double, planeDesign: PlaneDesign = PlaneDesign.defaultDesign, fuelFlowRate: Double = 0.0, useHydrogen: Bool = false) -> Double {
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

        // Active cooling: Fuel flows through leading edge structure
        // q_fuel = m_dot * c_p * ΔT * efficiency
        // Maximum cooling limited by fuel temperature rise
        let fuelCp = useHydrogen ? hydrogenSpecificHeat : fuelSpecificHeat
        let maxCoolingPower = fuelFlowRate * fuelCp * fuelMaxTemperatureRise * coolingEfficiency // Watts

        // Net heat that must be radiated after active cooling
        let q_net = max(0.0, q_aero - maxCoolingPower)

        // Radiative Cooling: q_rad = epsilon * sigma * (T_wall^4 - T_ambient^4)
        // Equilibrium: q_net = q_rad
        // T_wall^4 = (q_net / (epsilon * sigma)) + T_ambient^4
        // T_wall = ( ... )^0.25

        let t_ambient_4 = pow(ambientTempK, 4)
        let t_wall_4 = (q_net / (emissivity * stefanBoltzmann)) + t_ambient_4
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

    /// Calculate cooling power provided by fuel flow
    /// - Parameters:
    ///   - fuelFlowRate: Fuel mass flow rate in kg/s
    ///   - useHydrogen: If true, uses hydrogen fuel properties
    /// - Returns: Cooling power in Watts
    static func calculateCoolingPower(fuelFlowRate: Double, useHydrogen: Bool = false) -> Double {
        let fuelCp = useHydrogen ? hydrogenSpecificHeat : fuelSpecificHeat
        return fuelFlowRate * fuelCp * fuelMaxTemperatureRise * coolingEfficiency
    }

    /// Calculate required fuel flow rate to maintain target temperature
    /// - Parameters:
    ///   - altitude: Altitude in meters
    ///   - velocity: Velocity in m/s
    ///   - targetTemperature: Target leading edge temperature in °C
    ///   - planeDesign: Aircraft design parameters
    ///   - useHydrogen: If true, uses hydrogen fuel properties
    /// - Returns: Required fuel flow rate in kg/s (0 if passive cooling sufficient)
    static func getRequiredFuelFlowForCooling(altitude: Double, velocity: Double, targetTemperature: Double, planeDesign: PlaneDesign = PlaneDesign.defaultDesign, useHydrogen: Bool = false) -> Double {
        // First check temperature without active cooling
        let passiveTemp = calculateLeadingEdgeTemperature(altitude: altitude, velocity: velocity, planeDesign: planeDesign, fuelFlowRate: 0.0)

        if passiveTemp <= targetTemperature {
            return 0.0 // No active cooling needed
        }

        // Calculate aerodynamic heating
        let ambientTempK = AtmosphereModel.temperature(at: altitude)
        let density = AtmosphereModel.atmosphericDensity(at: altitude)
        let k_sutton = 1.74e-4
        let heatingMultiplier = planeDesign.heatingRateMultiplier()
        let effectiveRadius = noseRadius / heatingMultiplier
        let q_aero = k_sutton * sqrt(density / effectiveRadius) * pow(velocity, 3)

        // Calculate required radiative cooling at target temp
        let targetTempK = targetTemperature + 273.15
        let t_ambient_4 = pow(ambientTempK, 4)
        let t_target_4 = pow(targetTempK, 4)
        let q_rad = emissivity * stefanBoltzmann * (t_target_4 - t_ambient_4)

        // Required active cooling
        let q_fuel_needed = max(0.0, q_aero - q_rad)

        // Convert to fuel flow rate
        let fuelCp = useHydrogen ? hydrogenSpecificHeat : fuelSpecificHeat
        let requiredFlowRate = q_fuel_needed / (fuelCp * fuelMaxTemperatureRise * coolingEfficiency)

        return requiredFlowRate
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
    ///   - fuelFlowRate: Fuel mass flow rate for active cooling in kg/s (0 = no active cooling)
    ///   - useHydrogen: If true, uses hydrogen fuel properties
    /// - Returns: Tuple of (isOverLimit, temperature, margin)
    static func checkThermalLimits(altitude: Double, velocity: Double, planeDesign: PlaneDesign = PlaneDesign.defaultDesign, fuelFlowRate: Double = 0.0, useHydrogen: Bool = false) -> (exceeded: Bool, temperature: Double, margin: Double) {
        let temperature = calculateLeadingEdgeTemperature(altitude: altitude, velocity: velocity, planeDesign: planeDesign, fuelFlowRate: fuelFlowRate, useHydrogen: useHydrogen)
        let maxTemp = getMaxTemperature(for: planeDesign)
        let margin = maxTemp - temperature
        let exceeded = temperature > maxTemp

        return (exceeded, temperature, margin)
    }

    /// Calculate temperature reduction from active cooling
    /// - Parameters:
    ///   - altitude: Altitude in meters
    ///   - velocity: Velocity in m/s
    ///   - fuelFlowRate: Fuel mass flow rate in kg/s
    ///   - planeDesign: Aircraft design parameters
    ///   - useHydrogen: If true, uses hydrogen fuel properties
    /// - Returns: Temperature reduction in °C
    static func getCoolingBenefit(altitude: Double, velocity: Double, fuelFlowRate: Double, planeDesign: PlaneDesign = PlaneDesign.defaultDesign, useHydrogen: Bool = false) -> Double {
        let tempWithoutCooling = calculateLeadingEdgeTemperature(altitude: altitude, velocity: velocity, planeDesign: planeDesign, fuelFlowRate: 0.0)
        let tempWithCooling = calculateLeadingEdgeTemperature(altitude: altitude, velocity: velocity, planeDesign: planeDesign, fuelFlowRate: fuelFlowRate, useHydrogen: useHydrogen)
        return tempWithoutCooling - tempWithCooling
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
    ///   - fuelFlowRate: Fuel mass flow rate for active cooling in kg/s (0 = no active cooling)
    ///   - useHydrogen: If true, uses hydrogen fuel properties
    /// - Returns: Maximum safe velocity in m/s
    static func getMaxSafeVelocity(altitude: Double, planeDesign: PlaneDesign = PlaneDesign.defaultDesign, fuelFlowRate: Double = 0.0, useHydrogen: Bool = false) -> Double {
        let maxTemp = getMaxTemperature(for: planeDesign)

        // Binary search to find max velocity that keeps temp at limit
        var low = 0.0
        var high = 10000.0 // 10 km/s max search

        for _ in 0..<20 { // 20 iterations for convergence
            let mid = (low + high) / 2.0
            let temp = calculateLeadingEdgeTemperature(altitude: altitude, velocity: mid, planeDesign: planeDesign, fuelFlowRate: fuelFlowRate, useHydrogen: useHydrogen)

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

    // MARK: - Active Cooling Demonstration

    /// Print examples demonstrating active cooling effectiveness
    /// This shows how fuel flow through leading edges reduces temperature
    static func demonstrateActiveCooling() {
        print("\n========== ACTIVE COOLING DEMONSTRATION ==========")
        print("Fuel flowing through leading edge structure before engines\n")

        let testCases: [(altitude: Double, mach: Double, description: String)] = [
            (50000, 3.0, "High subsonic cruise (SR-71 regime)"),
            (80000, 5.0, "Hypersonic transition"),
            (100000, 8.0, "High hypersonic"),
            (150000, 12.0, "Near-orbital velocity")
        ]

        let planeDesign = PlaneDesign.defaultDesign

        for testCase in testCases {
            let altitudeMeters = testCase.altitude * PhysicsConstants.feetToMeters
            let speedOfSound = AtmosphereModel.speedOfSound(at: altitudeMeters)
            let velocity = testCase.mach * speedOfSound

            print("─────────────────────────────────────────────")
            print("\(testCase.description)")
            print("Altitude: \(Int(testCase.altitude)) ft, Mach \(String(format: "%.1f", testCase.mach))")

            // Without active cooling
            let tempPassive = calculateLeadingEdgeTemperature(altitude: altitudeMeters, velocity: velocity, planeDesign: planeDesign)

            // With jet fuel cooling at 5 kg/s
            let fuelFlow = 5.0 // kg/s
            let tempJetFuel = calculateLeadingEdgeTemperature(altitude: altitudeMeters, velocity: velocity, planeDesign: planeDesign, fuelFlowRate: fuelFlow, useHydrogen: false)
            let coolingJet = tempPassive - tempJetFuel

            // With hydrogen cooling at 5 kg/s
            let tempHydrogen = calculateLeadingEdgeTemperature(altitude: altitudeMeters, velocity: velocity, planeDesign: planeDesign, fuelFlowRate: fuelFlow, useHydrogen: true)
            let coolingH2 = tempPassive - tempHydrogen

            // Calculate required flow to stay at safe limit
            let maxTemp = getMaxTemperature(for: planeDesign)
            let requiredFlowJet = getRequiredFuelFlowForCooling(altitude: altitudeMeters, velocity: velocity, targetTemperature: maxTemp, planeDesign: planeDesign, useHydrogen: false)
            let requiredFlowH2 = getRequiredFuelFlowForCooling(altitude: altitudeMeters, velocity: velocity, targetTemperature: maxTemp, planeDesign: planeDesign, useHydrogen: true)

            print(String(format: "  Passive cooling only:      %.0f°C %@", tempPassive, tempPassive > maxTemp ? "⚠️ OVERHEAT" : "✓"))
            print(String(format: "  + Jet fuel (5 kg/s):       %.0f°C (-%d°C) %@", tempJetFuel, Int(coolingJet), tempJetFuel > maxTemp ? "⚠️" : "✓"))
            print(String(format: "  + Hydrogen (5 kg/s):       %.0f°C (-%d°C) %@", tempHydrogen, Int(coolingH2), tempHydrogen > maxTemp ? "⚠️" : "✓"))

            if requiredFlowJet > 0 {
                print(String(format: "  Required flow (jet fuel):  %.1f kg/s to stay at %d°C", requiredFlowJet, Int(maxTemp)))
            }
            if requiredFlowH2 > 0 {
                print(String(format: "  Required flow (hydrogen):  %.1f kg/s to stay at %d°C", requiredFlowH2, Int(maxTemp)))
            }
            print()
        }

        print("=================================================\n")
        print("KEY INSIGHTS:")
        print("• Liquid hydrogen is ~7x more effective than jet fuel")
        print("• Active cooling enables higher speeds/lower altitudes")
        print("• Fuel must flow before it's burned in engines")
        print("• Max fuel temp rise: 200°C to prevent coking/boiling\n")
    }
}
