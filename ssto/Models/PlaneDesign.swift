//
//  PlaneDesign.swift
//  ssto
//
//  Created by tom whittaker on 11/26/25.
//

import Foundation

/// Aircraft design parameters defining leading edge shape
struct PlaneDesign: Codable {
    let tiltAngle: Double   // degrees (-45 to 45) - FIXED at 0 for bilateral symmetry
    let sweepAngle: Double  // degrees (45 to 135) - defines leading edge shape
    let position: Double    // -150 to 150 (relative to cone midpoint)

    // Optimal design parameters
    static let optimalTilt: Double = 0.0  // Fixed for bilateral symmetry
    static let optimalSweep: Double = 80.0
    static let optimalPosition: Double = 174.0

    // Sweep neutral zone (no penalty/bonus)
    static let sweepNeutralMin: Double = 90.0
    static let sweepNeutralMax: Double = 100.0

    /// Default design (initial view settings) - bilaterally symmetric
    static let defaultDesign = PlaneDesign(tiltAngle: 0.0, sweepAngle: 92.0, position: 0.0)

    /// Optimal design for best overall performance
    static let optimalDesign = PlaneDesign(tiltAngle: optimalTilt, sweepAngle: optimalSweep, position: optimalPosition)

    /// Calculate maximum safe temperature multiplier (1.0 = baseline 600°C)
    /// Higher is better (can withstand more heat)
    func thermalLimitMultiplier() -> Double {
        var multiplier = 1.0

        // Sharper leading edge = heats up faster = lower thermal limit
        // Blunt nose = heats up slower = higher thermal limit

        // Sweep angle effect: Higher sweep (closer to 90°) = sharper edge = more heating
        // Within neutral zone (90-100): higher sweep increases heating
        if sweepAngle >= PlaneDesign.sweepNeutralMin && sweepAngle <= PlaneDesign.sweepNeutralMax {
            // Higher sweep = more heating (lower limit)
            let normalizedSweep = (sweepAngle - PlaneDesign.sweepNeutralMin) / (PlaneDesign.sweepNeutralMax - PlaneDesign.sweepNeutralMin)
            multiplier -= normalizedSweep * 0.15  // Up to 15% lower limit at 100°
        } else if sweepAngle < PlaneDesign.sweepNeutralMin {
            // Very blunt nose = better thermal properties
            let deviation = PlaneDesign.sweepNeutralMin - sweepAngle
            multiplier += deviation / 25.0 * 0.2  // Up to 20% bonus at 45°
        } else {
            // Very sharp nose = worse thermal properties
            let deviation = sweepAngle - PlaneDesign.sweepNeutralMax
            multiplier -= deviation / 40.0 * 0.25  // Up to 25% penalty at 135°
        }

        // Tilt angle effect: should always be 0 for bilateral symmetry
        // Any deviation from 0 affects thermal properties
        let tiltSharpness = abs(tiltAngle)
        multiplier -= tiltSharpness / 45.0 * 0.1  // Up to 10% penalty for tilt deviation

        // Position effect: doesn't significantly affect thermal properties
        // (thermal is mainly about leading edge shape, not overall size)

        return max(0.6, min(1.3, multiplier))  // Clamp between 60% and 130%
    }

    /// Calculate heating rate multiplier (1.0 = baseline)
    /// Lower is better (heats up slower)
    func heatingRateMultiplier() -> Double {
        // Inverse of thermal limit: sharper = heats up faster
        let thermalMult = thermalLimitMultiplier()
        // Convert thermal limit to heating rate (inverse relationship)
        // High thermal limit (1.3) = low heating rate (0.77)
        // Low thermal limit (0.6) = high heating rate (1.67)
        return 1.0 / thermalMult
    }

    /// Generate summary of design tradeoffs
    /// Note: Drag is now computed from actual geometry via panel methods.
    /// This summary focuses on thermal properties only.
    func summary() -> String {
        let thermal = thermalLimitMultiplier()
        let thermalPercent = Int((thermal - 1.0) * 100)
        let thermalStr = thermalPercent >= 0 ? "+\(thermalPercent)%" : "\(thermalPercent)%"

        return "Thermal Limit: \(thermalStr)"
    }

    /// Score design (0-100, higher is better)
    /// Note: Drag is now computed from actual geometry via panel methods.
    /// This score is based on thermal properties only.
    func score() -> Int {
        let thermal = thermalLimitMultiplier()

        // Higher thermal limit is better (1.3 = 100 points, 0.6 = 0 points)
        let thermalScore = (thermal - 0.6) * 100 / 0.7

        return Int(thermalScore)
    }
}
