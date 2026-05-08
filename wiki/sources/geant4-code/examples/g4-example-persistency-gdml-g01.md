---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - gdml-parser
  - auxiliary-tags
  - geometry-construction
  - sensitive-detector
---

# g4-example-persistency-gdml-g01


The GDML language reference by example. A `load_gdml` executable takes a GDML file, parses it via `G4GDMLParser`, and optionally writes it back out — the full read/write round-trip in three lines of integration code. The example ships ~15 GDML files that collectively cover every GDML feature: all standard solids, divisions, parameterised volumes, replicas, assemblies, scaled and tessellated solids, multi-union, optical surfaces, material catalogues with `<auxiliary>` tags, NIST material references, loops with variables and expressions. The key insight is that `G4GDMLParser` is the entire integration cost: hand it a file, get back a world physical volume, bolt everything else on as normal.

## Key concepts demonstrated

- `gdml-parser` — `G4GDMLParser::Read` + `GetWorldVolume()` is the complete replace for a hand-coded `DetectorConstruction`; three lines of code
- `auxiliary-tags` — `<auxiliary auxtype="..." auxvalue="..."/>` is the untyped integration seam for per-volume metadata (SD attachment, fields, regions); queried via `GetVolumeAuxiliaryInformation(lv)`
- `gdml-loop` — `<loop>` with `<variable>` expresses N-crystal rings or arrays without N explicit `<physvol>` entries; stays in data, not C++
- `external-material-catalogue` — `materials.xml` referenced from GDML keeps one materials file shared across many geometry files
- `gdml-round-trip` — `parser.Write(out, world)` serializes any constructed geometry back to GDML; useful for debugging and cross-tool handoff
- `geometry-construction` — separates geometry-as-data from C++ build steps; non-C++ collaborators can edit geometry without recompiling
