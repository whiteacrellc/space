//
//  PanelAerodynamicsSolver.swift
//  ssto
//
//  High-fidelity panel method aerodynamic solver for all flight regimes.
//  Computes lift and drag forces from surface pressure distribution.
//

import Foundation
import simd
import Accelerate

// MARK: - Data Structures

/// Drag force component breakdown
struct DragBreakdown {
    let skinFriction: Double         // Viscous drag (turbulent BL)
    let pressureDrag: Double         // Form + wave drag from panel pressures
    let inducedDrag: Double          // Vortex drag from lift
    let baseDrag: Double             // Blunt trailing edge
    let areaRulePenalty: Double      // Transonic penalty
    let total: Double
}

/// Complete aerodynamic force state
struct AerodynamicForces {
    let lift: Double                     // Lift force (N)
    let drag: Double                     // Drag force (N)
    let pitchMoment: Double              // Pitch moment (N·m)
    let CL: Double                       // Lift coefficient
    let CD: Double                       // Drag coefficient
    let angleOfAttack: Double            // Trim AoA (degrees)
    let pressureDistribution: [Double]   // Cp at each panel centroid
    let breakdown: DragBreakdown
}

// MARK: - Panel Aerodynamics Solver

class PanelAerodynamicsSolver {

    private let geometry: AerodynamicGeometry
    private let gamma: Double = 1.4  // Ratio of specific heats for air

    init(geometry: AerodynamicGeometry) {
        self.geometry = geometry
    }

    // MARK: - Main Entry Point

    /// Solve for aerodynamic forces at trim condition
    func solveTrimCondition(
        mach: Double,
        altitude: Double,
        velocity: Double,
        requiredLift: Double         // From weight - centrifugal (N)
    ) -> AerodynamicForces {

        // Get atmospheric properties
        let atm = AtmosphereModel.getAtmosphericConditions(altitudeFeet: altitude)
        let density = atm.density
        let dynamicPressure = 0.5 * density * velocity * velocity

        // 1. Determine required CL from trim condition
        let requiredCL = requiredLift / (dynamicPressure * geometry.planformArea)

        // 2. Estimate angle of attack for this CL (iterative)
        let alpha = estimateAlphaForCL(mach: mach, targetCL: requiredCL)

        // 3. Solve for pressure distribution based on regime
        let pressureCoeffs = solveRegime(mach: mach, alpha: alpha, altitude: altitude)

        // 4. Integrate panel pressures for lift and drag forces
        let (liftForce, dragPressure, pitchMoment) = integratePressureForces(
            pressureCoeffs: pressureCoeffs,
            dynamicPressure: dynamicPressure,
            alpha: alpha
        )

        // 5. Add viscous corrections (skin friction)
        let skinFrictionDrag = calculateSkinFrictionDrag(
            velocity: velocity,
            altitude: altitude,
            dynamicPressure: dynamicPressure
        )

        // 6. Calculate induced drag
        let oswaldEfficiency = estimateOswaldEfficiency(mach: mach)
        let inducedDrag = (requiredCL * requiredCL) / (.pi * geometry.aspectRatio * oswaldEfficiency)
        let inducedDragForce = inducedDrag * dynamicPressure * geometry.planformArea

        // 7. Base drag (blunt trailing edge)
        let baseDrag = calculateBaseDrag(mach: mach, dynamicPressure: dynamicPressure)

        // 8. Area rule penalty (transonic only)
        let areaRulePenalty = calculateAreaRulePenalty(mach: mach, dynamicPressure: dynamicPressure)

        // 9. Total drag
        let totalDrag = skinFrictionDrag + dragPressure + inducedDragForce + baseDrag + areaRulePenalty

        // 10. Coefficients
        let CL = liftForce / (dynamicPressure * geometry.planformArea)
        let CD = totalDrag / (dynamicPressure * geometry.planformArea)

        let breakdown = DragBreakdown(
            skinFriction: skinFrictionDrag,
            pressureDrag: dragPressure,
            inducedDrag: inducedDragForce,
            baseDrag: baseDrag,
            areaRulePenalty: areaRulePenalty,
            total: totalDrag
        )

        return AerodynamicForces(
            lift: liftForce,
            drag: totalDrag,
            pitchMoment: pitchMoment,
            CL: CL,
            CD: CD,
            angleOfAttack: alpha * 180.0 / .pi,  // Convert to degrees
            pressureDistribution: pressureCoeffs,
            breakdown: breakdown
        )
    }

    // MARK: - Regime Selection

    /// Select appropriate solver based on Mach number
    private func solveRegime(mach: Double, alpha: Double, altitude: Double) -> [Double] {
        if mach < 0.8 {
            return solveSubsonic(mach: mach, alpha: alpha)
        } else if mach < 1.2 {
            return solveTransonic(mach: mach, alpha: alpha)
        } else if mach < 5.0 {
            return solveSupersonic(mach: mach, alpha: alpha)
        } else {
            return solveHypersonic(mach: mach, alpha: alpha)
        }
    }

