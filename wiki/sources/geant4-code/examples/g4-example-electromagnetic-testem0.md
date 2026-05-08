---
type: source
domain: physics
g4_version: 11.4.0
status: stable
related:
  - em-calculator
  - em-physics-builder
  - physics-table-inspection
  - material-properties
---

# g4-example-electromagnetic-testem0


Not a simulation — a physics-table inspection tool. Given a material, particle, and energy, `G4EmCalculator` queries the already-built EM physics tables and prints cross sections, mean free paths, and stopping powers without running any geometry-driven transport. The deliverable is numbers ("at 10 MeV in silicon, electron range is X cm") rather than hits. A companion `DirectAccess.cc` shows how to query individual models directly, bypassing the table. The `setMat`-then-`beamOn` loop pattern drives a sweep over multiple materials in one process with no rebuild.

## Key concepts demonstrated

- `em-calculator` — `G4EmCalculator::GetDEDX`, `GetRange`, `ComputeCrossSectionPerAtom` are the read-only oracle into EM physics tables; output units depend on which call is made — always cross-check against `DirectAccess.out`
- `em-physics-builder` — `emstandard_opt0` through `_opt4`, `emlivermore`, `empenelope`, `emlowenergy` are string names for curated EM model sets; TestEm0 is the tool to confirm that switching builders actually changes the numbers you care about
- `physics-table-inspection` — `/run/beamOn 1` (not 0) triggers `BuildPhysicsTable()`; the example's value is the read-back, not the event output
- `material-properties` — `/testem/det/setMat <name>` swaps material between `beamOn` calls to sweep over a table of materials without re-initializing the run manager
