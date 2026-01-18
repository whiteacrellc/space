# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS SpriteKit/SceneKit game simulating a Single-Stage-To-Orbit (SSTO) aircraft. Players design a lifting-body aircraft, create a flight plan with waypoints, and simulate ascent to orbit while managing propulsion systems (ramjet/ejector, ramjet, scramjet, rocket) and thermal limits. The goal of the game is to create an aircrate that can get to orbit with the lowest dry weight. 

## Build Commands

```bash
# Build the project
xcodebuild -project ssto.xcodeproj -scheme ssto -configuration Debug build

# Run tests
xcodebuild test -project ssto.xcodeproj -scheme ssto -destination 'platform=iOS Simulator,name=iPhone 15'

# Clean build folder
xcodebuild clean -project ssto.xcodeproj -scheme ssto
```

## Architecture

### Scene Flow
The app follows a scene-based navigation pattern using SpriteKit:
1. **MenuScene** - Entry point with game options
2. **TopViewDesignViewController** (UIKit) - Design aircraft planform shape via cone-plane intersection
3. **SSTODesignViewController** (UIKit) - Design side profile cross-section using Bézier splines
4. **FlightPlanningScene** - Create waypoint-based flight plan (altitude/speed/engine mode)
5. **SimulationScene** - Execute physics simulation and visualize results
6. **ResultsScene** - Display mission outcome and scoring

### Core Systems

#### GameManager (Singleton)
- Manages global state: current flight plan, aircraft design, mission results
- Coordinates between UI scenes and simulation systems
- Stores cross-section spline points (`CrossSectionPoints`) for 3D geometry generation
- Location: `ssto/Managers/GameManager.swift`

#### Aircraft Geometry Engine
The lifting-body shape is generated using a two-stage process:

1. **Planform (Top View)**: Cone-plane intersection defines leading edge shape
   - User controls: `coneAngle`, `sweepAngle`, `tiltAngle`, `position`
   - Code: `LiftingBodyEngine.generateCrossSections()` in `ssto/Models/LiftingBody.swift`
   - The intersection curve determines spanwise distribution (width at each X station)

2. **Cross-Section (Side View)**: User-defined spline controls vertical profile
   - Defined by top/bottom Bézier control points stored in `GameManager`
   - Code: `LiftingBodyEngine.generateCrossSectionFromSpline()`
   - Applied at each longitudinal station, scaled by span and position

3. **3D Mesh Generation**: Combines planform + cross-section
   - Creates NURBS-like interpolated surface with ~60 longitudinal sections
   - Tapers from centerline height to wingtip height
   - Code: `LiftingBodyEngine.generateMeshFromSections()`

#### Physics Simulation
Located in `ssto/Physics/`:
- **FlightSimulator**: Main simulation loop integrating forces, updating state
  - Time-stepped integration (0.1s default)
  - Manages fuel consumption, altitude, velocity
  - Records trajectory points for visualization
- **DragCalculator**: Computes drag based on `PlaneDesign` parameters and atmospheric conditions
- **ThermalModel**: Calculates leading-edge temperature and checks thermal limits
- **AircraftVolumeModel**: Computes internal volume for payload/fuel capacity
- **AtmosphereModel**: Provides density/pressure/temperature vs altitude

#### Propulsion System
Located in `ssto/Propulsion/`:
- **PropulsionManager**: Selects optimal engine based on altitude/speed or manual override
- **PropulsionEngines.swift**: Defines four engine types with operating envelopes:
  - **JetEngine**: 0-50k ft, Mach 0-3
  - **RamjetEngine**: 40k-100k ft, Mach 2-6
  - **ScramjetEngine**: 80k-200k ft, Mach 4-15
  - **RocketEngine**: All altitudes, Mach 0-30
- Each engine has efficiency curves affecting thrust and fuel consumption

#### Design Scoring
`PlaneDesign` (in `ssto/Models/PlaneDesign.swift`) calculates performance multipliers:
- **thermalLimitMultiplier()**: Sharp leading edges heat faster (lower max temp)
- **heatingRateMultiplier()**: Inverse of thermal limit
- Optimal design: tilt=0°, sweep=80-100°, position=174

**Note:** Drag is now computed from actual aircraft geometry using panel methods (`PanelAerodynamicsSolver`). The old `dragMultiplier()` has been removed.

### Data Models
- **PlaneDesign**: Cone-plane parameters (sweep, tilt, position) with physics multipliers
- **FlightPlan**: Ordered list of `Waypoint` objects
- **Waypoint**: Target altitude (ft), speed (Mach), engine mode
- **MissionResult**: Contains trajectory segments, fuel used, success state, score
- **CrossSectionPoints**: Serializable spline control points (top/bottom curves)

## Key Coordinate Systems

1. **Model Space** (geometry generation):
   - Origin at aircraft apex (0,0,0)
   - X = longitudinal (fuselage length)
   - Y = spanwise (width)
   - Z = vertical (height)

2. **Canvas Space** (2D design UIs):
   - Origin at bottom-left
   - Uses `modelToView()` / `viewToModel()` conversions

3. **SceneKit 3D Space**:
   - Y-up convention
   - Lighting positioned to show surface contours

## Important Physics Constants
Located in `ssto/Physics/PhysicsConstants.swift`:
- Orbit altitude: 400,000 ft (~122 km)
- Orbit speed: Mach 25
- Dry mass: 15,000 kg
- Fuel density: 0.81 kg/L
- Reference area: 500 m²

## Testing Patterns

When writing tests for simulation components:
- Use fixed seed designs (e.g., `PlaneDesign.defaultDesign`)
- Mock `PropulsionManager` when testing `FlightSimulator` in isolation
- Verify trajectory points contain expected fields: time, altitude, speed, fuel, temperature
- Check thermal limits are enforced (temperature < max safe temp)

## Common Development Patterns

- Scene transitions use `SKTransition.fade(withDuration: 1.0)`
- SceneKit geometry updates require calling `setNeedsDisplay()` or regenerating node geometry
- GameManager state should be updated before transitioning to dependent scenes
- 3D viewports use `LiftingBody3DViewController` or `WireframeViewController`
- All UI scenes are landscape-only (enforced in `GameViewController`)
