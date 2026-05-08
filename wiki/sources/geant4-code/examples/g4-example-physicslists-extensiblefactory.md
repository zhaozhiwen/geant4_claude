---
type: source
domain: geant4-code
g4_version: 11.4.0
status: stable
related:
  - physics-list-factory
  - physics-list-dsl
  - run-manager
  - optical-physics
---

# g4-example-physicslists-extensiblefactory


How to select and compose any Geant4 reference physics list at runtime using `g4alt::G4PhysListFactory`, a strict superset of the standard `G4PhysListFactory`. The namesake feature is a string DSL for composing lists on the fly: `FTFP_BERT_EMX+G4OpticalPhysics+RADIO` replaces the EM constructor, adds optical physics, and adds radioactive decay — all from a command-line flag or `PHYSLIST` env var, no recompile. Custom physics lists and constructors register themselves into the global factory with a single macro (`G4_DECLARE_PHYSLIST_FACTORY`), making the same binary serve multiple physics regimes. `PrintAvailable()` lists every registered list and constructor at startup.

## Key concepts demonstrated

- `physics-list-factory` — `g4alt::G4PhysListFactory::GetReferencePhysList(name)` replaces hard-coded `new FTFP_BERT(0)`; the factory also honors `PHYSLIST` env var as a default, enabling batch-farm steering
- `physics-list-dsl` — `BASE[_REPLACE][+ADD]...` syntax: `_X` replaces a physics slot (e.g. EM), `+Y` adds a constructor; wrong operator silently produces a different list
- `physics-constructor-registry` — `G4_DECLARE_PHYSLIST_FACTORY` / `G4_DECLARE_PHYSCONSTR_FACTORY` are static-initializer macros; the object file must be linked into the binary or the registration silently does not happen
- `optical-physics` — `+G4OpticalPhysics` in the DSL is the idiomatic way to add optical physics on top of any base list; it's purely additive and costs nothing if no material has `RINDEX` defined
- `physlist-env-var` — `PHYSLIST` env var vs. `-p` CLI flag; CLI wins; documenting precedence prevents confusion in batch jobs
