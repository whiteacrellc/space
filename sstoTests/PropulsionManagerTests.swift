//
//  PropulsionManagerTests.swift
//  sstoTests
//
//  Created by tom whittaker on 11/25/25.
//

import XCTest
@testable import ssto

class PropulsionManagerTests: XCTestCase {

    var manager: PropulsionManager!

    override func setUp() {
        super.setUp()
        manager = PropulsionManager()
    }

    func testInitialState() {
        // Should default to Rocket
        XCTAssertEqual(manager.currentMode, .rocket)
        XCTAssertTrue(manager.isAutoMode)
    }

    func testEngineSelectionLowSpeed() {
        // At low speed, should use Rocket
        let (engine, mode) = manager.selectOptimalEngine(altitude: 0.0, speed: 0.5)
        XCTAssertEqual(mode, .rocket)
        XCTAssertTrue(engine is RocketEngine)
    }

    func testEngineSelectionMidSpeedHighAlt() {
        // Mach 4, 60k ft -> Ejector-Ramjet should be viable and likely efficient
        let (engine, mode) = manager.selectOptimalEngine(altitude: 60000.0, speed: 4.0)
        
        // Note: Selection depends on efficiency. 
        // Rocket efficiency is low (Isp ~300s -> ~3000 m/s exhaust velocity).
        // Ramjet/Ejector-Ramjet efficiency is high (Isp ~1000s+ equivalent).
        // So it should pick Ejector-Ramjet.
        
        XCTAssertEqual(mode, .ejectorRamjet)
        XCTAssertTrue(engine is EjectorRamjetEngine)
    }

    func testEngineSelectionScramjetConditions() {
        // Mach 8, 100k ft -> Scramjet territory
        let (engine, mode) = manager.selectOptimalEngine(altitude: 100000.0, speed: 8.0)
        
        // Scramjet starts at Mach 5. Ejector-Ramjet goes up to 10.
        // It depends on which is more efficient at Mach 8.
        // Usually Scramjet takes over around Mach 6-7.
        // Let's assert it is one of them.
        XCTAssertTrue(mode == .scramjet || mode == .ejectorRamjet)
    }

    func testManualMode() {
        manager.setManualEngine(.rocket)
        XCTAssertFalse(manager.isAutoMode)
        XCTAssertEqual(manager.currentMode, .rocket)

        // Update shouldn't change it even if conditions favor another
        manager.update(altitude: 60000.0, speed: 4.0)
        XCTAssertEqual(manager.currentMode, .rocket)
        
        // Re-enable auto
        manager.enableAutoMode()
        XCTAssertTrue(manager.isAutoMode)
        
        // Now update should switch
        manager.update(altitude: 60000.0, speed: 4.0)
        XCTAssertEqual(manager.currentMode, .ejectorRamjet)
    }
}
