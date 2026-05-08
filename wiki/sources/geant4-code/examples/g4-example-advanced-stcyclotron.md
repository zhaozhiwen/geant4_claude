---
type: source
domain: detector-sim
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-advanced-stcyclotron


A solid-target cyclotron for medical-isotope production: a proton beam hits a thin target through a foil and helium-cooled gap, and the example tracks which radioisotopes are produced, how many of each, and computes activity at end of beam including decay chains — expressed in the units a radiopharmaceutical chemist actually wants (MBq, half-lives). It is the canonical Geant4 activation/radioactive-decay example, and it invents a clean bookkeeping convention to bridge G4's event model to wall-clock beam time: one event = 10⁻¹¹ s of irradiation, with proton multiplicity derived from beam current.

## Key concepts demonstrated
- `radioactive-decay-physics` — `G4RadioactiveDecayPhysics` + `G4DecayPhysics` registered alongside hadronic builders; required additions to FTFP_BERT for any activation calculation
- `isotope-inventory-scoring` — per-radioisotope bookkeeping (count, λ, half-life, parent process, activity) assembled from track lifecycle data in `RunAction`/`EventAction`; Geant4 has no built-in inventory output
- `event-to-beam-time-convention` — one G4 event = fixed irradiation interval (10⁻¹¹ s); proton multiplicity = `beamCurrent × timePerEvent / charge`; translates "how many events?" into "how much beam time?"
- `enriched-material-from-isotopes` — `G4Isotope` + `G4Element` + `G4Material` API builds exact isotopic compositions (e.g., 60% enriched ⁶⁴Ni); the same data flow works in GDML via `<isotope>` + `<element>` + `<material>` tags
- `g4particlehpdata-requirement` — TENDL neutron-induced cross-section dataset required for accurate (p,xn) and (p,α) reactions below 200 MeV; must be set via env var or results are silently wrong
