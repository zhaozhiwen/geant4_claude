---
type: synthesis
domain: geant4-code
g4_version: 11.4.0
status: stable
sources:
  - source/tracking/src/G4SteppingManager.cc
  - source/tracking/include/G4SteppingManager.hh
  - source/track/include/G4StepStatus.hh
  - source/processes/management/src/G4ProcessManager.cc
  - source/processes/transportation/src/G4Transportation.cc
related: []
---

# g4-src-step-lifecycle

Understanding the Geant4 step as a concept is easy; understanding what actually
executes in what order — and what state is valid at each point — requires reading
`G4SteppingManager`. Documentation describes the three DoIt categories but elides
the GPIL competition, the iterator reversal, the SD call site, and the exact
moment `fGeomBoundary` gets written. These details determine when hit data is
correct and when user stepping actions can trust the step's bookkeeping.

## What the source actually does

### Entry point

`G4TrackingManager` drives the step loop. For each step it calls
`G4SteppingManager::Stepping()` (`G4SteppingManager.cc:120`). Before
`Stepping()` is called for the first step on a new track,
`SetInitialStep()` is called once to locate the track in the geometry and
populate the `PreStepPoint` (`G4SteppingManager.cc:268–371`).

### Per-step sequence inside `Stepping()`

```cpp
// G4SteppingManager.cc:141–264 (condensed)
fStep->CopyPostToPreStepPoint();       // 141: last post → new pre
fStep->ResetTotalEnergyDeposit();      // 142
fTrack->SetTouchableHandle(            // 146: advance volume
    fTrack->GetNextTouchableHandle());

// Branch: stopped particle
if (fTrack->GetTrackStatus() == fStopButAlive) {    // 166
    InvokeAtRestDoItProcs();                         // 168
    fStepStatus = fAtRestDoItProc;                   // 169
    fTrack->SetTrackStatus(fStopAndKill);            // 178
} else {
    DefinePhysicalStepLength();   // 187: GPIL competition
    fStep->SetStepLength(PhysicalStep);              // 190
    InvokeAlongStepDoItProcs();   // 198
    fStepStatus = fStep->GetPostStepPoint()          // 202
                      ->GetStepStatus();    // re-read: Transport may have changed it
    fStep->UpdateTrack();         // 205
    // safety bookkeeping 208–212
    InvokePostStepDoItProcs();    // 219
}

fTrack->AddTrackLength(fStep->GetStepLength());     // 232

// SD call
fSensitive = fStep->GetPreStepPoint()
                 ->GetSensitiveDetector();           // 245
if (fSensitive != nullptr)
    fSensitive->Hit(fStep);                          // 247

// User stepping action
fUserSteppingAction->UserSteppingAction(fStep);     // 254
regionalAction->UserSteppingAction(fStep);          // 260
```

### GPIL competition: how the winner is chosen

`DefinePhysicalStepLength()` (`G4SteppingManager.cc:443–575`) runs two
loops.

**PostStep GPIL loop** (`G4SteppingManager.cc:457–512`):
- Iterates `fPostStepGetPhysIntVector` (all registered PostStep processes).
- Calls `PostStepGPIL()` on each. The return value is a physical length; the
  process also writes a `G4ForceCondition`.
- If a process returns `ExclusivelyForced`, that process wins immediately and
  all remaining processes are set `InActivated` — the function returns early
  (`G4SteppingManager.cc:493–498`).
- Otherwise the smallest length wins (`G4SteppingManager.cc:500–505`):
  ```cpp
  if (physIntLength < PhysicalStep) {
      PhysicalStep = physIntLength;
      fStepStatus = fPostStepDoItProc;
      fPostStepDoItProcTriggered = G4int(np);
      fStep->GetPostStepPoint()->SetProcessDefinedStep(fCurrentProcess);
  }
  ```

**AlongStep GPIL loop** (`G4SteppingManager.cc:520–574`):
- Can further shrink `PhysicalStep` (the PostStep loop ran first and set an
  initial value).
- The smallest proposed length wins, but only if the process sets
  `fGPILSelection = CandidateForSelection`. Multi-scattering proposes a step
  limit but sets `NotCandidateForSelection`, so it can shorten the step
  without winning the status (`G4SteppingManager.cc:537–545`).
