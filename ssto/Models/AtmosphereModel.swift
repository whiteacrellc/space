//
//  AtmosphereModel.swift
//  ssto
//
//  Created by tom whittaker on 11/29/25.
//


// AtmosphereModel.swift
// A more accurate model for atmospheric density based on the 1976 U.S. Standard Atmosphere.
// This implements a layered model with temperature lapse rates, computing pressure and density accordingly.

import Foundation

class AtmosphereModel {
    static let g: Double = 9.80665  // m/s²
    static let R: Double = 8.3144598  // J/(mol·K)
    static let M: Double = 0.0289644  // kg/mol
    static let Rs: Double = R / M  // Specific gas constant for dry air, ≈287.058 J/(kg·K)
    
    static let baseAltitudes: [Double] = [0.0, 11000.0, 20000.0, 32000.0, 47000.0, 51000.0, 71000.0, 84852.0]  // meters
    
    static let baseTemperatures: [Double] = [288.15, 216.65, 216.65, 228.65, 270.65, 270.65, 214.65, 186.946]  // K
    
    static let basePressures: [Double] = [101325.0, 22632.63439302289, 5475.157308245899, 868.0881576113087, 110.91901929163438, 66.94711499880606, 3.9570957497490675, 0.3734621450621543]  // Pa
    
    static let lapseRates: [Double] = [-0.0065, 0.0, 0.0010, 0.0028, 0.0, -0.0028, -0.0020]  // K/m
    static let gamma: Double = 1.4
    
    private static func getLayerIndex(at altitude: Double) -> Int {
        var layer = baseAltitudes.count - 2
        for i in 0..<baseAltitudes.count - 1 {
            if altitude < baseAltitudes[i + 1] {
                layer = i
                break
            }
        }
        return layer
    }
    
    static func temperature(at altitudeMeters: Double) -> Double {
        if altitudeMeters < 0 { return baseTemperatures[0] }
        
        let layer = getLayerIndex(at: altitudeMeters)
        let hb = baseAltitudes[layer]
        let tb = baseTemperatures[layer]
        let lb = lapseRates[layer]
        let dh = altitudeMeters - hb
        
        if altitudeMeters >= baseAltitudes.last! {
            return baseTemperatures.last!
        }
        
        return tb + lb * dh
    }
    
    static func speedOfSound(at altitudeMeters: Double) -> Double {
        let t = temperature(at: altitudeMeters)
        return sqrt(gamma * Rs * t)
    }
    
    static func atmosphericDensity(at altitudeMeters: Double) -> Double {
        if altitudeMeters < 0 {
            return basePressures[0] / (Rs * baseTemperatures[0])  // Sea level density
        }
        
        // Find the layer index
        var layer = baseAltitudes.count - 2  // Default to last layer if above
        for i in 0..<baseAltitudes.count - 1 {
            if altitudeMeters < baseAltitudes[i + 1] {
                layer = i
                break
            }
        }
        
        let hb = baseAltitudes[layer]
        let tb = baseTemperatures[layer]
        let pb = basePressures[layer]
        let lb = lapseRates[layer]
        let dh = altitudeMeters - hb
        
        let t: Double
        if altitudeMeters >= baseAltitudes.last! {
            // Isothermal layer above 84.852 km
            t = baseTemperatures.last!
            let p = pb * exp(-g * M * dh / (R * t))  // Note: here pb, tb are from last base, dh from last hb
            return p / (Rs * t)
        } else {
            t = tb + lb * dh
        }
        
        let p: Double
        if lb == 0 {
            p = pb * exp(-g * M * dh / (R * tb))
        } else {
            p = pb * pow(t / tb, -g * M / (R * lb))
        }
        
        let density = p / (Rs * t)
        return density
    }

    /// Calculate dynamic viscosity using Sutherland's formula
    /// Returns viscosity in Pa·s (kg/(m·s))
    static func dynamicViscosity(at altitudeMeters: Double) -> Double {
        let T = temperature(at: altitudeMeters)

        // Sutherland's formula constants for air
        let mu0: Double = 1.716e-5  // Reference viscosity at T0 (Pa·s)
        let T0: Double = 273.15     // Reference temperature (K)
        let S: Double = 110.4       // Sutherland constant for air (K)

        let mu = mu0 * pow(T / T0, 1.5) * (T0 + S) / (T + S)
        return mu
    }

    /// Atmospheric conditions bundle
    struct AtmosphericConditions {
        let density: Double      // kg/m³
        let temperature: Double  // K
        let pressure: Double     // Pa
        let viscosity: Double    // Pa·s
        let speedOfSound: Double // m/s
    }

    /// Get complete atmospheric conditions at altitude (in feet)
    static func getAtmosphericConditions(altitudeFeet: Double) -> AtmosphericConditions {
        let altitudeMeters = altitudeFeet * 0.3048

        let density = atmosphericDensity(at: altitudeMeters)
        let temp = temperature(at: altitudeMeters)
        let sos = speedOfSound(at: altitudeMeters)
        let viscosity = dynamicViscosity(at: altitudeMeters)

        // Calculate pressure from density and temperature
        let pressure = density * Rs * temp

        return AtmosphericConditions(
            density: density,
            temperature: temp,
            pressure: pressure,
            viscosity: viscosity,
            speedOfSound: sos
        )
    }
}