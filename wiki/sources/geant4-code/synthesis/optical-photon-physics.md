---
type: concept
domain: physics
g4_version: 11.4.0
status: stable
related: ["[[em-processes]]", "[[physics-list-factory]]", "[[g4-src-opticalphoton-sentinel]]"]
---

# optical-photon-physics

Optical photon transport in Geant4 models Cherenkov radiation,
scintillation, wavelength shifting, and surface boundary interactions
(reflection, refraction, absorption). It is a separate physics
subsystem from the EM standard processes.

## The three production mechanisms

### Cherenkov radiation
Charged particles travelling faster than the phase velocity of light in
a medium emit Cherenkov photons. Geant4 models this as a discrete
process (`G4Cerenkov`):

```
threshold: β > 1/n(λ)
yield: ∝ sin²θ_C dλ/λ²  (Frank-Tamm)
```

Material must have a `RINDEX` property table (refractive index vs
photon energy).

### Scintillation
Energy deposition produces scintillation photons (`G4Scintillation`).
Yield is proportional to energy deposited, modified by a
particle-specific yield factor (`SCINTILLATIONYIELD`, `RESOLUTIONSCALE`,
`FASTCOMPONENT`, `SLOWCOMPONENT`, `FASTTIMECONSTANT`, …). Material must
have these properties in `G4MaterialPropertiesTable`.

### Wavelength shifting (WLS)
`G4OpWLS` absorbs a photon and re-emits it at a longer wavelength with
a time delay. Used for scintillating fibers and wavelength-shifting
plates.

## Optical boundary processes

When a photon hits a surface between two materials, `G4OpBoundaryProcess`
handles it:

| Model | Behaviour |
|-------|-----------|
| `dielectric_dielectric` | Fresnel reflection/refraction (requires `RINDEX` on both sides) |
| `dielectric_metal` | Reflection with absorption probability (`REFLECTIVITY`) |
| `dielectric_LUT` | Look-up table for measured surface response |
| `unified` | Micro-facet model; ground/polished/backpainted via surface finish |

Surface properties are set via `G4OpticalSurface` + `G4LogicalBorderSurface`
or `G4LogicalSkinSurface`.

## Enabling optical physics

Optical photons require a dedicated physics constructor added on top of
a reference list:

```cpp
auto pl = factory.GetReferencePhysList("FTFP_BERT");
pl->RegisterPhysics(new G4OpticalPhysics());
```

Or via macro if using the extensible factory: `FTFP_BERT+OPTICAL`.

**Important:** material properties (`RINDEX`, `ABSLENGTH`,
`FASTCOMPONENT`, etc.) must be set on `G4MaterialPropertiesTable`
**before** `/run/initialize`. They cannot be set via macro after the
run is initialised.

## Optical photon PDG sentinel

Optical photons are not standard photons in PDG terms — Geant4 assigns them PDG code **−22** rather than 22. SDs that filter on `pdg == 22` will miss every optical photon hit. The correct inclusive cut for any photon-like particle is `pdg == 22 || pdg == -22`. See [[g4-src-opticalphoton-sentinel]] for the source-grounded derivation (`G4OpticalPhoton.cc:67`) and the cascade of identification rules.
