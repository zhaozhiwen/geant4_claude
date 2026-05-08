---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - g4-run-manager
  - action-initialization
  - g4-accumulable
  - nist-material-manager
  - physics-list-reference
  - macro-layering
---

# g4-example-basic-b1


B1 is the minimum viable Geant4 application: a hand-built geometry (water envelope, tissue cone, bone trapezoid), the QBBC reference physics list, a 6 MeV gamma primary gun, and dose scoring done entirely through `SteppingAction` + `G4Accumulable` — no sensitive detectors, no hits collections, no analysis manager. It exists to prove the four-object `G4RunManager` contract (DetectorConstruction, PhysicsList, ActionInitialization, macro) and nothing else; every later basic example adds one layer on top of this skeleton.

## Key concepts demonstrated

- `g4-run-manager` — the four-object initialization contract that every Geant4 application must satisfy; B1 shows the smallest possible body for each object
- `action-initialization` — how `RunAction`, `EventAction`, and `SteppingAction` are wired together through a single `ActionInitialization` class, keeping all thread-local object creation in one place
- `g4-accumulable` — thread-safe scalar that the kernel auto-merges from worker threads to master at end-of-run; the reason MT user code can stay simple
- `nist-material-manager` — `G4NistManager` for material lookup by name (`G4_WATER`, `G4_A-150_TISSUE`); the right default before reaching for manual element/material definitions
- `physics-list-reference` — QBBC as a drop-in reference list; illustrates that you pick a list, not individual processes
- `macro-layering` — `init_vis.mac` → `vis.mac` for interactive and `run1.mac` / `run2.mac` for batch; the C++ never hardcodes the run
