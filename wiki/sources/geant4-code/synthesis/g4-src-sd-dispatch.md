---
type: synthesis
domain: geant4-code
g4_version: 11.4.0
status: stable
sources:
  - source/tracking/src/G4SteppingManager.cc:240–260
  - source/digits_hits/detector/include/G4VSensitiveDetector.hh:83–94
  - source/digits_hits/detector/src/G4VSensitiveDetector.cc
  - source/digits_hits/detector/src/G4SDManager.cc
  - source/digits_hits/detector/src/G4SDStructure.cc
  - source/processes/transportation/src/G4Transportation.cc:481–490, 768–790
related: []
---

# g4-src-sd-dispatch

The entry point `G4VSensitiveDetector::ProcessHits()` is familiar to every
Geant4 user, but the path from the stepping loop to that call is indirect and
contains non-obvious filtering. Crucially: `ProcessHits` is not called by
`G4SteppingManager` directly — it is called through `Hit()`, which performs
three gate checks first. The thread-safety model of sensitive detectors is also
frequently misunderstood: `G4SDManager` is thread-local, but SD objects
themselves are not automatically per-worker without explicit `Clone()`.

## What the source actually does

### Where and when the SD is called in the step sequence

After all DoIt phases have completed and the track has been updated,
`G4SteppingManager::Stepping()` calls the SD at lines 240–248:

```cpp
// G4SteppingManager.cc:240–248
fCurrentVolume = fStep->GetPreStepPoint()->GetPhysicalVolume();
StepControlFlag = fStep->GetControlFlag();
if (fCurrentVolume != nullptr && StepControlFlag != AvoidHitInvocation) {
    fSensitive = fStep->GetPreStepPoint()->GetSensitiveDetector();
    if (fSensitive != nullptr) {
        fSensitive->Hit(fStep);
    }
}
```

This is **after** `InvokeAlongStepDoItProcs()`, `InvokePostStepDoItProcs()`,
`fTrack->AddTrackLength()`, and **before** `fUserSteppingAction->UserSteppingAction()`.
The ordering is: AlongStep DoIt → PostStep DoIt → SD → UserSteppingAction.

Key consequence: when `ProcessHits` executes, the step is fully finalized.
`GetTotalEnergyDeposit()` reflects contributions from all AlongStep processes,
and secondaries from all PostStep processes are in the secondary vector.

### `Hit()` — the three gate checks before `ProcessHits`

`G4VSensitiveDetector::Hit()` is an inline method in the header
(`G4VSensitiveDetector.hh:83–94`):

```cpp
inline G4bool Hit(G4Step* aStep)
{
    G4TouchableHistory* ROhis = nullptr;
    if (! isActive()) return false;            // gate 1: activation flag
    if (filter != nullptr) {
        if (! (filter->Accept(aStep))) return false;  // gate 2: filter
    }
    if (ROgeometry != nullptr) {
        if (! (ROgeometry->CheckROVolume(aStep, ROhis))) return false; // gate 3: RO geometry
    }
    return ProcessHits(aStep, ROhis);
}
```

**Gate 1**: `isActive()` checks the `active` boolean, which defaults to `true`
and can be toggled via `G4SDManager::Activate()` or
`G4VSensitiveDetector::Activate()`. If false, `ProcessHits` is never called.

**Gate 2**: If a `G4VSDFilter` is attached (via `SetFilter()`), it runs first.
The filter can examine the step — particle type, energy, process — and veto
the hit. If no filter is attached, this gate is bypassed.

**Gate 3**: `G4VReadOutGeometry` maps tracking-geometry steps to a readout
geometry. If attached and the step doesn't map to a readout volume,
`ProcessHits` is skipped. `ROhis` is passed as the second argument to
`ProcessHits`; if no RO geometry exists, it is `nullptr`.

### Is `ProcessHits` called once per step or multiple times?

