//
//  JetEngine.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

class JetEngine: PropulsionSystem {
    let name = "Jet"
    let machRange = 0.0...3.0
    let altitudeRange = 0.0...50000.0 // feet

    func getThrust(altitude: Double, speed: Double) -> Double {
        let baseThrust = 250000.0 // 250 kN baseline
        let mach = speed // Assuming speed is in Mach number

        // Atmospheric density factor (exponential decay)
        // Jets need air to breathe
        let densityFactor = exp(-altitude / 30000.0)

        // Thrust decreases with Mach number above optimal range
        // Jets are most efficient at subsonic speeds (below Mach 0.85)
        let machFactor: Double
        if mach < 0.85 {
            machFactor = 1.0
        } else {
            // Performance degrades rapidly in transonic and supersonic
            machFactor = max(0.3, 1.0 - (mach - 0.85) / 2.15)
        }

        return baseThrust * densityFactor * machFactor
    }

    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let baseConsumption = 80.0 // liters/second
        let mach = speed

        // Consumption increases with speed (especially supersonic)
        let speedFactor = 1.0 + pow(mach / 3.0, 2) * 2.0

        // Thinner air at altitude means less fuel needed (but also less thrust)
        let densityFactor = exp(-altitude / 40000.0)

        return baseConsumption * speedFactor * densityFactor
    }
}
