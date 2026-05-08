---
type: entity
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[g4-src-run-lifecycle-mt]]", "[[user-actions]]"]
---

# G4MTRunManager

**Role:** the MT-aware run manager; orchestrates the master thread, spawns worker threads, owns the run-level barriers, and merges worker results before firing master end-of-run actions.

**Header:** `source/run/include/G4MTRunManager.hh`

## Key interface

| Method | What it does |
|--------|-------------|
| `BeamOn(nEvents)` | Start a run: seeds workers, releases the event-loop barrier, waits for all workers to finish, then fires master `EndOfRunAction` |
| `SetNumberOfThreads(n)` | Set worker count before `Initialize()`; overridden by `G4FORCENUMBEROFTHREADS` env var at construction time |
| `GetNumberOfThreads()` | Return the effective thread count |
| `SetUserInitialization(actionInit)` | Register `G4VUserActionInitialization`; immediately calls `BuildForMaster()` on the master thread |
| `SetUserInitialization(physList)` | Register the physics list |
| `SetUserInitialization(detConstr)` | Register detector construction |
| `MergeRun(localRun)` | Called by each worker under `runMergerMutex`; invokes `currentRun->Merge(localRun)` on the master's run object |

Note: `SetUserAction` for event, tracking, stacking, and stepping actions is **not valid** on `G4MTRunManager` (see below).

## Non-obvious facts

- **`SetUserAction` for non-run actions throws `FatalException` at setup time.** The `G4MTRunManager` override (`G4MTRunManager.cc:518–555`) rejects every action type except `G4UserRunAction`. Event, tracking, stacking, and stepping actions must be registered inside `G4VUserActionInitialization::Build()`, which is called on each worker thread. Calling `SetUserAction` with these types crashes immediately — not at run time. See [[g4-src-run-lifecycle-mt]].

- **Master `EndOfRunAction` is the safe place to write shared output.** `G4MTRunManager::RunTermination` calls `WaitForEndEventLoopWorkers()` before invoking master `EndOfRunAction`. All workers have called `MergeRun` and signaled `ThisWorkerEndEventLoop` before this barrier clears, so the master's `currentRun` contains fully merged data. Writing a `TFile` in master `EndOfRunAction` is safe; writing in `G4Run::Merge` (which runs on the worker thread) is not. See [[g4-src-run-lifecycle-mt]].

- **`IsMasterThread()` is a thread-local ID check, not a run-state check.** It returns `true` if the thread-local `G4ThreadID` equals `MASTER_ID` (a compile-time negative sentinel). It is safe to call from anywhere, including physics constructors. However, physics constructors always run on the master, so `IsMasterThread()` there is vacuously true — not a meaningful guard.

- **Worker count can be forced by environment.** `G4FORCENUMBEROFTHREADS` is read at `G4MTRunManager` construction (`G4MTRunManager.cc:157–187`) and overrides any subsequent `SetNumberOfThreads` call. See [[g4-src-run-lifecycle-mt]].
