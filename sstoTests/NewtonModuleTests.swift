
import Testing
import Foundation
@testable import ssto

struct NewtonModuleTests {

    @Test func testOptimizeLengthIteratesMoreThanOnce() {
        // Given
        // 1. Setup a flight plan that targets orbit
        let flightPlan = FlightPlan()
        // Add intermediate waypoint to ensure valid path
        flightPlan.addWaypoint(Waypoint(altitude: 50000, speed: 3.0, engineMode: .ramjet))
        flightPlan.addWaypoint(Waypoint(altitude: 100000, speed: 6.0, engineMode: .scramjet))
        // Target orbit
        flightPlan.addWaypoint(Waypoint(altitude: 400000, speed: 25.0, engineMode: .rocket))

        // 2. Setup GameManager with default design but a suboptimal length
        var planform = TopViewPlanform.defaultPlanform
        planform.aircraftLength = 100.0 // Start with a length likely too small/large
        GameManager.shared.setTopViewPlanform(planform)
        GameManager.shared.setSideProfile(SideProfileShape.defaultProfile)
        GameManager.shared.setPlaneDesign(PlaneDesign.defaultDesign)
        GameManager.shared.setCrossSectionPoints(CrossSectionPoints.defaultPoints)

        // When
        // Run optimization starting from the suboptimal length
        let result = NewtonModule.optimizeLength(
            initialLength: 100.0,
            flightPlan: flightPlan,
            planeDesign: PlaneDesign.defaultDesign
        )

        // Then
        // Verify that it took more than 1 iteration to converge
        #expect(result.iterations > 1, "Optimization should require more than 1 iteration, took \(result.iterations)")

        // Verify it actually converged
        #expect(result.converged, "Optimization should converge")

        // Verify the error is small
        let finalDryWeight = PhysicsConstants.calculateDryMass(
            volumeM3: AircraftVolumeModel.calculateInternalVolume() * pow(result.optimalLength / 100.0, 3.0),
            waypoints: flightPlan.waypoints,
            planeDesign: PlaneDesign.defaultDesign,
            maxTemperature: 800.0
        )
        #expect(abs(result.fuelError) < 0.001 * finalDryWeight, "Final error should be within convergence threshold")
    }

    @Test func testStartingAtMaxLengthWithDeficit() {
        // Given
        // This test specifically validates the bug fix where starting at 150m
        // with a huge fuel deficit would result in zero step size
        let flightPlan = FlightPlan()
        // Add waypoints that create large fuel requirements
        flightPlan.addWaypoint(Waypoint(altitude: 65617, speed: 3.1, engineMode: .ejectorRamjet))  // 20000m
        flightPlan.addWaypoint(Waypoint(altitude: 131234, speed: 6.0, engineMode: .ramjet))        // 40000m
        flightPlan.addWaypoint(Waypoint(altitude: 229659, speed: 15.0, engineMode: .scramjet))     // 70000m
        flightPlan.addWaypoint(Waypoint(altitude: 656168, speed: 24.0, engineMode: .rocket))       // 200000m

        var planform = TopViewPlanform.defaultPlanform
        planform.aircraftLength = 150.0  // Start at old maxLength
        GameManager.shared.setTopViewPlanform(planform)
        GameManager.shared.setSideProfile(SideProfileShape.defaultProfile)
        GameManager.shared.setPlaneDesign(PlaneDesign.defaultDesign)
        GameManager.shared.setCrossSectionPoints(CrossSectionPoints.defaultPoints)

        // When
        let result = NewtonModule.optimizeLength(
            initialLength: 150.0,
            flightPlan: flightPlan,
            planeDesign: PlaneDesign.defaultDesign
        )

        // Then
        // Should take multiple iterations (not get stuck at iteration 1)
        #expect(result.iterations > 1, "Should iterate more than once even starting at old maxLength, took \(result.iterations)")

        // Should step to a much larger length (beyond the old 150m limit)
        #expect(result.optimalLength > 200.0, "Optimal length should exceed old maxLength of 150m, got \(result.optimalLength)m")

        // Length should increase on first step (not stay at 150m)
        #expect(result.lengthHistory.count >= 2, "Should have at least 2 length values")
        if result.lengthHistory.count >= 2 {
            let firstStep = result.lengthHistory[1] - result.lengthHistory[0]
            #expect(abs(firstStep) > 1.0, "First step should be significant (>1m), was \(firstStep)m")
        }
    }

    @Test func testNewtonRaphsonStepCalculation() {
        // Given
        // Verify the Newton-Raphson step calculation works correctly
        // when derivative is small but nonzero
        let flightPlan = FlightPlan()
        flightPlan.addWaypoint(Waypoint(altitude: 100000, speed: 6.0, engineMode: .scramjet))
        flightPlan.addWaypoint(Waypoint(altitude: 300000, speed: 20.0, engineMode: .rocket))

        var planform = TopViewPlanform.defaultPlanform
        planform.aircraftLength = 80.0
        GameManager.shared.setTopViewPlanform(planform)
        GameManager.shared.setSideProfile(SideProfileShape.defaultProfile)
        GameManager.shared.setPlaneDesign(PlaneDesign.defaultDesign)
        GameManager.shared.setCrossSectionPoints(CrossSectionPoints.defaultPoints)

        // When
        let result = NewtonModule.optimizeLength(
            initialLength: 80.0,
            flightPlan: flightPlan,
            planeDesign: PlaneDesign.defaultDesign
        )

        // Then
        // Should not get stuck due to derivative being too small
        #expect(result.iterations > 1, "Should iterate successfully")

        // Should find a valid optimal length within bounds
        #expect(result.optimalLength >= NewtonModule.minLength, "Optimal length should be >= minLength")
        #expect(result.optimalLength <= NewtonModule.maxLength, "Optimal length should be <= maxLength")
    }
}
