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

    /// DEPRECATED: Drag is now computed from actual aircraft geometry using panel methods.
    /// This method is kept for backward compatibility and legacy scoring only.
    /// For actual drag calculation, see PanelAerodynamicsSolver.
    @available(*, deprecated, message: "Drag is now computed from panel method aerodynamics. Use PanelAerodynamicsSolver instead.")
    func dragMultiplier() -> Double {
        var multiplier = 0.3

        // Position effect: too small increases drag (plane too thick for fuel capacity)
        // Optimal around 129, penalty increases as we move toward apex
        let positionFromOptimal = abs(position - PlaneDesign.optimalPosition)
        let positionPenalty = positionFromOptimal / 150.0 * 0.3  // Up to 30% penalty
        multiplier += positionPenalty

        // Sweep angle effect: Outside 90-100 range increases drag
        var sweepPenalty = 0.0
        if sweepAngle < PlaneDesign.sweepNeutralMin {
            // Below 90: increasingly bad
            let deviation = PlaneDesign.sweepNeutralMin - sweepAngle
            sweepPenalty = deviation / 25.0 * 0.4  // Up to 40% penalty at 45°
        } else if sweepAngle > PlaneDesign.sweepNeutralMax {
            // Above 100: increasingly bad
            let deviation = sweepAngle - PlaneDesign.sweepNeutralMax
            sweepPenalty = deviation / 40.0 * 0.4  // Up to 40% penalty at 135°
        } else {
            // Within neutral zone: lower sweep = better drag
            // Linearly interpolate: 90° is best (0% bonus), 100° is worst (10% penalty)
            let normalizedSweep = (sweepAngle - PlaneDesign.sweepNeutralMin) / (PlaneDesign.sweepNeutralMax - PlaneDesign.sweepNeutralMin)
            sweepPenalty = normalizedSweep * 0.1
        }
        multiplier += sweepPenalty

        // Tilt angle effect: should always be 0 for bilateral symmetry
        // Any deviation from 0 adds penalty
        let tiltPenalty = abs(tiltAngle) / 45.0 * 0.15  // Up to 15% penalty
        multiplier += tiltPenalty

        return max(0.7, min(2.0, multiplier))  // Clamp between 70% and 200%
    }

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
    func summary() -> String {
        let drag = dragMultiplier()
        let thermal = thermalLimitMultiplier()
        let dragPercent = Int((drag - 1.0) * 100)
        let thermalPercent = Int((thermal - 1.0) * 100)

        let dragStr = dragPercent >= 0 ? "+\(dragPercent)%" : "\(dragPercent)%"
        let thermalStr = thermalPercent >= 0 ? "+\(thermalPercent)%" : "\(thermalPercent)%"

        return "Drag: \(dragStr), Thermal Limit: \(thermalStr)"
    }

    /// Score design (0-100, higher is better)
    /// Balanced scoring considering both drag and thermal properties
    func score() -> Int {
        let drag = dragMultiplier()
        let thermal = thermalLimitMultiplier()

        // Lower drag is better (1.0 = 100 points, 2.0 = 0 points)
        let dragScore = max(0, 100 - (drag - 0.7) * 100 / 1.3)

        // Higher thermal limit is better (1.3 = 100 points, 0.6 = 0 points)
        let thermalScore = (thermal - 0.6) * 100 / 0.7

        // Weighted average: drag is slightly more important
        let finalScore = dragScore * 0.6 + thermalScore * 0.4

        return Int(finalScore)
    }
}
