---
type: concept
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[init-quartet]]", "[[scoring-styles]]", "[[analysis-manager]]", "[[g4-src-run-lifecycle-mt]]"]
---

# user-actions

The five Geant4 user action classes are the hooks where your code runs
at each level of the simulation lifecycle. Understanding which lifecycle
level to hook at is the key decision for any non-trivial analysis.

## The hierarchy

```
Run (one per job or sub-run)
  └─ Event (one per beamOn call)
       └─ Track (one per primary + one per secondary created)
            └─ Step (one per tracking step along a track)
```

Each level has a corresponding action class:

| Class | Registered in | Key method | What it owns |
|-------|--------------|------------|--------------|
| `G4UserRunAction` | `ActionInitialization::BuildForMaster()` + `Build()` | `BeginOfRunAction`, `EndOfRunAction` | File open/close, histogram booking, run-level summaries |
| `G4UserEventAction` | `Build()` | `BeginOfEventAction`, `EndOfEventAction` | Per-event accumulators, flush to TTree |
| `G4UserStackingAction` | `Build()` | `ClassifyNewTrack` | Particle filtering — kill unwanted secondaries early, implement trigger logic |
| `G4UserTrackingAction` | `Build()` | `PreUserTrackingAction`, `PostUserTrackingAction` | Per-track truth recording, parent-daughter bookkeeping |
| `G4UserSteppingAction` | `Build()` | `UserSteppingAction` | Per-step scoring (the B1 approach) |

All five are registered through `G4VUserActionInitialization::Build()`.
`BuildForMaster()` registers only the `RunAction` on the master thread
(which manages files and histograms in MT mode).

## When you need each one

**`RunAction`** — almost always. Open output files in `Begin`, close
and write in `End`. In MT mode, `BeginOfRunAction` is called on both
master and workers; use `G4Threading::IsMasterThread()` to distinguish
if needed.

**`EventAction`** — whenever you accumulate per-event quantities (step
sum, hit list) that need flushing to output at event end. Most examples
use this.

**`SteppingAction`** — only for B1-style scoring where you want every
step without a full SD framework. Gets expensive at high track
multiplicity; prefer an SD.

**`StackingAction`** — trigger emulation, signal filtering. Example:
kill all gammas below 1 MeV to speed up a background study. Or:
only track events where at least one muon exists. `ClassifyNewTrack`
returns `fKill`, `fWaiting`, or `fUrgent`.

**`TrackingAction`** — per-track truth table: primary particle PDG,
initial momentum, vertex position. Needed if you want MC truth
alongside hit data.

## MT safety

In multi-threaded mode each worker has its own set of actions. The
master thread has only `RunAction`. Shared state (TFile, TTree) must
be thread-local or protected. The standard pattern: each worker owns
its own `TTree`; `RunAction::EndOfRunAction` on the master merges
them (or writes separate files per worker).

**`SetUserAction` calls on [[g4-mt-run-manager|`G4MTRunManager`]] for event, tracking, stacking, and stepping actions are a fatal error at setup time** (`G4MTRunManager.cc:518–555`). The override throws `FatalException` immediately — not at run time. These four action types must be registered exclusively through `ActionInitialization::Build()`, which runs on each worker thread.

**Master `EndOfRunAction` is the safe place to write or close a shared `TFile`.** It fires only after `WaitForEndEventLoopWorkers` returns, which blocks until every worker has called `ThisWorkerEndEventLoop`. Since workers call `MergeRun` before signaling the barrier, all worker merges into the master `G4Run` are complete by then. By contrast, `G4Run::Merge` itself runs on the worker thread (serialized by `runMergerMutex`) — do not open or write shared output there. See [[g4-src-run-lifecycle-mt]].
