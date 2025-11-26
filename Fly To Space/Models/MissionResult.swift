//
//  MissionResult.swift
//  Fly To Space
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
                var adjustedPoint = point
                let adjusted = TrajectoryPoint(
                    time: point.time + timeOffset,
                    altitude: point.altitude,
                    speed: point.speed,
                    fuelRemaining: point.fuelRemaining,
                    engineMode: point.engineMode
                )
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
