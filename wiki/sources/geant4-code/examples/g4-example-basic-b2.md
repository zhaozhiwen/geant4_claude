---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - sensitive-detector
  - hits-collection
  - parameterised-volume
  - magnetic-field
  - user-limits
  - detector-messenger
  - g4-region
---

# g4-example-basic-b2


B2 introduces the canonical Geant4 scoring path — `G4VSensitiveDetector` + `G4VHit` + `G4THitsCollection<T>` — through a tracker with six chambers around a target. Beyond scoring, it adds a uniform magnetic field via `G4GlobalMagFieldMessenger`, step-length capping with `G4UserLimits`, and a `DetectorMessenger` that exposes live UI commands for material and step-length changes. It comes in two flavors: B2a with explicit chamber placements and B2b with a `G4PVParameterised` volume, making it also the first introduction to replicated geometry.

## Key concepts demonstrated

- `sensitive-detector` — `G4VSensitiveDetector` + `ProcessHits` as the per-step scoring callback; why this beats `SteppingAction` scoring whenever you want per-hit records rather than run totals
- `hits-collection` — `G4THitsCollection<T>` as the per-event container for typed hit objects; how `G4SDManager` registers and retrieves collections
- `parameterised-volume` — `G4PVParameterised` + `G4VPVParameterisation` replicates one logical volume with per-copy-number transforms, avoiding N separate physvol placements for regular arrays
- `magnetic-field` — `G4GlobalMagFieldMessenger` for a uniform field with built-in UI command; the zero-custom-code path for constant fields
- `user-limits` — `G4UserLimits` + `G4StepLimiter` process to cap step length inside a region; required when Geant4's adaptive stepping is too coarse for tracking accuracy in a field
- `detector-messenger` — pattern for a `G4UImessenger` subclass that exposes per-detector UI directories so geometry/material knobs can be swept without recompiling
