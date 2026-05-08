---
name: geant4-physics-list
description: Choosing a Geant4 physics list and tuning step/range cuts. Load when configuring a simulation that has non-default physics needs (hadronic, EM-only, low-energy, optical).
---

# geant4-physics-list

The plugin's generic main hard-codes **`FTFP_BERT`** as the constructor
default. That's the right choice for ~90% of HEP applications — fast,
well-validated, and covers EM + hadronic over a wide energy range. Most
users should not touch this.

This skill exists for the cases where the default is *wrong*.

## When to keep the default `FTFP_BERT`

- General-purpose calorimetry, tracking, or shielding studies.
- Beam energies from ~tens of MeV to TeV.
- A mix of EM and hadronic interactions.
- You don't have a specific reason to switch.

If the answer is "I don't know," it's `FTFP_BERT`.

## When to switch

| Need | Recommended list | Notes |
|------|------------------|-------|
| Heavy-ion, nuclear fragmentation | `QGSP_BIC_HP` | Binary cascade for nuclei + high-precision neutrons. |
| Low-energy neutrons (< 20 MeV), reactor / dosimetry | `*_HP` variant (`FTFP_BERT_HP`, `QGSP_BIC_HP`) | High-precision neutron data libraries; slower. |
| Radiation protection / shielding | `Shielding` | Specialized list assembled for shielding studies. |
| Pure EM (no hadronic at all, fast) | `G4EmStandardPhysics_option4` (build a custom modular list) | Use for purely electromagnetic detectors when speed matters. |
| Medical / low-energy human-tissue | `QBBC` or `Livermore` | Better low-energy electron/photon physics. |
| Optical photons (scintillation, Cherenkov) | Add `G4OpticalPhysics` to whatever base you use | Optical is *not* in any of the default lists. |

## How to switch (without recompiling the plugin)

The plugin's main currently hard-codes `FTFP_BERT`. **MVP limitation:**
you cannot swap the physics list from a macro alone. Three options:

1. **You're using the example main.** Open `src/geant4_claude_main.cc`
   (copied into your workspace by `/geant4-example`), replace the
   `FTFP_BERT` constructor with the desired list (e.g. `Shielding`,
   `QGSP_BIC_HP`), then `/geant4-build`.
2. **You have your own main.** Edit your `main.cc` to hold the physics
   list constant your app needs (or thread a CLI/env knob through), then
   `/geant4-build`.
3. **Long-term:** open an issue / PR adding a `--physics-list` flag to
   the example main so users no longer have to fork the file.

Document the choice in the workspace's `CLAUDE.md` so future runs aren't
ambiguous.

Either way, **never** silently change the physics list — record the
choice in `runs/<id>/config.json` (extend the schema with a
`physics_list` field).

## Range cuts and step limits

Range cuts control how finely Geant4 tracks low-energy secondaries.
Default is 1 mm. Set in the macro **after** `/run/initialize`:

```text
/run/setCut 0.1 mm                    # global default cut
/run/setCutForRegion DefaultRegion 0.05 mm
```

Smaller cut → more secondaries tracked → slower run but more accurate
low-energy deposition. For thin sensitive layers (silicon trackers,
thin scintillators) you typically want 0.01–0.1 mm. For bulk
calorimetry, 1 mm is fine.

Step limits constrain individual step length inside a volume. They are
applied via `G4StepLimiter` and a per-volume `<auxiliary
auxtype="StepLimit" auxvalue="0.5 mm"/>` (Geant4 11.x recognizes this
GDML aux convention with the right physics list). Use sparingly — most
users do not need step limits.

## Things to record in `config.json`

If the simulation deviates from default physics, capture it as
provenance:

- `"physics_list": "Shielding"` (or whatever was used),
- `"range_cut_mm": 0.1`,
- any region-specific cuts,
- whether `G4OpticalPhysics` was added.

This goes alongside `particle`, `energy_MeV`, `n_events` so a future
analysis can tell which physics produced the hits without rerunning.

## Quick references

- Geant4 reference physics lists guide:
  https://geant4-userdoc.web.cern.ch/UsersGuides/PhysicsListGuide/
- A short rule: anything ending in `_HP` adds the high-precision neutron
  treatment and roughly doubles run time for hadronic showers.
