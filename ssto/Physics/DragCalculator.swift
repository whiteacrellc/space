//
//  DragCalculator.swift
//  ssto
//
//  Calculates aerodynamic forces (Drag) based on aircraft geometry and flight conditions.
//  Implements a component buildup method for drag estimation:
//  Total Cd = Cd0_compressible(Mach) + Cdi(Lift, Mach)
//

import Foundation
import SceneKit
import CoreGraphics

// MARK: - Aerodynamic Configuration

/// Stores derived geometric and aerodynamic properties of the aircraft
struct AerodynamicConfiguration {
    let referenceArea: Double       // Planform Area (m²) - S
    let wingspan: Double            // Wingspan (m) - b
    let aspectRatio: Double         // AR = b² / S
    let oswaldEfficiency: Double    // e (0.7 - 0.9 typically)
    let dragMultiplier: Double      // Shape factor from design (1.0 nominal)
    
    /// Initialize from raw geometry
    init(planform: TopViewPlanform, design: PlaneDesign) {
        // Calculate geometry
        let (area, span) = GeometryAnalyzer.calculatePlanformProperties(planform: planform)
        
        self.referenceArea = max(1.0, area) // Avoid div/0
        self.wingspan = span
        self.aspectRatio = (span * span) / self.referenceArea
        
        // Estimate Oswald Efficiency based on Sweep
        // Highly swept wings typically have lower 'e' at low speeds but are optimized for high speed
        // Simple approximation:
        self.oswaldEfficiency = 0.85
        
        self.dragMultiplier = design.dragMultiplier()
    }
}

// MARK: - Geometry Analyzer

/// Helper to calculate geometric properties from design data
class GeometryAnalyzer {
    
    /// Calculate Planform Area (S) and Wingspan (b)
    static func calculatePlanformProperties(planform: TopViewPlanform) -> (area: Double, span: Double) {
        let noseX = planform.noseTip.x
        let tailX = planform.tailLeft.x
        let length = planform.aircraftLength
        
        // Canvas to Meters scale factor
        let scale = length / max(1.0, tailX - noseX)
        
        // Numerical Integration for Area
        let steps = 100
        let dx = (tailX - noseX) / Double(steps)
        var totalAreaCanvas: Double = 0.0
        var maxHalfSpanCanvas: Double = 0.0
        
        for i in 0...steps {
            let x = noseX + Double(i) * dx
            // getPlanformWidth returns total width or half width?
            // DragCalculator original impl seems to imply half width logic in bezier solve (y coordinates)
            // Let's verify: midLeft.y is ~ -80. So getPlanformWidth returning abs(y) is half-width.
            let halfWidth = getPlanformHalfWidth(at: x, planform: planform)
            
            if i == 0 || i == steps {
                totalAreaCanvas += halfWidth
            } else {
                totalAreaCanvas += 2.0 * halfWidth
            }
            
            if halfWidth > maxHalfSpanCanvas {
                maxHalfSpanCanvas = halfWidth
            }
        }
        
        totalAreaCanvas *= (dx / 2.0)
        
        // Total Planform Area = 2 * Half Area (Symmetric)
        let totalPlanformAreaCanvas = totalAreaCanvas * 2.0
        let fullSpanCanvas = maxHalfSpanCanvas * 2.0
        
        // Convert to Meters
        // Area scales with scale^2
        let areaMeters = totalPlanformAreaCanvas * scale * scale
        // Span scales with scale
        let spanMeters = fullSpanCanvas * scale
        
        return (areaMeters, spanMeters)
    }
    
