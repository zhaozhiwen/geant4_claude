---
type: synthesis
domain: geant4-code
g4_version: 11.4.0
status: stable
sources:
  - source/tracking/src/G4TrackingManager.cc
  - source/event/src/G4EventManager.cc:91–437
  - source/event/src/G4StackManager.cc:87–732
  - source/event/include/G4StackManager.hh
  - source/track/include/G4TrackStatus.hh
related: []
---

# g4-src-track-and-secondary-lifecycle

The official documentation describes the track lifecycle at a conceptual level — primary tracks, secondaries, the urgent/waiting/postpone stacks — but it does not show the exact call order, where track IDs are stamped, what each `G4TrackStatus` value actually causes the stepping loop to do, or how `fSuspend` and `fSuspendAndWait` differ at the stack level. Those details live in three source files and understanding them is necessary for writing correct `G4UserStackingAction`, `G4UserTrackingAction`, and sensitive detector code.

## What the source actually does

### Entry point: G4EventManager::DoProcessing

`G4EventManager::DoProcessing` (`G4EventManager.cc:91`) is the top-level event driver. Its inner loop pops tracks from `G4StackManager` and dispatches them:

```cpp
// G4EventManager.cc:177–302
do {
  while ((track = trackContainer->PopNextTrack(&previousTrajectory)) != nullptr) {
    G4VTrackingManager* particleTrackingManager =
        track->GetParticleDefinition()->GetTrackingManager();
    if (particleTrackingManager != nullptr) {
      particleTrackingManager->HandOverOneTrack(track);
      trackingManagersToFlush.insert(particleTrackingManager);
    } else {
      tracking = true;
      trackManager->ProcessOneTrack(track);     // <-- standard path
      istop = track->GetTrackStatus();
      tracking = false;
      // ... handle secondaries and istop (switch block, lines 252–286)
    }
  }
  for (G4VTrackingManager *tm : trackingManagersToFlush) tm->FlushEvent();
  trackingManagersToFlush.clear();
  G4GlobalFastSimulationManager::GetGlobalFastSimulationManager()->Flush();
} while (trackContainer->GetNUrgentTrack() > 0);
```

The outer `do-while` repeats because flushing a custom tracking manager or fast-simulation model can push new tracks onto the urgent stack (`G4EventManager.cc:302`).

### G4TrackingManager::ProcessOneTrack call order

Inside `ProcessOneTrack` (`G4TrackingManager.cc:59–156`), the order is:

1. Clear the secondaries vector (`G4TrackingManager.cc:70–73`).
2. Call `fpSteppingManager->SetInitialStep(fpTrack)` (`G4TrackingManager.cc:79`).
3. **`PreUserTrackingAction` fires here** (`G4TrackingManager.cc:85–86`), before the trajectory is created and before the first step.
4. Trajectory object is constructed if `StoreTrajectory != 0` (`G4TrackingManager.cc:94–111`).
5. `StartTracking` is called on all processes (`G4TrackingManager.cc:121`).
6. The stepping loop runs while `fAlive` or `fStopButAlive` (`G4TrackingManager.cc:125–136`):
   ```cpp
   while ((fpTrack->GetTrackStatus() == fAlive) ||
          (fpTrack->GetTrackStatus() == fStopButAlive)) {
     fpTrack->IncrementCurrentStepNumber();
     fpSteppingManager->Stepping();
     if (EventIsAborted)
       fpTrack->SetTrackStatus(fKillTrackAndSecondaries);
   }
   ```
7. `EndTracking` on all processes (`G4TrackingManager.cc:138`).
8. **`PostUserTrackingAction` fires here** (`G4TrackingManager.cc:142–144`), after the loop exits regardless of stop reason.

`PreUserTrackingAction` fires after `SetInitialStep` but before any `Stepping()` call. `PostUserTrackingAction` fires after `EndTracking`, so process state is already cleaned up when it executes.

