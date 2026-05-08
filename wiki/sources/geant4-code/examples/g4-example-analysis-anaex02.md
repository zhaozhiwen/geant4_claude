---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-analysis-anaex02


AnaEx02 produces identical physics output to AnaEx01 (same N03 calorimeter, same four histograms and two ntuples) but via direct ROOT API calls: `new TFile`, `new TH1D`, `TTree::Branch`, `TTree::Fill`, `TFile::Write`, `TFile::Close`. Reading it alongside AnaEx01 makes the trade-off concrete: `G4AnalysisManager` buys backend portability and MT safety at the cost of a thinner API; direct ROOT buys full control (TProfile, TH2, TGraph, arbitrary branch layouts, in-run `TF1` fits) at the cost of a hard ROOT dependency and manual MT handling. The branch leaflist syntax (`"Eabs/D"`, `"a/I:b/D"`) and direct memory binding to long-lived member variables are the key idioms to absorb.

## Key concepts demonstrated
- `direct-root-ttree` — `TTree::Branch(name, &member, leaflist)` binds a pointer; mutate the member and call `Fill()`; fastest fill path with no API copy
- `branch-leaflist-syntax` — `"Eabs/D"` declares one double; `"a/I:b/D:c[10]/F"` declares int, double, and 10-float array
- `root-object-ownership` — histograms created after `new TFile` belong to that file and are freed on close; creating them before the file or deleting them manually causes double-free or silent loss
- `single-owner-histogram-manager` — all `TFile`, `TH1D`, and `TTree` pointers in one class; the only place that calls `new TFile` and `Close`
- `root-mt-caveat` — direct ROOT I/O is not thread-safe; AnaEx02 is sequential-only; `G4AnalysisManager` handles MT for free
