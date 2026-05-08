---
type: source
domain: physics
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-exoticphysics-monopole


The monopole example shows the minimum recipe for adding a completely new particle to Geant4: a `G4ParticleDefinition` (mass and charge set at startup via command-line args, not a macro), a `G4VPhysicsConstructor` registering its custom ionization process on top of `FTFP_BERT`, and a `G4MonopoleFieldSetup` that swaps the equation of motion for the dual-charge Lorentz force. The dE/dx and range histograms for the monopole vs. a proton illustrate that the full transport machinery handles novel particles once these three pieces compose. It is also the only example in this batch that demonstrates swapping the equation of motion for a non-standard particle in a magnetic field.

## Key concepts demonstrated
- `custom-particle-definition` — `G4ParticleDefinition` with both electric and magnetic charge; mass/charge are physics-defining and must be set before `BuildPhysicsTable`, hence CLI args not macros
- `physics-constructor-extension` — `G4VPhysicsConstructor` bolted onto a reference list; the clean way to add new physics without forking the reference list
- `custom-equation-of-motion` — `G4MonopoleEquation` replaces `G4Mag_UsualEqRhs`; mandatory for any exotic-particle field simulation
- `step-limit-per-volume` — `G4UserLimits::MaxAllowedStep` on the active LV ensures fine enough sampling for long-mean-free-path particles
- `process-dump-sanity-check` — `/particle/process/dump` after init confirms the expected processes are registered; catches silent "forgot the constructor" bugs
