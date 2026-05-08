# DESIGN.md — `geant4_claude`

## Goal

Let any Claude Code user, on any machine with apptainer and Python, **design
a Geant4 detector, run a simulation, and analyze the output** without writing
C++ for the common case. The plugin contributes:

- a small set of slash commands that drive the full loop,
- a generic Geant4 main that loads any GDML and writes a flat hits TTree,
- a single apptainer wrapper (`bin/g4run`) so the runtime is one swap away,
- focused skills with the syntactic knowledge (GDML, physics lists, uproot)
  Claude needs to make good choices.

## Non-goals (MVP)

- Replacing a full simulation framework like GEMC or G4Beamline.
- Autonomous experiment optimization or parameter sweeps. (A user's project can
  build that on top.)
- A graphical UI. Visualization happens via Geant4's own viewers inside the
  container, or via post-hoc Python plots.
- Supporting Geant4 versions other than the one pinned in `bin/g4run`.

## User journey (the MVP smoke test)

```
$ cd ~/projects/my-detector
$ claude
> /geant4-init
✓ wrote workspace skeleton (geometries/, macros/, runs/, analysis/, CLAUDE.md)
✓ pulled ghcr.io/gemc/g4install:11.4.0-almalinux-9.4 (cached at ~/.geant4_claude/sif)
✓ built generic main → ~/.geant4_claude/build/geant4_claude_main

> /geant4-detector "1x1x10 cm lead block centered at origin, air world 50 cm"
✓ wrote geometries/det.gdml (validated against schema)

> /geant4-run --particle e- --energy 1 GeV --events 1000
✓ run 20260503-221045-a3f9c0 finished in 8.2 s
  → runs/20260503-221045-a3f9c0/{hits.root, log.txt, config.json}

> /geant4-analyze runs/20260503-221045-a3f9c0
✓ edep_hist.png   (mean = 312 MeV, fwhm ≈ 78 MeV, 1000 events)
```

## Architecture

```
                ┌────────────────────────────────────────────────────────┐
                │                    user's project                      │
                │  geometries/   macros/   runs/<id>/   analysis/        │
                └───▲────────────────▲─────────────▲──────────▲──────────┘
                    │ writes/edits   │ writes      │ reads    │ writes plots
                    │                │             │          │
   ┌────────────────┴───┐    ┌───────┴────────┐    │   ┌──────┴───────────┐
   │ /geant4-detector   │    │ /geant4-run    │    │   │ /geant4-analyze  │
   │  (Claude + skills) │    │  (Claude)      │    │   │  (Claude)        │
   └────────┬───────────┘    └───────┬────────┘    │   └──────┬───────────┘
            │                        │             │          │
            │              bin/g4run sim …         │          │ python (uproot, numpy, mpl)
            │                        │             │          │
            │                ┌───────▼─────────────┴──────────┐
            │                │  apptainer exec sif:           │
            │                │  source docker-entrypoint.sh   │
            │                │  geant4_claude_main GDML MAC   │
            └─ validation ──►│  (Geant4 11.4.0, ROOT)         │
              (xmllint via   │  → hits.root + log.txt          │
               bin/g4run)    └────────────────────────────────┘

                 image: ghcr.io/gemc/g4install:11.4.0-almalinux-9.4
```

Three things to notice:

- **`bin/g4run` is the single seam** between the plugin and the simulator.
  Everything else above the dashed line is Claude prompting + Python.
- **Geometry edits never trigger a rebuild.** GDML is data; the generic main
  is built once per host.
- **Analysis runs on the host**, not in the container. ROOT files are read
  with `uproot`, which requires only `pip install uproot numpy matplotlib`.

## Component contracts

### `bin/g4run`

```
bin/g4run build              # build src/ into ~/.geant4_claude/build/ (idempotent)
bin/g4run sim   <gdml> <mac> <out_dir>
bin/g4run shell              # interactive shell inside the container
bin/g4run root  <args…>      # forward to ROOT inside the container
```

Internally each subcommand:

1. ensures the `.sif` for the pinned tag exists at `~/.geant4_claude/sif/…`,
   pulling on first use;
2. invokes `apptainer exec --bind <project>,<cache> <sif> bash -lc
   'source /usr/local/bin/docker-entrypoint.sh && <cmd>'`.

The image tag is the only place it appears. Bumping the tag is a minor-version
bump for the plugin.