- Transportation is assumed to be the *last* process in the AlongStep vector
  (`G4SteppingManager.cc:549`). If it wins, the code defers setting
  `fStepStatus = fGeomBoundary` to `G4Transportation::AlongStepDoIt` (see
  below).

**Safety tracking** (`G4SteppingManager.cc:516–574`): `proposedSafety` keeps
the running minimum safety proposed by all AlongStep processes. After
`InvokeAlongStepDoItProcs()` completes, the endpoint safety is:
```cpp
endpointSafety = std::max(proposedSafety - GeomStepLength, kCarTolerance);
```
(`G4SteppingManager.cc:210`)

### `fGeomBoundary` assignment

**It is not set by `DefinePhysicalStepLength`**. The comment in
`G4SteppingManager.cc:549–554` documents why: a parallel world can propose the
shortest length while expecting `fGeomBoundary` to come from Transportation.
The actual assignment occurs inside `G4Transportation::AlongStepDoIt`
(`G4Transportation.cc:506–508`):
```cpp
if(fGeometryLimitedStep)
{
    stepData.GetPostStepPoint()->SetStepStatus(fGeomBoundary);
}
```
After `InvokeAlongStepDoItProcs()` returns, `Stepping()` re-reads the status
from the PostStepPoint (`G4SteppingManager.cc:202`) to pick up this change.

### The three DoIt invocations

**`InvokeAlongStepDoItProcs()`** (`G4SteppingManager.cc:716–764`): skipped
entirely if `fStepStatus == fExclusivelyForcedProc` (`G4SteppingManager.cc:722`).
Otherwise all active AlongStep processes fire unconditionally in vector order.
Each process writes into `fParticleChange`; `UpdateStepForAlongStep` applies
it to the step, then `fParticleChange` is cleared for the next process.

**`InvokePostStepDoItProcs()`** (`G4SteppingManager.cc:767–805`): iterates in
*reverse* order relative to `fSelectedPostStepDoItVector` (the vector was
built with DoIt in inverse order of GPIL). A process fires if its selection
flag matches the current `fStepStatus`:
```cpp
if (((Cond == NotForced) && (fStepStatus == fPostStepDoItProc)) ||
    ((Cond == Forced) && (fStepStatus != fExclusivelyForcedProc)) ||
    ((Cond == ExclusivelyForced) && (fStepStatus == fExclusivelyForcedProc)) ||
    ((Cond == StronglyForced)))
```
(`G4SteppingManager.cc:779–783`). If the track is killed, the loop breaks
*except* for `StronglyForced` processes, which still fire
(`G4SteppingManager.cc:795–803`).

**`InvokeAtRestDoItProcs()`** (`G4SteppingManager.cc:636–713`): only when
`fTrack->GetTrackStatus() == fStopButAlive`. All `Forced` processes fire; the
winning non-Forced process is the one with the shortest lifetime returned by
`AtRestGPIL()`. Stable ions (lifetime > 1e+100) skip all DoIt calls and get
`fNoProcess` as the defined step process.

### G4StepStatus values and when they are set

From `source/track/include/G4StepStatus.hh`:

| Enumerator | Meaning | Set where |
|---|---|---|
| `fWorldBoundary` | Track left world | `G4SteppingManager.cc:787` (after `InvokePSDIP` when `GetNextVolume()==nullptr`) |
| `fGeomBoundary` | Volume boundary | `G4Transportation::AlongStepDoIt:508` |
| `fAtRestDoItProc` | Rest process | `G4SteppingManager.cc:169` |
| `fPostStepDoItProc` | PostStep process won GPIL | `G4SteppingManager.cc:502` |
| `fExclusivelyForcedProc` | ExclusivelyForced PostStep | `G4SteppingManager.cc:474` |
| `fUserDefinedLimit` | User step limit | set by Transportation when UserLimit triggers |
| `fUndefined` | Initial value | constructor / `SetInitialStep` |

`fAlongStepDoItProc` in the enum (`G4StepStatus.hh:47`) is never set by
`G4SteppingManager`; it is present for completeness.

### What is on `G4Step`/`G4Track` at each hook

