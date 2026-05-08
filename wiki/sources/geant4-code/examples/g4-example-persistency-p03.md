---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - geometry-construction
  - replica-volume
  - text-geometry
  - gdml-parser
---

# g4-example-persistency-p03


A third geometry input route — plain-text `.txt` files parsed by `G4tgrFileReader` — and, more importantly, the canonical replica example for this note set. The colon-prefixed line syntax (`:VOLU`, `:PLACE`, `:REPL`, `:DIV`) is shorter and more hand-editable than GDML but offers no round-trip writer and no schema validation. The eight example `g4geom_*.txt` files are a concise feature catalog: simple placement, materials, booleans, reflections, replicas, divisions, linear/square parameterisations, and assemblies. The replica and division variants in `g4geom_replicas.txt` serve as the reference implementation for GDML `<replicavol>` translation.

## Key concepts demonstrated

- `replica-volume` — `:REPL name mother X 5 400. 10.` places 5 identical copies along X at pitch 400 mm; the mother solid must match exactly N × daughter dimension; one LV, O(1) memory regardless of N
- `geometry-construction` — mixed-source pattern: `ExTGDetectorConstructionWithCpp` injects C++-built daughters into a text-loaded mother for the 5% of geometry that doesn't fit any file format
- `text-geometry` — `G4tgrFileReader` reads the colon-tag format; no writer exists, no schema, typos produce at-runtime failures — the contrast with GDML's round-trippability
- `division-volume` — `:DIV` automatically divides a mother into N daughters; sibling to replicas, useful when pitch comes from mother size / N rather than an explicit width
- `parameterised-volume` — N copies whose size or material varies by copy number, midpoint between replica (identical) and full placement (free)
