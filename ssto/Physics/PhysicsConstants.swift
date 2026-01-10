//
//  PhysicsConstants.swift
//  ssto
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

    // Fuel properties
    static let slushHydrogenDensity = 86.0 // kg/m³ (slush hydrogen)
    static let kgPerLiter = slushHydrogenDensity / 1000.0 // 0.086 kg/L

    // Aircraft properties (calculated based on fuel volume and design)
    static let dryMass = 15000.0 // kg (baseline - used only as fallback)
    static let cargoMass = 22800.0 // kg (fixed cargo/payload weight)
    static let dragCoefficient = 0.02
    static let referenceArea = 500.0 // m² cross-sectional area (baseline)

    /// Calculate actual dry mass based on aircraft design and flight plan
    /// Calculate total dry mass based on wetted surface area
    /// - Parameters:
    ///   - volumeM3: Internal volume in cubic meters
    ///   - waypoints: Flight plan waypoints
    ///   - planeDesign: Aircraft design parameters
    /// - Returns: Calculated dry mass in kg
    static func calculateDryMass(
        volumeM3: Double,
        waypoints: [Waypoint],
        planeDesign: PlaneDesign
    ) -> Double {
        // Calculate surface area breakdown from current design
        let areaBreakdown = AircraftVolumeModel.calculateWettedSurfaceArea()

        return EngineWeightModel.calculateDryMass(
            areaBreakdown: areaBreakdown,
            volumeM3: volumeM3,
            waypoints: waypoints,
            planeDesign: planeDesign
        )
    }

    // Flight parameters
    static let orbitAltitude = 200000.0 // meters (Low Earth Orbit)
    static let orbitAltitudeFeet = orbitAltitude * metersToFeet // 656,168 feet
    static let orbitSpeed = 24.0 // Mach number
    static let speedOfSoundSeaLevel = 340.29 // m/s at 15°C

    // Engine operating limits (altitude in meters, speed in Mach)
    struct EngineLimits {
        static let jet = (
            minAltitude: 0.0,
            maxAltitude: 25001.0,
            minSpeed: 0.0,
            maxSpeed: 3.2
        )
        static let ramjet = (
            minAltitude: 12500.0,
            maxAltitude: 40001.0,
            minSpeed: 2.0,
            maxSpeed: 8.0
        )
        static let scramjet = (
            minAltitude: 25000.0,
            maxAltitude: 75001.0,
            minSpeed: 5.0,
            maxSpeed: 16.0
        )
        static let rocket = (
            minAltitude: 0.0,
            maxAltitude: 500000.0,
            minSpeed: 0.0,
            maxSpeed: 30.0
        )
    }

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
        return AtmosphereModel.atmosphericDensity(at: altitudeMeters)
    }

    /// Check if orbital parameters are achieved
    /// - Parameters:
    ///   - altitude: Altitude in feet
    ///   - speed: Speed in Mach
    /// - Returns: True if altitude and speed meet orbital requirements
    static func isOrbitAchieved(altitude: Double, speed: Double) -> Bool {
        let altitudeMeters = altitude * feetToMeters
        return altitudeMeters >= orbitAltitude && speed >= orbitSpeed
    }
}
