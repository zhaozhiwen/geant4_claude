---
type: concept
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[init-quartet]]", "[[sensitive-detectors-via-gdml-aux]]"]
---

# physics-list-factory

`G4PhysListFactory` is Geant4's built-in registry for named reference
physics lists. It lets you pick a physics list by string at runtime —
no recompile per experiment, no hard-coded class name in main.

## What it is

```cpp
#include "G4PhysListFactory.hh"

G4PhysListFactory factory;
G4VModularPhysicsList* pl = factory.GetReferencePhysList("FTFP_BERT");
// pl is null if the name is unknown — check it
runManager->SetUserInitialization(pl);
```

The factory knows every Geant4 reference list by name: `FTFP_BERT`,
`QGSP_BIC_HP`, `Shielding`, `QGSP_BIC_AllHP`, etc. It also understands
additive suffixes:

| Suffix | Adds |
|--------|------|
| `_HP`  | high-precision neutron transport |
| `_EMV`, `_EMX`, `_EMY`, `_EMZ` | alternate EM constructor options |
| `+OPTICAL` | `G4OpticalPhysics` |

The DSL in `extensibleFactory` extends this further with a `+`/`_`
composition syntax (see [[g4-example-physicslists-extensiblefactory]]).

## Common reference lists and when to use them

| List | Use case |
|------|----------|
| `FTFP_BERT` | Default for most HEP; EM + FTFP hadronic above a few GeV, Bertini cascade below. |
| `QGSP_BIC_HP` | Shielding, neutron-heavy setups; HP (data-driven) below 20 MeV. |
| `Shielding` | Radiation protection: HP neutrons + decay + activation. |
| `FTFP_BERT_PEN` | Penelope EM (lower energy, medical dosimetry). |
| `QBBC` | Faster hadronic, test beam studies where CPU matters. |

For a first simulation of any kind, start with `FTFP_BERT`. Switch only
when there's a specific physics reason (low-energy neutrons, optical
photons, medical dosimetry).

## Adding optional physics constructors

Physics constructors can be bolted onto any modular physics list after
instantiation:

```cpp
auto pl = factory.GetReferencePhysList("FTFP_BERT");
pl->RegisterPhysics(new G4OpticalPhysics());     // Cherenkov, scintillation
pl->RegisterPhysics(new G4RadioactiveDecayPhysics()); // isotope decay
```

For optical photons you also need to set material properties
(`G4MaterialPropertiesTable`) before `/run/initialize`.

## Selecting via environment variable

Most advanced examples check `PHYSLIST` at startup:

```cpp
G4String listName = "FTFP_BERT";
if (getenv("PHYSLIST")) listName = getenv("PHYSLIST");
auto pl = factory.GetReferencePhysList(listName);
```

This is the standard pattern for detector-physics decoupling —
geometry and macro are fixed, physics is swappable without recompile.

## Caution: some settings must precede BuildPhysicsTable

A few physics-defining values (e.g., the magnetic monopole mass
in `exoticphysics-monopole`) must be set **after** the physics list is
registered but **before** `runManager->Initialize()` (which calls
`BuildPhysicsTable`). They cannot live in macros. If a physics
parameter behaves unexpectedly from a macro, check whether it falls
in this category.
