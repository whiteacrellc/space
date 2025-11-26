//
//  RocketEngine.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

class RocketEngine: PropulsionSystem {
    let name = "Rocket"
    let machRange = 0.0...30.0 // Can operate at any speed
    let altitudeRange = 0.0...400000.0 // To orbit and beyond

    func getThrust(altitude: Double, speed: Double) -> Double {
        let baseThrust = 300000.0 // 300 kN

        // Rockets actually become MORE efficient in vacuum
        // No atmospheric back-pressure
        let vacuumFactor = 1.0 + (altitude / 400000.0) * 0.15

        return baseThrust * vacuumFactor
    }

    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let baseConsumption = 120.0 // liters/second

        // Relatively constant consumption (carries own oxidizer)
        // Slightly more efficient in vacuum (better expansion)
        let vacuumFactor = 1.0 - (altitude / 400000.0) * 0.1

        return baseConsumption * vacuumFactor
    }
}
