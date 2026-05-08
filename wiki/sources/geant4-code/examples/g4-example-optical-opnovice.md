---
type: source
domain: physics
g4_version: 11.4.0
status: stable
related:
  - optical-physics
  - material-properties-table
  - optical-surface
  - physics-list-factory
---

# g4-example-optical-opnovice


The minimum viable demonstration of optical photon physics: Cherenkov production, scintillation, `G4OpAbsorption`, `G4OpRayleigh`, and boundary handling at dielectric/dielectric and dielectric/metal interfaces. A water tank in air; 500 keV positrons; optical photons tracked until absorbed or escaped. The example shows that three separate ingredients must all be present for optical simulation to work: `G4OpticalPhysics` registered in the physics list, a `G4MaterialPropertiesTable` with `RINDEX` (and optionally `SCINTILLATIONYIELD`, `ABSLENGTH`) attached to every relevant material, and `G4OpticalSurface` + `G4LogicalSurface` for any interface you want to model explicitly. Missing any one silently produces no optical photons.

## Key concepts demonstrated

- `optical-physics` — `G4OpticalPhysics` is purely additive; `FTFP_BERT->RegisterPhysics(new G4OpticalPhysics())` is the correct idiom; never use it *instead of* a base list
- `material-properties-table` — `G4MaterialPropertiesTable` keyed on photon energy (eV range, not wavelength); `RINDEX` enables Cherenkov, `SCINTILLATIONYIELD` enables scintillation, `ABSLENGTH` prevents photons living forever; missing entries silently suppress the corresponding process
- `optical-surface` — `G4OpticalSurface` + `G4LogicalSurface` models boundary reflection/refraction/absorption; `G4OpticalParametersMessenger` command `/process/optical/cerenkov/setMaxPhotons` is essential CPU control in dense media
- `gdml-optical-properties` — GDML `<matrix>` and material `<property>` tags encode the `G4MaterialPropertiesTable` inside the geometry file; the plugin is GDML-first so this is the natural entry point for optical sims
- `optical-photon-pdg` — `opticalphoton` is a distinct particle from `gamma`; PDG code is internally `-22` in Geant4 with no standard external PDG value; output trees need an explicit sentinel to distinguish them
