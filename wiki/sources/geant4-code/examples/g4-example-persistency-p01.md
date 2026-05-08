---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - root-persistency
  - sensitive-detector
  - hits-collection
  - root-dictionary
---

# g4-example-persistency-p01


How to stream full hit objects (not flat scalars) into a ROOT TTree using ROOT Reflex dictionaries. The sim fills a `G4VHitsCollection` of custom `ExP01TrackerHit` objects and writes them as a TBranch of C++ objects, preserving the natural Geant4 hit hierarchy including nested vectors and inheritance. A companion `readHits` binary proves the file is portable without the simulation binary. The critical build-time requirement is `REFLEX_GENERATE_DICTIONARY` — a CMake step that compiles a ROOT dictionary for the hit class so ROOT knows its memory layout at I/O time. Without that step, TBranch-of-objects is impossible.

## Key concepts demonstrated

- `root-dictionary` — `genreflex` + a `selection.xml` file compiles a dictionary lib at build time; this is required to TFile-stream any non-trivial C++ class, and a version mismatch with ROOT produces a confusing build failure
- `hits-collection` — `G4VHitsCollection` is the canonical container an SD fills per event; `EndOfEventAction` walks it to copy hits into the persistent vector
- `root-persistency` — route 2 (TBranch of objects) vs. route 1 (flat scalar branches); objects preserve structure but cost a dictionary build and a ROOT dependency at read time, making `uproot`-only analysis harder
- `separate-reader-binary` — a `readHits` exe that round-trips the file without the simulation binary is the cheapest regression test for a TTree schema change
