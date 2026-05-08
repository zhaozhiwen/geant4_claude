---
type: concept
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[init-quartet]]", "[[physics-list-factory]]", "[[g4-src-sd-dispatch]]", "[[g4-src-gdml-auxiliary-walk]]"]
---

# sensitive-detectors-via-gdml-aux

Geant4 sensitive detectors (SDs) record what particles do inside a volume. Normally you wire SDs in C++ by overriding `G4VUserDetectorConstruction::ConstructSDandField()`. An alternative is to keep the wiring in the GDML file via `<auxiliary>` tags and have a small loader walk the volumes at construction time. This page describes the Geant4-side mechanism; the canonical reference is `extended/persistency/gdml/G04`.

## What the tag looks like

```xml
<volume name="det_lv">
  <materialref ref="G4_Pb"/>
  <solidref ref="det_box"/>
  <auxiliary auxtype="SensDet" auxvalue="MySD"/>
</volume>
```

The `auxtype` and `auxvalue` strings are arbitrary — Geant4 stores them without interpretation (see [[g4-src-gdml-auxiliary-walk]] for the parser details). Whatever code reads them defines their meaning. There is no Geant4-side schema.

## The walk algorithm

```cpp
auto store = G4LogicalVolumeStore::GetInstance();
for (auto* lv : *store) {
    auto aux = parser.GetVolumeAuxiliaryInformation(lv);
    for (const auto& a : aux) {
        if (a.type == "SensDet") {                 // your chosen vocabulary
            auto* sd = makeSDForVolume(lv, a.value);
            G4SDManager::GetSDMpointer()->AddNewDetector(sd);
            lv->SetSensitiveDetector(sd);
        }
    }
}
```

This runs from `ConstructSDandField()` so the SD instances are created per worker thread in MT mode. Calling `G4SDManager::AddNewDetector` registers the SD globally; `SetSensitiveDetector` attaches it to the logical volume.

## The canonical G04 pattern

`extended/persistency/gdml/G04` is the reference implementation in the Geant4 distribution: it uses `<auxiliary auxtype="SensDet" auxvalue="VolumeName"/>` tags and a small `ReadGDML.cc` loader to attach a project-specific SD class. See [[g4-example-persistency-gdml-g04]] for the full pattern analysis.

## SD dispatch timing

SD dispatch happens at `G4SteppingManager.cc:247`, **before** `UserSteppingAction` fires. The full per-step call order is:

```
AlongStep DoIt → PostStep DoIt → fSensitive->Hit(fStep) → UserSteppingAction
```

When `ProcessHits` executes, all DoIt phases are complete: `GetTotalEnergyDeposit()` is final, secondaries are already in the secondary vector, and the track has been updated. The `PreStepPoint` reflects where the particle entered the sensitive volume at the start of this step; the `PostStepPoint` reflects where it ended up. The SD lookup uses the `PreStepPoint` physical volume — so for a boundary-crossing step, the SD that fires belongs to the volume the particle *was in*, not where it arrived.

See [[g4-src-sd-dispatch]] and [[g4-src-step-lifecycle]].

## Limitations of the GDML-auxiliary-tag mechanism

- **Strings only.** `auxtype` and `auxvalue` are plain strings. Anything richer (lists, numbers, references) requires your own parser.
- **Nested `<auxiliary>` children are silently ignored** by the typical walk. The GDML parser's `G4GDMLAuxStructType` exposes a flat `auxList` plus a pointer to nested children, but a straightforward walk that only iterates the flat list never inspects the nested pointer. Any `<auxiliary>` tag nested inside another is invisible. See [[g4-src-gdml-auxiliary-walk]].
- **Schema is convention, not enforced.** Two projects using different `auxtype` vocabularies in the same GDML will collide silently. Pick a small, project-scoped vocabulary and document it.
- **Per-step semantics.** SDs called this way receive every `G4Step` end-point in the sensitive volume — no automatic aggregation. Per-hit, per-track, or per-event aggregation is the SD's responsibility.
