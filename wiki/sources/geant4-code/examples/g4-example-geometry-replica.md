---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - replica-volume
  - geometry-construction
  - sensitive-detector
  - em-physics-builder
---

# g4-example-geometry-replica


The C++-side replica reference, drawn from TestEm3 (the canonical sampling calorimeter benchmark in `extended/electromagnetic/`). TestEm3 builds a calorimeter as nested replicas: the mother is sliced into N layers via `G4PVReplica`, each layer is itself sliced into M absorber slabs via another `G4PVReplica`. One logical volume, one physical-volume object, O(1) memory regardless of N. The example also demonstrates the modern `G4MultiFunctionalDetector` + `G4PSEnergyDeposit` scorer pattern (attaches to the LV once; all replicated copies inherit it), parameter-driven geometry via UI commands, and a selectable EM physics builder for benchmarking.

## Key concepts demonstrated

- `replica-volume` — `G4PVReplica(name, daughterLV, motherLV, axis, nReplicas, width)` with axis `kXAxis` / `kYAxis` / `kZAxis` / `kRho` / `kPhi`; mother solid must be exactly `N × daughter` along that axis or Geant4 throws a fatal at init
- `nested-replicas` — a replica LV can itself contain a replica; TestEm3 uses two levels (layer → absorber slab); the navigator handles arbitrary nesting
- `multifunctional-detector` — `G4MultiFunctionalDetector` + `G4PSEnergyDeposit` is the modern alternative to a hand-rolled SD class; attaches to an LV, works correctly with replicas because the SD lives on the one shared LV
- `gdml-replicavol` — GDML `<replicavol>` is the XML equivalent with identical semantics; aux-tag SD attachment on the daughter LV is inherited by all N copies
- `parameterised-volume` — the next step up when copies need per-index size or material variation; `G4PVParameterised` vs. `G4PVReplica` vs. `G4PVPlacement` as a three-point tradeoff
