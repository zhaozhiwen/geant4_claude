---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-field-field01


field01 is the authoritative reference for setting up a magnetic field with the modern post-Geant4-10.4 API: `G4FieldBuilder` constructs the equation of motion, chord finder, and Runge-Kutta integrator and exposes `/field/...` macro commands so the stepper type, minimum step, and field magnitude are all runtime-configurable without recompiling. The example exhaustively documents the three-layer looper-threshold override system (`G4TransportationParameters` → `G4PhysicsListHelper` → `RunAction`) and names the silent failure mode — low-energy electrons being killed without warning — that surprises every first-time field user. The stepper menu (DP745 default, FSAL variants, non-smooth-field options) and `G4StepLimiterPhysics` are covered as the practical set of knobs.

## Key concepts demonstrated
- `g4-field-builder` — modern facade for field setup; replaces manual `G4Mag_UsualEqRhs` + `G4MagIntegratorStepper` + `G4ChordFinder` boilerplate; auto-creates `/field/...` messenger
- `rk-stepper-selection` — `DormandPrince745` is the correct default for smooth fields since Geant4 10.4; FSAL variants halve field-eval cost for smooth fields; non-FSAL needed at field discontinuities
- `looper-thresholds` — three energy parameters control when curling low-E particles are killed; below the warning energy the kill is silent; `UseLowLooperThresholds()` vs. `UseHighLooperThresholds()` is a one-line physics choice
- `transportation-parameters` — `G4TransportationParameters` singleton sets looper thresholds before physics construction; PhysicsListHelper and RunAction methods override it in that order
- `step-limiter-physics` — `G4StepLimiterPhysics` registers a process that respects per-LV `G4UserLimits::MaxAllowedStep`; standard companion to field sims with long-free-path particles
