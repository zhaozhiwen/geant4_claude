---
type: source
domain: detector-sim
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-advanced-hgcal-testbeam


A faithful Geant4 model of the CMS HGCal October-2018 test beam: a silicon-pad ECAL/HCAL front section followed by an analogue HCAL with SiPM-on-tile readout, three selectable configurations, and configurable step size (default 30 µm) in silicon. The defining feature is that its output TTree is already at the readout level — `EndOfEventAction` digitizes raw step hits into per-pixel records (summed Edep, TOA, TOA-of-last-deposit) before writing. This example also demonstrates ROOT-file primary injection, three-tier physics list selection, and clean per-subsystem messenger discipline.

## Key concepts demonstrated
- `in-simulation-digitization` — `EndOfEventAction` collapses per-step Edep into per-fired-pixel records with timing; reduces output size by 100–1000× versus raw steps and produces detector-level data directly
- `hit-time-gating` — `/HGCalTestbeam/hits/timeCut <ns>` drops late deposits, modeling the readout window; real detectors do not see out-of-time energy
- `toa-threshold` — time-of-arrival is "first time integrated Edep crosses threshold," not first-hit time, correctly modeling leading-edge discrimination
- `root-file-primaries` — `/HGCalTestbeam/generator/fReadInputFile true` ingests per-event (PDG, momentum, position) from an upstream particle-tracking ntuple; single-threaded only
- `three-tier-physics-selection` — `getenv("PHYSLIST")` → coded named options → `G4PhysListFactory` fallback; robust against typos and SLURM-script overrides
