---
type: synthesis
domain: geant4-code
g4_version: 11.4.0
status: stable
sources:
  - source/processes/management/src/G4ProcessManager.cc
  - source/processes/management/include/G4ProcessManager.hh
  - source/run/src/G4VModularPhysicsList.cc
  - source/run/src/G4VUserPhysicsList.cc:501–684
  - source/run/src/G4RunManagerKernel.cc:489–747
  - source/run/src/G4PhysicsListHelper.cc:196–253
related: []
---

# g4-src-process-registration-ordering

The Geant4 process ordering system controls which process fires for each step,
but the actual data structures — six `G4ProcessVector` arrays, ordering integers,
and the GPIL inversion — are not documented in any user guide. Physics list
authors routinely use `ordInActive`, `ordDefault`, and `ordLast` without
understanding their concrete values or what happens when two processes share the
same ordering parameter. Transportation's ordering is especially subtle:
it registers as `ordInActive` for AtRest (meaning inactive) and "first" for
AlongStep/PostStep, which is achieved by a special `SetProcessOrderingToFirst`
call rather than the `ordInActive` constant.

## What the source actually does

### The six internal process vectors

`G4ProcessManager` maintains a fixed array of six `G4ProcessVector*`
(`G4ProcessManager.hh:291`: `SizeOfProcVectorArray = 6`):

| Index | Name | Role |
|---|---|---|
| 0 | AtRest GPIL | GetPhysicalInteractionLength for at-rest |
| 1 | AtRest DoIt | Invoke at-rest processes |
| 2 | AlongStep GPIL | GPIL for along-step (continuous) |
| 3 | AlongStep DoIt | Invoke along-step processes |
| 4 | PostStep GPIL | GPIL for post-step (discrete) |
| 5 | PostStep DoIt | Invoke post-step processes |

GPIL vectors (even indices) are built automatically as the *reverse* of the
corresponding DoIt vectors by `CreateGPILvectors()` (`G4ProcessManager.cc:1135–1160`):

```cpp
// G4ProcessManager.cc:1147–1158
for(G4int i=0; i<SizeOfProcVectorArray; i += 2) {
    G4ProcessVector* procGPIL = theProcVector[i];
    G4ProcessVector* procDoIt = theProcVector[i+1];
    G4int nproc = (G4int)procDoIt->entries();
    procGPIL->clear();
    for(G4int j=nproc-1;j>=0;--j) {  // reverse iteration
        G4VProcess* aProc = (*procDoIt)[j];
        procGPIL->insert(aProc);
    }
}
```

`CreateGPILvectors()` is called after every `AddProcess`, `RemoveProcess`,
and `SetProcessOrdering*` call.

### The ordering constants and what they mean

From `G4ProcessManager.hh:87–92`:

```cpp
enum G4ProcessVectorOrdering
{
    ordInActive = -1,   // process is not in this DoIt vector
    ordDefault  = 1000, // default ordering parameter
    ordLast     = 9999  // process is forced to the end
};
```

`ordInActive = -1` means the process has no slot in that particular vector.
In `AddProcess()`, if an ordering parameter is negative, `idxProcVector` is
set to `-1` and the process is not inserted into that vector
(`G4ProcessManager.cc:472–476`):
```cpp
if (pAttr->ordProcVector[ivec] < 0) {
    pAttr->idxProcVector[ivec] = -1;  // not in this vector
} else {
    G4int ip = FindInsertPosition(...);
    InsertAt(ip, aProcess, ivec);
}
```

`ordDefault = 1000` means "somewhere in the middle". For most physics processes
added via `G4PhysicsListHelper`, the ordering comes from a table file
(`G4PhysicsListHelper::ReadOrdingParameterTable()`), not from the constant
itself. Common values: ionization at 2, Compton at 10, multiple scattering at
100, Bremsstrahlung at 10.

`ordLast = 9999` forces the process to the end of its vector.
`SetProcessOrderingToLast()` calls `SetProcessOrdering(aProcess, idDoIt, ordLast)`
(`G4ProcessManager.cc:891`).

**Position is determined by `FindInsertPosition()`** (`G4ProcessManager.cc:383–402`):
it finds the lowest ordering value strictly greater than `ord` and inserts before
those processes. If two processes have the same ordering parameter, the later
`AddProcess` call places the new process *after* existing ones with the same value.

### `AddProcess`: what happens step by step

`G4ProcessManager::AddProcess()` (`G4ProcessManager.cc:405–514`) does:

