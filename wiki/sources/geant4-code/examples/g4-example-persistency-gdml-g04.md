---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - auxiliary-tags
  - sensitive-detector
  - gdml-parser
  - geometry-construction
---

# g4-example-persistency-gdml-g04


The exact pattern the plugin's generic main uses: wiring a sensitive detector to a GDML-loaded volume via `<auxiliary>` tags. A single GDML file declares a box with `<auxiliary auxtype="SensDet" auxvalue="veloSD"/>`, and `ConstructSDandField()` walks all logical volumes, pulls each volume's aux list via `GetVolumeAuxiliaryInformation`, matches on `auxtype == "SensDet"`, and registers the SD by name. That is the complete integration of GDML metadata with Geant4's SD machinery — about 15 lines of C++. G04 is also notable for demonstrating GDML `<variable>` substitution in aux values and nested `<auxiliary>` tags for structured metadata.

## Key concepts demonstrated

- `auxiliary-tags` — `GetVolumeAuxiliaryInformation(lv)` returns a vector of `{type, value, unit, nested list}`; string equality on `.type` is the only match mechanism, so a typo silently skips the SD attachment
- `sensitive-detector` — the aux→SD walk in `ConstructSDandField` is called per worker thread in MT mode; SDs are thread-local by design, but global resources (files, queues) need a one-time init guard
- `gdml-parser` — aux tags are on logical volumes only; two physvols sharing an LV cannot have different SDs via aux tags alone — clone the LV instead
- `gdml-variable-substitution` — `<variable name="veloSD" value="4"/>` used as `auxvalue="veloSD"` lets one GDML file describe N detectors with a name/index map
