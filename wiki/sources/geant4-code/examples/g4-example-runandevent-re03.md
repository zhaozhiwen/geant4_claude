---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-runandevent-re03


RE03 demonstrates the second fundamental scoring strategy in Geant4: instead of attaching SDs to real volumes, activate `G4ScoringManager` and define box, cylinder, or arbitrary meshes entirely through `/score/...` macro commands. The mass geometry (a water box) is untouched; a parallel-world grid overlays it and the kernel projects each step onto mesh cells automatically. At end of run, arrays are dumped to text files. Four macros show overlapping meshes, adjacent meshes of different granularity, and a cylindrical mesh — enough to cover every typical dose-map or fluence-map use case without writing a single C++ scoring class.

## Key concepts demonstrated
- `scoring-mesh` — `G4ScoringManager` + `/score/create/boxMesh` defines a 3D binned scorer without C++; the right tool for dose maps and fluence maps
- `parallel-world-scoring` — the mesh lives in a separate world; tracking is shared via `G4ParallelWorldProcess`; mass geometry is untouched
- `primitive-scorers` — `/score/quantity/energyDeposit`, `nOfStep`, `flatSurfaceCurrent`, `cellFlux` etc. are pre-built quantities; no SD class needed
- `particle-filter` — `/score/filter/particle` restricts a scorer to one PDG; one mesh can hold multiple filtered quantities simultaneously
- `score-dump` — `/score/dumpQuantityToFile` exports arrays as text; override `G4VUserScoreWriter` for HDF5/ROOT output
