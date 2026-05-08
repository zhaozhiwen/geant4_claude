---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-analysis-anaex01


AnaEx01 demonstrates `G4AnalysisManager` as a backend-agnostic histogram and ntuple API: book histograms by name in C++, fill them per-event from `EventAction`, and write to ROOT, CSV, XML, or HDF5 by changing a single macro line — no recompile. The detector is N03's lead/LAr sampling calorimeter; four histograms (energy deposit and track length in absorber and gap) plus two ntuples (per-event scalars) cover the standard "summary plots" use case. The `HistoManager` class pattern — a single owner for all analysis state — keeps histogram IDs and fill calls co-located and avoids scattered `G4AnalysisManager::Instance()` calls in action classes.

## Key concepts demonstrated
- `g4-analysis-manager` — singleton MT-safe facade for histograms and ntuples; no direct ROOT dependency at write time
- `runtime-format-selection` — `/analysis/setDefaultFileType root|csv|xml|hdf5` in the macro, not in C++; the same binary serves shell-scripting and ROOT downstream workflows
- `histogram-manager-class` — single C++ owner of all booked IDs and fill calls; prevents ID-collision bugs in multi-class simulations
- `ntuple-merging` — `SetNtupleMerging(true)` required in MT mode to merge per-worker ntuples on the master; default off
- `analysis-manager-lifecycle` — `OpenFile` before booking, `Write`+`CloseFile` at end of run; easy to forget either, producing empty output
