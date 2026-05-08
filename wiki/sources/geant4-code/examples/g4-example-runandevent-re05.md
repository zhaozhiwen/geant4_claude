---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-runandevent-re05


RE05 assembles a miniature collider detector — barrel tracker, lead/scintillator calorimeter, and muon planes — and demonstrates three advanced features together: PYTHIA primary events read through `G4HEPEvtInterface`, a parallel-world readout geometry that overlays phi-z cells on the physical calorimeter tubes so segmentation is decoupled from construction, and a three-stage `G4UserStackingAction` that functions as an in-simulation trigger: track only primary muons first, check isolation, then track the RoI around surviving muons. The stacking-action stage gate is the key takeaway: it gives 10–100x CPU speedup on rare-signal studies by aborting uninteresting events before showers run.

## Key concepts demonstrated
- `stacking-action-stage-gate` — `ClassifyNewTrack` + `NewStage` implement multi-pass event filtering; events that fail a stage are aborted before the expensive physics runs
- `hepevt-interface` — `G4HEPEvtInterface` reads column-based ASCII event files as primaries; the cheapest path from an external generator before committing to HepMC3
- `parallel-world-readout` — parallel world registered via `RegisterParallelWorld` + `G4ParallelWorldPhysics`; SD attaches to parallel LVs to provide readout segmentation independent of physical layout
- `region-of-interest-tracking` — stage 3 promotes only tracks inside a cone around isolated muons; the RoI concept for trigger-emulation in simulation
- `multiple-worlds-multiple-sds` — SDs on the inner tracker, muon planes, and calorimeter parallel world coexist; each world contributes its own hits independently
