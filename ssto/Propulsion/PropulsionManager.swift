//
//  PropulsionManager.swift
//  ssto
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

enum EngineMode: String, Codable, CaseIterable {
    case auto = "Auto"
    case ejectorRamjet = "Ejector-Ramjet"
    case ramjet = "Ramjet"
    case scramjet = "Scramjet"
    case rocket = "Rocket"
}

class PropulsionManager {
    private let engines: [EngineMode: PropulsionSystem]
    private(set) var currentEngine: PropulsionSystem
    private(set) var currentMode: EngineMode
    private(set) var isAutoMode: Bool = true

    init() {
        // Initialize all engines
        engines = [
            .ejectorRamjet: EjectorRamjetEngine(),
            .ramjet: RamjetEngine(),
            .scramjet: ScramjetEngine(),
            .rocket: RocketEngine()
        ]

        // Start with Rocket engine (needed for takeoff/low speed)
        currentEngine = engines[.rocket]!
        currentMode = .rocket
    }

    /// Select the optimal engine based on efficiency at current conditions
    func selectOptimalEngine(altitude: Double, speed: Double) -> (engine: PropulsionSystem, mode: EngineMode) {
        var bestEngine: PropulsionSystem = engines[.rocket]!
        var bestMode: EngineMode = .rocket
        var bestEfficiency: Double = 0.0

        // If speed is low, rocket is likely the only choice
        if speed < 2.0 {
             return (engines[.rocket]!, .rocket)
        }

        // Evaluate each engine type
        for (mode, engine) in engines {
            // Skip rocket in efficiency check if we have air-breathing options available
            // unless we are very high altitude
            if mode == .rocket && altitude < 150000 && speed > 2.0 {
                // Check if any air-breather works
                let airBreathersWork = engines.values.contains { 
                    $0.name != "Rocket" && $0.canOperate(at: altitude, speed: speed) 
                }
                if airBreathersWork { continue }
            }
            
            let efficiency = engine.getEfficiency(altitude: altitude, speed: speed)

            if efficiency > bestEfficiency {
                bestEfficiency = efficiency
                bestEngine = engine
                bestMode = mode
            }
        }
        
        // Fallback to rocket if nothing else works
        if bestEfficiency <= 0.0 {
             return (engines[.rocket]!, .rocket)
        }

        return (bestEngine, bestMode)
    }

    /// Manually set the engine mode (disables auto mode)
    func setManualEngine(_ mode: EngineMode) {
        guard mode != .auto else {
            enableAutoMode()
            return
        }

        guard let engine = engines[mode] else { return }

        isAutoMode = false
        currentEngine = engine
        currentMode = mode
    }

    /// Re-enable automatic engine selection
    func enableAutoMode() {
        isAutoMode = true
    }

    /// Update the current engine based on flight conditions
    /// Call this every frame/timestep during simulation
    func update(altitude: Double, speed: Double) {
        if isAutoMode {
            let (engine, mode) = selectOptimalEngine(altitude: altitude, speed: speed)
            currentEngine = engine
            currentMode = mode
        }
    }

    /// Get the current thrust
    func getThrust(altitude: Double, speed: Double) -> Double {
        return currentEngine.getThrust(altitude: altitude, speed: speed)
    }

    /// Get the current fuel consumption
    func getFuelConsumption(altitude: Double, speed: Double) -> Double {
        return currentEngine.getFuelConsumption(altitude: altitude, speed: speed)
    }

    /// Check if current engine can operate in given conditions
    func canOperate(at altitude: Double, speed: Double) -> Bool {
        return currentEngine.canOperate(at: altitude, speed: speed)
    }

    /// Get engine for a specific mode (useful for waypoint planning)
    func getEngine(for mode: EngineMode) -> PropulsionSystem? {
        return engines[mode]
    }

    // MARK: - Static Helper Methods

    /// Determine which engine mode to use based on flight conditions
    /// This is the canonical implementation for auto engine mode selection
    /// - Parameters:
    ///   - altitude: Altitude in feet
    ///   - speed: Speed in Mach
    /// - Returns: Recommended engine mode
    static func selectEngineMode(altitude: Double, speed: Double) -> EngineMode {
        let altitudeMeters = altitude * PhysicsConstants.feetToMeters

        // Check operating envelopes in order of efficiency
        if altitudeMeters >= PhysicsConstants.EngineLimits.scramjet.minAltitude
            && speed >= PhysicsConstants.EngineLimits.scramjet.minSpeed {
            return .scramjet
        } else if altitudeMeters >= PhysicsConstants.EngineLimits.ramjet.minAltitude
            && altitudeMeters <= PhysicsConstants.EngineLimits.ramjet.maxAltitude
            && speed >= PhysicsConstants.EngineLimits.ramjet.minSpeed
            && speed <= PhysicsConstants.EngineLimits.ramjet.maxSpeed {
            return .ramjet
        } else if altitudeMeters <= PhysicsConstants.EngineLimits.jet.maxAltitude
            && speed <= PhysicsConstants.EngineLimits.jet.maxSpeed {
            return .ejectorRamjet
        } else {
            return .rocket
        }
    }
}
