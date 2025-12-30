//
//  FlightPlan.swift
//  ssto
//
//  Created by tom whittaker on 11/25/25.
//

import Foundation

class FlightPlan: Codable {
    private(set) var waypoints: [Waypoint] = []

    init() {
        // Always start at ground level, stationary
        waypoints.append(Waypoint(altitude: 0, speed: 0, engineMode: .auto))
    }

    /// Add a waypoint to the flight plan
    func addWaypoint(_ waypoint: Waypoint) {
        waypoints.append(waypoint)
    }

    /// Insert a waypoint at a specific index
    func insertWaypoint(_ waypoint: Waypoint, at index: Int) {
        guard index >= 0 && index <= waypoints.count else { return }
        waypoints.insert(waypoint, at: index)
    }

    /// Remove a waypoint at a specific index (cannot remove the starting waypoint)
    func removeWaypoint(at index: Int) {
        guard index > 0 && index < waypoints.count else { return }
        waypoints.remove(at: index)
    }

    /// Update a waypoint at a specific index
    func updateWaypoint(at index: Int, with waypoint: Waypoint) {
        guard index >= 0 && index < waypoints.count else { return }
        // Don't allow changing the starting waypoint's altitude/speed
        if index == 0 {
            waypoints[index].engineMode = waypoint.engineMode
        } else {
            waypoints[index] = waypoint
        }
    }

    /// Check if the flight plan is valid for launch
    func isValidForFlight() -> Bool {
        // Must have at least 2 waypoints (start + at least one target)
        guard waypoints.count >= 2 else { return false }

        // All waypoints must be individually valid
        for waypoint in waypoints {
            guard waypoint.isValid() else { return false }
        }

        // Check if final waypoint reaches orbit
        if let last = waypoints.last {
            let lastAltitudeMeters = last.altitude * PhysicsConstants.feetToMeters
            return lastAltitudeMeters >= PhysicsConstants.orbitAltitude &&
                   last.speed >= PhysicsConstants.orbitSpeed
        }

        return false
    }

    /// Get a summary of the flight plan
    func summary() -> String {
        return "Flight plan with \(waypoints.count) waypoints, targeting \(waypoints.last?.altitude ?? 0) ft at Mach \(waypoints.last?.speed ?? 0)"
    }

    /// Clear all waypoints except the starting point
    func reset() {
        waypoints = [Waypoint(altitude: 0, speed: 0, engineMode: .auto)]
    }
}
