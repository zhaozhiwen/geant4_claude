---
type: entity
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[g4-src-track-and-secondary-lifecycle]]", "[[g4-stepping-manager]]", "[[g4-step]]"]
---

# G4TrackingManager

**Role:** drives one track to completion — initializes the step state, runs the step loop until the track stops or is killed, and fires `PreUserTrackingAction`/`PostUserTrackingAction` at the correct points.

**Header:** `source/tracking/include/G4TrackingManager.hh`

## Key interface

| Method | What it does |
|--------|-------------|
| `ProcessOneTrack(track)` | Full lifecycle for one track: `SetInitialStep`, pre-tracking action, step loop, end-tracking, post-tracking action |
| `SetUserAction(trackingAction)` | Register the `G4UserTrackingAction`; called by the run manager during action initialization |
| `GetSteppingManager()` | Access the owned `G4SteppingManager` instance for diagnostics or direct step inspection |
| `EventAborted()` | Signal that the event was aborted; the step loop exits by forcing `fKillTrackAndSecondaries` on the current track |
| `SetVerboseLevel(n)` | Control tracking verbosity (0 = silent, higher = per-step printout) |

## Non-obvious facts

- **`PreUserTrackingAction` fires before the first step, not before geometry location.** The call order inside `ProcessOneTrack` is: `SetInitialStep()` → `PreUserTrackingAction` (line 85–86) → trajectory construction → `StartTracking` on processes → step loop. The track is already placed in geometry when `PreUserTrackingAction` fires; `GetVolume()` and the touchable are valid. See [[g4-src-track-and-secondary-lifecycle]].

- **`PostUserTrackingAction` fires after `EndTracking`, regardless of how the track stopped.** This includes tracks killed by `EventAborted()` (status `fKillTrackAndSecondaries`). Code in `PostUserTrackingAction` that assumes the track completed normally must check `GetTrackStatus()` first. See [[g4-src-track-and-secondary-lifecycle]].

- **Secondary track IDs are not yet assigned when `PostUserTrackingAction` runs.** Secondaries accumulate in `G4TrackingManager`'s vector during stepping. `StackTracks` — which assigns `trackID` — is called by `G4EventManager` only after `ProcessOneTrack` returns. Any access to `GetTrackID()` on a secondary inside `PostUserTrackingAction` returns 0 (or whatever the creating process set), not the final stacked ID. See [[g4-src-track-and-secondary-lifecycle]].

- **Particles with a custom `G4VTrackingManager` bypass `G4TrackingManager` entirely.** `G4EventManager` dispatches to `HandOverOneTrack` instead, skipping `ProcessOneTrack`, user tracking actions, and the standard stacking protocol. The plugin's generic main must not assume all particles pass through this class.
