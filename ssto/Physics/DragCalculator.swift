import Foundation

/**
 A Swift module for calculating aerodynamic properties, specifically the Drag Coefficient (Cd),
 for an aircraft at various flight regimes.

 The calculation relies on a simplified International Standard Atmosphere (ISA) model to determine
 air density and speed of sound at the given altitude, and a piecewise function to estimate Cd
 based on the resultant Mach number and altitude.

 Assumptions:
 - Altitude is in meters (m).
 - Velocity is in meters per second (m/s).
 - The drag coefficient is estimated for a streamlined aircraft across different Mach regimes.
 */
class DragCalculator {

    // Aircraft characteristics
    private let referenceArea: Double
    private let baselineDragCoefficient: Double
    private let planeDesign: PlaneDesign

    init(referenceArea: Double = PhysicsConstants.referenceArea,
         baselineDragCoefficient: Double = PhysicsConstants.dragCoefficient,
         planeDesign: PlaneDesign = PlaneDesign.defaultDesign) {
        self.referenceArea = referenceArea
        self.baselineDragCoefficient = baselineDragCoefficient
        self.planeDesign = planeDesign
    }
    
    // --- Atmospheric Constants (International Standard Atmosphere) ---
    private static let R: Double = 287.05287       // Specific gas constant for dry air (J/kg·K)
    private static let GAMMA: Double = 1.4         // Adiabatic index (ratio of specific heats)
    private static let g0: Double = 9.80665        // Standard gravitational acceleration (m/s^2)
    private static let T0: Double = 288.15         // Sea-level temperature (K)
    private static let RHO0: Double = 1.225        // Sea-level density (kg/m^3)
    private static let L_RATE: Double = -0.0065    // Temperature lapse rate in troposphere (K/m)
    private static let H_TROPO: Double = 11000.0   // Altitude of the tropopause (m)
    
    // MARK: - Atmospheric Calculations
    
    /**
     Calculates the speed of sound and air density for a given altitude using the ISA model.
     
     - Parameter altitude_m: The altitude above sea level in meters.
     - Returns: A tuple containing the speed of sound (m/s) and air density (kg/m^3).
     */
    private static func getAtmosphericData(altitude_m: Double) -> (speedOfSound: Double, density: Double) {
        
        let altitude = max(0, altitude_m) // Ensure altitude is non-negative
        
        // 1. Calculate Temperature (Troposphere up to 11 km)
        var T: Double
        if altitude <= H_TROPO {
            // Troposphere (constant temperature lapse rate)
            T = T0 + L_RATE * altitude
        } else {
            // Stratosphere (isothermal layer, assuming constant temp at tropopause)
            T = T0 + L_RATE * H_TROPO
        }
        
        // 2. Calculate Speed of Sound (a = sqrt(gamma * R * T))
        let a = sqrt(GAMMA * R * T)
        
        // 3. Calculate Density (Rho)
        var rho: Double
        if altitude <= H_TROPO {
            // Troposphere density calculation
            let exponent = (-g0 / (L_RATE * R)) - 1.0
            rho = RHO0 * pow(T / T0, exponent)
        } else {
            // Stratosphere density (isothermal layer)
            let T_tropo = T0 + L_RATE * H_TROPO
            let rho_tropo = RHO0 * pow(T_tropo / T0, (-g0 / (L_RATE * R)) - 1.0)
            
            // P/P_tropo = exp(-g0 * (h - h_tropo) / (R * T_tropo))
            let P_ratio = exp(-g0 * (altitude - H_TROPO) / (R * T_tropo))
            rho = rho_tropo * P_ratio
        }
        
        return (a, rho)
    }
    
    // MARK: - Drag Coefficient Model
    
    /**
     Estimates the Drag Coefficient (Cd) of a streamlined aircraft based on Mach number and altitude.

     Aircraft drag varies significantly across flight regimes, with transonic drag rise
     being particularly important for reaching orbit.

     - Parameters:
       - Ma: The Mach number (velocity / speed of sound).
       - altitude_m: Altitude in meters
     - Returns: The estimated Drag Coefficient (unitless).
     */
    private func getDragCoefficient(Ma: Double, altitude_m: Double) -> Double {
        var cd = baselineDragCoefficient

        if Ma < 0.8 {
            // Subsonic flow: Low drag for streamlined aircraft
            cd = baselineDragCoefficient * 1.0

        } else if Ma < 1.2 {
            // Transonic flow (0.8 <= Ma < 1.2): Dramatic drag rise
            // Wave drag begins, shock waves form
            let delta = Ma - 0.8
            let dragRiseMultiplier = 1.0 + delta * delta * 15.0
            cd = baselineDragCoefficient * dragRiseMultiplier

        } else if Ma < 5.0 {
            // Supersonic flow (Ma >= 1.2): High wave drag, decreases with Mach
            // Peak drag just past Mach 1, then gradually decreases
            let supersonicFactor = 1.2 / Ma
            let waveDragMultiplier = 5.0 + supersonicFactor * 4.0
            cd = baselineDragCoefficient * waveDragMultiplier

        } else {
            // Hypersonic flow (Ma >= 5.0): Drag Coefficient decreases asymptotically
            // At high Mach, wave drag coefficient decreases (roughly 1/M^2 trend),
            // but viscous interaction increases.
            // We model a decay from the supersonic level (~6.0) down to a high-speed floor (~2.5).
            let decay = exp(-(Ma - 5.0) / 10.0)
            cd = baselineDragCoefficient * (2.5 + 3.5 * decay)
        }

        // Altitude effects: rarefied flow at extreme altitudes
        cd *= getAltitudeFactor(altitude_m: altitude_m)

        // Apply plane design drag multiplier
        cd *= planeDesign.dragMultiplier()

        return cd
    }

