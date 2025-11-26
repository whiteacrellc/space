//
//  PropulsionManager.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

enum EngineMode: String, Codable, CaseIterable {
    case auto = "Auto"
    case jet = "Jet"
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
            .jet: JetEngine(),
            .ramjet: RamjetEngine(),
            .scramjet: ScramjetEngine(),
            .rocket: RocketEngine()
        ]

        // Start with jet engine
        currentEngine = engines[.jet]!
        currentMode = .jet
    }

    /// Select the optimal engine based on efficiency at current conditions
    func selectOptimalEngine(altitude: Double, speed: Double) -> (engine: PropulsionSystem, mode: EngineMode) {
        var bestEngine: PropulsionSystem = engines[.jet]!
        var bestMode: EngineMode = .jet
        var bestEfficiency: Double = 0.0

        // Evaluate each engine type
        for (mode, engine) in engines {
            let efficiency = engine.getEfficiency(altitude: altitude, speed: speed)

            if efficiency > bestEfficiency {
                bestEfficiency = efficiency
                bestEngine = engine
                bestMode = mode
            }
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
}
