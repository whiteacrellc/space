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

    // Rocket propellant characteristics
    // Uses liquid oxygen (LOX) as oxidizer with kerosene-type fuel (RP-1)
    // Typical oxidizer-to-fuel ratio: 2.56:1 by mass
    private let oxidizerToFuelRatio = 2.56

    func getThrust(altitude: Double, speed: Double) -> Double {
        let baseThrust = 300000.0 // 300 kN

        // Rockets become MORE efficient in vacuum
        // No atmospheric back-pressure allows better nozzle expansion
        let vacuumFactor = 1.0 + (altitude / 400000.0) * 0.15

        return baseThrust * vacuumFactor
    }

    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let baseFuelRate = 120.0 // liters/second of fuel only

        // Must account for liquid oxygen (LOX) oxidizer consumption
        // Total propellant = fuel + oxidizer
        // For LOX/RP-1: ~2.56 kg oxidizer per 1 kg fuel
        let totalPropellantRate = baseFuelRate * (1.0 + oxidizerToFuelRatio)

        // Slightly more efficient in vacuum due to better nozzle expansion
        // Less wasted exhaust energy from back-pressure
        let vacuumFactor = 1.0 - (altitude / 400000.0) * 0.1

        // Return total propellant consumption (fuel + liquid oxygen)
        return totalPropellantRate * vacuumFactor
    }
}