Once per step, per volume. The call site in `G4SteppingManager.cc:247` is a
single call with `fSensitive` obtained from the `PreStepPoint`. There is no
loop over multiple SDs here. However, a logical volume can be associated with
a `G4MultiSensitiveDetector`, which internally forwards to multiple SDs — but
this is transparent to `G4SteppingManager`.

For a step that crosses a geometry boundary:
- `fSensitive` is the SD of the **entering** volume (pre-step), not the
  exiting volume. The particle has moved past the boundary; the step's SD hit
  records energy in the volume the particle just left.
- In the next step, the new `PreStepPoint` SD will be the detector of the
  next volume (if any).

### What `G4TouchableHistory` is and what `ProcessHits` receives

`G4TouchableHistory` is a snapshot of the volume hierarchy at a point in the
geometry. It encodes the full mother-volume stack from world to the touched
physical volume, with the corresponding local transforms.

`ProcessHits` receives two arguments:
- `G4Step* aStep`: the full step. `aStep->GetPreStepPoint()->GetTouchableHandle()` gives
  the touchable at the step entry. `aStep->GetPostStepPoint()->GetTouchableHandle()` gives
  the touchable at exit.
- `G4TouchableHistory* ROhist`: the readout-geometry touchable, or `nullptr` if
  no RO geometry is registered.

The comment in `G4VSensitiveDetector.hh:117–124` states explicitly:
> "the volume and the position information is kept in PreStepPoint of G4Step"

This is the canonical source of truth for hit position and volume identity.

### MT thread-safety: SD per-worker or shared?

`G4SDManager` is declared `G4ThreadLocal` (`G4SDManager.cc:37`):
```cpp
G4ThreadLocal G4SDManager* G4SDManager::fSDManager = nullptr;
```

This means each worker thread has its own `G4SDManager` instance and its own
SD tree. However, `G4VSensitiveDetector` objects themselves are **not**
automatically thread-local. The responsibility for making them per-worker lies
with `G4VUserDetectorConstruction::ConstructSDandField()`, which is called on
each worker thread by the MT run manager.

If `ConstructSDandField()` creates a fresh SD instance (with `new`) and
registers it via `sdm->AddNewDetector(sd)` and
`lv->SetSensitiveDetector(sd)`, then each worker gets its own SD object —
which is the correct pattern.

