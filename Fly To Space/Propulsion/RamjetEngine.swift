//
//  RamjetEngine.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

class RamjetEngine: PropulsionSystem {
    let name = "Ramjet"
    let machRange = 3.0...6.0
    let altitudeRange = 40000.0...100000.0 // feet

    func getThrust(altitude: Double, speed: Double) -> Double {
        let baseThrust = 180000.0 // 180 kN
        let mach = speed

        // Ramjet needs speed to function (ram compression)
        // Gradually ramps up between Mach 2.5 and 3.0
        let ramFactor = max(0, min(1.0, (mach - 2.5) / 0.5))

        // Optimal efficiency at Mach 4-5
        let machEfficiency: Double
        if mach < 4.5 {
            // Performance increases as speed builds
            machEfficiency = 0.5 + (mach - 3.0) / 3.0
        } else {
            // Performance decreases as we exceed optimal range
            machEfficiency = max(0.4, 1.0 - (mach - 4.5) / 1.5)
        }

        // Still air-breathing, but operates at higher altitude
        let densityFactor = exp(-altitude / 35000.0)

        return baseThrust * ramFactor * machEfficiency * densityFactor
    }

    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        let baseConsumption = 60.0 // liters/second
        let mach = speed

        // More efficient than jets at high speed (no mechanical compressor)
        let speedFactor = 1.0 + pow((mach - 3.0) / 3.0, 1.5)

        return baseConsumption * speedFactor
    }
}