1. Checks `IsApplicable()` on the process.
2. Registers with `G4ProcessTable` (`G4ProcessManager.cc:434`).
3. Appends process to `theProcessList` (master list, all processes).
4. **Remaps zero to one**: if any ordering parameter is exactly 0, it is set
   to 1 (`G4ProcessManager.cc:457–459`). The value 0 is reserved for
   `SetProcessOrderingToFirst()`.
5. Creates a `G4ProcessAttribute` with the ordering parameters stored at all
   six indices (even GPIL indices mirror DoIt indices: `ordProcVector[0]` =
   `ordProcVector[1]` = AtRest ordering, etc., `G4ProcessManager.cc:462–467`).
6. For each DoIt slot with non-negative ordering, calls `FindInsertPosition`
   and `InsertAt` to place the process in the DoIt vector.
7. Calls `CreateGPILvectors()` to rebuild the reverse GPIL vectors.
8. Calls `aProcess->SetProcessManager(this)`.

### `SetProcessOrdering` variants

There are four variants:

- `SetProcessOrdering(proc, idDoIt, ord)`: sets an explicit integer value,
  calls `FindInsertPosition` (`G4ProcessManager.cc:620–704`).
- `SetProcessOrderingToFirst(proc, idDoIt)`: removes the process, sets ordering
  to 0, inserts at position 0 (`G4ProcessManager.cc:707–780`). Issues a warning
  if called twice for the same DoIt index (tracked by `isSetOrderingFirstInvoked`).
- `SetProcessOrderingToSecond(proc, idDoIt)`: sets ordering to 0 and inserts
  just before the first process with ordering > 0 (`G4ProcessManager.cc:782–883`).
- `SetProcessOrderingToLast(proc, idDoIt)`: delegates to `SetProcessOrdering`
  with `ordLast` (`G4ProcessManager.cc:886–903`).

### `G4VModularPhysicsList`: how constructors are assembled

`G4VModularPhysicsList` holds a vector of `G4VPhysicsConstructor*` (stored in
thread-local `G4MT_physicsVector`).

**`ConstructParticle()`** (`G4VModularPhysicsList.cc:112–118`) iterates the
constructor vector and calls `(*itr)->ConstructParticle()` on each. This must
create all particle definitions before processes are registered.

**`ConstructProcess()`** (`G4VModularPhysicsList.cc:134–142`):
```cpp
void G4VModularPhysicsList::ConstructProcess()
{
    G4AutoLock l(&constructProcessMutex);  // global mutex
    AddTransportation();                   // first: transportation
    for (auto itr = G4MT_physicsVector->...) {
        (*itr)->ConstructProcess();        // then physics constructors in order
    }
}
```

The mutex (noted in the source comment at line 127–131 as a known limitation
awaiting removal) serializes process construction across threads. This means
even with 100 threads, `ConstructProcess` runs sequentially on each
physics constructor.

`AddTransportation()` is called before any user constructor. This guarantees
transportation is registered on every particle's process manager before
physics constructors can modify ordering relative to it.

### When `BuildPhysicsTable` runs relative to `/run/initialize`

The sequence driven by `G4RunManagerKernel`:

1. `/run/initialize` → `G4RunManager::Initialize()` → `G4RunManager::InitializePhysics()` → `G4RunManagerKernel::InitializePhysics()` (`G4RunManagerKernel.cc:553–603`):
   - Calls `physicsList->Construct()`, which calls `ConstructParticle()` then `ConstructProcess()`.
   - Calls `physicsList->SetCuts()`.
   - Sets `physicsInitialized = true`.

2. `G4RunManager::BeamOn()` → `G4RunManager::RunInitialization()` → `G4RunManagerKernel::RunInitialization()` (`G4RunManagerKernel.cc:606–647`):
   - Calls `BuildPhysicsTables(fakeRun)` (`G4RunManagerKernel.cc:635`), which calls:
     ```cpp
     physicsList->BuildPhysicsTable();  // G4RunManagerKernel.cc:740
     ```

3. `G4VUserPhysicsList::BuildPhysicsTable()` (`G4VUserPhysicsList.cc:501–564`):
   - Iterates all particles and calls `PreparePhysicsTable(particle)` on each.
   - Then calls `BuildPhysicsTable(particle)` in priority order: gamma, e−, e+,
     proton, then all others (`G4VUserPhysicsList.cc:546–560`).
   - For each particle, iterates its process vector and calls either
     `BuildPhysicsTable(*particle)` (master thread) or
     `BuildWorkerPhysicsTable(*particle)` (worker thread)
     (`G4VUserPhysicsList.cc:675–681`).

**Practical consequence**: production cut values, material tables, and
cross-section tables must be set *before* `/run/initialize` triggers
`ConstructProcess()`, and they must not change after `BuildPhysicsTable()`
runs. Cut values set after this point have no effect until the next
`/run/initialize`. Energy limits set inside a process constructor are safe
because they are used during `BuildPhysicsTable`. Energy limits set by the
user after `/run/initialize` are ignored unless the user manually re-triggers
physics table rebuilding.

