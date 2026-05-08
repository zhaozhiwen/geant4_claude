---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-parameterisations-par01


Par01 shows how to replace full Geant4 transport inside a calorimeter with a parametric shower model: when a primary enters the envelope logical volume, the `G4VFastSimulationModel` fires on the first step, distributes energy as discrete spots via a private `G4Navigator`, and returns — the particle is consumed and no shower tracking occurs inside the envelope. An EM model is bolted to the EM calorimeter volume directly; a pion model uses a ghost volume spanning both EM and hadronic calorimeters to avoid touching the mass geometry. `G4FastSimulationPhysics` must be added to the physics list or the model is registered but never fires. This is the mechanism that makes LHC-scale calorimeter simulations tractable.

## Key concepts demonstrated
- `fast-simulation-model` — `G4VFastSimulationModel` override of `IsApplicable` and `DoIt`; the plumbing for parametric shower replacement
- `envelope-volume` — any LV can become a fast-simulation region by binding a `G4FastSimulationManager`; no special solid type required
- `ghost-volumes` — parallel-world geometry used to define a fast-model envelope that spans multiple mass-world volumes without restructuring them
- `fast-simulation-physics` — `G4FastSimulationPhysics` constructor must be in the physics list; without it the model silently never fires
- `energy-spot-navigator` — model emits `(position, edep)` pairs; a `G4Navigator` distributes them into the correct LV, decoupling shower shape from geometry boundaries
