---
type: entity
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[g4-src-step-lifecycle]]", "[[g4-src-sd-dispatch]]", "[[g4-process-manager]]", "[[g4-step]]"]
---

# G4SteppingManager

**Role:** drives the per-step simulation loop — GPIL competition, DoIt invocations, SD dispatch, and user action callbacks — for one step of one track.

**Header:** `source/tracking/include/G4SteppingManager.hh`

## Key interface

| Method | What it does |
|--------|-------------|
| `Stepping()` | Execute one complete step: pre-step setup, GPIL, AlongStep DoIt, PostStep DoIt, SD call, user stepping action |
| `SetInitialStep(track)` | Called once per track before the first `Stepping()` call; locates the track in geometry and populates `PreStepPoint` |
| `DefinePhysicalStepLength()` | Runs the PostStep then AlongStep GPIL loops; determines `PhysicalStep` and `fStepStatus` |
| `InvokeAlongStepDoItProcs()` | Fires all active AlongStep DoIt methods in vector order; skipped if step is `fExclusivelyForcedProc` |
| `InvokePostStepDoItProcs()` | Fires PostStep DoIt methods in reverse-GPIL order; respects `ForceCondition` flags and track kill status |
| `InvokeAtRestDoItProcs()` | Fires when `fTrack->GetTrackStatus() == fStopButAlive`; runs winning at-rest process |

## Non-obvious facts

- **SD is called before `UserSteppingAction`, not after.** The call order inside `Stepping()` is: AlongStep DoIt → PostStep DoIt → `fSensitive->Hit(fStep)` (line 247) → `UserSteppingAction` (line 254). The step state is identical for both, so `UserSteppingAction` can inspect secondaries already enqueued by PostStep DoIt. See [[g4-src-step-lifecycle]].

- **`fCurrentVolume` for the SD lookup uses the PreStepPoint, not the PostStepPoint.** At line 242, `fCurrentVolume` is reassigned to `fStep->GetPreStepPoint()->GetPhysicalVolume()` before the SD lookup. For a boundary-crossing step, the SD that fires belongs to the volume the particle *came from*. See [[g4-src-sd-dispatch]].

- **`fGeomBoundary` is not set by `DefinePhysicalStepLength`.** Transportation sets it inside `G4Transportation::AlongStepDoIt` (`G4Transportation.cc:506–508`). After `InvokeAlongStepDoItProcs` returns, `Stepping()` re-reads `PostStepPoint->GetStepStatus()` (line 202) to pick up the change. A process that checks `fStepStatus` before this re-read will see the pre-Transportation value.

- **`InvokeAlongStepDoItProcs` is entirely skipped for `fExclusivelyForcedProc` steps** (line 722). Energy loss, scattering, and Transportation do not run in that step; `PhysicalStep` retains the value from the GPIL loop that aborted early. See [[g4-src-step-lifecycle]].
