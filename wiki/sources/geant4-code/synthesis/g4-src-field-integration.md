---
type: synthesis
domain: geant4-code
g4_version: 11.4.0
status: stable
sources:
  - source/geometry/magneticfield/src/G4ChordFinder.cc:78-411
  - source/geometry/magneticfield/include/G4ChordFinder.hh:100-195
  - source/geometry/magneticfield/include/G4FieldManager.hh:108-328
  - source/geometry/magneticfield/include/G4FieldParameters.hh:150-160
  - source/geometry/magneticfield/src/G4FieldManager.cc:38-179
  - source/geometry/navigation/src/G4PropagatorInField.cc:46-738
related: ["[[magnetic-field-setup]]"]
---

# g4-src-field-integration

Charged-track propagation through a magnetic field involves five interacting
classes across two geometry subsystems. Headers expose the API; they do not
explain which class drives the outer loop, how the field manager is resolved
per volume, what the chord-finding algorithm actually bisects, or what the
numerical defaults mean in practice. A user configuring field accuracy for a
detector simulation needs the source-level answers. For the user-facing
configuration pattern (uniform field, mapped field, local-LV override) see
[[magnetic-field-setup]].

## What the source actually does

### The call chain

The entry point per tracking step is `G4PropagatorInField::ComputeStep()`
(`source/geometry/navigation/src/G4PropagatorInField.cc:115`).
This method drives the loop. Inside it:

1. **Field manager resolution** — `FindAndSetFieldManager(pPhysVol)` is
   called once per step (`PropagatorInField.cc:180`).
2. **Epsilon is computed** — relative accuracy `epsilon = deltaOneStep /
   CurrentProposedStepLength`, then clamped to `[epsilonMin, epsilonMax]`
   (`PropagatorInField.cc:202-207`).
3. **Inner loop** — a `do {...} while` loop calls
   `GetChordFinder()->AdvanceChordLimited(...)` (`PropagatorInField.cc:320-325`)
   to advance the track one chord-limited sub-step.
4. **Boundary test** — `IntersectChord(SubStartPoint, EndPointB, ...)` checks
   whether the straight chord (start→end of sub-step) crosses a volume
   boundary (`PropagatorInField.cc:336-338`).
5. **Intersection refinement** — if the chord intersects,
   `G4MultiLevelLocator::EstimateIntersectionPoint` uses
   `ApproxCurvePointS` (Brent / inverse-parabolic) or `ApproxCurvePointV`
   (linear) to find the exact true-path intersection point
   (`PropagatorInField.cc:355-359`).

`G4ChordFinder::AdvanceChordLimited` asks its `fIntgrDriver` to advance the
state and enforce the chord condition (`G4ChordFinder.hh:100-114`). The driver
calls the stepper's Runge-Kutta evaluations internally.

### Field manager resolution: global vs. local

`FindAndSetFieldManager` at `PropagatorInField.cc:697-738`:

```cpp
currentFieldMgr = fDetectorFieldMgr;   // global default
if( pCurrentPhysicalVolume != nullptr )
{
  G4LogicalVolume* pLogicalVol = pCurrentPhysicalVolume->GetLogicalVolume();
  if( pLogicalVol != nullptr )
  {
    // Region-level field manager checked first
    G4Region* pRegion = pLogicalVol->GetRegion();
    if( pRegion != nullptr )
    {
      pRegionFieldMgr = pRegion->GetFieldManager();
      if( pRegionFieldMgr != nullptr )
        currentFieldMgr = pRegionFieldMgr;   // region overrides global
    }

    // Logical-volume-level field manager overrides everything
    localFieldMgr = pLogicalVol->GetFieldManager();
    if( localFieldMgr != nullptr )
      currentFieldMgr = localFieldMgr;       // LV overrides region
  }
}
```

Priority order (lowest to highest): global world field manager → region field
manager → logical-volume field manager. The local LV manager wins if it
exists, regardless of any region setting.

### Epsilon: what it bounds and the defaults

`epsilon` is the **relative accuracy** of each Runge-Kutta integration step
(i.e., acceptable fractional error in the momentum components).

Defaults from `source/geometry/magneticfield/include/G4FieldParameters.hh`:

```cpp
// G4FieldParameters.hh:150-158
constexpr G4double kDeltaChord        = 0.25 * CLHEP::mm;
constexpr G4double kDeltaOneStep      = 0.01 * CLHEP::mm;
constexpr G4double kDeltaIntersection = 0.001 * CLHEP::mm;
constexpr G4double kMinimumEpsilonStep = 5.0e-5;
constexpr G4double kMaximumEpsilonStep = 0.001;
```

`G4PropagatorInField::ComputeStep` computes:

```cpp
// PropagatorInField.cc:202-207
epsilon = fCurrentFieldMgr->GetDeltaOneStep() / CurrentProposedStepLength;
G4double epsilonMin = fCurrentFieldMgr->GetMinimumEpsilonStep();  // 5e-5
G4double epsilonMax = fCurrentFieldMgr->GetMaximumEpsilonStep();  // 1e-3
if( epsilon < epsilonMin ) epsilon = epsilonMin;
if( epsilon > epsilonMax ) epsilon = epsilonMax;
```

