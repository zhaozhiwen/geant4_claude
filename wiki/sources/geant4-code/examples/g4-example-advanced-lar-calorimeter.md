---
type: source
domain: detector-sim
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-advanced-lar-calorimeter


The ATLAS Forward Calorimeter (FCAL) test-beam simulation: three liquid-argon sampling modules (one EM copper/LAr, two hadronic tungsten/LAr) covering the very-forward LHC region. Geometry dimensions come from three external `.input` parameter files, and primaries can be overridden by per-event kinematic files (`data-tracks/`) at six beam energies. A simpler, lighter companion to `composite_calorimeter` — same file-driven-geometry school of design, but with minimal ceremony — and a useful reference for `G4_lAr` material definition and the `G4AnalysisManager` histogram output pattern.

## Key concepts demonstrated
- `kinematic-input-files` — per-event (X, Y, Z, cosX, cosY, cosZ) files in `data-tracks/` set particle position and direction per event; a minimal pre-HepMC interface for upstream-sim handoff
- `module-parameter-input-files` — plain ASCII listing dimensions per module; the `scanf`-loop geometry construction pattern at its most compact
- `g4lar-material` — `G4_lAr` is liquid argon at 87 K (1.39 g/cm³); `G4_Ar` is gaseous argon at NTP (1.66 mg/cm³) — a silent three-orders-of-magnitude density error if confused
- `g4analysismanager-histograms` — four `G4AnalysisManager` histograms per run; backend swappable from ROOT to XML by changing one line in `RunAction`, reinforcing the same lesson as `composite_calorimeter`
- `lookhere-comment-idiom` — `***LOOKHERE***` marks lines intended to be user-edited; explicit signposting for code that ships with sane defaults but expects customization
