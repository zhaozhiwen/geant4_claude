---
type: concept
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[init-quartet]]", "[[sensitive-detectors-via-gdml-aux]]", "[[analysis-manager]]", "[[scoring-mesh]]", "[[g4-src-sd-dispatch]]", "[[g4-src-step-lifecycle]]"]
---

# scoring-styles

Geant4 has no single scoring style. Every example picks from a menu of
five approaches. Knowing the menu — and when to escalate — is the
first design decision in any simulation.

## The five approaches

### 1. User action (B1 pattern)
Record hits by hand in `G4UserSteppingAction::UserSteppingStep()`.
Accumulate into a member variable; read out in `EventAction` or
`RunAction`.

- **Pro:** Zero toolkit machinery. Transparent.
- **Con:** Everything is custom C++. Scoring logic lives outside the
  geometry, so per-volume cuts require explicit volume-name checks.
- **When:** Prototypes, single-volume energy-deposition totals.

### 2. Custom sensitive detector (B2 pattern)
Subclass `G4VSensitiveDetector`, implement `ProcessHits()`, push into
a `G4HitsCollection`. Attach to a volume in
`DetectorConstruction::ConstructSDandField()`.

- **Pro:** Volume-local, thread-safe, reusable. The right abstraction
  for "this volume is a detector."
- **Con:** One class per detector type; boilerplate hits collection.
- **When:** Any time you need per-volume control or reuse across runs.

`ProcessHits` is called at `G4SteppingManager.cc:247`, **before** `UserSteppingAction`. The step is fully finalized at that point: all DoIt phases have run, `GetTotalEnergyDeposit()` is final. The `PreStepPoint` reflects the volume the track entered at the start of this step; it is the canonical source for hit position and volume identity. See [[g4-src-sd-dispatch]] and [[g4-src-step-lifecycle]].

### 3. Multi-functional detector + primitive scorers (B3/B4d pattern)
Attach a `G4MultiFunctionalDetector` to a volume; add
`G4VPrimitiveSensitivity` scorers (e.g. `G4PSEnergyDeposit`,
`G4PSFlatSurfaceFlux`, `G4PSDoseDeposit`). No custom hit class needed.

- **Pro:** Library of scorers covers most physics quantities. Composable.
  `G4TScoreNtupleWriter` serializes directly to ROOT/CSV.
- **Con:** Less flexible than custom SD for non-standard quantities.
- **When:** Standard quantities (energy, fluence, dose) without custom
  hit logic.

### 4. Custom `G4Run` accumulator (B4b pattern)
Override `G4Run::Merge()` to thread-safely accumulate per-event data
into a run-level summary without any SD machinery.

- **Pro:** Cleanest approach when the output is a single per-run
  aggregate (mean, histogram). No per-event hit collection overhead.
- **Con:** You own the merge logic; no volume-level granularity.
- **When:** Benchmarks, cross-section measurements, single-number
  output.

### 5. Command-based scoring mesh (RE03 pattern)
Call `G4ScoringManager::GetScoringManager()` in `main()`, then use
`/score/...` UI commands in a macro to define a scoring mesh, quantities,
and output. No C++ needed after the one-line activation.

- **Pro:** Zero C++ per scoring task. Macro-driven, reproducible.
  Works with any geometry.
- **Con:** Mesh is axis-aligned boxes; can't match arbitrary volume
  shapes. Output is separate from the `Hits` TTree.
- **When:** Dose grids, fluence maps, any regular-grid scoring.

See [[scoring-mesh]] for the activation detail.

## Decision guide

```
Need per-step detail in a specific volume?
  Yes → custom SD (B2)
  No  ↓
Standard physics quantity (edep, dose, flux)?
  Yes → MultiFunctionalDetector + primitive scorer (B3/B4d)
  No  ↓
Single per-run aggregate?
  Yes → custom G4Run (B4b)
  No  ↓
Regular spatial grid?
  Yes → scoring mesh (/score/ macros) (RE03)
  No  → custom SD with custom hit class
```
