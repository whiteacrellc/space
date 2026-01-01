//
//  Waypoint.swift
//  ssto
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

struct Waypoint: Codable, Equatable {
    var altitude: Double // feet
    var speed: Double // Mach number
    var engineMode: EngineMode // .auto, .jet, .ramjet, .scramjet, .rocket

    init(altitude: Double, speed: Double, engineMode: EngineMode = .auto) {
        self.altitude = altitude
        self.speed = speed
        self.engineMode = engineMode
    }

    /// Validate that this waypoint is physically reasonable
    func isValid() -> Bool {
        // Altitude must be non-negative
        guard altitude >= 0 else { return false }

        // Speed must be non-negative
        guard speed >= 0 else { return false }

        // Check if engine mode is appropriate for speed
        switch engineMode {
        case .ejectorRamjet:
            return speed >= 3.0 && speed <= 10.0
        case .ramjet:
            return speed >= 2.5 && speed <= 6.5
        case .scramjet:
            return speed >= 5.0 && speed <= 16.0
        case .rocket:
            return true // Rockets work at any speed
        case .auto:
            return true // Auto mode will select appropriate engine
        }
    }
}