### Generic Geant4 main (`src/geant4_claude_main.cc`)

CLI: `geant4_claude_main <geometry.gdml> <run.mac> <output.root>`.

Behavior:

- Loads `geometry.gdml` via `G4GDMLParser`.
- Default physics list: `FTFP_BERT` (overridable in the macro).
- Attaches a generic sensitive detector to every logical volume tagged with
  GDML `auxiliary` `<auxiliary auxtype="sensitive" auxvalue="true"/>`.
- Writes one flat TTree `Hits` with branches:
  `event/I, volume/C, edep/D, x/D, y/D, z/D, t/D, pdg/I`.
- Runs the macro, then writes and closes the TFile.

That schema is the contract analysis tools depend on. Adding branches is
backwards-compatible; renaming or removing one is a breaking change requiring
a plugin major-version bump.

### Run record (`runs/<id>/config.json`)

```json
{
  "run_id":      "20260503-221045-a3f9c0",
  "geometry":    "geometries/det.gdml",
  "macro":       "macros/run.mac",
  "particle":    "e-",
  "energy_MeV":  1000,
  "n_events":    1000,
  "image":       "ghcr.io/gemc/g4install:11.4.0-almalinux-9.4",
  "image_digest":"sha256:…",
  "git_sha":     "<workspace HEAD or null>",
  "started_utc": "2026-05-03T22:10:45Z",
  "duration_s":  8.2
}
```

Analysis tools read this, *not* the surrounding directory structure. It is
the provenance record.

## Slash command surface

| Command | One-line purpose |
|--------|------------------|
| `/geant4-init` | Scaffold workspace, pull image, build generic main. On first run, also offers (one prompt, plugin-wide) to shallow-clone the Geant4 source tree to `${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src/` for offline citation verification. |
| `/geant4-detector` | Translate a natural-language detector spec into a validated GDML file. |
| `/geant4-run` | Run a simulation and produce a fresh `runs/<id>/`. |
| `/geant4-analyze` | Read `runs/<id>/hits.root`, produce plots + summary. |

Each command's full contract lives in its `.md` file under `commands/`.

## Skill split

| Skill | Owns |
|-------|------|
| `geant4-geometry` | GDML structure, units, materials, common shapes, validation, `auxiliary` tags for sensitive detectors. |
| `geant4-physics-list` | Choosing among FTFP_BERT / QGSP_BIC / etc.; range cuts; what to set for EM-only vs hadronic. |
| `geant4-analysis` | `uproot` recipes (read `Hits` TTree → numpy), common plots (edep histogram, hit map, per-volume sums). |

A skill never executes the workflow — it's syntax + judgment. Workflow lives
in commands.

## Workspace conventions (what `/geant4-init` writes)

```
my-project/
├── CLAUDE.md            # rules for Claude inside this workspace (tight version of plugin rules)
├── .gitignore           # excludes runs/, *.root, build/, __pycache__/
├── geometries/
│   └── example.gdml     # 1×1×10 cm lead block in air world; sensitive
├── macros/
│   └── run.mac          # particle gun, FTFP_BERT, /run/beamOn 1000
├── runs/                # one subdir per /geant4-run invocation
└── analysis/
    └── example.py       # uproot read + edep histogram
```

Each directory has a single, well-defined role. Skills and commands assume
this layout. Users can extend it (e.g., `notes/`, `papers/`) but should not
rename these four.

## Versioning & compatibility

- Plugin version: semver in `.claude-plugin/plugin.json`.
- Image tag is pinned in `bin/g4run`. Bumping it = minor bump (behavior may
  shift inside Geant4 across patch versions).
- TTree schema change = major bump.
- GDML is whatever Geant4 11.4 accepts; we don't define our own schema layer.

## Open questions (parked, do not block MVP)

- **Sensitive detectors via aux tags vs. C++.** Lean: aux tags only for MVP;
  expose a C++ extension hook in v2 so users with custom scoring can register
  their own SD without forking the main.
- **Scoring meshes vs. SD hits.** Lean: SD hits only for MVP. Adding scoring
  meshes would mean a second TTree contract; defer until a real user asks.
- **Experiment log / sweep command.** Out of MVP. A `/geant4-sweep` that
  parameterizes one knob across runs is the obvious next command, but it adds
  schema (sweep manifests, joined analysis) and is best added after one real
  user has lived with the four-command MVP.