**When `ProcessHits` is called** (`G4SteppingManager.cc:245–248`):
All DoIt phases have completed; `fStep->UpdateTrack()` has run after both
AlongStep and PostStep. The step is fully finalized: `GetPostStepPoint()` holds
the track's new position, energy, and momentum. The `PreStepPoint` holds the
entry position (the physical beginning of the step). `GetTotalEnergyDeposit()`
is final. The `fCurrentVolume` used to look up the SD is the **PreStepPoint**
physical volume (`G4SteppingManager.cc:242`), so the SD belongs to the volume
the particle *was in* before the step, not where it arrived.

**When `UserSteppingAction` is called** (`G4SteppingManager.cc:253–260`):
Identical state to `ProcessHits`. Both SD and user stepping action see the same
completed step. `UserSteppingAction` fires after the SD call, so it can inspect
secondaries already enqueued.

### PostStepDoIt at geometry boundaries

Yes, PostStepDoIt *does* fire at geometry boundaries.
`InvokePostStepDoItProcs()` is called unconditionally after AlongStep
(`G4SteppingManager.cc:219`). Any process with `Forced` or `StronglyForced`
fires regardless of `fStepStatus`. The physics-winner (the process that set
`fStepStatus = fPostStepDoItProc`) fires when `Cond == NotForced`. At a
geometry boundary, `fStepStatus` has been overwritten to `fGeomBoundary` by
Transportation, so the physics-winner's DoIt does **not** fire in that step
(unless it declared `Forced`). This is intentional: geometry boundaries reset
the step, and the physics interaction is deferred to the next step.

## Gotchas / edge cases

1. **GPIL vector is reverse of DoIt vector.** `G4ProcessManager::CreateGPILvectors()`
   (`G4ProcessManager.cc:1135–1160`) builds the GPIL vectors by iterating the
   DoIt vector *backwards* and inserting. The DoIt loop in
   `InvokePostStepDoItProcs()` then traverses with index `MAXofPostStepLoops - np - 1`
   (`G4SteppingManager.cc:777`) to compensate. Net effect: processes fire in the
   same priority order for both GPIL and DoIt. Getting this wrong when manually
   constructing test harnesses is a common mistake.

2. **`fCurrentVolume` in the SD call uses PreStepPoint, not PostStepPoint.**
   At `G4SteppingManager.cc:242`, `fCurrentVolume` is reassigned to the
   *PreStepPoint* physical volume before the SD lookup. This means if a step
   crosses a boundary, the SD that fires is the one attached to the volume the
   particle *came from*, not where it arrived. The particle's new volume is
   accessible via `fStep->GetPostStepPoint()->GetPhysicalVolume()` or
   `fTrack->GetNextTouchableHandle()`.

3. **Zero-ordering parameter is silently changed to 1.**
   In `G4ProcessManager::AddProcess()` (`G4ProcessManager.cc:457–459`):
   ```cpp
   if (ordAtRestDoIt==0)    ordAtRestDoIt    = 1;
   if (ordAlongStepDoIt==0) ordAlongStepDoIt = 1;
   if (ordPostStepDoIt==0)  ordPostStepDoIt  = 1;
   ```
   Passing `ordDefault = 0` has the opposite of the intended effect; `0` means
   "first" internally (used only by `SetProcessOrderingToFirst`), and passing it
   via `AddProcess` is remapped to `1`. Use named constants.

4. **AlongStepDoIt is skipped for ExclusivelyForced steps.**
   If a PostStep process returns `ExclusivelyForced`, `InvokeAlongStepDoItProcs()`
   returns immediately (`G4SteppingManager.cc:722–724`). This means energy loss,
   scattering, and transportation do *not* execute in that step. The step length
   is still set to `PhysicalStep` from the GPIL loop (which aborted early), so
   `GetStepLength()` returns the value proposed by the forced process.

5. **`fStopAndKill` mid-PostStep loop.**
   If a PostStep process kills the track, the loop breaks — but `StronglyForced`
   processes still execute (`G4SteppingManager.cc:795–803`). If your sensitive
   detector logic depends on examining all PostStep secondaries, it must account
   for the track potentially already being dead.