    /// Interpolates the Top View Planform to get half-width at a given X (Canvas Units)
    static func getPlanformHalfWidth(at x: Double, planform: TopViewPlanform) -> Double {
        let noseTip = planform.noseTip.toCGPoint()
        let frontControlLeft = planform.frontControlLeft.toCGPoint()
        let midLeft = planform.midLeft.toCGPoint()
        let rearControlLeft = planform.rearControlLeft.toCGPoint()
        let tailLeft = planform.tailLeft.toCGPoint()

        // Before nose
        if x < noseTip.x { return 0.0 }
        
        // Fuselage Body
        var halfWidth: Double = 0.0
        
        if x <= midLeft.x {
            let segmentLength = midLeft.x - noseTip.x
            if segmentLength <= 0 { return 0.0 }
            let t = (x - noseTip.x) / segmentLength
            halfWidth = solveQuadraticBezierY(t: t, p0: noseTip, p1: frontControlLeft, p2: midLeft)
        } else if x <= tailLeft.x {
            let segmentLength = tailLeft.x - midLeft.x
            if segmentLength <= 0 { return abs(midLeft.y) }
            let t = (x - midLeft.x) / segmentLength
            halfWidth = solveQuadraticBezierY(t: t, p0: midLeft, p1: rearControlLeft, p2: tailLeft)
        } else {
            return abs(tailLeft.y)
        }
        
        // Wing contribution
        // Check if we need to add wings. The legacy DragCalculator logic relied on "PlanformWidth"
        // which seemed to just be the fuselage spline.
        // However, LiftingBody.swift has wing logic:
        // wingStartX = nose + length * wingStartPos
        // wingTip = fuselageWidthAtTail + wingSpan
        // For accurate drag, we MUST include wing area.
        
        let fuselageLen = tailLeft.x - noseTip.x
        let wingStartX = noseTip.x + (fuselageLen * planform.wingStartPosition)
        let wingEndX = tailLeft.x
        
        if x >= wingStartX && x <= wingEndX {
            let t = (x - wingStartX) / (wingEndX - wingStartX)
            
            // Fuselage width at start/end of wing
            // We can approximate or re-calc. For speed, let's assume linear growth of wing
            // from fuselage surface.
            
            // Re-calculate fuselage width at start/end to be precise
            // But 'halfWidth' is already the fuselage width at current X.
            // The wing extends BEYOND this.
            
            // Wait, TopViewShapeView draws wings separately.
            // The wing is a triangle added to the side.
            // Leading edge starts at (wingStartX, fuselageWidth(wingStartX))
            // Trailing edge ends at (wingEndX, fuselageWidth(wingEndX) + wingSpan)
            // This is a swept delta wing attached to the side.
            
            // Get fuselage width at wing end (tail)
            let tailHalfWidth = abs(tailLeft.y)
            let wingTipY = tailHalfWidth + planform.wingSpan
            
            // Get fuselage width at wing start
            // (Recursively call self? No, extract logic)
            // Just assume the current `halfWidth` is the inner boundary.
            
            // Interpolate outer boundary
            // Outer boundary goes from (wingStartX, fuselageWidthAtStart) -> (wingEndX, wingTipY)
            let fuselageWidthAtStart = getFuselageOnlyHalfWidth(at: wingStartX, planform: planform)
            
            let outerY = fuselageWidthAtStart + (wingTipY - fuselageWidthAtStart) * t
            
            // If the wing sticks out further than the fuselage, that's our new max width
            halfWidth = max(halfWidth, outerY)
        }
        
        return halfWidth
    }
    
    private static func getFuselageOnlyHalfWidth(at x: Double, planform: TopViewPlanform) -> Double {
        let noseTip = planform.noseTip.toCGPoint()
        let frontControlLeft = planform.frontControlLeft.toCGPoint()
        let midLeft = planform.midLeft.toCGPoint()
        let rearControlLeft = planform.rearControlLeft.toCGPoint()
        let tailLeft = planform.tailLeft.toCGPoint()
        
        if x < noseTip.x { return 0.0 }
        if x <= midLeft.x {
            let t = (x - noseTip.x) / max(1.0, midLeft.x - noseTip.x)
            return solveQuadraticBezierY(t: max(0, min(1, t)), p0: noseTip, p1: frontControlLeft, p2: midLeft)
        } else if x <= tailLeft.x {
            let t = (x - midLeft.x) / max(1.0, tailLeft.x - midLeft.x)
            return solveQuadraticBezierY(t: max(0, min(1, t)), p0: midLeft, p1: rearControlLeft, p2: tailLeft)
        }
        return abs(tailLeft.y)
    }

    private static func solveQuadraticBezierY(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> Double {
        let u = 1 - t
        let y = u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
        return abs(y)
    }
}

// MARK: - Drag Calculator

/**
 A Swift module for calculating aerodynamic properties, specifically the Drag Coefficient (Cd),
 for an aircraft at various flight regimes.
 
 Uses Reference Area (S) for all coefficient calculations.
 */
class DragCalculator {

    // Aircraft characteristics
    private var config: AerodynamicConfiguration
    private let baselineZeroLiftCd: Double // Cd0_subsonic

    /// Initialize with optional overrides or current game state
    init(baselineDragCoefficient: Double = 0.020,
         planeDesign: PlaneDesign? = nil,
         planform: TopViewPlanform? = nil) {
        
        self.baselineZeroLiftCd = baselineDragCoefficient
        
        // Use provided values or fall back to GameManager
        let effectivePlanform = planform ?? GameManager.shared.getTopViewPlanform()
        let effectiveDesign = planeDesign ?? GameManager.shared.getPlaneDesign()
        
        self.config = AerodynamicConfiguration(planform: effectivePlanform, design: effectiveDesign)
        
        print("DragCalculator Initialized:")
        print("  Reference Area (S): \(String(format: "%.2f", config.referenceArea)) m²")
        print("  Wingspan (b): \(String(format: "%.2f", config.wingspan)) m")
        print("  Aspect Ratio (AR): \(String(format: "%.2f", config.aspectRatio))")
    }
    
    // MARK: - Drag Calculation
    
