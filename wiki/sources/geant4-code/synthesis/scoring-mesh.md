---
type: concept
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[scoring-styles]]", "[[init-quartet]]"]
---

# scoring-mesh

`G4ScoringManager` provides command-based scoring meshes — axis-aligned
box grids that score physics quantities (energy deposit, dose, fluence)
over a regular spatial grid without any C++ sensitive detector code.
It's activated with a single line in `main()`.

## Activation

```cpp
// In main(), before runManager->Initialize():
G4ScoringManager::GetScoringManager();
```

That's it. Once registered, the full `/score/` UI macro interface is
available:

```
/score/create/boxMesh myMesh
/score/mesh/boxSize 10. 10. 5. cm
/score/mesh/nBin 20 20 10
/score/quantity/energyDeposit eDep
/score/quantity/doseDeposit dose
/score/close
/run/beamOn 10000
/score/dumpQuantityToFile myMesh dose dose.csv
```

## What it does

The mesh is a virtual geometry overlay — it doesn't affect particle
tracking. At each step, Geant4 maps the step end-point into the mesh
voxel and accumulates the scored quantity. Output is a 3D array in CSV
or ROOT format.

## Comparison with SD-based scoring

| Property | Scoring mesh | Custom SD |
|----------|-------------|-----------|
| Code required | Zero | C++ per detector type |
| Geometry coupling | Independent of detector geometry | Must attach to a logical volume |
| Output granularity | Regular voxel grid | Per-hit, arbitrary |
| Multi-run persistence | Via dump command | Via TTree write |
| Format | CSV, ROOT | Anything (TTree, HDF5, …) |

## Limitations

- Mesh must be axis-aligned boxes. Cylindrical or spherical meshes
  are possible but require additional setup.
- Mesh voxels are not physical volumes — you can't score optical
  photons or apply volume-specific cuts this way.
- Output is separate from the `Hits` TTree; post-analysis must combine
  them if both are needed.
