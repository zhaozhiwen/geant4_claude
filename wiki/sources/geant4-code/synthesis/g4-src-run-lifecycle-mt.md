---
type: synthesis
domain: geant4-code
g4_version: 11.4.0
status: stable
sources:
  - source/run/src/G4MTRunManager.cc:120–730
  - source/run/src/G4MTRunManagerKernel.cc:122–236
  - source/run/src/G4WorkerRunManager.cc:76–762
  - source/run/src/G4WorkerThread.cc:70–90
  - source/run/src/G4VUserActionInitialization.cc
  - source/run/src/G4RunManager.cc:357,498–522
  - source/run/src/G4Run.cc:65–70
  - source/global/management/src/G4Threading.cc:51–69
related: ["[[g4-mt-run-manager]]", "[[user-actions]]"]
---

# g4-src-run-lifecycle-mt

The Geant4 MT documentation says "use `IsMasterThread()` to guard file operations" and "workers call `Build()`, master calls `BuildForMaster()`". What it does not say is which thread calls which run-action hook and when, what barriers guarantee ordering, where `G4Run::Merge` runs, and what exactly `IsMasterThread()` checks under the hood. Without that precision, file I/O code in run actions is written by trial and error. This page traces the actual source. For the entity-level summary of the orchestrator class itself, see [[g4-mt-run-manager]].

## What the source actually does

### Thread count and creation

Thread count is set by `G4MTRunManager::SetNumberOfThreads` (`G4MTRunManager.cc:242`). The count can also be forced via the `G4FORCENUMBEROFTHREADS` environment variable at construction time (`G4MTRunManager.cc:157–187`); the env-var wins.

Threads are created in `G4MTRunManager::CreateAndStartWorkers` (`G4MTRunManager.cc:304–334`):

```cpp
// G4MTRunManager.cc:323–330
for (G4int nw = 0; nw < nworkers; ++nw) {
  auto context = new G4WorkerThread;
  context->SetNumberThreads(nworkers);
  context->SetThreadId(nw);
  G4Thread* thread =
      userWorkerThreadInitialization->CreateAndStartWorker(context);
  threads.push_back(thread);
}
```

Each thread immediately enters `G4MTRunManagerKernel::StartThread` (`G4MTRunManagerKernel.cc:122`).

### What StartThread does on each worker

`StartThread` is the worker thread's entry point. Its seven steps (`G4MTRunManagerKernel.cc:122–236`):

1. Set thread-local ID via `G4Threading::G4SetThreadId(thisID)` (`G4MTRunManagerKernel.cc:148`). This is what `IsMasterThread()` and `IsWorkerThread()` test (see below).
2. Clone the master RNG engine (`G4MTRunManagerKernel.cc:162`).
3. Call `UserWorkerInitialization::WorkerInitialize()` if set (`G4MTRunManagerKernel.cc:168`).
4. Call `G4WorkerThread::BuildGeometryAndPhysicsVector()` — copies the split-class geometry and physics workspaces from master (`G4MTRunManagerKernel.cc:177`, `G4WorkerThread.cc:71–79`).
5. Create `G4WorkerRunManager` and call **`G4VUserActionInitialization::Build()`** on the worker thread (`G4MTRunManagerKernel.cc:196–198`):
   ```cpp
   if (masterRM->GetUserActionInitialization() != nullptr) {
     masterRM->GetNonConstUserActionInitialization()->Build();
   }
   ```
6. Call `wrm->Initialize()`, then enter `wrm->DoWork()` — the worker's run loop.
7. On exit: `WorkerStop`, geometry workspace cleanup.

### BuildForMaster vs Build

`BuildForMaster` is called on the **master thread** inside `G4MTRunManager::SetUserInitialization(G4VUserActionInitialization*)` (`G4MTRunManager.cc:491–495`):

```cpp
void G4MTRunManager::SetUserInitialization(G4VUserActionInitialization* userInit) {
  userActionInitialization = userInit;
  userActionInitialization->BuildForMaster();   // master thread, during setup
}
```

`Build` is called on each **worker thread** in `StartThread` step 5 above. The two calls happen at completely different times: `BuildForMaster` is synchronous with the user's `main()` before `beamOn`; `Build` is concurrent, once per thread, when that thread first starts.

Both calls route through `G4VUserActionInitialization::SetUserAction` (`G4VUserActionInitialization.cc:36–68`), which calls `G4RunManager::GetRunManager()->SetUserAction(...)`. Because `GetRunManager()` is thread-local, actions registered in `Build` attach to the worker's `G4WorkerRunManager`; actions registered in `BuildForMaster` attach to the master's `G4MTRunManager`.

