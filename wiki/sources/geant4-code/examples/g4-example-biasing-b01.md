---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-biasing-b01


B01 is the canonical geometry-based importance sampling example: an 18-slab concrete cylinder with integer importance values per slab drives track splitting (forward crossings) and Russian roulette (backward crossings) so that deep slabs accumulate statistically meaningful neutron tallies without the exponential CPU cost of an analog run. An alternate `argv=1` mode shows weight-window biasing producing the same answer through a different algorithm, making B01 a side-by-side tutorial in variance reduction fundamentals. The multi-functional detector with primitive scorers (`G4PSNofCollision`) demonstrates clean "count N things per cell" scoring without a custom SD class.

## Key concepts demonstrated
- `importance-sampling` — `G4IStore` maps per-`G4GeometryCell` integer importances; `G4GeometrySampler` + `G4ImportanceBiasing` constructor wire the kernel splitting/rouletting
- `weight-window-biasing` — `G4WeightWindowBiasing` produces the equivalent result with energy-dependent upper/lower weight windows; more knobs than importance sampling
- `track-weight` — `track->GetWeight()` is the universal biasing output; every scorer in a biased sim must multiply by it or the result is silently wrong
- `multi-functional-detector` — `G4MultiFunctionalDetector` with primitive scorers is the right tool when the question is "how many of X per cell" with no per-step detail needed
- `biasing-as-physics-constructor` — registering biasing as a `G4VPhysicsConstructor` on the modular list keeps biasing MT-safe and co-located with physics
