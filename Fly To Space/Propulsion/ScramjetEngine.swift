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

        // Still air-breathing, but operates at extreme altitude
        let densityFactor = exp(-altitude / 50000.0)

        return baseThrust * activationFactor * machEfficiency * densityFactor
    }

    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let baseConsumption = 45.0 // liters/second
        let mach = speed

        // Very efficient at design speed (supersonic combustion is efficient)
        let speedFactor = 1.0 + pow((mach - 6.0) / 9.0, 1.3)

        return baseConsumption * speedFactor
    }
}
