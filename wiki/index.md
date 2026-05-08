# Wiki index

## synthesis/

*Cross-domain synthesis pages — wiki-specific content that bridges `sources/physics/` and `sources/geant4-code/`.*

- [[passage-particles-matter-geant4-mapping]] — PDG Ch. 34 sections mapped to the Geant4 classes that implement them (`G4BetheBlochModel`, `G4UrbanMscModel`, `G4eBremsstrahlungRelModel`, `G4Cerenkov`, …).

## sources/physics/

*Particle physics reference, PDG-grounded. Pages cite specific PDG editions; data is fetched on demand, not mirrored.*

- [[passage-particles-matter]] — PDG Ch. 34 (Groom & Klein, 2023) **full content**: verbatim translation of all 7 sections, 47 equations, 27 figures, 90-entry reference list.
- [[passage-particles-matter-summary]] — same chapter, **wiki summary** form: paraphrased prose + Geant4 cross-references appendix mapping to `G4*Model`/`G4*Process` classes.
- [[pdg-api-access]] — how to query PDG (REST API, Python `pdg` client, bulk SQLite); what's available vs what isn't.

## sources/geant4-code/examples/

*One page per canonical Geant4 example.*

### basic/
- [[g4-example-basic-b1]] — minimum app; one geometry, one gun, dose in stepping action.
- [[g4-example-basic-b2]] — first custom SD + hits collection, magnetic field, parameterised volumes.
- [[g4-example-basic-b3]] — modular physics list, `G4MultiFunctionalDetector` + primitive scorers, PET schematic.
- [[g4-example-basic-b4]] — sampling calorimeter four ways; the scoring decision cheat sheet.
- [[g4-example-basic-b5]] — multi-arm spectrometer, four SDs, `G4GenericMessenger`, vector ntuple branches.

### extended/
- [[g4-example-analysis-anaex01]] — `G4AnalysisManager` reference: histogram booking, ntuple filling, writing.
- [[g4-example-analysis-anaex02]] — direct ROOT `TFile`/`TTree` without `G4AnalysisManager`.
- [[g4-example-biasing-b01]] — geometry-based importance sampling; deep-shielding pattern.
- [[g4-example-biasing-gb01]] — generic biasing operators; operator composition.
- [[g4-example-electromagnetic-testem0]] — minimal EM cross-section probe; no transport.
- [[g4-example-electromagnetic-testem5]] — EM benchmarking with thin-target transport.
- [[g4-example-eventgenerator-hepmcex01]] — HepMC interface for upstream MC events.
- [[g4-example-exoticphysics-monopole]] — magnetic monopoles; physics-list pre-init constraint.
- [[g4-example-field-field01]] — canonical magnetic field setup pattern.
- [[g4-example-geometry-replica]] — `G4PVReplica` for periodic calorimeter layers.
- [[g4-example-geometry-transforms]] — rotations, translations, the five Geant4 rotation conventions.
- [[g4-example-hadronic-hadr00]] — hadronic cross-section probe; no transport.
- [[g4-example-hadronic-hadr01]] — calorimetric hadronic shower in a homogeneous block.
- [[g4-example-optical-opnovice]] — Cherenkov, scintillation, optical photon transport.
- [[g4-example-parameterisations-par01]] — fast-simulation parameterisation hooks.
- [[g4-example-persistency-gdml-g01]] — `G4GDMLParser` reader/writer; GDML feature reference.
- [[g4-example-persistency-gdml-g02]] — extended GDML: multiple files, auxiliary tag patterns.
- [[g4-example-persistency-gdml-g03]] — schema-extended GDML for typed metadata.
- [[g4-example-persistency-gdml-g04]] — wire SDs to GDML-loaded volumes via `<auxiliary>`; spine of `geant4_claude`.
- [[g4-example-persistency-p01]] — object-streaming hits via Reflex/genreflex.
- [[g4-example-persistency-p03]] — text geometry; lightweight read-only sibling to GDML.
- [[g4-example-physicslists-extensiblefactory]] — pick a physics list by name; compose with `+`/`_` DSL.
- [[g4-example-polarisation-pol01]] — polarised EM processes.
- [[g4-example-runandevent-re03]] — scoring meshes via `G4ScoringManager`; zero-SD scoring alternative.
- [[g4-example-runandevent-re05]] — event biasing intro; parallel worlds.

