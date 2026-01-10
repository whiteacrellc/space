//
//  TakeoffModule.swift
//  ssto
//
//  Created by tom whittaker on 11/26/25.
//

import Foundation

class TakeoffModule {
    
    // MARK: - Constants
    
    /// Takeoff speed in knots (standard assumption for heavy aircraft)
    static let takeoffSpeedKnots: Double = 150.0
    
    /// Takeoff speed in m/s
    static let takeoffSpeedMps: Double = takeoffSpeedKnots * 0.514444
    
    /// Rolling resistance coefficient (rubber on concrete)
    static let frictionCoefficient: Double = 0.02
    
    /// Sea level altitude (meters)
    static let seaLevelAltitude: Double = 0.0
    
    // MARK: - Fuel Consumption Calculation
    
    /// Computes how much fuel is required for takeoff (0 to lift-off speed).
    /// Simulates runway acceleration integrating thrust, drag, and friction.
    ///
    /// - Parameters:
    ///   - planeDesign: The geometric design of the aircraft (for drag).
    ///   - propulsion: The propulsion system used for takeoff.
    /// - Returns: Total fuel consumed in Liters. Returns infinity if takeoff is impossible.
    static func takeoffFuelConsumption(planeDesign: PlaneDesign, propulsion: PropulsionSystem) -> Double {
        
        // 1. Determine Aircraft Mass
        // Use the standard mass calculation logic from FlightSimulator/AircraftVolumeModel
        // Assume takeoff with full fuel load
        let volumeM3 = AircraftVolumeModel.calculateInternalVolume()
        let fuelMass = volumeM3 * 1000.0 * PhysicsConstants.kgPerLiter
        let totalMass = PhysicsConstants.dryMass + fuelMass
        
        // 2. Setup Simulation
        var velocity: Double = 0.0 // m/s
        var position: Double = 0.0 // m (runway distance)
        var time: Double = 0.0     // s
        var totalFuelConsumed: Double = 0.0 // Liters
        
        let dt: Double = 0.1 // Time step
        let dragCalc = DragCalculator(planeDesign: planeDesign)
        
        // 3. Integration Loop
        while velocity < takeoffSpeedMps {
            // Altitude is 0 (Sea Level)
            let altitude = seaLevelAltitude
            
            // Check if engine can operate
            // Note: PropulsionSystem.canOperate checks Mach range.
            // At v=0, Mach=0. Ramjets/Scramjets will return false/0 thrust.
            let mach = velocity / PhysicsConstants.speedOfSoundSeaLevel // Approx
            
            // Get Thrust
            // Use 'max' to prevent negative thrust issues if engine logic fails at 0
            let thrust = max(0.0, propulsion.getThrust(altitude: altitude * PhysicsConstants.metersToFeet, speed: mach))
            
            // If thrust is zero or very low at standstill, takeoff is impossible
            if velocity < 1.0 && thrust < 1000.0 {
                print("Takeoff Impossible: Insufficient static thrust for \(propulsion.name) engine.")
                return Double.infinity
            }
            
            // Calculate Resistance Forces
            // Drag
            let drag = dragCalc.calculateDrag(altitude: altitude, velocity: velocity)
            
            // Lift (Simplified) - needed for friction reduction
            // L = 0.5 * rho * v^2 * Cl * A
            // Assume linear ramp of lift to weight at takeoff speed (rotation)
            // L_takeoff = Weight. So L(v) = Weight * (v / v_takeoff)^2
            let weight = totalMass * 9.81
            let liftRatio = pow(velocity / takeoffSpeedMps, 2.0)
            let lift = weight * liftRatio
            
            // Friction: F_f = mu * (W - L)
            let normalForce = max(0.0, weight - lift)
            let friction = frictionCoefficient * normalForce
            
            // Net Force
            let netForce = thrust - drag - friction
            
            // Acceleration
            let acceleration = netForce / totalMass
            
            // Check for stalling (not moving)
            if acceleration <= 0 && velocity < 1.0 {
                print("Takeoff Impossible: Thrust cannot overcome friction.")
                return Double.infinity
            }
            
            // Update State
            velocity += acceleration * dt
            position += velocity * dt
            time += dt
            
            // Integrate Fuel
            // getFuelConsumption returns Liters/second
            let fuelRate = propulsion.getFuelConsumption(altitude: altitude * PhysicsConstants.metersToFeet, speed: mach)
            totalFuelConsumed += fuelRate * dt
            
            // Safety break for infinite loops (e.g. accelerating too slowly)
            if time > 300.0 { // 5 minutes on runway is too long
                print("Takeoff Timeout: Acceleration too slow.")
                return Double.infinity
            }
            
            // Thermal Check (Safety)
            // Engines usually fine at sea level/low speed, but check protocol
            if propulsion.maxOperatingTemperature > 0 {
                 // Get ambient/stagnation temp from ThermalModel
                 // At low speed, T ~ T_ambient
                 // Just a placeholder check
            }
        }
        
        return totalFuelConsumed
    }
}
