---
type: source
domain: physics
g4_version: 11.4.0
status: stable
related:
  - physics-list-factory
  - hadronic-process-store
  - physics-table-inspection
  - run-manager
---

# g4-example-hadronic-hadr00


The hadronic analogue of TestEm0: given a physics list, projectile, and target element, print hadronic cross sections vs. energy and momentum as ROOT histograms via `G4HadronicProcessStore`. The simulation runs only to populate physics tables; the deliverable is the cross-section log, not hits. The binary takes the physics list name as an argv (or `PHYSLIST` env var), demonstrating `G4PhysListFactory` as the clean replacement for hard-coded physics list construction — the same pattern the plugin's main needs. The `/run/setCut 1 km` trick suppresses secondary tracking during table inspection, reducing noise in the output.

## Key concepts demonstrated

- `physics-list-factory` — `G4PhysListFactory::GetReferencePhysList("QGSP_BIC_HP")` is the idiomatic runtime physics list selector; same binary, many lists; `PHYSLIST` env var as fallback matches batch-farm conventions
- `hadronic-process-store` — `G4HadronicProcessStore::GetCrossSectionPerAtom(particle, energy, element, material)` is the hadronic oracle analogous to `G4EmCalculator`; returns zero (not an error) for particles or processes not registered
- `physics-table-inspection` — `/run/setCut 1 km` is a legitimate trick to skip secondary tracking when only primary cross-section data is wanted
- `physlist-env-var` — `PHYSLIST` env var precedence vs. argv physics-list flag; CLI wins; A/B comparisons across lists naturally map to one process per list
- `radioactive-decay` — `/testhadr/RadDecay true` flips on radioactive decay physics for the run; activation cross sections require this
