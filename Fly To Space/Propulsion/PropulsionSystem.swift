//
//  PropulsionSystem.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

protocol PropulsionSystem {
    var name: String { get }
    var machRange: ClosedRange<Double> { get }
    var altitudeRange: ClosedRange<Double> { get }

    // Core physics calculations
    func getThrust(altitude: Double, speed: Double) -> Double // Returns Newtons
    func getFuelConsumption(altitude: Double, speed: Double) -> Double // Returns liters/second

    // Efficiency and operational checks
    func getEfficiency(altitude: Double, speed: Double) -> Double // 0.0 to 1.0
    func canOperate(at altitude: Double, speed: Double) -> Bool
}

// Helper functions for all engines
extension PropulsionSystem {
    /// Speed of sound at given altitude (feet) - returns m/s
    func speedOfSound(at altitude: Double) -> Double {
        // Temperature decreases with altitude in troposphere
        let altitudeMeters = altitude * 0.3048
        let temperatureK: Double

        if altitudeMeters < 11000 {
            // Troposphere: linear temp decrease
            temperatureK = 288.15 - 0.0065 * altitudeMeters
        } else {
            // Stratosphere: constant temp
            temperatureK = 216.65
        }

        // Speed of sound: sqrt(gamma * R * T)
        // gamma = 1.4 for air, R = 287 J/(kg*K)
        return sqrt(1.4 * 287.0 * temperatureK)
    }

    /// Convert Mach number to meters/second at given altitude
    func machToMetersPerSecond(_ mach: Double, at altitude: Double) -> Double {
        return mach * speedOfSound(at: altitude)
    }

    /// Convert meters/second to Mach number at given altitude
    func metersPerSecondToMach(_ speed: Double, at altitude: Double) -> Double {
        return speed / speedOfSound(at: altitude)
    }

    /// Atmospheric density at altitude (feet) - returns kg/m³
    func atmosphericDensity(at altitude: Double) -> Double {
        let altitudeMeters = altitude * 0.3048
        let seaLevelDensity = 1.225 // kg/m³
        let scaleHeight = 8500.0 // meters

        return seaLevelDensity * exp(-altitudeMeters / scaleHeight)
    }

    /// Default implementation of canOperate
    func canOperate(at altitude: Double, speed: Double) -> Bool {
        let mach = speed // Assuming speed is already in Mach
        return machRange.contains(mach) && altitudeRange.contains(altitude)
    }

    /// Default implementation of getEfficiency
    func getEfficiency(altitude: Double, speed: Double) -> Double {
        guard canOperate(at: altitude, speed: speed) else { return 0.0 }

        let thrust = getThrust(altitude: altitude, speed: speed)
        let fuelConsumption = getFuelConsumption(altitude: altitude, speed: speed)

        // Efficiency = thrust per unit fuel consumption
        // Normalize to 0-1 range (higher is better)
        let efficiency = thrust / max(1.0, fuelConsumption * 1000.0)
        return min(1.0, max(0.0, efficiency))
    }
}
