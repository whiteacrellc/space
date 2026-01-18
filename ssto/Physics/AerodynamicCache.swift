//
//  AerodynamicCache.swift
//  ssto
//
//  Caches aerodynamic geometry and solutions for performance.
//  Panel method computation is expensive (~10-50ms per solve).
//

import Foundation
import CryptoKit

// MARK: - Aerodynamic Cache

class AerodynamicCache {

    // MARK: - Cache Storage

    private static var geometryCache: [String: AerodynamicGeometry] = [:]

    private static let maxCacheSize = 50  // Maximum entries before cleanup

    // MARK: - Public Interface

    /// Get or compute aerodynamic geometry for current design
    static func getGeometry(
        planform: TopViewPlanform,
        profile: SideProfileShape,
        crossSection: CrossSectionPoints
    ) -> AerodynamicGeometry {

        let hash = computeGeometryHash(planform: planform, profile: profile, crossSection: crossSection)

        // Check cache
        if let cached = geometryCache[hash] {
            return cached
        }

        // Compute geometry
        let geometry = GeometricAnalyzer.analyzeAerodynamicGeometry(
            planform: planform,
            profile: profile,
            crossSection: crossSection
        )

        // Store in cache
        geometryCache[hash] = geometry

        // Cleanup if cache is too large
        if geometryCache.count > maxCacheSize {
            cleanupCache()
        }

        return geometry
    }

    /// Clear all cached data
    static func clearCache() {
        geometryCache.removeAll()
    }

    // MARK: - Hash Computation

    /// Compute hash of design parameters for cache lookup
    private static func computeGeometryHash(
        planform: TopViewPlanform,
        profile: SideProfileShape,
        crossSection: CrossSectionPoints
    ) -> String {

        var hashString = ""

        // Planform parameters
        hashString += "\(planform.noseTip.x),\(planform.noseTip.y),"
        hashString += "\(planform.frontControlLeft.x),\(planform.frontControlLeft.y),"
        hashString += "\(planform.midLeft.x),\(planform.midLeft.y),"
        hashString += "\(planform.rearControlLeft.x),\(planform.rearControlLeft.y),"
        hashString += "\(planform.tailLeft.x),\(planform.tailLeft.y),"
        hashString += "\(planform.wingStartPosition),\(planform.wingSpan),"
        hashString += "\(planform.aircraftLength)"

        // Profile parameters
        hashString += "|\(profile.frontStart.x),\(profile.frontStart.y),"
        hashString += "\(profile.frontControl.x),\(profile.frontControl.y),"
        hashString += "\(profile.frontEnd.x),\(profile.frontEnd.y),"
        hashString += "\(profile.topStart.x),\(profile.topStart.y),"
        hashString += "\(profile.topControl.x),\(profile.topControl.y),"
        hashString += "\(profile.topEnd.x),\(profile.topEnd.y),"
        hashString += "\(profile.engineEnd.x),\(profile.engineEnd.y),"
        hashString += "\(profile.exhaustControl.x),\(profile.exhaustControl.y),"
        hashString += "\(profile.exhaustEnd.x),\(profile.exhaustEnd.y)"

        // Cross-section points (just first and last for brevity)
        if let firstTop = crossSection.topPoints.first,
           let lastTop = crossSection.topPoints.last,
           let firstBottom = crossSection.bottomPoints.first,
           let lastBottom = crossSection.bottomPoints.last {
            hashString += "|\(firstTop.x),\(firstTop.y),"
            hashString += "\(lastTop.x),\(lastTop.y),"
            hashString += "\(firstBottom.x),\(firstBottom.y),"
            hashString += "\(lastBottom.x),\(lastBottom.y)"
        }

        // Compute SHA256 hash
        let data = Data(hashString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Remove oldest entries when cache exceeds size limit
    private static func cleanupCache() {
        // Simple strategy: remove half the cache
        // In production, could use LRU or other eviction policy
        let targetSize = maxCacheSize / 2

        let keysToRemove = Array(geometryCache.keys.prefix(geometryCache.count - targetSize))
        for key in keysToRemove {
            geometryCache.removeValue(forKey: key)
        }
    }
}
