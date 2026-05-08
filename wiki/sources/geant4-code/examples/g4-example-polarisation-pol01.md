---
type: source
domain: physics
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-polarisation-pol01


Pol01 demonstrates spin-polarized EM physics: a polarized electron or photon beam hits a magnetized iron block, and the simulation tracks Stokes parameters and spin vectors through polarized Compton, bremsstrahlung, pair production, and annihilation models. Switching between `"standard"` (unpolarized) and `"polarized"` physics builders via a single macro command lets the user measure asymmetries and compare to analytic predictions (Klein-Nishina with polarization, etc.). This is the reference example for polarimetry experiments and any beam-line simulation that cares about spin transport.

## Key concepts demonstrated
- `polarized-em-physics` — `G4PolarizedComptonModel` and siblings compute spin-dependent cross sections and assign final-state polarizations; absent from all reference lists by default
- `volume-polarization` — `G4PolarizationManager` assigns a spin vector to a logical volume by name, representing a magnetized analyzer material
- `primary-polarization` — `/gun/polarization` sets the beam Stokes/spin vector; defaults silently to zero if omitted
- `histogram-on-demand` — histograms are defined in C++ but binning is configured by macro `/analysis/h1/set`, letting one binary serve multiple studies
- `physics-list-swap-by-macro` — `/testem/phys/addPhysics polarized` replaces the EM module at run time, same UI lever seen in TestEm examples