### Transportation's ordering and why it matters

`G4PhysicsListHelper::AddTransportation()` (`G4PhysicsListHelper.cc:196–253`)
registers transportation for every particle:

```cpp
// G4PhysicsListHelper.cc:249–251
pmanager->AddProcess(theTransportationProcess);
pmanager->SetProcessOrderingToFirst(theTransportationProcess, idxAlongStep);
pmanager->SetProcessOrderingToFirst(theTransportationProcess, idxPostStep);
```

The `AddProcess` call uses default arguments (`ordInActive, ordInActive, ordInActive`
from `G4ProcessManager.hh:171–174`). This means transportation is initially
**inactive** in all three DoIt categories. Then `SetProcessOrderingToFirst` for
`idxAlongStep` and `idxPostStep` overrides the ordering to 0 (the internal
"first" position) for those two categories. The AtRest ordering remains
`ordInActive = -1`, so transportation is never in the AtRest vector.

Why "first" in AlongStep matters: `G4SteppingManager::DefinePhysicalStepLength()`
iterates AlongStep GPIL from index 0 to N-1. The GPIL vector is the *reverse*
of the DoIt vector (`CreateGPILvectors` reverses). Transportation, as the
"first" DoIt entry (index 0), appears *last* in the GPIL vector. This makes
Transportation's `AlongStepGPIL` the *last* to run in the GPIL loop
(`G4SteppingManager.cc:549`): "Transportation is assumed to be the last process
in the vector." The source is explicit about this assumption.

The physical meaning: Transportation proposes the geometry step length, which
acts as a hard upper bound on `PhysicalStep`. Physics processes run their GPIL
first and may propose a shorter step. Transportation sees those proposals via
the `PhysicalStep` argument passed into `AlongStepGPIL`, applies the geometry
navigation, and returns the actual geometric step — which may again be shorter.
The minimum of all proposals wins.

For PostStep, being "first" means Transportation's `PostStepDoIt` runs last in
the invocation loop (again because the GPIL vector is reversed for DoIt). This
is correct: Transportation must update position and touchable *after* other
PostStep processes have decided what to do with the track.

## Gotchas / edge cases

1. **Same ordering parameter: later `AddProcess` wins position, not priority.**
   `FindInsertPosition()` (`G4ProcessManager.cc:383–402`) returns the position
   of the first process with strictly greater ordering, inserting *before* it.
   Two processes with `ordDefault = 1000` end up adjacent, with the first added
   earlier in the vector. GPIL iterates the GPIL vector (reverse of DoIt), so the
   process added *later* with the same ordering parameter gets its GPIL called
   *first*. If both propose a step length, the one called first can win by
   proposing a shorter step. This is order-dependent and potentially fragile.

2. **`ordInActive` for AtRest transportation is not the same as "transportation
   doesn't run at rest."** For a stopped particle, `G4SteppingManager` checks
   `fStopButAlive`, skips AlongStep/PostStep entirely, and calls
   `InvokeAtRestDoItProcs()`. Transportation has no entry in the AtRest vector
   (`ordInActive → idxProcVector = -1`), so it is simply not in the loop.
   At-rest processes (radioactive decay, annihilation at rest, etc.) dominate
   this branch.

3. **`RegisterPhysics` is only valid in `G4State_PreInit`.**
   `G4VModularPhysicsList::RegisterPhysics()` (`G4VModularPhysicsList.cc:147–153`)
   checks `currentState == G4State_PreInit` and issues a warning and early
   return if not. Calling it after `/run/initialize` (which transitions to
   `G4State_Idle`) silently does nothing.

4. **`ConstructProcess` is serialized across workers by a mutex.**
   The comment at `G4VModularPhysicsList.cc:127–131` acknowledges this is a
   known limitation (as of the source tagged for 11.4.0, not yet removed). In
   an application with many workers and many physics constructors, this
   serialization can be a scaling bottleneck during initialization.

5. **`BuildPhysicsTable` is called for gamma, e−, e+, proton first.**
   `G4VUserPhysicsList::BuildPhysicsTable()` (`G4VUserPhysicsList.cc:545–560`)
   builds tables for these four particles before iterating the rest. This
   ordering exists because many other particles borrow cross-section tables from
   these four (proton cross sections scale for hadrons, electron tables are used
   for positrons, etc.). If you have a custom particle that must be built before
   proton for some reason, you need a custom `BuildPhysicsTable` override — the
   default order cannot be changed at the physics list level.
