---
type: concept
domain: geant4-code
g4_version: 11.4.0
status: stable
related: ["[[user-actions]]", "[[scoring-styles]]", "[[sensitive-detectors-via-gdml-aux]]"]
---

# analysis-manager

`G4AnalysisManager` is Geant4's built-in histogram and ntuple service.
It abstracts the output format (ROOT, CSV, HDF5, XML) behind a single
API so the same code can write different file types without change.

## What it is

```cpp
#include "G4AnalysisManager.hh"

auto am = G4AnalysisManager::Instance();
am->SetVerboseLevel(1);
am->SetNtupleMerging(true);    // MT: merge worker ntuples on master

// In RunAction::BeginOfRunAction:
am->OpenFile("output");        // extension determined by format

// Book histograms (once, usually in RunAction constructor):
am->CreateH1("edep", "Energy deposit", 100, 0., 1000.);  // returns id

// Book ntuple:
int nid = am->CreateNtuple("Hits", "Step hits");
am->CreateNtupleDColumn(nid, "edep");
am->CreateNtupleDColumn(nid, "x");
am->FinishNtuple(nid);

// Fill per-step (in EventAction or SteppingAction):
am->FillH1(0, edep_MeV);
am->FillNtupleDColumn(nid, 0, edep);
am->FillNtupleDColumn(nid, 1, x);
am->AddNtupleRow(nid);

// In RunAction::EndOfRunAction:
am->Write();
am->CloseFile();
```

## Output format selection

Set before `OpenFile`:

```cpp
am->SetDefaultFileType("root");   // or "csv", "hdf5", "xml"
```

Or override per file via the filename extension: `output.csv`,
`output.root`.

## What B3, B4, AnaEx01 each show

| Example | What it adds |
|---------|-------------|
| B3 | First use of `G4AnalysisManager`; hooks `G4TScoreNtupleWriter` to a multi-functional detector — zero fill calls needed |
| B4 (all variants) | Shows the same scoring problem solved four ways; B4a uses `G4AnalysisManager` as the standard path |
| AnaEx01 | The reference implementation: histogram booking, filling, writing in `RunAction`; ntuple filling in `EventAction` |
| AnaEx02 | The bypass: direct ROOT `TFile`/`TTree` access without `G4AnalysisManager`; shows what the manager abstracts away |

## MT merging

With `SetNtupleMerging(true)`, workers write to in-memory trees and
the master merges at run end. Without it, each worker writes its own
file (`output_t0.root`, `output_t1.root`, …). The merged path is
recommended; it requires ROOT output (not all formats support it).
