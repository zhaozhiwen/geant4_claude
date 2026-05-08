---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-eventgenerator-hepmcex01


HepMCEx01 drives Geant4 with realistic collider events from either a HepMC ASCII file or a live Pythia call. `G4HepMCInterface` adapts the HepMC vertex graph into `G4PrimaryVertex` + `G4PrimaryParticle` objects; the user subclass only decides how to read the next event (file vs. generator). The detector is a simplified collider geometry with an important side lesson: the calorimeter SD uses a readout geometry to assign hits to phi-z cells without segmenting the physical construction, which avoids placing thousands of physical volumes. Three-stage stacking-action filtering mirrors RE05's trigger-emulation pattern. The complete six-class user-action hierarchy (`Run`, `Event`, `Stacking`, `Tracking`, `Stepping`, plus `PrimaryGenerator`) shows what a production-scale simulation looks like beyond the three-class MVP.

## Key concepts demonstrated
- `hepmc-interface` — `G4HepMCInterface` is Geant4's adapter for the HepMC event-record format; any HepMC source (file, Pythia, MadGraph) plugs in via subclassing
- `readout-geometry-on-sd` — SD holds a pointer to a segmentation geometry; `SetReadOutGeometry` lets the SD find a hit's phi-z cell from global position without GDML segmentation
- `stacking-action-stage-gate` — three-pass `ClassifyNewTrack` + `NewStage` implements per-event trigger emulation; abort uninteresting events before showers (same pattern as RE05)
- `primary-generator-as-thin-glue` — `G4VUserPrimaryGeneratorAction` is kept minimal; heavy lifting is in `HepMCG4Interface`; composition not deep inheritance
- `full-user-action-hierarchy` — Stacking + Tracking + Stepping actions each have a defined job; this example is the receipt for when the three-action MVP is insufficient
