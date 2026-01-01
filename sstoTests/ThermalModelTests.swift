//
//  ThermalModelTests.swift
//  sstoTests
//
//  Created by tom whittaker on 11/26/25.
//

import XCTest
@testable import ssto

final class ThermalModelTests: XCTestCase {

    func testCalculateTemperatureConvenience() {
        // Test inputs in Feet and Mach
        let altitudeFt = 70000.0
        let mach = 3.0
        
        let temp = ThermalModel.calculateTemperature(altitude: altitudeFt, speed: mach)
        
        // At Mach 3 at 70k feet, we expect significant heating.
        // Ambient is ~216K (-56C).
        // Stagnation (Adiabatic) ~ 216 * (1 + 0.2 * 9) = 216 * 2.8 = 604K = 331C.
        // With radiation, it should be lower, maybe 250-300C.
        // Let's assert a reasonable range.
        
        XCTAssertGreaterThan(temp, 100.0, "Temperature should be hot at Mach 3")
        XCTAssertLessThan(temp, 1000.0, "Temperature should not be absurdly high for Mach 3")
    }
    
    func testCalculateLeadingEdgeTemperatureCore() {
        // Test inputs in Meters and m/s
        let altitudeM = 20000.0 // 20km
        let speedMps = 1000.0   // 1 km/s (~Mach 3.3)
        
        let temp = ThermalModel.calculateLeadingEdgeTemperature(altitude: altitudeM, velocity: speedMps)
        
        XCTAssertGreaterThan(temp, 200.0)
    }
    
    func testMaxSafeTempConstant() {
        XCTAssertEqual(ThermalModel.maxSafeTemp, 600.0, "maxSafeTemp should be 600.0")
    }
    
    func testThermalLimits() {
        let design = PlaneDesign.defaultDesign
        let limit = ThermalModel.getMaxTemperature(for: design)
        
        // Check normal flight
        let (exceeded1, temp1, _) = ThermalModel.checkThermalLimits(altitude: 30000, velocity: 200, planeDesign: design)
        XCTAssertFalse(exceeded1, "Subsonic flight should not exceed thermal limits")
        XCTAssertLessThan(temp1, limit)
        
        // Check extreme flight
        let (exceeded2, temp2, _) = ThermalModel.checkThermalLimits(altitude: 0, velocity: 3000, planeDesign: design)
        XCTAssertTrue(exceeded2, "Hypersonic flight at sea level MUST exceed thermal limits")
        XCTAssertGreaterThan(temp2, limit)
    }
    
    func testAtmosphereIntegration() {
        // Ensure that higher altitude (lower density) results in lower temperature for same Mach?
        // Wait, T_stagnation depends mostly on T_ambient and Mach.
        // T_ambient is constant in stratosphere.
        // But radiative cooling depends on density. Lower density -> lower heat flux -> lower T_wall (closer to T_ambient, further from T_adiabatic).
        // So at same Mach, higher altitude should be cooler.
        
        let mach = 5.0
        
        let tempLowAlt = ThermalModel.calculateTemperature(altitude: 30000, speed: mach) // 30k ft
        let tempHighAlt = ThermalModel.calculateTemperature(altitude: 80000, speed: mach) // 80k ft
        
        // At 80k ft, density is much lower. Heat flux is lower. Radiation cools it more effectively relative to input.
        XCTAssertLessThan(tempHighAlt, tempLowAlt, "Higher altitude should be cooler at same Mach due to radiative equilibrium")
    }
}
