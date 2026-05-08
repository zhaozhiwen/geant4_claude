---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - generic-messenger
  - hit-attributes
  - multiple-sensitive-detectors
  - vector-ntuple-branch
  - visualization-workflow
  - event-action-pattern
---

# g4-example-basic-b5


B5 assembles a double-arm magnetic spectrometer — hodoscopes, drift chambers, EM calorimeter, hadronic calorimeter, and a steered field region — to show what a small but realistic multi-detector experiment looks like in Geant4. Four distinct sensitive detectors with their own hit classes all feed a single `G4AnalysisManager` ntuple. It introduces `G4GenericMessenger` as the modern declarative replacement for hand-rolled `G4UImessenger` subclasses, `G4AttDef`/`G4AttValue` hit attributes for visualization picking, and vector ntuple branches for per-event cell data. B5 is the reference template before starting a real detector project.

## Key concepts demonstrated

- `generic-messenger` — `G4GenericMessenger` with `DeclareProperty` / `DeclareMethodWithUnit` replaces `G4UImessenger` subclassing; strictly less code, used across detector, field, and generator classes
- `multiple-sensitive-detectors` — four SDs of different types in one event; `EventAction` caches hit-collection IDs once on the first event and pulls each collection from `G4HCofThisEvent` at end-of-event — the canonical multi-detector pattern
- `hit-attributes` — `G4AttDef` / `G4AttValue` key-value metadata on each hit, surfaced by the visualization layer for picking and `drawByAttribute` filtering; free debug channel from sim to viewer
- `vector-ntuple-branch` — `CreateNtupleDColumn(name, vector)` writes a variable-length vector per row (e.g. per-event EM-cal cell edeps); the right shape for segmented calorimeters, avoiding the row-per-cell explosion
- `event-action-pattern` — caching hit-collection IDs in `EventAction` on first event rather than per-event name lookup; a small but real performance pattern that scales with detector count
- `visualization-workflow` — `tsg_offscreen.mac` for batch image rendering and `plotter.mac` for live plot windows; HepRep attribute picking as a debug tool beyond geometry display
