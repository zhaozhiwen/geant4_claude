---
type: source
domain: physics
g4_version: 11.4.0
status: stable
related:
  - em-physics-builder
  - em-calculator
  - multiple-scattering
  - range-cut
---

# g4-example-electromagnetic-testem5


The thin-target EM benchmark: one rectangular absorber in a vacuum world, beam normal to the front face, score transmission, reflection, and energy/angular distributions. The example ships ~20 macros named after canonical published experiments (Hanson, Bichsel, Gottschalk, Acosta, Shen, …), each pointing at a reference dataset and a ROOT plotting macro so you can compare Geant4 physics builders against measured data. It is the definitive tool for "is my EM physics choice numerically correct for my energy regime?" and the reference for multiple-scattering angular distribution validation.

## Key concepts demonstrated

- `em-physics-builder` — `/testem/phys/addPhysics emstandard_opt3` swaps the EM builder between `beamOn` calls; same binary, many physics regimes; the canonical A/B testing hook
- `range-cut` — `/run/setCut 7 um` between runs; cut must be much smaller than absorber thickness or low-energy secondaries are truncated and the spectrum looks artificially narrow
- `multiple-scattering` — `/testem/stack/killSecondaries` isolates the primary's angular straggling for clean MS plots; the benchmark macros use this to match specific published distributions
- `magnetic-field` — `/testem/det/setField` must come *after* `/run/initialize`; order-dependent commands are a recurring Geant4 footgun documented explicitly in the README
- `benchmark-culture` — each `.mac` maps to an author subdirectory with experimental data; the pattern of "reproduce a known measurement before approving a physics list" is the takeaway for any real experiment
