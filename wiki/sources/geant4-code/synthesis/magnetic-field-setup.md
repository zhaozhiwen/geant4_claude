---
type: concept
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[init-quartet]]", "mvp-boundary", "[[g4-src-field-integration]]"]
---

# magnetic-field-setup

Setting up a magnetic field in Geant4 requires wiring a field object
into the transportation manager. The `extended/field/field01` example
is the canonical pattern.

## Minimal uniform field

```cpp
// In DetectorConstruction::ConstructSDandField():
auto field = new G4UniformMagField(G4ThreeVector(0., 0., 1.*tesla));

auto fieldMgr = G4TransportationManager::GetTransportationManager()
                  ->GetFieldManager();
fieldMgr->SetDetectorField(field);
fieldMgr->CreateChordFinder(field);
```

`CreateChordFinder` creates the integrator (default: 4th-order
Runge-Kutta) with a default step accuracy. The chord finder is the
core of Geant4's propagation in a field — it finds the curved path
between step endpoints.

## Field scope

A field set on the global `FieldManager` (above) applies everywhere.
For a local field (e.g., a solenoid inside a specific volume):

```cpp
auto localFieldMgr = logicalVolume->GetFieldManager();
// or create a new one:
auto localFieldMgr = new G4FieldManager(field);
localFieldMgr->CreateChordFinder(field);
logicalVolume->SetFieldManager(localFieldMgr, true); // true = propagate to daughters
```

## Controlling step accuracy

The chord finder accuracy affects both physics correctness and
simulation speed:

```cpp
fieldMgr->SetMinimumEpdensity(1.e-3 * mm);   // tightest step
G4double minEps = 1.e-5, maxEps = 1.e-4;
fieldMgr->SetMinimumEpsilonStep(minEps);
fieldMgr->SetMaximumEpsilonStep(maxEps);
```

Looser tolerances → faster simulation; tighter → more accurate track
curvature. For spectrometer work, use tight; for calorimetry, loose
is often fine.

**Default integrator and defaults from source** (`G4FieldParameters.hh:150–158`, `G4ChordFinder.cc:329–360`):

- Default integrator: `G4DormandPrince745` (DOPRI5, 5th/4th-order embedded RK, 7-stage FSAL). Instantiated automatically by `CreateChordFinder(field)`.
- `kDeltaChord = 0.25 mm` — maximum allowed sagitta (chord miss-distance) before the sub-step is halved.
- `epsilonMin = 5e-5`, `epsilonMax = 1e-3` — bounds on the relative RK integration accuracy per step. Do not widen `epsilonMax` above 1e-3; DOPRI5 underestimates local error at larger values.

The FSAL property reuses the last function evaluation of each sub-step as the first of the next, saving one field query per sub-step.

See [[g4-src-field-integration]].

**Local field manager resolution** (`G4PropagatorInField.cc:697–738`): a field manager attached via `G4LogicalVolume::SetFieldManager` overrides the global field manager for that volume. Resolution happens once per step (not per track), so a mid-track change to a local field manager is picked up on the next step. Priority: global → region → logical-volume (LV wins).

See [[g4-src-field-integration]].

## Field map (non-uniform field)

For a non-uniform field (solenoid, dipole map from a file), subclass
`G4MagneticField` and implement `GetFieldValue()`:

```cpp
class MyFieldMap : public G4MagneticField {
public:
  void GetFieldValue(const G4double pos[4], G4double* field) const override {
    // interpolate from stored map at pos[0..2]
    field[0] = ...; field[1] = ...; field[2] = ...;
  }
};
```

## Thread safety

In MT mode, `ConstructSDandField()` is called per-worker thread. Each
worker must have its own field manager and chord finder instance.
Create them inside `ConstructSDandField()`, not in the constructor.
