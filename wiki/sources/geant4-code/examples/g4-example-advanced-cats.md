---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-advanced-cats


"Calorimeter and Tracker Simulation" — a framework-style example by Hans Wenzel showing how to build a real, extensible Geant4 application: a GDML-driven detector with seven simultaneously-active sensitive-detector types (Tracker, Calorimeter, DRCalorimeter, MultipleScatter, Photon, lArTPC, Radiator) selected via GDML auxiliary tags, a string-spec physics configurator, and a two-stage output pipeline (raw hit ROOT files consumed by per-SD-type analysis binaries). It also demonstrates Opticks integration for GPU-offloaded optical photon transport.

## Key concepts demonstrated
- `gdml-aux-tag-sd-dispatch` — `<auxiliary auxtype="SensDet" auxvalue="TrackerSD"/>` in GDML selects the C++ SD class at parse time; a richer vocabulary than binary `sensitive=true/false` and the documented v2 evolution path for our plugin
- `physics-string-spec-builder` — `PhysicsConfigurator` parses a `+`-delimited spec like `"FTFP_BERT+OPTICAL+STEPLIMIT"` to chain modular constructors; more composable than factory env vars
- `two-stage-analysis-pipeline` — simulation writes per-SD-type raw hit ROOT files; separate `readXxxHits` binaries collapse them to histograms; validates the design pattern our plugin already uses
- `dual-readout-calorimeter` — `DRCalorimeterSD` scores both deposited energy and Cerenkov photon yield on the same volume, demonstrating that a single SD can track multiple physics quantities
- `opticks-gpu-photon-transport` — `RadiatorSD` and `lArTPCSD` collect "genstep" handoff records for GPU propagation; a new SD role category: handoff rather than scoring