### advanced/
- [[g4-example-advanced-cats]] — full-stack reference: multiple SDs + GDML + ROOT output.
- [[g4-example-advanced-composite-calorimeter]] — full sampling-calorimeter mini-app; real detector reference.
- [[g4-example-advanced-dna]] — Geant4-DNA; biology-scale low-energy physics.
- [[g4-example-advanced-hadrontherapy]] — proton therapy beamline + dose; parallel-world scoring.
- [[g4-example-advanced-hgcal-testbeam]] — high-granularity calorimeter test beam; per-pixel digitization.
- [[g4-example-advanced-lar-calorimeter]] — liquid-argon calorimeter; histogram-driven analysis.
- [[g4-example-advanced-medical-linac]] — clinical linac simulation; dose voxel grid via `/score`.
- [[g4-example-advanced-stcyclotron]] — cyclotron / radioactive isotope production.

---

## sources/geant4-code/synthesis/

*Concepts, entities, and source-derived synthesis pages. Page type is in each file's frontmatter.*

### Concepts
- [[analysis-manager]] — `G4AnalysisManager`: histogram + ntuple API; format abstraction; MT merging.
- [[em-processes]] — photon and e± EM processes; EM constructor options; energy-loss straggling.
- [[init-quartet]] — the four objects every Geant4 program hands to `G4RunManager`.
- [[magnetic-field-setup]] — uniform and map-based field setup; DOPRI5 default; local LV priority.
- [[optical-photon-physics]] — Cherenkov, scintillation, WLS, boundary processes; PDG = −22.
- [[physics-list-factory]] — `G4PhysListFactory`: runtime list selection, reference lists, additive constructors.
- [[scoring-mesh]] — `G4ScoringManager` command-based scoring; one-line activation; dose grids via `/score/`.
- [[scoring-styles]] — the five scoring approaches; decision guide.
- [[sensitive-detectors-via-gdml-aux]] — SD wiring via GDML `<auxiliary>`; Hits TTree schema; dispatch timing.
- [[user-actions]] — the five lifecycle hooks; MT safety; safe TFile write point.

### Entities
- [[g4-mt-run-manager]] — `G4MTRunManager`: master-thread orchestrator; `BuildForMaster` vs `Build`.
- [[g4-process-manager]] — `G4ProcessManager`: owns/orders process vectors per particle type.
- [[g4-step]] — `G4Step`: per-step snapshot; PreStepPoint/PostStepPoint; energy deposit finality.
- [[g4-stepping-manager]] — `G4SteppingManager`: drives the step loop; SD fires before `UserSteppingAction`.
- [[g4-tracking-manager]] — `G4TrackingManager`: drives one track; secondary ID assignment timing.

### From source reading (g4-src-*)
- [[g4-src-field-integration]] — `G4PropagatorInField` + `G4ChordFinder` loop; DOPRI5; epsilon/delta defaults.
- [[g4-src-gdml-auxiliary-walk]] — exact `G4GDMLAuxStructType` API; no parent→daughter inheritance; nested aux ignored.
- [[g4-src-opticalphoton-sentinel]] — optical photon PDG = −22; identification by pointer not code; plugin recommendation.
- [[g4-src-process-registration-ordering]] — six process vectors; GPIL reversal; ordering constants; `BuildPhysicsTable` timing.
- [[g4-src-run-lifecycle-mt]] — `BuildForMaster` vs `Build`; merge barrier; safe TFile point; `SetUserAction` restriction.
- [[g4-src-sd-dispatch]] — SD called before `UserSteppingAction`; filter gates; PreStepPoint volume; MT safety.
- [[g4-src-step-lifecycle]] — full per-step call order; GPIL competition; `fGeomBoundary` set by Transportation.
- [[g4-src-track-and-secondary-lifecycle]] — track/secondary stack lifecycle; `trackID` assignment timing; `G4TrackStatus` values.
