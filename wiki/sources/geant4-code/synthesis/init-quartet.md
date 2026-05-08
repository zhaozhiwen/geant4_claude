---
type: concept
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[physics-list-factory]]", "[[sensitive-detectors-via-gdml-aux]]"]
---

# init-quartet

Every Geant4 program hands a `G4RunManager` exactly **four objects** at
initialization. Once you internalize this shape, reading any new
Geant4 example becomes mechanical: skim those four, and you've got the
program's spine.

## What it is

The four objects, in the order they're typically registered:

1. **`G4VUserDetectorConstruction`** — defines geometry and materials.
   Implements `Construct()` (returns the world physical volume) and
   optionally `ConstructSDandField()` (attaches sensitive detectors and
   field managers, called per worker thread in MT mode).
2. **`G4VUserPhysicsList`** (or a subclass like
   `G4VModularPhysicsList`) — defines what physics processes exist
   for which particles. In practice you don't author this; you pick a
   pre-canned reference list (`FTFP_BERT`, `QGSP_BIC_HP`, `Shielding`,
   …) or compose one via [[physics-list-factory]].
3. **`G4VUserActionInitialization`** — registers the per-worker user
   actions: a primary generator (e.g. `G4ParticleGun`,
   `G4GeneralParticleSource`, or a `G4VPrimaryGeneratorAction` reading
   a HepMC file), plus optional `G4UserRunAction`,
   `G4UserEventAction`, `G4UserStackingAction`, `G4UserTrackingAction`,
   `G4UserSteppingAction`. The kernel calls these at the named lifecycle
   points.
4. The driving macro / interactive UI session — not a class but a
   command stream. `/run/initialize`, `/gun/...`, `/run/beamOn N`,
   `/score/...`. Written in a `.mac` file (batch) or typed into the UI
   (interactive).

## Why it matters

The init quartet is the only **rigid** part of Geant4. Everything
inside each of the four is yours. Most of the variation between
examples is just a different combination of:

- which `DetectorConstruction` (hand-coded? GDML? Tessellated mesh from CAD?),
- which physics list,
- which user actions,
- which macro commands.

Recognising the quartet lets you read an unfamiliar example in five
minutes — find the `main()`, find the four registrations, then read
each in isolation.

## Variations seen across the 38 example study corpus

- B1 registers all four via concrete subclasses inline; minimal scoring
  done in `SteppingAction`.
- B5 + advanced apps add multiple SDs in `ConstructSDandField`, use
  `G4GenericMessenger` for runtime knobs, and split macros for batch
  vs interactive.
- `composite_calorimeter` and `lAr_calorimeter` use
  `G4PhysListFactory` keyed off `argv` or a `PHYSLIST` env var (see
  [[physics-list-factory]]).
- HepMC-based examples replace `G4ParticleGun` with a HepMC reader
  inside `ActionInitialization::Build()`.
- Optical examples *add* `G4OpticalPhysics` to the chosen physics list
  rather than replacing it — physics list composition.
