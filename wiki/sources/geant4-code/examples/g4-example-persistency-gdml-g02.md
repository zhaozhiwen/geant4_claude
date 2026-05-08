---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - gdml-parser
  - gdml-round-trip
  - geometry-construction
  - assembly-volume
---

# g4-example-persistency-gdml-g02


The GDML writer torture test. Builds a non-trivial geometry entirely in C++ — including `G4AssemblyVolume`, parameterised volumes, and reflected solids — then serializes it to GDML via `G4GDMLParser::Write` and reads it back to verify round-trip fidelity. This is the example that proves "yes, if you have a legacy C++ detector you can dump it to GDML once and treat the file as the new source of truth." It also demonstrates modular GDML output (splitting into a top file plus per-subdetector includes) and, as a side note, STEP-Tools CAD file loading.

## Key concepts demonstrated

- `gdml-round-trip` — `G4GDMLParser::Write(filename, worldPV)` is the authoritative serializer; output is self-contained GDML loadable by any G01-style reader
- `assembly-volume` — `G4AssemblyVolume` is expanded into individual placements on write; the GDML loses the assembly abstraction, which is worth knowing before editing the output
- `geometry-construction` — C++-to-GDML migration path: instantiate any `DetectorConstruction`, call `Write`, drop the resulting file into a GDML-first workflow
- `gdml-parser` — writer options control volume naming and file splitting; set them before `Write` to avoid `Volume_1` / `Volume_2` anonymous names
- `reflection-factory` — `G4ReflectionFactory` placements round-trip in 11.4 but should be verified; negative-determinant frames are a known fragile point
