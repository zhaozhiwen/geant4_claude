---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - placement-rotation
  - geometry-construction
  - reflection-factory
  - detector-messenger
---

# g4-example-geometry-transforms


The definitive tutorial on Geant4's five placement-rotation conventions, which are off-by-an-inverse from each other in ways that cause half of all "my detector is rotated wrong" bugs. Two trapezoids in a tube are placed identically via: `G4Transform3D` (active, explicit), raw `G4RotationMatrix*` (passive/inverse), axial `rotateX/Y/Z` chaining, Euler-angle constructor, and `G4ReflectionFactory` for mirror flips. All five produce the same physical result; the example proves it by making the method runtime-switchable via a `DetectorMessenger`. The lesson is concrete: always use `G4Transform3D` (active rotation convention) in new code, and always go through `G4ReflectionFactory` for negative-determinant transforms.

## Key concepts demonstrated

- `placement-rotation` — `G4RotationMatrix*` passed to `G4PVPlacement` is interpreted as the passive/inverse rotation; `G4Transform3D` is active and explicit; mixing them is the source of most rotation bugs
- `reflection-factory` — `G4ReflectionFactory::Place()` is required for mirror placements; bypassing it with a plain `G4PVPlacement` of a negative-determinant transform can silently break navigation for parameterisations and assemblies
- `detector-messenger` — the runtime-switchable construction pattern (a `G4UImessenger` driving an enum) is the right way to A/B compare geometries without rebuilding the binary
- `gdml-rotations` — in GDML the equivalent danger is forgetting `unit="deg"` (default is `rad`) and expressing mirror imaging as a `<scale x="-1"/>` rather than a 180° rotation
