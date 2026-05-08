---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - modular-physics-list
  - radioactive-decay
  - multifunctional-detector
  - primitive-scorer
  - analysis-manager
  - custom-material
  - particle-kill
---

# g4-example-basic-b3


B3 models a schematic PET scanner — LSO crystal rings around a brain-tissue cylinder with F-18 beta-plus primaries — to teach three things simultaneously: building a modular physics list from constructor ingredients (no monolithic reference list), using `G4MultiFunctionalDetector` + built-in `G4VPrimitiveScorer`s instead of hand-rolled SDs, and writing output through `G4TScoreNtupleWriter` / `G4AnalysisManager` with no ROOT API in user code. It is the fastest path from "I know what physics I need" to a working scored simulation.

## Key concepts demonstrated

- `modular-physics-list` — registering `G4DecayPhysics`, `G4RadioactiveDecayPhysics`, and `G4EmStandardPhysics` onto a `G4VModularPhysicsList`; leaner than FTFP_BERT when hadronic processes are not needed
- `radioactive-decay` — `G4RadioactiveDecayPhysics` + `G4RADIOACTIVEDATA` env var; how to make an ion primary actually decay rather than sit still
- `multifunctional-detector` — `G4MultiFunctionalDetector` as the SD container for a list of `G4VPrimitiveScorer`s; eliminates the need to write a custom hit class for standard quantities
- `primitive-scorer` — `G4PSEnergyDeposit`, `G4PSDoseDeposit`, `G4PSCellFlux`, etc. cover ~80% of scoring needs without any C++; first place to look before writing a custom SD
- `analysis-manager` — `G4TScoreNtupleWriter` hooks the SD scoring system and writes a flat ntuple per scorer automatically; `G4AnalysisManager` as the one API for ROOT/CSV/HDF5/XML output
- `particle-kill` — `SetDefaultClassification(particle, fKill)` to drop nuisance particles (here: F-18 decay neutrino) before tracking; cheaper than per-step kills in `SteppingAction`
- `custom-material` — LSO (Lu₂SiO₅) built from G4 elements with mass fractions; the pattern for any material not in the NIST database
