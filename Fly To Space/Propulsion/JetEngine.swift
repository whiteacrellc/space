//
//  JetEngine.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

class JetEngine: PropulsionSystem {
    let name = "Jet"
    let machRange = 0.0...3.2  // J58 engine operates up to Mach 3.2
    let altitudeRange = 0.0...85000.0 // feet

    // Number of J58 engines (calculated based on aircraft needs)
    private var engineCount: Int = 2

    init(engineCount: Int = 2) {
        self.engineCount = engineCount
    }

    func getThrust(altitude: Double, speed: Double) -> Double {
        let mach = speed
        return AircraftVolumeModel.j58TotalThrust(
            engineCount: engineCount,
            altitude: altitude,
            mach: mach
        )
    }

    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        // Base consumption rate from J58 specs
        let baseRate = AircraftVolumeModel.j58FuelConsumptionRate(engineCount: engineCount)

        let mach = speed

        // Consumption increases with Mach number (afterburner usage)
        let speedFactor: Double
        if mach < 1.0 {
            speedFactor = 1.0
        } else if mach < 3.0 {
            // Increased consumption in supersonic regime
            speedFactor = 1.0 + (mach - 1.0) * 0.5
        } else {
            // Maximum consumption at high Mach
            speedFactor = 2.0
        }

        // Altitude affects efficiency slightly
        let altitudeFactor = 1.0 - (altitude / 100000.0) * 0.1

        return baseRate * speedFactor * max(0.5, altitudeFactor)
    }

    func setEngineCount(_ count: Int) {
        engineCount = max(1, count)
    }

    func getEngineCount() -> Int {
        return engineCount
    }
}
