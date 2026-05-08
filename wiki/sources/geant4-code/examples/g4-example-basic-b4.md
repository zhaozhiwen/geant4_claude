---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - scoring-strategy
  - replica-volume
  - analysis-manager
  - custom-g4run
  - multifunctional-detector
  - primitive-scorer
  - sampling-calorimeter
---

# g4-example-basic-b4


B4 uses a simple sampling calorimeter (lead absorber + liquid argon active layers) as a fixed backdrop to compare four scoring strategies side-by-side: (a) `SteppingAction` into `EventAction` data members, (b) `SteppingAction` into a custom `G4Run` subclass, (c) custom `G4VSensitiveDetector` + hit classes, and (d) `G4MultiFunctionalDetector` + primitive scorers. All four variants produce identical histograms and ntuples through `G4AnalysisManager`. It is the definitive Geant4 scoring cheat sheet, and also the canonical introduction to `G4PVReplica` for periodic structures.

## Key concepts demonstrated

- `scoring-strategy` — explicit comparison of four approaches (A→D) mapped to trade-offs: code volume vs. per-step access vs. extensibility; the decision framework for any new simulation
- `replica-volume` — `G4PVReplica` replicates an LV along an axis with constant pitch, filling the parent solid edge-to-edge; cheaper than `G4PVParameterised` for true periodic structures (sampling calos, fiber bundles)
- `analysis-manager` — `G4AnalysisManager` as the default output path: ROOT/CSV/HDF5/XML selected by file extension, no ROOT headers in user code; the single biggest "stop reinventing" lesson from B4
- `custom-g4run` — variant B4b subclasses `G4Run` and overrides `Merge()` to aggregate worker-thread data on the master, decoupling scoring from `EventAction`/`RunAction` inter-action coupling
- `multifunctional-detector` — variant B4d replaces ~100 lines of custom SD + hit class with `G4MultiFunctionalDetector` + `G4PSEnergyDeposit` + `G4PSTrackLength` for identical output; the default for new scoring volumes
- `sampling-calorimeter` — alternating absorber/gap geometry as the canonical calorimeter pattern; how copy-number indexing from replicas maps naturally to layer hits