If the user registers the SD on the master thread only, the worker threads
will still have the `G4SDManager` structure but the logical volumes will not
have SDs attached (because logical volumes are shared, and `SetSensitiveDetector`
modifies the logical volume's pointer). The result is silent — no hits —
unless `G4VSensitiveDetector::Clone()` is overridden and the MT run manager
calls it during worker initialization.

`Clone()` in the base class throws `FatalException` if called without an
override (`G4VSensitiveDetector.cc:61–68`):
```cpp
G4VSensitiveDetector* G4VSensitiveDetector::Clone() const
{
    G4ExceptionDescription msg;
    msg << "Derived class does not implement cloning,\n"
        << "but Clone method called.\n";
    G4Exception(..., FatalException, msg);
    return nullptr;
}
```

The safe pattern for MT: always create SDs inside `ConstructSDandField()`, not
in the detector geometry `Construct()`.

### SD registration and the directory tree

`G4SDManager::AddNewDetector()` (`G4SDManager.cc:69–86`) places the SD into a
hierarchical `G4SDStructure` directory tree rooted at `/`. The SD name can
contain path separators: `"SD/det1"` places the SD in the `/SD/` directory.
Registration also records all hit collection names in `G4HCtable`
(`G4SDManager.cc:76–85`), which assigns each collection an integer ID used at
analysis time.

The SD lookup during stepping does *not* go through `G4SDManager`. It goes
directly through `G4StepPoint::GetSensitiveDetector()`, which reads a pointer
stored on the logical volume. `G4SDManager` is used during construction and at
event boundaries (`PrepareNewEvent`, `TerminateCurrentEvent`) but not in the
hot step loop.

### `IsFirstStepInVolume()` and `IsLastStepInVolume()`

These are methods on `G4Step` (`source/track/include/G4Step.hh:120–121`), backed
by boolean fields `fFirstStepInVolume` and `fLastStepInVolume`
(`G4Step.hh:198–199`).

They are set by `G4Transportation::AlongStepDoIt` and `AlongStepGPIL`:

```cpp
// G4Transportation.cc:481–485 (in AlongStepGPIL)
fFirstStepInVolume = fNewTrack || fLastStepInVolume;
fLastStepInVolume  = false;
fNewTrack          = false;
fParticleChange.ProposeFirstStepInVolume(fFirstStepInVolume);
```

`fLastStepInVolume` is set in `AlongStepDoIt` when a geometry boundary is
detected (`G4Transportation.cc:768`):
```cpp
fLastStepInVolume = isLastStep;
fParticleChange.ProposeFirstStepInVolume(fFirstStepInVolume);
fParticleChange.ProposeLastStepInVolume(isLastStep);
```

This means: `IsFirstStepInVolume()` is `true` on the step immediately
*after* a boundary crossing (the particle just entered), and
`IsLastStepInVolume()` is `true` on the step that *ends at* a boundary.
Both flags are propagated via `G4ParticleChange` into the step, so they
are valid when `ProcessHits` reads them.

These flags are set by Transportation, not by `G4SteppingManager`. They are
unavailable for particles that use a custom tracking manager that bypasses
`G4Transportation`.

## Gotchas / edge cases

1. **`ProcessHits` sees `StepControlFlag == AvoidHitInvocation` silently.**
   If any process (or the user stepping action in a previous step) sets
   `fStep->SetControlFlag(AvoidHitInvocation)`, the entire SD call block is
   skipped (`G4SteppingManager.cc:243`). This is a hidden veto that does not
   produce any warning. Users who set custom control flags and then wonder why
   their SD is not firing should check `GetControlFlag()`.

2. **SD is looked up from `PreStepPoint`, not from the track's current volume.**
   At `G4SteppingManager.cc:242–245`, `fCurrentVolume` is the PreStepPoint
   physical volume, and `fSensitive` is its logical volume's SD. This is
   correct for recording energy deposited during the step, but surprising if
   you expect the SD to reflect where the track *ends up*. For boundary steps,
   the post-step volume is returned by `fTrack->GetNextVolume()`, which has a
   different SD (or none).

3. **`G4SDManager` thread-locality versus logical-volume SD pointer.**
   Logical volumes are shared across all threads (they live in
   `G4LogicalVolumeStore`). Their `fSensitiveDetector` pointer, set by
   `lv->SetSensitiveDetector(sd)`, is therefore shared. In MT mode,
   `ConstructSDandField()` must be called per worker, and each call should
   create a *new* SD instance to avoid workers writing to each other's hit
   collections. If you call `SetSensitiveDetector` with a worker-local SD,
   the last worker to call it wins for the shared pointer — this is a race
   condition. The framework prevents this by calling `ConstructSDandField()`
   on a copy of the logical volume store per worker, but only if implemented
   correctly by the user.

4. **`collectionName` must be filled in the constructor before `AddNewDetector`.**
   `G4SDManager::AddNewDetector()` (`G4SDManager.cc:71`) reads
   `aSD->GetNumberOfCollections()` immediately. If `collectionName` is not
   populated in the SD constructor before registration, no collection IDs are
   assigned, and `GetCollectionID()` returns -1 at analysis time. This is a
   common silent failure.

5. **Zero-energy steps still invoke `Hit()`.** `G4SteppingManager` does not
   filter on energy deposit before calling `fSensitive->Hit(fStep)`. The SD is
   called for every step in a sensitive volume, including boundary steps with
   zero energy deposit. The `isActive()` and filter gates can suppress these,
   but by default they do not. A custom SD that does not filter must guard
   with `if (edep <= 0.) return false;` (or its equivalent) to avoid
   recording zero-energy boundary crossings.