## MVP boundary — what real Geant4 apps do that v0.0.1 doesn't

`geant4_claude` v0.0.1 is intentionally narrow. This section maps what real Geant4 apps do that the plugin does not yet support, synthesized from reading 38 canonical Geant4 examples. Each item is an honest gap, not a bug. They define the upgrade roadmap.

### 1. Runtime-selectable physics list

**What real apps do:** `G4PhysListFactory` keyed off `argv` or a `PHYSLIST` env var. See [physics-list-factory](../wiki/sources/geant4-code/synthesis/physics-list-factory.md) in the wiki.

**What we do:** Hard-code `new FTFP_BERT(0)`.

**Impact on users:** Users with non-standard physics needs (HP neutrons, optical photons, radioactive decay, medical dosimetry) must edit `src/geant4_claude_main.cc` and trigger a rebuild. This friction is the single biggest barrier for users beyond "generic HEP calorimeter."

**Upgrade path:** `--physics-list <name>` flag to `geant4-run`, plus `--extra-physics <comma-list>` for additive constructors. Logged in `config.json`. Single CLI surface. Estimated: ~50 lines of C++ + command update.

### 2. Output matching the user's mental level

**What real apps do:** Per-pixel digitized hit maps (`HGCal_testbeam`), dose voxel grids (`medical_linac`, `hadrontherapy`), per-track summaries (`composite_calorimeter`), 2D scatter plots (`dna`).

**What we do:** Per-step flat TTree. Works for "how much energy was deposited per event in volume X." Wrong shape for any segmented or binned output.

**Impact on users:** Users who want a dose grid, a pixel map, or per-track energy loss must post-process the flat TTree in numpy. The `geant4-analysis` skill has aggregation recipes for the common cases.

**Upgrade path:** This is fundamentally a TTree contract change (adds branches, changes granularity). Reserve for a post-MVP major. The honest interim is documenting the "post-bin in numpy" recipe, which the analysis skill already does.

### 3. Magnetic fields

**What real apps do:** `G4UniformMagField`, `G4TransportationManager`, `G4PropagatorInField`. The `field/field01` example is the canonical pattern.

**What we do:** Nothing. No field of any kind.

**Impact on users:** Any user with a solenoid, dipole, or beamline with bending is immediately blocked. This is the highest-leverage missing feature for real physics work — spectrometers, cyclotrons, and therapy beamlines all require it.

**Upgrade path:** A GDML auxiliary tag (`auxtype="field" auxvalue="uniform:0,0,1T"`) that `DetectorConstruction` reads and passes to `G4FieldManager`. Uniform field first; map-based field later. No TTree contract change required.

### 4. Multi-stage user actions

**What real apps do:** `G4UserStackingAction` (event filtering / trigger emulation — kill secondaries early, classify tracks) and `G4UserTrackingAction` (per-track hooks — record truth kinematics, wire to an MC truth tree).

**What we do:** Only `RunAction`, `EventAction`, and `PrimaryGeneratorAction`.

**Impact on users:** Any rare-signal study that needs to filter on particle type or track origin is blocked. Also blocks any analysis that needs primary particle truth information at the track level (not step level).

**Upgrade path:** The v2 C++ extension hook (see "Open questions" above). Until then, users can get some tracking information post-hoc by filtering the step TTree on `pdg` and `event`.

### 5. External primary sources

**What real apps do:** HepMC readers (HEP collider events), `G4GeneralParticleSource` (GPS — arbitrary phase-space distributions, isotropic sources, beams with angular spread), kinematic files (test beam).

**What we do:** `G4ParticleGun` only. Single particle, single energy, single direction per event.

**Impact on users:** Any physics requiring a realistic primary distribution is blocked: beam spread, angular divergence, energy spread, multi-particle events, upstream MC output.

**Upgrade path:** GPS is already in Geant4 with zero new dependencies. Expose it via macro commands (`/gps/...`) — the user's `.mac` file already reaches GPS if the generator is wired up. This is the cheapest fix: ~10 lines of C++ + documentation.

### Smaller TODOs (from individual study notes)

