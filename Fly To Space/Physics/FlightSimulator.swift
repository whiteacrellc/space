//
//  FlightSimulator.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

class FlightSimulator {
    // Aircraft properties
    private var altitude: Double // meters
    private var velocity: Double // m/s
    private var fuelMass: Double // kg
    private let dryMass: Double
    private let dragCoefficient: Double
    private let referenceArea: Double

    // Simulation parameters
    private let timeStep: Double
    private let maxSimulationTime: Double

    init(
        initialFuel: Double = 50000.0, // liters
        dryMass: Double = PhysicsConstants.dryMass,
        dragCoefficient: Double = PhysicsConstants.dragCoefficient,
        referenceArea: Double = PhysicsConstants.referenceArea,
        timeStep: Double = 0.1,
        maxSimulationTime: Double = 1000.0
    ) {
        self.altitude = 0
        self.velocity = 0
        self.fuelMass = initialFuel * PhysicsConstants.kgPerLiter
        self.dryMass = dryMass
        self.dragCoefficient = dragCoefficient
        self.referenceArea = referenceArea
        self.timeStep = timeStep
        self.maxSimulationTime = maxSimulationTime
    }

    /// Simulate flight between two waypoints
    func simulateSegment(
        from start: Waypoint,
        to end: Waypoint,
        propulsionManager: PropulsionManager
    ) -> FlightSegmentResult {
        // Convert to SI units
        var h = start.altitude * PhysicsConstants.feetToMeters
        var v = start.speed * PhysicsConstants.speedOfSoundSeaLevel

        let targetH = end.altitude * PhysicsConstants.feetToMeters
        let targetV = end.speed * PhysicsConstants.speedOfSoundSeaLevel

        var time = 0.0
        var fuelUsed = 0.0
        var trajectory: [TrajectoryPoint] = []

        // Set engine mode if manual
        if end.engineMode != .auto {
            propulsionManager.setManualEngine(end.engineMode)
        } else {
            propulsionManager.enableAutoMode()
        }

        // Initial trajectory point
        let initialFuelRemaining = fuelMass / PhysicsConstants.kgPerLiter
        trajectory.append(TrajectoryPoint(
            time: 0,
            altitude: start.altitude,
            speed: start.speed,
            fuelRemaining: initialFuelRemaining,
            engineMode: propulsionManager.currentMode
        ))

        // Simulation loop
        while time < maxSimulationTime {
            // Update engine selection if in auto mode
            let altitudeFeet = h * PhysicsConstants.metersToFeet
            let speedMach = v / PhysicsConstants.speedOfSoundSeaLevel
            propulsionManager.update(altitude: altitudeFeet, speed: speedMach)

            // Calculate forces
            let thrust = propulsionManager.getThrust(altitude: altitudeFeet, speed: speedMach)
            let drag = calculateDrag(altitude: h, velocity: v)
            let gravity = PhysicsConstants.gravity(at: h)
            let mass = dryMass + fuelMass

            // Net acceleration
            let acceleration = (thrust - drag) / mass - gravity

            // Update velocity and altitude
            v += acceleration * timeStep
            h += v * timeStep

            // Prevent going underground
            if h < 0 {
                h = 0
                v = max(0, v) // Can't go down if on ground
            }

            // Update fuel
            let fuelRate = propulsionManager.getFuelConsumption(altitude: altitudeFeet, speed: speedMach)
            let fuelBurnedLiters = fuelRate * timeStep
            let fuelBurnedKg = fuelBurnedLiters * PhysicsConstants.kgPerLiter
            fuelMass -= fuelBurnedKg
            fuelUsed += fuelBurnedLiters

            time += timeStep

            // Record trajectory point every 10 steps (1 second) to reduce data
            if Int(time * 10) % 10 == 0 {
                trajectory.append(TrajectoryPoint(
                    time: time,
                    altitude: h * PhysicsConstants.metersToFeet,
                    speed: v / PhysicsConstants.speedOfSoundSeaLevel,
                    fuelRemaining: max(0, fuelMass / PhysicsConstants.kgPerLiter),
                    engineMode: propulsionManager.currentMode
                ))
            }

            // Check termination conditions
            if fuelMass <= 0 {
                print("Simulation ended: Out of fuel")
                break
            }

            // Check if we've reached the target (within tolerance)
            let altitudeDiff = abs(h - targetH)
            let velocityDiff = abs(v - targetV)

            if altitudeDiff < 1000 && velocityDiff < 50 {
                // Close enough to target
                break
            }

            // Check if we're moving away from target (diverging)
            if time > 10 {
                // If we're far from target and not making progress, give up
                if altitudeDiff > 50000 || v < 0 {
                    print("Simulation ended: Cannot reach target")
                    break
                }
            }
        }

        // Update simulator state for next segment
        self.altitude = h
        self.velocity = v

        // Create final trajectory point
        trajectory.append(TrajectoryPoint(
            time: time,
            altitude: h * PhysicsConstants.metersToFeet,
            speed: v / PhysicsConstants.speedOfSoundSeaLevel,
            fuelRemaining: max(0, fuelMass / PhysicsConstants.kgPerLiter),
            engineMode: propulsionManager.currentMode
        ))

        return FlightSegmentResult(
            trajectory: trajectory,
            fuelUsed: fuelUsed,
            finalAltitude: h * PhysicsConstants.metersToFeet,
            finalSpeed: v / PhysicsConstants.speedOfSoundSeaLevel,
            duration: time,
            engineUsed: propulsionManager.currentMode
        )
    }

    /// Calculate drag force
    private func calculateDrag(altitude: Double, velocity: Double) -> Double {
        let density = PhysicsConstants.atmosphericDensity(at: altitude)
        // Drag = 0.5 * ρ * v² * C_d * A
        return 0.5 * density * velocity * velocity * dragCoefficient * referenceArea
    }

    /// Reset simulator state
    func reset(fuelLiters: Double = 50000.0) {
        self.altitude = 0
        self.velocity = 0
        self.fuelMass = fuelLiters * PhysicsConstants.kgPerLiter
    }

    /// Get current fuel remaining in liters
    func getFuelRemaining() -> Double {
        return max(0, fuelMass / PhysicsConstants.kgPerLiter)
    }
}
