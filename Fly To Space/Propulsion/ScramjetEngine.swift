//
//  ScramjetEngine.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

class ScramjetEngine: PropulsionSystem {
    let name = "Scramjet"
    let machRange = 6.0...15.0
    let altitudeRange = 80000.0...200000.0 // feet

    func getThrust(altitude: Double, speed: Double) -> Double {
        let baseThrust = 150000.0 // 150 kN
        let mach = speed

        // Needs high Mach to start supersonic combustion
        // Activation threshold around Mach 5-6
        let activationFactor = max(0, min(1.0, (mach - 5.0) / 1.0))

        // Optimal efficiency at Mach 10 (hypersonic sweet spot)
        let machEfficiency: Double
        if mach < 10.0 {
            // Performance increases up to Mach 10
            machEfficiency = 0.6 + (mach - 6.0) / 10.0
        } else {
            // Gradually decreases above Mach 10
            machEfficiency = max(0.5, 1.0 - (mach - 10.0) / 5.0)
        }

        // Air-breathing: MORE air at lower altitude = MORE thrust
        // Creates critical tradeoff: lower = more thrust but EXTREME heating at hypersonic speeds
        // Scramjets are very sensitive to air density
        let densityFactor = exp(-altitude / 50000.0)

        // Enhanced air density benefit for scramjets
        // Must balance thrust gain against thermal limits at Mach 10+
        let airMassFactor = 0.2 + 2.0 * densityFactor

        return baseThrust * activationFactor * machEfficiency * airMassFactor
    }

    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let baseConsumption = 45.0 // liters/second
        let mach = speed

        // Very efficient at design speed (supersonic combustion is efficient)
        let speedFactor = 1.0 + pow((mach - 6.0) / 9.0, 1.3)

        return baseConsumption * speedFactor
    }
}