- `G4ScoringManager::GetScoringManager()` — one line in `main.cc` activates `/score/...` UI commands for free, giving users scoring meshes without changing the TTree contract. See [g4-example-runandevent-re03](../wiki/sources/geant4-code/examples/g4-example-runandevent-re03.md).
- **Biasing weight branch** — importance sampling (biasing-B01, GB01) requires a `weight/D` branch on the `Hits` TTree. This is a contract change → minor version bump. Design the schema now, ship in v0.2.
- **Optical photon PDG is −22** (confirmed from source: `G4OpticalPhoton.cc:67`). The `pdg/I` branch will record −22 when optical physics is enabled. The current `edep <= 0` guard in `GenericSD` means optical photons are silently dropped anyway — document this behaviour before optical support ships. See [g4-src-opticalphoton-sentinel](../wiki/sources/geant4-code/synthesis/g4-src-opticalphoton-sentinel.md).
- **Replica volumes in the geometry skill** — most segmented detectors use `G4PVReplica`; the `geant4-geometry` skill doesn't mention it. See [g4-example-geometry-replica](../wiki/sources/geant4-code/examples/g4-example-geometry-replica.md).

### What the MVP is good for right now

- Generic HEP-style calorimeter: energy deposition per event in a single sensitive volume with `FTFP_BERT` EM+hadronic physics.
- Quick geometry prototyping: GDML edit → rerun, no recompile.
- Educational: stepping through a new detector geometry idea.
- Any problem that fits "point gun at target, record steps."

For anything beyond that, check this section first — the gap may already be documented.

## How the plugin extends Geant4

### Generic SD via GDML auxiliary tags

The plugin uses the GDML `<auxiliary>` mechanism (Geant4 G04 pattern — see [wiki/sensitive-detectors-via-gdml-aux](../wiki/sources/geant4-code/synthesis/sensitive-detectors-via-gdml-aux.md)) to wire a generic sensitive detector without per-geometry C++.

**Tag form:**

```xml
<volume name="det_lv">
  ...
  <auxiliary auxtype="sensitive" auxvalue="true"/>
</volume>
```

**Walk** (in `src/geant4_claude_main.cc::ConstructSDandField`, ~lines 120–143):

```cpp
auto aux = parser.GetVolumeAuxiliaryInformation(lv);
for (const auto& a : aux) {
    if (a.type == "sensitive" && a.value == "true") {
        auto sd = new GenericSD(lv->GetName(), treeFiller);
        G4SDManager::GetSDMpointer()->AddNewDetector(sd);
        lv->SetSensitiveDetector(sd);
    }
}
```

`GenericSD` is a `G4VSensitiveDetector` subclass that records one row per `G4Step` end-point into a shared `TreeFiller` buffer. `RunAction` owns the `TFile` and `TTree`; `EventAction` flushes the buffer at end-of-event. Volumes not tagged `sensitive=true` produce no rows.

**Hits TTree schema** (the contract — bumping any of these is a major version):

| Branch | Type | Description |
|--------|------|-------------|
| `event` | `I` | Event number |
| `volume` | `C` | Logical volume name (32-char max) |
| `edep` | `D` | Energy deposited in this step (MeV) |
| `x`, `y`, `z` | `D` | Step end-point position (mm) |
| `t` | `D` | Global time (ns) |
| `pdg` | `I` | PDG code of the track |

**`GenericSD::ProcessHits` guard:** zero-energy boundary-crossing steps are silently dropped via `if (edep <= 0.) return false`. This is required because `G4SteppingManager` calls `Hit()` on every step in a sensitive volume, including zero-energy boundary crossings (see [wiki/g4-src-sd-dispatch](../wiki/sources/geant4-code/synthesis/g4-src-sd-dispatch.md)). It also drops optical photons by construction (their energy goes into surface scattering, not ionisation).

**Auxtype vocabulary (current):**

| auxtype | auxvalue | Meaning |
|---------|----------|---------|
| `sensitive` | `true` | Attach `GenericSD`; record all steps |

**Planned (would require TTree contract change → minor version bump):**

| auxtype | auxvalue | Meaning |
|---------|----------|---------|
| `scorer` | `edep` / `flux` / `dose` | Use a `G4MultiFunctionalDetector` primitive scorer instead |
| `filter` | `charged` / `neutral` | Only record tracks passing the filter |

### Python deps via `SessionStart` hook (currently: `pdg`)