    // MARK: - Subsonic Solver (Vortex Lattice Method)

    /// Subsonic flow solver using simplified Vortex Lattice Method
    private func solveSubsonic(mach: Double, alpha: Double) -> [Double] {
        var pressureCoeffs: [Double] = []

        // Simplified VLM: Pressure coefficient based on panel inclination
        // Full VLM requires solving [AIC] matrix, which is computationally expensive
        // For game purposes, use analytical approximation

        for panel in geometry.panels {
            // Local inclination angle relative to freestream
            let panelAngle = calculatePanelAngle(panel: panel, alpha: alpha)

            // Prandtl-Glauert compressibility correction
            let beta = sqrt(1.0 - mach * mach)
            let Cp_incompressible = 2.0 * sin(panelAngle)

            // Apply compressibility correction
            let Cp = Cp_incompressible / beta

            pressureCoeffs.append(Cp)
        }

        return pressureCoeffs
    }

    // MARK: - Transonic Solver (Interpolation + Area Rule)

    /// Transonic flow solver with drag divergence and area rule penalty
    private func solveTransonic(mach: Double, alpha: Double) -> [Double] {
        // Interpolate between subsonic and supersonic solutions
        let subsonicCp = solveSubsonic(mach: 0.8, alpha: alpha)
        let supersonicCp = solveSupersonic(mach: 1.2, alpha: alpha)

        // Blend factor (0 at M=0.8, 1 at M=1.2)
        let blendFactor = (mach - 0.8) / 0.4

        var transonicCp: [Double] = []
        for i in 0..<geometry.panels.count {
            let Cp_sub = subsonicCp[i]
            let Cp_sup = supersonicCp[i]

            // Nonlinear blending (drag divergence spike at M≈1)
            let dragDivergenceFactor = 1.0 + 2.0 * sin(.pi * blendFactor)

            let Cp = Cp_sub + (Cp_sup - Cp_sub) * blendFactor * dragDivergenceFactor

            transonicCp.append(Cp)
        }

        return transonicCp
    }

    // MARK: - Supersonic Solver (Shock-Expansion Theory)

    /// Supersonic flow solver using linearized shock-expansion theory
    private func solveSupersonic(mach: Double, alpha: Double) -> [Double] {
        var pressureCoeffs: [Double] = []

        let beta = sqrt(mach * mach - 1.0)  // Mach angle parameter

        for panel in geometry.panels {
            // Local panel inclination angle
            let panelAngle = calculatePanelAngle(panel: panel, alpha: alpha)

            // Ackeret theory (linearized supersonic)
            // Cp = 2 * θ / sqrt(M² - 1)
            var Cp = 2.0 * panelAngle / beta

            // Sweep correction (Mach normal component)
            let sweepAngle = geometry.leadingEdgeSweep * .pi / 180.0
            let machNormal = mach * cos(sweepAngle)
            if machNormal > 1.0 {
                let betaNormal = sqrt(machNormal * machNormal - 1.0)
                Cp = 2.0 * panelAngle / betaNormal
            }

            // Apply sign based on windward/leeward
            if panelAngle < 0 {
                // Leeward surface (expansion)
                Cp = max(Cp, -1.0)  // Vacuum pressure limit
            } else {
                // Windward surface (compression/shock)
                Cp = min(Cp, 2.0 / (gamma * mach * mach))  // Stagnation limit
            }

            pressureCoeffs.append(Cp)
        }

        return pressureCoeffs
    }

    // MARK: - Hypersonic Solver (Modified Newtonian Impact Theory)

    /// Hypersonic flow solver using Modified Newtonian impact theory
    private func solveHypersonic(mach: Double, alpha: Double) -> [Double] {
        var pressureCoeffs: [Double] = []

        // Stagnation pressure coefficient (Modified Newtonian)
        let Cp_max = 2.0 / (gamma * mach * mach)

        for panel in geometry.panels {
            // Local panel inclination angle
            let panelAngle = calculatePanelAngle(panel: panel, alpha: alpha)

            var Cp: Double

            if panelAngle > 0 {
                // Windward surface: Cp = Cp_max * sin²(θ)
                Cp = Cp_max * sin(panelAngle) * sin(panelAngle)
            } else {
                // Leeward surface: Prandtl-Meyer expansion
                // Simplified: assume low pressure
                Cp = -0.2  // Base pressure approximation
            }

            pressureCoeffs.append(Cp)
        }

        return pressureCoeffs
    }

    // MARK: - Helper Functions

    /// Calculate panel inclination angle relative to freestream
    private func calculatePanelAngle(panel: SurfacePanel, alpha: Double) -> Double {
        // Freestream direction (in body axes, alpha = pitch angle)
        let freestream = SIMD3<Float>(
            Float(cos(alpha)),
            0,
            Float(sin(alpha))
        )

        // Panel normal
        let normal = panel.normal

        // Angle between freestream and panel normal
        // θ = acos(V · n) - π/2
        let dotProduct = simd_dot(freestream, normal)
        let angle = Double(acos(max(-1.0, min(1.0, dotProduct)))) - .pi / 2.0

        return angle
    }

