//
//  EjectorRamjetEngineTests.swift
//  sstoTests
//
//  Created by tom whittaker on 11/25/25.
//

import XCTest
@testable import ssto

class EjectorRamjetEngineTests: XCTestCase {

    var engine: EjectorRamjetEngine!

    override func setUp() {
        super.setUp()
        engine = EjectorRamjetEngine()
    }

    func testProperties() {
        XCTAssertEqual(engine.name, "Ejector-Ramjet")
        XCTAssertEqual(engine.machRange, 3.0...10.0)
        XCTAssertEqual(engine.altitudeRange, 50000.0...150000.0)
    }

    func testThrustInsideEnvelope() {
        // Test at a sweet spot (e.g., Mach 4, 60k ft)
        let thrust = engine.getThrust(altitude: 60000.0, speed: 4.0)
        XCTAssertGreaterThan(thrust, 0.0)
    }

    func testThrustOutsideMachRange() {
        // Below range
        let thrustLow = engine.getThrust(altitude: 60000.0, speed: 0.5)
        XCTAssertEqual(thrustLow, 0.0)
        
        // Above range (should be low or zero depending on curve)
        // Physics model might still return something small or 0 depending on heat limits
        // At Mach 20, it should definitely fail heat or return 0
        let thrustHigh = engine.getThrust(altitude: 60000.0, speed: 20.0)
        XCTAssertEqual(thrustHigh, 0.0)
    }

    func testThrustOutsideAltitudeRange() {
        // Too low (should operate but maybe inefficient, or model constraints)
        // The simple model uses ISA properties which work at 0, but canOperate checks range.
        // getThrust relies on model.
        // Let's check canOperate
        XCTAssertFalse(engine.canOperate(at: 10000.0, speed: 4.0))
        XCTAssertTrue(engine.canOperate(at: 60000.0, speed: 4.0))
    }

    func testFuelConsumption() {
        // Should consume fuel when producing thrust
        let fuel = engine.getFuelConsumption(altitude: 60000.0, speed: 4.0)
        XCTAssertGreaterThan(fuel, 0.0)

        // Should be 0 when no thrust
        let fuelNoThrust = engine.getFuelConsumption(altitude: 60000.0, speed: 0.5)
        XCTAssertEqual(fuelNoThrust, 0.0)
    }
}
