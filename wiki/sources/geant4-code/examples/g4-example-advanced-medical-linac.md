---
type: source
domain: detector-sim
g4_version: 11.4.0
status: stable
related: []
---

# g4-example-advanced-medical-linac


A clinical photon-mode LINAC (GE Saturn 43, 12 MV, EURADOS Working Group 6 intercomparison geometry) simulated component by component — electron source, target, primary collimator, flattening filter, ion chamber, movable secondary jaws, and a PMMA-walled water phantom. Its defining feature is that all scoring is handled by Geant4's command-based scoring framework (`/score/...` UI commands) with zero sensitive detector code in the application; the entire dose mesh is defined and dumped from the macro. Experimental dosimetric data ships with the example for validation.

## Key concepts demonstrated
- `command-based-scoring` — `/score/create/boxMesh`, `/score/quantity/doseDeposit`, `/score/dumpQuantityToFile` produce a full 3D dose grid purely from UI commands; no `G4VSensitiveDetector` subclass required
- `g4scoringmanager` — `G4ScoringManager::GetScoringManager()` must be called before any `/score/` command or those commands silently do nothing
- `emstandard-opt3` — the EM physics option tuned for medical-energy electrons/photons; tighter step control and more accurate MSC than the default `_opt0`
- `boundary-material-realism` — the PMMA entrance wall (4 mm) and side walls (15 mm) around the phantom are simulated because they affect backscatter; omitting boundary materials is a common source of dosimetry error
- `g4runmanagerfactory` — `CreateRunManager()` with no type argument takes the platform MT default; contrasted with hardcoding `G4MTRunManager`