### Run action lifecycle: which thread, which hook

**Master thread (sequential):**

| When | Call |
|------|------|
| User calls `SetUserInitialization(actionInit)` | `BuildForMaster()` |
| `G4MTRunManager::InitializeEventLoop` (before workers start) | Seeds filled, `PrepareCommandsStack`, `CreateAndStartWorkers`, `WaitForReadyWorkers` |
| `G4RunManager::RunInitialization` (master) | `userRunAction->BeginOfRunAction(currentRun)` at `G4RunManager.cc:357` |
| `G4MTRunManager::RunTermination` | `WaitForEndEventLoopWorkers()` blocks until all workers done, then `G4RunManager::RunTermination()` which calls `userRunAction->EndOfRunAction(currentRun)` at `G4RunManager.cc:510` |

**Worker threads (concurrent with each other):**

| When | Call |
|------|------|
| `StartThread` step 5 | `Build()` on worker thread |
| `G4WorkerRunManager::RunInitialization` line 231 | `userRunAction->BeginOfRunAction(currentRun)` (worker's run action, worker's current run) |
| `G4WorkerRunManager::RunTermination` line 442 | `MergePartialResults()` — merges scores and calls `G4MTRunManager::MergeRun(currentRun)` |
| After `MergePartialResults` | `G4RunManager::RunTermination()` calls worker's `userRunAction->EndOfRunAction(currentRun)` |
| After worker `EndOfRunAction` | `ThisWorkerEndEventLoop()` — signals the barrier |

### The merge barrier: what G4Run::Merge guarantees

`G4MTRunManager::MergeRun` (`G4MTRunManager.cc:565–569`) is called from each worker's `RunTermination` under a mutex:

```cpp
// G4MTRunManager.cc:565–569
void G4MTRunManager::MergeRun(const G4Run* localRun) {
  G4AutoLock l(&runMergerMutex);
  if (currentRun != nullptr && localRun != nullptr)
    currentRun->Merge(localRun);
}
```

`G4Run::Merge` itself (`G4Run.cc:65–70`) just increments `numberOfEvent` and copies event pointers from the worker's run:

```cpp
void G4Run::Merge(const G4Run* right) {
  numberOfEvent += right->numberOfEvent;
  for (auto& itr : *(right->eventVector))
    eventVector->push_back(itr);
}
```

This runs **on the worker thread**, serialized by `runMergerMutex`. It is called **before** the worker signals `ThisWorkerEndEventLoop`.

Master `RunTermination` calls `WaitForEndEventLoopWorkers` first (`G4MTRunManager.cc:456`). This barrier blocks until every worker has called `ThisWorkerEndEventLoop` (`G4WorkerRunManager.cc:455`). Since `ThisWorkerEndEventLoop` is called after `MergePartialResults` (which calls `MergeRun`), by the time the master's `EndOfRunAction` fires, all worker merges are complete. The master's `currentRun` contains the fully merged data.

### G4MTRunManager::Run() sequence (full view)

The master's `BeamOn` → `DoEventLoop` → `InitializeEventLoop` sequence (`G4MTRunManager.cc:337–423`):

1. Fill seeds on master.
2. `PrepareCommandsStack` — snapshot UI commands for workers.
3. `CreateAndStartWorkers` — spawn threads, each calls `StartThread`.
4. `NewActionRequest(NEXTITERATION)` — release workers to start event loop.
5. `WaitForReadyWorkers` — block until all workers signal ready (`beginOfEventLoopBarrier`).
6. Master returns from `InitializeEventLoop`; `DoEventLoop` finishes; calls `RunTermination`.
7. `G4MTRunManager::RunTermination`: `WaitForEndEventLoopWorkers` blocks.
8. Workers finish their event loops, call `MergePartialResults`, call worker `EndOfRunAction`, then signal `endOfEventLoopBarrier`.
9. Master unblocks, calls `G4RunManager::RunTermination` → master `EndOfRunAction`.

### IsMasterThread(): what it actually checks

From `G4Threading.cc:51,68–69`:

```cpp
G4ThreadLocal G4int G4ThreadID = G4Threading::MASTER_ID;
// ...
G4bool G4Threading::IsWorkerThread() { return (G4ThreadID >= 0); }
G4bool G4Threading::IsMasterThread()  { return (G4ThreadID == MASTER_ID); }
```

`MASTER_ID` is a compile-time negative sentinel. Workers get their ID set to a non-negative integer (0, 1, 2, …) in `StartThread` via `G4SetThreadId(thisID)` (`G4MTRunManagerKernel.cc:148`). The master thread's `G4ThreadID` is never reset from `MASTER_ID`, so `IsMasterThread()` is purely a check on the thread-local `G4ThreadID` — not on any OS thread identity or mutex state. It is safe to call from anywhere.