### Secondaries: creation and stacking

Secondaries are accumulated inside `G4SteppingManager::Stepping()` as physics DoIt methods run. After `ProcessOneTrack` returns, `G4EventManager` calls `trackManager->GimmeSecondaries()` (`G4EventManager.cc:251`) and hands the vector to `StackTracks` (`G4EventManager.cc:404–437`):

```cpp
// G4EventManager.cc:404–437
void G4EventManager::StackTracks(G4TrackVector* trackVector, G4bool IDhasAlreadySet) {
  for (auto newTrack : *trackVector) {
    ++trackIDCounter;
    if (!IDhasAlreadySet) {
      newTrack->SetTrackID(trackIDCounter);          // ID assigned here
      // also propagated to the G4PrimaryParticle if applicable
    }
    newTrack->SetOriginTouchableHandle(newTrack->GetTouchableHandle());
    trackContainer->PushOneTrack(newTrack);          // -> ClassifyNewTrack
  }
  trackVector->clear();
}
```

`trackIDCounter` is a monotonically incrementing integer reset to 0 at `ProcessOneEvent` entry (`G4EventManager.cc:468`). Every track — primary or secondary — gets a unique ID within one event. The counter is not thread-safe across events; each worker thread has its own `G4EventManager` instance (it is `G4ThreadLocal`, `G4EventManager.cc:55`).

`parentID` is set by the physics process that creates the secondary (in `G4SteppingManager`), not by `StackTracks`. It equals the `trackID` of the parent at the moment of production.

### ClassifyNewTrack timing

`ClassifyNewTrack` is called from inside `G4StackManager::PushOneTrack` (`G4StackManager.cc:87–164`), which is called from `StackTracks` above. The sequence per secondary is:

1. Validate that the particle has a process manager (`G4StackManager.cc:91`).
2. Call `DefineDefaultClassification` to determine the built-in classification (`G4StackManager.cc:119`).
3. Call `userStackingAction->ClassifyNewTrack(newTrack)` if a user action is registered (`G4StackManager.cc:121–135`).
4. Route to urgent, waiting, postpone, or a sub-event stack via `SortOut` (`G4StackManager.cc:161`).

`ClassifyNewTrack` therefore sees each secondary individually, immediately after it is assigned its track ID but before any stepping.

### G4TrackStatus values and their effect

From `G4TrackStatus.hh:40–58` and the `switch` block at `G4EventManager.cc:252–286`:

| Status | Comment in header | What EventManager does |
|--------|------------------|------------------------|
| `fAlive` | Continue tracking | Stepping loop continues; if returned from `ProcessOneTrack` it is an illegal state and triggers `JustWarning` |
| `fStopButAlive` | Invoke rest processes, then kill | Track pushed back to urgent stack via `PushOneTrack`; secondaries stacked |
| `fStopAndKill` | Kill the track | Secondaries stacked; track deleted |
| `fKillTrackAndSecondaries` | Kill track and all secondaries | Secondaries deleted without stacking; track deleted (`G4EventManager.cc:277–284`) |
| `fSuspend` | Suspend the track | Track pushed back to urgent stack with its partial trajectory; secondaries stacked |
| `fSuspendAndWait` | Suspend and send to waiting stack | Same push-back as `fSuspend` but `SortOut` sends it to `waitingStack` (via `DefineDefaultClassification`, `G4StackManager.cc:728`) |
| `fPostponeToNextEvent` | Defer to next event | Track pushed to `postponeStack`; secondaries stacked |

The `fStopButAlive` and `fSuspend` cases share the same `PushOneTrack` call (`G4EventManager.cc:257`). The difference is resolved inside `G4StackManager::DefineDefaultClassification` (`G4StackManager.cc:705–732`): `fSuspendAndWait` maps to `fWaiting`; all others default to `fUrgent` unless overridden.

### fSuspend vs fSuspendAndWait at the stack level

