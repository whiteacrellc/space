//
//  PlaneDesign.swift
//  Fly To Space
//
//  Created by tom whittaker on 11/26/25.
//

import Foundation

/// Aircraft design parameters defining leading edge shape
struct PlaneDesign: Codable {
    let pitchAngle: Double  // degrees (-45 to 45)
    let yawAngle: Double    // degrees (45 to 135)
    let position: Double    // -150 to 150 (relative to cone midpoint)

    // Optimal design parameters
    static let optimalPitch: Double = 4.0
    static let optimalYaw: Double = 78.0
    static let optimalPosition: Double = 129.0

    // Yaw neutral zone (no penalty/bonus)
    static let yawNeutralMin: Double = 70.0
    static let yawNeutralMax: Double = 95.0

    /// Default design (initial view settings)
    static let defaultDesign = PlaneDesign(pitchAngle: -3.0, yawAngle: 92.0, position: 0.0)

    /// Optimal design for best overall performance
    static let optimalDesign = PlaneDesign(pitchAngle: optimalPitch, yawAngle: optimalYaw, position: optimalPosition)

    /// Calculate drag coefficient multiplier (1.0 = baseline)
    /// Lower is better (less drag)
    func dragMultiplier() -> Double {
        var multiplier = 1.0

        // Position effect: too small increases drag (plane too thick for fuel capacity)
        // Optimal around 129, penalty increases as we move toward apex
        let positionFromOptimal = abs(position - PlaneDesign.optimalPosition)
        let positionPenalty = positionFromOptimal / 150.0 * 0.3  // Up to 30% penalty
        multiplier += positionPenalty

        // Yaw angle effect: Outside 70-95 range increases drag
        var yawPenalty = 0.0
        if yawAngle < PlaneDesign.yawNeutralMin {
            // Below 70: increasingly bad
            let deviation = PlaneDesign.yawNeutralMin - yawAngle
            yawPenalty = deviation / 25.0 * 0.4  // Up to 40% penalty at 45°
        } else if yawAngle > PlaneDesign.yawNeutralMax {
            // Above 95: increasingly bad
            let deviation = yawAngle - PlaneDesign.yawNeutralMax
            yawPenalty = deviation / 40.0 * 0.4  // Up to 40% penalty at 135°
        } else {
            // Within neutral zone: lower yaw = better drag
            // Linearly interpolate: 70° is best (0% bonus), 95° is worst (10% penalty)
            let normalizedYaw = (yawAngle - PlaneDesign.yawNeutralMin) / (PlaneDesign.yawNeutralMax - PlaneDesign.yawNeutralMin)
            yawPenalty = normalizedYaw * 0.1
        }
        multiplier += yawPenalty

        // Pitch angle effect: sharper (more negative or positive) = lower drag
        // Optimal is around 4°, but sharper angles reduce drag at cost of thermal issues
        let pitchFromOptimal = abs(pitchAngle - PlaneDesign.optimalPitch)
        let pitchPenalty = pitchFromOptimal / 45.0 * 0.15  // Up to 15% penalty
        multiplier += pitchPenalty

        return max(0.7, min(2.0, multiplier))  // Clamp between 70% and 200%
    }

    /// Calculate maximum safe temperature multiplier (1.0 = baseline 600°C)
    /// Higher is better (can withstand more heat)
    func thermalLimitMultiplier() -> Double {
        var multiplier = 1.0

        // Sharper leading edge = heats up faster = lower thermal limit
        // Blunt nose = heats up slower = higher thermal limit

        // Yaw angle effect: Higher yaw (closer to 90°) = sharper edge = more heating
        // Within neutral zone (70-95): higher yaw increases heating
        if yawAngle >= PlaneDesign.yawNeutralMin && yawAngle <= PlaneDesign.yawNeutralMax {
            // Higher yaw = more heating (lower limit)
            let normalizedYaw = (yawAngle - PlaneDesign.yawNeutralMin) / (PlaneDesign.yawNeutralMax - PlaneDesign.yawNeutralMin)
            multiplier -= normalizedYaw * 0.15  // Up to 15% lower limit at 95°
        } else if yawAngle < PlaneDesign.yawNeutralMin {
            // Very blunt nose = better thermal properties
            let deviation = PlaneDesign.yawNeutralMin - yawAngle
            multiplier += deviation / 25.0 * 0.2  // Up to 20% bonus at 45°
        } else {
            // Very sharp nose = worse thermal properties
            let deviation = yawAngle - PlaneDesign.yawNeutralMax
            multiplier -= deviation / 40.0 * 0.25  // Up to 25% penalty at 135°
        }

        // Pitch angle effect: sharper pitch = more extreme temperatures
        let pitchSharpness = abs(pitchAngle)
        multiplier -= pitchSharpness / 45.0 * 0.1  // Up to 10% penalty for extreme pitch

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
