---
type: source
domain: detector-sim
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-advanced-hadrontherapy


The reference proton/ion-therapy beamline simulation, featuring five interchangeable real clinical beamlines selectable at runtime, a voxelized water phantom (200×1×1 slices, 0.2 mm each), and per-voxel scoring of dose, dose-averaged LET, and RBE using the LEM model with three cell lines. It demonstrates what a production dosimetry simulation looks like: parametric geometry driven by UI commands, scoring decoupled from construction via a parallel readout geometry, and validation against shipped experimental data.

## Key concepts demonstrated
- `runtime-geometry-switching` — a controller/messenger pair lets `/geometrySetup/selectGeometry <name>` rebuild the beamline world without recompiling
- `parallel-world-scoring` — `G4ParallelWorldPhysics` overlays a voxel dose grid that doesn't perturb the physical geometry tree; the canonical decoupling of scoring from construction
- `step-size-limits` — `/Step/waterPhantomStepMax 0.01 mm` is mandatory in thin scoring slices; without it, the default step can traverse an entire voxel and miss it entirely
- `dose-averaged-let` — `HadrontherapyLet` builds LET on top of step-level edep/path data; Geant4 does not compute this natively
- `medical-physics-builders` — `HADRONTHERAPY_1` (proton-optimized) and `_2` (ion-optimized) modular physics constructors document the domain-specific physics-list menu
