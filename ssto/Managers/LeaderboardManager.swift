//
//  LeaderboardManager.swift
//  ssto
//
//  Manages leaderboard entries for successful orbital missions
//

import Foundation

/// Manages the global leaderboard
class LeaderboardManager {
    static let shared = LeaderboardManager()

    private let userDefaults = UserDefaults.standard
    private let leaderboardKey = "SSTO_Leaderboard"
    private let maxEntries = 100 // Keep top 100 internally

    private init() {}

    /// Add a new entry to the leaderboard
    /// - Parameters:
    ///   - playerName: Name of the player
    ///   - volume: Volume of the vehicle in m³
    ///   - optimalLength: Optimal length in meters
    ///   - fuelCapacity: Fuel capacity in kg
    func addEntry(playerName: String, volume: Double, optimalLength: Double, fuelCapacity: Double) {
        var entries = getAllEntries()

        let newEntry = LeaderboardEntry(
            name: playerName,
            volume: volume,
            optimalLength: optimalLength,
            fuelCapacity: fuelCapacity,
            date: Date()
        )

        entries.append(newEntry)

        // Sort by volume (ascending - lower is better)
        entries.sort()

        // Keep only top entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        // Save back to UserDefaults
        saveEntries(entries)
    }

    /// Get top N entries from the leaderboard
    /// - Parameter limit: Number of entries to return (default: 10)
    /// - Returns: Array of leaderboard entries sorted by dry mass
    func getTopEntries(limit: Int = 10) -> [LeaderboardEntry] {
        let entries = getAllEntries()
        return Array(entries.prefix(limit))
    }

    /// Get all leaderboard entries
    /// - Returns: Array of all leaderboard entries sorted by dry mass
    func getAllEntries() -> [LeaderboardEntry] {
        guard let data = userDefaults.data(forKey: leaderboardKey) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            let entries = try decoder.decode([LeaderboardEntry].self, from: data)
            return entries.sorted()
        } catch {
            print("Error decoding leaderboard: \(error)")
            return []
        }
    }

    /// Save entries to UserDefaults
    /// - Parameter entries: Array of leaderboard entries
    private func saveEntries(_ entries: [LeaderboardEntry]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(entries)
            userDefaults.set(data, forKey: leaderboardKey)
        } catch {
            print("Error encoding leaderboard: \(error)")
        }
    }

    /// Clear all leaderboard entries (for testing)
    func clearLeaderboard() {
        userDefaults.removeObject(forKey: leaderboardKey)
    }

    /// Check if a score would make it to the top 10
    /// - Parameter volume: Volume of the vehicle
    /// - Returns: True if this would be in top 10
    func wouldMakeTopTen(volume: Double) -> Bool {
        let topTen = getTopEntries(limit: 10)
        if topTen.count < 10 {
            return true
        }
        return volume < topTen.last!.volume
    }

    /// Get rank for a given volume
    /// - Parameter volume: Volume of the vehicle
    /// - Returns: Rank (1-based), or nil if not in leaderboard
    func getRank(volume: Double) -> Int? {
        let entries = getAllEntries()
        for (index, entry) in entries.enumerated() {
            if entry.volume >= volume {
                return index + 1
            }
        }
        return nil
    }
}