    /**
     Calculate altitude correction factor for drag coefficient.
     At extreme altitudes, rarefied flow changes drag characteristics.

     - Parameter altitude_m: Altitude in meters
     - Returns: Correction factor (0.0 to 1.0+)
     */
    private func getAltitudeFactor(altitude_m: Double) -> Double {
        if altitude_m < 15000 {
            // Dense atmosphere: normal drag
            return 1.0
        } else if altitude_m < 30000 {
            // Upper atmosphere: slight decrease
            let transitionFactor = (altitude_m - 15000) / 15000
            return 1.0 - transitionFactor * 0.05
        } else if altitude_m < 60000 {
            // Very high altitude: rarefied flow begins
            let rarefiedFactor = (altitude_m - 30000) / 30000
            return 0.95 - rarefiedFactor * 0.2
        } else {
            // Near-vacuum: minimal drag
            return 0.75 * exp(-(altitude_m - 60000) / 30000)
        }
    }
    
    // MARK: - Public API

    /**
     Calculate drag force acting on the aircraft.

     Uses accurate Mach-dependent drag coefficients and atmospheric models.

     - Parameters:
       - altitude: Altitude in meters
       - velocity: Velocity in meters per second
     - Returns: Drag force in Newtons
     */
    func calculateDrag(altitude: Double, velocity: Double) -> Double {
        guard altitude >= 0, velocity >= 0 else {
            return 0.0
        }

        // Get atmospheric data
        let (speedOfSound, density) = DragCalculator.getAtmosphericData(altitude_m: altitude)

        // Calculate Mach number
        let mach = velocity / speedOfSound

        // Get drag coefficient for current conditions
        let cd = getDragCoefficient(Ma: mach, altitude_m: altitude)

        // Calculate drag force: F_drag = 0.5 * ρ * v² * C_d * A
        let dragForce = 0.5 * density * velocity * velocity * cd * referenceArea

        return dragForce
    }

    /**
     Get diagnostic information about current flight regime.

     - Parameters:
       - velocity: Velocity in meters per second
       - altitude: Altitude in meters
     - Returns: String describing the current regime
     */
    func getDragRegime(velocity: Double, altitude: Double) -> String {
        let (speedOfSound, _) = DragCalculator.getAtmosphericData(altitude_m: altitude)
        let mach = velocity / speedOfSound

        let regime: String
        if mach < 0.8 {
            regime = "Subsonic"
        } else if mach < 1.2 {
            regime = "Transonic (High Drag)"
        } else if mach < 5.0 {
            regime = "Supersonic"
        } else {
            regime = "Hypersonic"
        }

        let altitudeKm = altitude / 1000.0
        return "\(regime) at \(String(format: "%.1f", altitudeKm)) km"
    }
}

// MARK: - Example Usage

/*
 // Example 1: Subsonic Flight (Fast plane at high altitude)
 let altitude1 = 10000.0 // 10 km (near tropopause)
 let velocity1 = 0.250    // 0.25 km/s = 250 m/s
 let cd1 = DragCalculator.calculateDragCoefficient(velocity_kms: velocity1, altitude_m: altitude1)
 // Expect Ma < 0.8, Cd approx 2.0
 print("--- Example 1: Subsonic ---")
 print("Altitude: \(altitude1) m, Velocity: \(velocity1) km/s")
 print("Estimated Drag Coefficient (Cd): \(cd1)")
 
 // Example 2: Transonic/Supersonic Flight (entering space, high speed)
 let altitude2 = 500.0   // 0.5 km (low altitude)
 let velocity2 = 1.5     // 1.5 km/s = 1500 m/s
 let cd2 = DragCalculator.calculateDragCoefficient(velocity_kms: velocity2, altitude_m: altitude2)
 // Expect Ma > 1.2, Cd approx 1.6
 print("\n--- Example 2: Supersonic ---")
 print("Altitude: \(altitude2) m, Velocity: \(velocity2) km/s")
 print("Estimated Drag Coefficient (Cd): \(cd2)")
 
 // Example 3: Near Mach 1 (peak drag)
 let altitude3 = 0.0   // Sea level
 let velocity3 = 0.340 // 0.340 km/s (approx 340 m/s, speed of sound at sea level)
 let cd3 = DragCalculator.calculateDragCoefficient(velocity_kms: velocity3, altitude_m: altitude3)
 // Expect Ma near 1.0, Cd peak > 2.0
 print("\n--- Example 3: Near Mach 1 ---")
 print("Altitude: \(altitude3) m, Velocity: \(velocity3) km/s")
 print("Estimated Drag Coefficient (Cd): \(cd3)")
 */
