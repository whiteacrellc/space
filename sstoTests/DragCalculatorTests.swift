
import Testing
@testable import ssto

struct DragCalculatorTests {

    @Test func testGeometryAnalysis() {
        // Given default planform
        // Nose: 50, Tail: 750 (Canvas Length = 700)
        // Length: 70m. Scale = 0.1 m/unit
        // Mid Width: 84 (Half). Total Width = 168.
        // Approx Area (Triangle + Rectangle-ish)
        // Let's rely on consistency rather than exact values unless we integrate by hand.
        
        let planform = TopViewPlanform.defaultPlanform
        let (area, span) = GeometryAnalyzer.calculatePlanformProperties(planform: planform)
        
        // Check reasonable bounds
        // Span: max half width ~85 + wing span ~67 = ~152. Full span ~304 canvas units.
        // Scale: 70 / 700 = 0.1
        // Span Meters: ~23.5m (max width ~117 * 2 * 0.1)
        #expect(span > 20.0 && span < 30.0, "Span should be around 23m, got \(span)")
        
        // Area: Length 70m * Avg Width (~15m?) ~ 1000m²
        #expect(area > 200.0 && area < 2000.0, "Area should be reasonable for a 70m aircraft, got \(area)")
    }
    
    @Test func testZeroLiftDrag() {
        let calc = DragCalculator()
        
        // Subsonic
        let cd0_sub = calc.getCd0(mach: 0.5)
        #expect(cd0_sub > 0.01 && cd0_sub < 0.1, "Subsonic Cd0 reasonable")
        
        // Transonic Peak
        let cd0_tran = calc.getCd0(mach: 1.2)
        #expect(cd0_tran > cd0_sub, "Transonic drag should be higher than subsonic")
        
        // Supersonic Decay
        let cd0_super = calc.getCd0(mach: 3.0)
        #expect(cd0_super < cd0_tran, "Supersonic drag should decay from peak")
    }
    
    @Test func testInducedDrag() {
        let calc = DragCalculator()
        
        // Sea level, 100 m/s
        let alt = 0.0
        let vel = 100.0
        
        // Zero Lift
        let dragZero = calc.calculateDrag(altitude: alt, velocity: vel, lift: 0.0)
        
        // Heavy Lift (e.g. takeoff weight ~500,000 N)
        let lift = 500000.0
        let dragHeavy = calc.calculateDrag(altitude: alt, velocity: vel, lift: lift)
        
        #expect(dragHeavy > dragZero, "Induced drag should increase total drag")
        
        // Check scaling with lift squared
        let dragHeavy2 = calc.calculateDrag(altitude: alt, velocity: vel, lift: lift * 2.0)
        let induced1 = dragHeavy - dragZero
        let induced2 = dragHeavy2 - dragZero
        
        // Should be roughly 4x (within FP error)
        let ratio = induced2 / induced1
        #expect(abs(ratio - 4.0) < 0.1, "Induced drag should scale with lift squared")
    }
    
    @Test func testDragRegimeOutput() {
        let calc = DragCalculator()
        let regime = calc.getDragRegime(velocity: 3000.0, altitude: 20000.0)
        #expect(regime.contains("Hypersonic"), "Should detect hypersonic regime")
    }
}
