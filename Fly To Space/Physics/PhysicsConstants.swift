//
//  PhysicsConstants.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

struct PhysicsConstants {
    // Earth properties
    static let earthMass = 5.972e24 // kg
    static let earthRadius = 6371000.0 // meters
    static let gravitationalConstant = 6.674e-11 // N⋅m²/kg²

    // Atmospheric properties
    static let seaLevelDensity = 1.225 // kg/m³
    static let scaleHeight = 8500.0 // meters for exponential atmosphere model

    // Conversion factors
    static let feetToMeters = 0.3048
    static let metersToFeet = 3.28084
    static let kgPerLiter = 0.8 // Approximate density of jet fuel

    // Aircraft properties (can be customized later)
    static let dryMass = 15000.0 // kg (empty aircraft mass)
    static let dragCoefficient = 0.02
    static let referenceArea = 50.0 // m² cross-sectional area

    // Flight parameters
    static let orbitAltitude = 300000.0 // feet
    static let orbitSpeed = 24.0 // Mach number
    static let speedOfSoundSeaLevel = 340.29 // m/s at 15°C

    /// Standard gravity at sea level (m/s²)
    static func standardGravity() -> Double {
        return gravitationalConstant * earthMass / (earthRadius * earthRadius)
    }

    /// Gravity at a given altitude (meters)
    static func gravity(at altitudeMeters: Double) -> Double {
        let r = earthRadius + altitudeMeters
        return gravitationalConstant * earthMass / (r * r)
    }

    /// Atmospheric density at altitude (meters)
    static func atmosphericDensity(at altitudeMeters: Double) -> Double {
        return seaLevelDensity * exp(-altitudeMeters / scaleHeight)
    }
}