`requirements.txt` at the plugin root is installed automatically into `${CLAUDE_PLUGIN_DATA}/venv/` (resolves to `~/.claude/plugins/data/geant4-claude.../venv/`) by `hooks/install-deps.sh` on every Claude Code session start. The hook is idempotent: it diffs the bundled `requirements.txt` against a stored copy in `${CLAUDE_PLUGIN_DATA}` and reinstalls only when they differ — so first session installs, later sessions are a 3 ms no-op. uv is preferred when available; falls back to `python3 -m venv` + pip.

The venv survives session restarts and plugin updates and is deleted automatically when the plugin is uninstalled (per Claude Code's plugin lifecycle).

**Calling pattern** for skills, commands, or Bash:

```bash
"${CLAUDE_PLUGIN_DATA}/venv/bin/python" -c "import pdg; ..."
```

The current `requirements.txt` carries `pdg>=0.2.2` only. Add a package only when something in `commands/`/`skills/` actually imports it; touching `requirements.txt` triggers reinstall on the next session.

### deepwiki MCP (Geant4 Q&A in-loop)

[DeepWiki](https://deepwiki.com/Geant4/geant4) is a free service that runs LLM-powered RAG over public GitHub repos. The plugin ships an MCP server at `.mcp.json` (plugin root) so Claude Code can ask Q&A about the Geant4 codebase without leaving the loop. No auth, no key.

**How it gets enabled:**

| You are… | What happens |
|----------|--------------|
| A user who installed `geant4_claude` from a marketplace | Plugin's `.mcp.json` is loaded automatically when the plugin is enabled. Claude Code may prompt once to approve the external server; approve it and the three `mcp__deepwiki__*` tools appear. |
| A maintainer who cloned this repo to hack on it | Your working dir *is* the plugin root, so `.mcp.json` is picked up as a project-scope MCP. Same behavior — one approval prompt, then tools available next session. |
| Someone who wants deepwiki without `geant4_claude` | Run `claude mcp add --transport http --scope project deepwiki https://mcp.deepwiki.com/mcp` in your project. Same effect; no plugin required. |

Verify any path with `claude mcp list` — expect `deepwiki: https://mcp.deepwiki.com/mcp (HTTP) - ✓ Connected`. Tools become callable in the next session start.

**Tools exposed:**

| Tool | What it does |
|------|--------------|
| `mcp__deepwiki__read_wiki_structure` | List documentation topics for a repo (`Geant4/geant4`). Use for a sitemap. |
| `mcp__deepwiki__read_wiki_contents` | Read the wiki body for a repo. Use for narrative architecture overview. |
| `mcp__deepwiki__ask_question` | Ask a free-form question against a repo (or up to 10 repos). LLM-grounded, returns prose + a search-permalink. |

**Usage rule (echoed in `wiki/CLAUDE.md`):** treat deepwiki answers as **hypotheses to verify** against `wiki/raw/geant4-src/` before citing them in a wiki synthesis page. Citation discipline is weaker than direct grep — in our smoke test the tool gave the correct optical-photon PDG = −22 but did not name `G4OpticalPhoton.cc:67` even when asked. If a deepwiki claim survives a `grep` in the local source tree, it earns a place in a synthesis page — citing the `.cc` file, not deepwiki.

### Distribution: marketplace + optional source-tree clone

**Self-hosted marketplace.** The plugin repo doubles as a single-plugin Claude Code marketplace via `.claude-plugin/marketplace.json` (alongside `plugin.json`). The marketplace entry points back at the same repo with `"source": "./"` so `/plugin marketplace add zhaozhiwen/geant4_claude` + `/plugin install geant4-claude@geant4-marketplace` is the supported install path; manual `git clone` still works as a fallback. Marketplace name (`geant4-marketplace`) is set there once — keep stable across releases or you'll break user install commands.

**Optional Geant4 source clone.** The wiki's `sources/geant4-code/synthesis/` pages cite `.cc:line` ranges. Those citations are only verifiable if the Geant4 source tree is locally present at `${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src/`. To keep fresh-clone size small, the tree is **gitignored** and not shipped. `/geant4-init` step 6 detects whether the tree is already there and, if missing, asks the user once whether to shallow-clone it. The tag is derived from `bin/g4run`'s pinned image (single source of truth) so a container bump automatically asks for a matching source bump. Idempotent: subsequent `/geant4-init` calls in other workspaces detect the existing tree and skip the prompt.
