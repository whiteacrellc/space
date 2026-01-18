//
//  MissionResult.swift
//  ssto
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

/// Data point in the flight trajectory
struct TrajectoryPoint {
    let time: Double // seconds
    let altitude: Double // feet
    let speed: Double // Mach number
    let fuelRemaining: Double // liters
    let engineMode: EngineMode
    let temperature: Double // leading edge temperature in Celsius

    // Aerodynamic diagnostics (optional, may be nil for old data)
    var liftCoefficient: Double? = nil
    var dragCoefficient: Double? = nil
    var angleOfAttack: Double? = nil  // degrees
    var reynoldsNumber: Double? = nil
    var dragBreakdown: DragBreakdown? = nil
}

/// Result of simulating one flight segment (between two waypoints)
struct FlightSegmentResult {
    let trajectory: [TrajectoryPoint]
    let fuelUsed: Double // liters
    let finalAltitude: Double // feet
    let finalSpeed: Double // Mach
    let duration: Double // seconds
    let engineUsed: EngineMode
}

/// Complete mission result
struct MissionResult {
    let segments: [FlightSegmentResult]
    let totalFuelUsed: Double // liters
    let totalDuration: Double // seconds
    let success: Bool // Did we reach orbit?
    let finalAltitude: Double // feet
    let finalSpeed: Double // Mach
    let score: Int
    let maxTemperature: Double // maximum temperature experienced (Celsius)

    /// Calculate fuel efficiency (higher is better)
    var efficiency: Double {
        return success ? 1000000.0 / max(1.0, totalFuelUsed) : 0
    }

    /// Get complete trajectory across all segments
    func completeTrajectory() -> [TrajectoryPoint] {
        var allPoints: [TrajectoryPoint] = []
        var timeOffset: Double = 0

        for segment in segments {
            for point in segment.trajectory {
                // Adjust time to be cumulative across segments
                var adjusted = TrajectoryPoint(
                    time: point.time + timeOffset,
                    altitude: point.altitude,
                    speed: point.speed,
                    fuelRemaining: point.fuelRemaining,
                    engineMode: point.engineMode,
                    temperature: point.temperature
                )
                // Copy aerodynamic diagnostics if present
                adjusted.liftCoefficient = point.liftCoefficient
                adjusted.dragCoefficient = point.dragCoefficient
                adjusted.angleOfAttack = point.angleOfAttack
                adjusted.reynoldsNumber = point.reynoldsNumber
                adjusted.dragBreakdown = point.dragBreakdown

                allPoints.append(adjusted)
            }
            timeOffset += segment.duration
        }

        return allPoints
    }

    /// Generate a summary string
    func summary() -> String {
        if success {
            return "SUCCESS! Orbit achieved at \(Int(finalAltitude)) ft, Mach \(String(format: "%.1f", finalSpeed))\nFuel: \(Int(totalFuelUsed))L, Time: \(Int(totalDuration))s, Score: \(score)"
        } else {
            return "FAILED. Final: \(Int(finalAltitude)) ft, Mach \(String(format: "%.1f", finalSpeed))\nFuel: \(Int(totalFuelUsed))L, Time: \(Int(totalDuration))s"
        }
    }
}