    /**
     Calculate total drag force acting on the aircraft.
     F_drag = q * S * (Cd0(M) + Cdi(M, CL))
     
     - Parameters:
       - altitude: Altitude in meters
       - velocity: Velocity in meters per second
       - lift: Lift force required (Newtons). If omitted, assumes zero-lift drag.
     - Returns: Drag force in Newtons
     */
    func calculateDrag(altitude: Double, velocity: Double, lift: Double = 0.0) -> Double {
        guard altitude >= 0, velocity >= 0 else {
            return 0.0
        }

        // 1. Atmosphere
        let density = AtmosphereModel.atmosphericDensity(at: altitude)
        let speedOfSound = AtmosphereModel.speedOfSound(at: altitude)

        // 2. Flight Conditions
        let mach = velocity / speedOfSound
        let dynamicPressure = 0.5 * density * velocity * velocity
        
        guard dynamicPressure > 0.001 else { return 0.0 }

        // 3. Coefficients
        // Zero-Lift Drag Coefficient (Parasitic + Wave)
        let cd0 = getZeroLiftDragCoefficient(Ma: mach)
        
        // Induced Drag Coefficient (Lift-Dependent)
        // Cdi = k * CL²
        let cl = lift / (dynamicPressure * config.referenceArea)
        let cdi = getInducedDragCoefficient(cl: cl, mach: mach)
        
        // Total Cd
        let totalCd = cd0 + cdi

        // 4. Force
        let dragForce = dynamicPressure * totalCd * config.referenceArea

        return dragForce
    }

    /**
     Get the zero-lift drag coefficient (Cd0) at specified Mach number.
     Includes skin friction, form drag, and zero-lift wave drag.
     */
    func getCd0(mach: Double) -> Double {
        return getZeroLiftDragCoefficient(Ma: mach)
    }
    
    /**
     Get the drag coefficient (Cd) at specified Mach number and altitude.
     Currently returns the zero-lift drag coefficient (Cd0).
     Kept for backward compatibility.
     */
    func getCd(mach: Double, altitude: Double) -> Double {
        return getCd0(mach: mach)
    }

    /**
     Estimates the Zero-Lift Drag Coefficient (Cd0) based on Mach number.
     References Planform Area.
     */
    private func getZeroLiftDragCoefficient(Ma: Double) -> Double {
        var cd = baselineZeroLiftCd

        if Ma < 0.8 {
            // Subsonic: Constant Cd0
            cd = baselineZeroLiftCd

        } else if Ma < 1.2 {
            // Transonic: Drag Divergence
            // Quadratic rise to peak
            let delta = Ma - 0.8
            let dragRiseFactor = 1.0 + delta * delta * 20.0 // Peak ~4x baseline at Mach 1.2
            cd = baselineZeroLiftCd * dragRiseFactor

        } else if Ma < 4.0 {
            // Supersonic: Wave drag dominates but coefficient drops with Mach (Prandtl-Glauert / Ackeret)
            // Model: Peak at 1.2, then decay roughly proportional to 1/sqrt(M^2 - 1)
            // Simplified algebraic decay
            let peakCd = baselineZeroLiftCd * 4.2 // Peak value
            let factor = (Ma - 1.2) / 2.8
            // Linear-ish decay for simplicity in this range
            cd = peakCd - (peakCd - baselineZeroLiftCd * 2.0) * factor

        } else {
            // Hypersonic: High speed floor
            // Viscous interaction effects might increase it slightly, but generally Cd is low
            cd = baselineZeroLiftCd * 2.0
        }

        // Apply plane design drag multiplier (shape factor penalty)
        cd *= config.dragMultiplier

        return cd
    }

    /**
     Calculate induced drag coefficient.
     C_di = C_L² / (π * AR * e)
     
     Note: In supersonic flow, "e" effectively decreases, or we can model wave drag due to lift.
     For simplicity, we assume standard induced drag formula but 'e' could degrade with Mach.
     */
    private func getInducedDragCoefficient(cl: Double, mach: Double) -> Double {
        // Oswald efficiency degradation with Mach (simplified)
        var e = config.oswaldEfficiency
        if mach > 1.0 {
            e *= 0.6 // Significant efficiency loss in supersonic lift
        }
        
        let k = 1.0 / (Double.pi * config.aspectRatio * e)
        return k * cl * cl
    }

    /**
     Get diagnostic information about current flight regime.
     */
    func getDragRegime(velocity: Double, altitude: Double) -> String {
        let speedOfSound = AtmosphereModel.speedOfSound(at: altitude)
        let mach = velocity / speedOfSound

        let regime: String
        if mach < 0.8 {
            regime = "Subsonic"
        } else if mach < 1.2 {
            regime = "Transonic"
        } else if mach < 5.0 {
            regime = "Supersonic"
        } else {
            regime = "Hypersonic"
        }

        return "\(regime) (M \(String(format: "%.2f", mach)))"
    }
}