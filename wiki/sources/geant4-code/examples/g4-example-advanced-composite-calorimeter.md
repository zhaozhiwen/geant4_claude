---
type: source
domain: detector-sim
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-advanced-composite-calorimeter


A scaled-down replica of the CMS 1996 H2 test beam — 7×7 PbWO4 ECAL backed by a 28-layer Cu/scintillator HCAL — whose core lesson is architectural rather than physical: keep all geometry, material, field, visualization, and configuration knowledge in external ASCII databases and let C++ classes simply parse them. This is the canonical Geant4 example showing how real experiments avoid hardcoding the detector, with the explicit claim that the same format scales unchanged to the full CMS detector.

## Key concepts demonstrated
- `external-data-driven-geometry` — shape, placement, rotations, and materials live in text files (`*.geom`, `material.cms`, `rotation.cms`); C++ never spells a dimension
- `g4physlistfactory` — `G4PhysListFactory::ReferencePhysList()` reads the `PHYSLIST` env var so physics lists are swappable at runtime without recompiling
- `g4analysismanager` — native Geant4 histogram/ntuple manager with a ROOT default backend swappable to XML/CSV by changing one line
- `configurable-subsystem-inclusion` — commenting a line in `g4testbeamhcal96.conf` drops a subsystem from both simulation and reconstruction
- `gui-macro-extension` — `gui.mac` adds custom Qt menu buttons for particle, energy, and event count
