---
type: source
domain: physics
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-hadronic-hadr01


Hadr01 is the canonical hadronic-shower benchmark in the extended examples: a cylindrical target divided into longitudinal slices scores `dE/dz` profiles, a surrounding "Check" shell scores escapers, and `G4UserStackingAction` selectively counts or kills secondary species before they are tracked. A battery of `.in` macros (one per beam/target combination) makes it a regression suite for hadronic physics lists. Reading Hadr01 after Hadr00 completes the picture: Hadr00 computes cross sections, Hadr01 shows what those cross sections produce inside matter.

## Key concepts demonstrated
- `longitudinal-calorimetry` — scoring `dE/dz` via `G4PVReplica` slices; the reference pattern for any longitudinal shower profile study
- `multiple-sensitive-detectors` — two distinct SDs in one geometry, each writing its own histogram set; proves SDs are questions, not geometry features
- `stacking-action-secondary-control` — `G4UserStackingAction` kills or counts secondaries at stack-push time before tracking, enabling "primary-only" diagnostics without rerunning
- `physics-list-augmentation` — adding neutrino or charge-exchange processes on top of a reference list via the factory pattern
- `escaper-scoring` — a shell volume in world material catches particles leaving the target; distinct from energy-deposition SDs
- `per-target-macro-naming` — `.in` files named `<beam>_<target>.in` so results are reproducible by name