### Where it is safe to open a TFile (or any output file)

| Location | Thread | Safe to open a file? |
|----------|--------|----------------------|
| `BuildForMaster` | Master | Yes — fully sequential |
| Worker `BeginOfRunAction` | Worker | Yes — each worker opens its own file; no shared state if paths differ per thread ID |
| Worker `EndOfRunAction` | Worker | Yes — same guarantee |
| Master `BeginOfRunAction` | Master | Yes — workers are not yet dispatched when master `BeginOfRunAction` fires (master `RunInitialization` runs before `InitializeEventLoop` and `CreateAndStartWorkers`) |
| Master `EndOfRunAction` | Master | Yes — all workers have already called `ThisWorkerEndEventLoop` (barrier enforced) and all merges are complete |
| `G4Run::Merge` (called on worker) | Worker | **No** — `MergeRun` holds `runMergerMutex` but writes to the master's `G4Run` object; do not open or write files here |
| `RecordEvent` | Worker | Depends — runs on the worker thread during event loop; writing to a shared file here without a mutex causes data races |

Opening one `TFile` per worker in `BeginOfRunAction`, then closing it in `EndOfRunAction`, is the standard safe pattern. The worker's thread ID is available at that point via `G4Threading::G4GetThreadId()`. Using `IsMasterThread()` to guard a single shared output file in a run action is valid only if the write happens in master `EndOfRunAction` after the merge barrier.

## Gotchas / edge cases

1. **Worker `BeginOfRunAction` fires before master `BeginOfRunAction` is possible — but actually both fire on their respective threads before the event loop.** The master calls `RunInitialization` (which includes master `BeginOfRunAction`) before dispatching workers. Workers call their own `BeginOfRunAction` inside `G4WorkerRunManager::RunInitialization` (`G4WorkerRunManager.cc:231`) after receiving the `NEXTITERATION` signal. The ordering between master `BeginOfRunAction` and worker `BeginOfRunAction` is: master fires first, then workers. However, the barrier at `WaitForReadyWorkers` (`G4MTRunManager.cc:661–666`) ensures the master does not proceed past `InitializeEventLoop` until all workers have signaled ready — which happens at `G4WorkerRunManager::RunInitialization:187`, after their `BeginOfRunAction`. So all worker `BeginOfRunAction` calls complete before the master proceeds to process events.

2. **Worker `EndOfRunAction` fires before master `EndOfRunAction`, and before `G4Run::Merge`.** Workers call `MergePartialResults` then `G4RunManager::RunTermination` (which calls worker `EndOfRunAction`) then signal the end-of-loop barrier. The order within one worker is: `MergeRun` → worker `EndOfRunAction` → `ThisWorkerEndEventLoop`. Workers therefore see their own (local) run object in `EndOfRunAction`, not the merged master run. If you need merged totals in an action, use the master's `EndOfRunAction`.

3. **`IsMasterThread()` returns `true` for the master even during `BuildForMaster`, construction, and all of `Initialize`.** It is implemented as a thread-local ID check, not a run-state check. If a user calls `IsMasterThread()` from inside a physics constructor, it always returns `true` because physics construction happens on the master. Using it to guard "write summary to file" in a constructor is correct but for the wrong reason; it will silently break if the physics constructor is ever called on a worker (e.g., via physics list cloning).

4. **`G4Run::Merge` is not virtual in the base class's counting sense — the user must override it.** The default `G4Run::Merge` only accumulates `numberOfEvent` and copies event pointers (`G4Run.cc:65–70`). Any custom histogram or accumulator the user puts in a derived `G4Run` will not be merged unless the user overrides `Merge`. Forgetting this is the most common MT output bug.

5. **There is no barrier between individual worker events.** Workers process events from the shared counter independently, pulling batches of `eventModulo` events at a time via `SetUpNEvents` (`G4MTRunManager.cc:594–619`). Event IDs are assigned atomically under `setUpEventMutex`, but there is no ordering guarantee for which worker processes which event. Two workers can be processing event 42 and event 43 simultaneously; sensitive detector code must not write to shared data structures without a mutex.

6. **`G4MTRunManager::SetUserAction` for event/tracking/stacking/stepping actions is a fatal error.** The override (`G4MTRunManager.cc:518–555`) throws `FatalException` for every action type except `G4UserRunAction`. These actions must be registered via `G4VUserActionInitialization::Build()` on the worker thread. Forgetting this causes a crash at setup, not at run time.