    /// Integrate panel pressures to get lift, drag, and moment
    private func integratePressureForces(
        pressureCoeffs: [Double],
        dynamicPressure: Double,
        alpha: Double
    ) -> (lift: Double, drag: Double, moment: Double) {

        var liftForce: Double = 0.0
        var dragForce: Double = 0.0
        var pitchMoment: Double = 0.0

        for (i, panel) in geometry.panels.enumerated() {
            let Cp = pressureCoeffs[i]
            let pressure = Cp * dynamicPressure
            let force = pressure * panel.area

            // Force components in body axes
            let forceVector = SIMD3<Double>(
                Double(panel.normal.x) * force,
                Double(panel.normal.y) * force,
                Double(panel.normal.z) * force
            )

            // Rotate to wind axes (alpha rotation about Y)
            let lift_component = forceVector.x * sin(alpha) + forceVector.z * cos(alpha)
            let drag_component = forceVector.x * cos(alpha) - forceVector.z * sin(alpha)

            liftForce += lift_component
            dragForce += drag_component

            // Pitch moment about center (assume center at 50% length)
            let momentArm = Double(panel.centroid.x) - geometry.aircraftLength * 0.5
            pitchMoment += lift_component * momentArm
        }

        return (liftForce, dragForce, pitchMoment)
    }

    /// Estimate angle of attack required for target CL (iterative)
    private func estimateAlphaForCL(mach: Double, targetCL: Double) -> Double {
        // Simple analytical estimate based on regime
        var CLalpha: Double  // Lift curve slope (per radian)

        if mach < 0.8 {
            // Subsonic: CL = 2π * α * correction
            CLalpha = 2.0 * .pi / (1.0 + 2.0 / geometry.aspectRatio)
        } else if mach < 1.2 {
            // Transonic: reduced slope
            CLalpha = 1.5 * .pi
        } else if mach < 5.0 {
            // Supersonic: Ackeret theory CL = 4α / sqrt(M²-1)
            let beta = sqrt(mach * mach - 1.0)
            CLalpha = 4.0 / beta
        } else {
            // Hypersonic: Newtonian CL = 2 sin(α) cos(α) ≈ 2α for small α
            CLalpha = 2.0
        }

        // Alpha in radians
        let alpha = targetCL / CLalpha

        // Clamp to realistic range (-20° to +30°)
        return max(-0.35, min(0.52, alpha))
    }

    /// Calculate skin friction drag
    private func calculateSkinFrictionDrag(
        velocity: Double,
        altitude: Double,
        dynamicPressure: Double
    ) -> Double {

        let atm = AtmosphereModel.getAtmosphericConditions(altitudeFeet: altitude)
        let density = atm.density
        let viscosity = atm.viscosity

        // Reynolds number
        let Re = density * velocity * geometry.aircraftLength / viscosity

        // Turbulent flat plate skin friction coefficient
        // Cf = 0.455 / (log₁₀(Re))^2.58
        let logRe = log10(max(1e5, Re))
        let Cf = 0.455 / pow(logRe, 2.58)

        // Wetted area drag
        let skinFrictionDrag = Cf * geometry.wettedArea * dynamicPressure

        return skinFrictionDrag
    }

    /// Estimate Oswald efficiency factor
    private func estimateOswaldEfficiency(mach: Double) -> Double {
        // Oswald efficiency 'e' typically 0.7-0.95
        // Lower at supersonic speeds due to wave drag effects

        if mach < 0.8 {
            return 0.85
        } else if mach < 1.2 {
            return 0.75
        } else {
            return 0.60
        }
    }

    /// Calculate base drag from blunt trailing edge
    private func calculateBaseDrag(mach: Double, dynamicPressure: Double) -> Double {
        // Base drag coefficient Cd_base ≈ 0.02-0.05
        // Depends on base area (assume 2% of planform area)
        let baseArea = geometry.planformArea * 0.02
        let Cd_base = 0.03

        return Cd_base * baseArea * dynamicPressure
    }

    /// Calculate area rule penalty for transonic flight
    private func calculateAreaRulePenalty(mach: Double, dynamicPressure: Double) -> Double {
        // Only applies in transonic regime (0.8 < M < 1.4)
        if mach < 0.8 || mach > 1.4 {
            return 0.0
        }

        // Compute second derivative of volume distribution
        let volumeDist = geometry.volumeDistribution
        var curvaturePenalty: Double = 0.0

        for i in 1..<(volumeDist.count - 1) {
            let d2A = volumeDist[i-1] - 2.0 * volumeDist[i] + volumeDist[i+1]
            curvaturePenalty += abs(d2A)
        }

        // Peak penalty at M=1.0
        let transonicFactor = sin(.pi * (mach - 0.8) / 0.6)

        // Area rule drag coefficient
        let Cd_area_rule = curvaturePenalty * 0.05 * transonicFactor

        return Cd_area_rule * geometry.planformArea * dynamicPressure
    }
}