For a 1 m proposed step: raw epsilon = 0.01 mm / 1000 mm = 1e-5, which is
below `epsilonMin`, so it is clamped to 5e-5. For a 0.1 mm step: raw =
0.01/0.1 = 0.1, clamped to 1e-3. The clamp ensures integration never exceeds
0.1% relative error per step regardless of step length.

`fMaxAcceptedEpsilon` is a separate guard at the field manager constructor
level (set to 0.01 at `G4FieldManager.cc:41`), with a comment noting the
recommended value is 0.001 or below because DormandPrince(7)45 underestimates
local error at large epsilon values.

### The chord concept and the bisection algorithm

A "chord" is the **straight line segment** connecting the start and end
positions of a tentative Runge-Kutta integration step. A curved trajectory
in a magnetic field deviates from its chord by some perpendicular distance
("sagitta"). The chord is useful because straight lines can be intersected with
geometry volumes efficiently.

`G4ChordFinder` controls the maximum allowed miss-distance: `fDeltaChord =
fDefaultDeltaChord = 0.25 mm` (`G4ChordFinder.hh:191`,
`G4FieldParameters.hh:150`). `AdvanceChordLimited` asks the driver to integrate
a trial step; if the chord miss exceeds `fDeltaChord`, the step is halved and
retried.

When the chord crosses a boundary, the intersection locator refines the
crossing point using `ApproxCurvePointS` (`G4ChordFinder.cc:428-533`), which
applies inverse-parabolic interpolation (Brent-style) between three already-
evaluated curve points to estimate the arc-length parameter at the boundary
surface. If the parabolic fails (degenerate case), it falls back to
`ApproxCurvePointV` (`G4ChordFinder.cc:538-642`), which linearly interpolates
`|AE|/|AB|` along the curve length.

### Default integrator

When `G4FieldManager::CreateChordFinder(G4MagneticField*)` is called
(`G4FieldManager.cc:162-179`), it calls:

```cpp
fChordFinder = new G4ChordFinder( detectorMagField );
```

This invokes `G4ChordFinder`'s second constructor with no stepper argument and
no `stepperDriverId`, which falls into the `else` branch
(`G4ChordFinder.cc:329-360`). The default stepper is:

```cpp
using NewFsalStepperType = G4DormandPrince745;
auto fsalStepper = new NewFsalStepperType(pEquation);
fIntgrDriver = new G4FSALIntegrationDriver<NewFsalStepperType>(
    stepMinimum, fsalStepper, fsalStepper->GetNumberOfVariables());
```

`G4DormandPrince745` is a 5th-order / 4th-order embedded Runge-Kutta method
(Dormand-Prince, also known as DOPRI5 or DoPri5), 7-stage
(`G4ChordFinder.cc:126-133`). The driver type is `G4FSALIntegrationDriver`:
First-Same-As-Last, meaning the last function evaluation of one step is reused
as the first of the next, saving one field query per step.

`CreateChordFinder(field)` is a convenience wrapper that allocates all
intermediate objects (equation, stepper, driver) in one call and registers
ownership with the field manager (`fAllocatedChordFinder = true`,
`G4FieldManager.cc:173`). A manually constructed `G4ChordFinder` handed to
`SetChordFinder(cf)` bypasses this ownership: the field manager will not delete
it on destruction unless `fAllocatedChordFinder` is true.

## Gotchas / edge cases

1. **Field manager is re-resolved every step, not every track.** The flag
   `fSetFieldMgr` is reset to `false` at the end of each `ComputeStep` call
   (`PropagatorInField.cc:182`). A per-volume field manager change mid-track
   is picked up immediately on the next step. This is correct behaviour but
   means profiling costs of `FindAndSetFieldManager` scale with step count,
   not track count.

2. **`fMaxAcceptedEpsilon = 0.01` is a legacy value.** The source comment at
   `G4FieldManager.cc:42-48` explicitly warns that DOPRI5 underestimates
   local error for epsilon > 0.001. The hard limit allows setting `epsilonMax`
   up to 0.01, but doing so gives poor accuracy. The effective safe bound is
   0.001, which is also `kMaximumEpsilonStep`.

3. **`fDeltaChord` can grow during a step.** If the inner loop count exceeds
   `fIncreaseChordDistanceThreshold` and `canRelaxDeltaChord` is true, the
   chord is doubled each threshold iterations
   (`PropagatorInField.cc:308-316`). This is the looping-track recovery
   mechanism. It means a track that spirals tightly may eventually use a much
   larger chord than `kDeltaChord`, and volume crossings may be missed in
   extreme cases.

4. **`CreateChordFinder` deletes the old chord finder.** If called a second
   time on a field manager that already has `fAllocatedChordFinder = true`,
   the old chord finder is deleted (`G4FieldManager.cc:164-167`). Calling it
   twice on the same manager is safe; calling it after manually setting a
   chord finder with `SetChordFinder` would delete user-owned memory if the
   field manager was previously given a `fAllocatedChordFinder = true` finder.

5. **Equation of motion owns the field pointer, not the field manager.** When
   `G4ChordFinder(G4MagneticField*, ...)` is called, `G4Mag_UsualEqRhs` is
   constructed with a pointer to the field (`G4ChordFinder.cc:165`). The field
   object must outlive both the equation and the chord finder. `G4FieldManager`
   does not enforce this; the user is responsible.