`fSuspend` → default classification `fUrgent` → track goes back to the urgent stack and competes immediately for re-selection.

`fSuspendAndWait` → default classification `fWaiting` → track goes to `waitingStack`. The waiting stack drains to urgent only when the urgent stack is empty and `NewStage` is invoked (`G4StackManager.cc:185`):

```cpp
// G4StackManager.cc:176–213
while (GetNUrgentTrack() == 0) {
  waitingStack->TransferTo(urgentStack);
  // ... additional waiting stacks transferred in order ...
  if (userStackingAction != nullptr) userStackingAction->NewStage();
  if ((GetNUrgentTrack() == 0) && (GetNWaitingTrack() == 0)) return nullptr;
}
```

A track in `fSuspendAndWait` is guaranteed not to resume until all current urgent tracks (and their descendants) are exhausted. There is a guard in `PushOneTrack` (`G4StackManager.cc:136–138`): if a `fSuspendAndWait` track is classified back to urgent by `ClassifyNewTrack`, its status is silently reset to `fSuspend` to prevent it from re-entering the waiting stack on the next cycle.

### Postponed tracks

Postponed tracks survive the event boundary. `G4StackManager::PrepareNewEvent` (`G4StackManager.cc:270–338`) transfers them out of `postponeStack` at the start of the next event, calls `ClassifyNewTrack` on each, and resets their `parentID` to -1 and assigns negative `trackID` values (`G4StackManager.cc:322–323`):

```cpp
aTrack->SetParentID(-1);
aTrack->SetTrackID(-(++n_passedFromPrevious));
```

These negative IDs serve as a sentinel distinguishing postponed tracks from normal ones.

## Gotchas / edge cases

1. **`PostUserTrackingAction` still fires when a track is killed mid-event.** If `EventAborted()` is called, `EventIsAborted` is set to `true` and the stepping loop exits by forcing `fKillTrackAndSecondaries` (`G4TrackingManager.cc:133–135`). `PostUserTrackingAction` still executes (`G4TrackingManager.cc:142–144`). Code that accesses `fpTrack` in `PostUserTrackingAction` will see the track in `fKillTrackAndSecondaries` status; it must not attempt to push new tracks or access a trajectory that may not have been stored.

2. **`fSuspendAndWait` classification override is silently swallowed.** If `ClassifyNewTrack` returns a classification > 0 (i.e., not `fKill`) for a track that is in `fSuspendAndWait` status, the stacking manager resets the track status to `fSuspend` (`G4StackManager.cc:136–138`). The user's intent to wait is overridden without any warning; this is the intended behavior but surprises users who return `fUrgent` for these tracks.

3. **Secondary IDs are not assigned until after `PostUserTrackingAction`.** Secondaries accumulate in `G4TrackingManager`'s vector during stepping. `StackTracks` — which assigns the `trackID` — is called only after `ProcessOneTrack` returns and `PostUserTrackingAction` has fired. Any access to `secondaries[i]->GetTrackID()` inside `PostUserTrackingAction` returns whatever value was set by the creating process (usually 0), not the final stacked ID.

4. **`fKillTrackAndSecondaries` deletes secondaries in EventManager, not in TrackingManager.** The stepping loop exits as soon as this status is set. `GimmeSecondaries()` returns whatever was accumulated up to that step. `G4EventManager` then deletes them all (`G4EventManager.cc:278–284`) without calling `ClassifyNewTrack`. A user stacking action will never see these secondaries.

5. **Custom tracking managers bypass the entire stacking protocol.** If a particle type has a `G4VTrackingManager` registered via `G4ParticleDefinition::SetTrackingManager`, that particle goes through `HandOverOneTrack` (`G4EventManager.cc:197`). The stacking manager's `ClassifyNewTrack` is never called for it, and `ProcessOneTrack` / user tracking actions are not invoked. The plugin's generic main must not assume all particles pass through `G4TrackingManager`.
