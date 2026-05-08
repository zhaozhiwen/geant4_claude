---
type: entity
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[g4-src-process-registration-ordering]]", "[[g4-src-step-lifecycle]]", "[[g4-stepping-manager]]"]
---

# G4ProcessManager

**Role:** owns and orders the six process vectors (three DoIt + three GPIL) for one particle type; determines which process fires at each step.

**Header:** `source/processes/management/include/G4ProcessManager.hh`

## Key interface

| Method | What it does |
|--------|-------------|
| `AddProcess(proc, atRest, along, post)` | Add a process to the manager with ordering parameters for each DoIt category; negative means inactive in that category |
| `SetProcessOrdering(proc, idDoIt, ord)` | Set explicit integer ordering for one DoIt slot; rebuilds GPIL vectors |
| `SetProcessOrderingToFirst(proc, idDoIt)` | Place the process first (ordering = 0) in that slot; issues a warning if called twice for the same slot |
| `SetProcessOrderingToLast(proc, idDoIt)` | Place the process last (ordering = `ordLast = 9999`) |
| `GetProcessList()` | Returns the flat master `G4ProcessVector` of all registered processes |
| `GetAlongStepProcessVector(type)` | Returns the DoIt or GPIL along-step vector (`type` = `typeGPIL` or `typeDoIt`) |
| `GetPostStepProcessVector(type)` | Returns the DoIt or GPIL post-step vector |

## Non-obvious facts

- **GPIL vectors are the reverse of DoIt vectors.** `CreateGPILvectors()` (`G4ProcessManager.cc:1147–1158`) iterates each DoIt vector backwards and builds the corresponding GPIL vector. `G4SteppingManager` then iterates the GPIL vector forward and the DoIt vector in reverse to compensate — net result: GPIL and DoIt fire processes in the same priority order. Manually constructing test harnesses that ignore this reversal is a common mistake. See [[g4-src-process-registration-ordering]].

- **Passing ordering = 0 to `AddProcess` is silently remapped to 1.** At `G4ProcessManager.cc:457–459`, any ordering parameter of exactly 0 is changed to 1. The value 0 is reserved for `SetProcessOrderingToFirst()`; using it in `AddProcess` has the opposite of the intended effect. Use the named constants (`ordInActive`, `ordDefault`, `ordLast`) or call `SetProcessOrderingToFirst` explicitly. See [[g4-src-process-registration-ordering]].

- **Transportation registers with `ordInActive` for all three DoIts, then is promoted.** `G4PhysicsListHelper::AddTransportation()` calls `AddProcess` with all-inactive defaults, then calls `SetProcessOrderingToFirst` for `idxAlongStep` and `idxPostStep`. This places Transportation last in the GPIL loop (because GPIL is the reverse of DoIt) — exactly the design intent: Transportation's geometry step acts as the hard upper bound after physics processes have proposed their lengths.

- **`RegisterPhysics` is only valid before `/run/initialize` (`G4State_PreInit`).** Calling it after initialization silently does nothing; no warning is issued beyond a state-check message. Adding processes after `/run/initialize` additionally requires calling `G4RunManager::PhysicsHasBeenModified()` to force a table rebuild. See [[g4-src-process-registration-ordering]].
