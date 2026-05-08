---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-biasing-gb01


GB01 demonstrates the modern generic biasing framework: a `G4VBiasingOperator` attached to a logical volume intercepts each step and returns a `G4VBiasingOperation` (or `nullptr`) that multiplies the interaction cross section of a named particle by a user-chosen factor. `G4GenericBiasingPhysics::Bias("gamma")` wraps every process attached to that particle in one call; the operator's per-step logic decides the factor. Track weights are updated automatically. Compared to B01's geometry-boundary splitting, this is the more general framework — newer, maintained, and the basis for all modern Geant4 biasing. GB01 also resolves the operator-composition question left open in B01: one operator per LV, one LV at a time, last-attached wins.

## Key concepts demonstrated
- `generic-biasing-operator` — `G4VBiasingOperator` on an LV answers three per-step queries (occurrence, final-state, non-physics); returning `nullptr` means no biasing that step
- `cross-section-modification` — `G4BOptnChangeCrossSection` is the prebuilt occurrence-biasing operation; changing the final state requires a different subclass
- `generic-biasing-physics` — `G4GenericBiasingPhysics::Bias("particle")` wraps all processes for that particle in one line; the entry point for any modern biasing
- `track-weight` — same `track->GetWeight()` channel as B01; biasing is silently bias-introducing in any scorer that ignores it
- `lv-scoped-biasing` — operator is per-LV, not per-region or global; attach to each LV that should be biased
