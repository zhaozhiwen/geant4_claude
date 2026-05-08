---
type: entity
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[g4-src-step-lifecycle]]", "[[g4-src-sd-dispatch]]", "[[g4-stepping-manager]]", "[[g4-tracking-manager]]"]
---

# G4Step

**Role:** the data object passed to all user hooks during a step; carries the pre- and post-step point snapshots, accumulated energy deposit, step length, and the owning track reference.

**Header:** `source/track/include/G4Step.hh`

## Key interface

| Method / member | What it provides |
|-----------------|-----------------|
| `GetPreStepPoint()` | `G4StepPoint*` at the start of the step: position, volume, SD, touchable, momentum, time |
| `GetPostStepPoint()` | `G4StepPoint*` at the end of the step: updated position, momentum, step status, process that defined the step |
| `GetTotalEnergyDeposit()` | Sum of energy deposits from all AlongStep DoIt processes; final when `ProcessHits` and `UserSteppingAction` are called |
| `GetTrack()` | The owning `G4Track*`; reflects post-step state after `UpdateTrack()` |
| `GetStepLength()` | Physical step length in mm |
| `IsFirstStepInVolume()` | `true` on the step immediately after a boundary crossing (particle just entered the volume) |
| `IsLastStepInVolume()` | `true` on the step that ends at a boundary |
| `GetSecondary()` | Vector of secondaries produced by PostStep DoIt methods during this step |

## Non-obvious facts

- **`IsFirstStepInVolume()` and `IsLastStepInVolume()` are set by Transportation, not by `G4SteppingManager`.** They propagate via `G4ParticleChange` inside `G4Transportation::AlongStepGPIL` and `AlongStepDoIt` (`G4Transportation.cc:481–485`, `768`). They are unavailable for particles that use a custom tracking manager that bypasses `G4Transportation`. Both flags are valid by the time `ProcessHits` reads them. See [[g4-src-sd-dispatch]].

- **`PreStepPoint`'s physical volume is used for the SD lookup, not `PostStepPoint`.** `G4SteppingManager` assigns `fCurrentVolume = fStep->GetPreStepPoint()->GetPhysicalVolume()` (line 242) before calling `fSensitive->Hit(fStep)`. For a boundary-crossing step, the SD that fires belongs to the volume the particle *was in*, not where it arrived. The arriving volume is `fTrack->GetNextVolume()` or `PostStepPoint->GetPhysicalVolume()`. See [[g4-src-step-lifecycle]].

- **`GetTotalEnergyDeposit()` is fully finalized before `ProcessHits` is called.** All DoIt phases and `fStep->UpdateTrack()` have completed by the time the SD call site executes (line 247). A zero energy deposit on a boundary-crossing step is normal — ionization was not computed in that step — which is why per-step SD code typically guards with `if (edep <= 0.) return false`. See [[g4-src-step-lifecycle]].

- **`fAlongStepDoItProc` in `G4StepStatus` is never set by `G4SteppingManager`.** The enum value exists in `G4StepStatus.hh:47` for completeness, but the stepping manager never assigns it. Code that tests `GetPostStepPoint()->GetStepStatus() == fAlongStepDoItProc` will never match. See [[g4-src-step-lifecycle]].
