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
> /geant4-claude:geant4-init
✓ wrote workspace skeleton (src/, geometries/, macros/, runs/, analysis/, CLAUDE.md, log.md, result.md)
✓ pulled ghcr.io/gemc/g4install:11.4.0-almalinux-9.4 (cached at ${CLAUDE_PLUGIN_DATA}/cache/sif)

> /geant4-claude:geant4-detector            # describe detector → standalone GDML
  describe your detector: a 1×1×10 cm lead block in an air world,
                          tag the lead as sensitive
✓ wrote geometries/lead_block.gdml (validated)

> /geant4-claude:geant4-example             # drops in the GDML-loading main + macro + analysis
✓ wrote src/{geant4_claude_main.cc, CMakeLists.txt}, geometries/example.gdml,
  macros/run.mac, analysis/example.py
  (the example main consumes any GDML, including geometries/lead_block.gdml)

> /geant4-claude:geant4-build
✓ built build/geant4_claude_main

> /geant4-claude:geant4-run --exe build/geant4_claude_main -- geometries/lead_block.gdml macros/run.mac {run_dir}/hits.root
✓ run 20260508-221045-a3f9c0 finished in 8.2 s
  → runs/20260508-221045-a3f9c0/{hits.root, log.txt, config.json}

> /geant4-claude:geant4-analyze runs/20260508-221045-a3f9c0
✓ edep_hist.png  (1000 events, ~1.2M hits, mean = 312 MeV/event)
```

## Architecture

```
                ┌──────────────────────────────────────────────────────────────┐
                │                       user's project                        │
                │  src/   geometries/   macros/   build/   runs/<id>/   analysis/  │
                └──▲──────▲──────────────▲───────▲───────▲───────────────▲────┘
                   │      │              │       │       │ reads         │ writes plots
                   │      │              │       │       │               │
  ┌─────────┐  ┌───┴──┐  ┌┴─────────┐  ┌─┴────┐ ┌┴────┐ │           ┌────┴───────────┐
  │ /init   │  │/det- │  │/build    │  │/run  │ │/run │ │           │ /analyze       │
  │         │  │ector │  │          │  │      │ │     │ │           │  (Claude)      │
  └────┬────┘  └──┬───┘  └────┬─────┘  └──┬───┘ └─┬───┘ │           └────┬───────────┘
       │          │           │            │     │     │                │
       │  validation          │            │     │     │                │ python (uproot, numpy, mpl)
       │  via g4run           │            │     │     │                │
       │  validate-gdml       │            │     │     │                │
       │                      │            │     │     │                │
       │           ┌──────────▼────────────▼─────▼─────┴────────────────┴┐
       │           │  bin/g4run  (apptainer exec sif:                    │
       │           │   source docker-entrypoint.sh; cmake / exec)        │
       └──────────►│   build → ./build/<binary>                          │
                   │   exec  → user binary writes into runs/<id>/        │
                   │  (Geant4 11.4.0, ROOT 6.38)                         │
                   └─────────────────────────────────────────────────────┘

                 image: ghcr.io/gemc/g4install:11.4.0-almalinux-9.4
```

Three things to notice:

- **`bin/g4run` is the single seam** between the plugin and the simulator.
  Everything else above the dashed line is Claude prompting + Python.
- **GDML decouples geometry from rebuilds (when the user opts in).** The
  example main parses GDML at runtime, so geometry changes don't require
  recompilation. Users with hardcoded geometry rebuild via `/geant4-claude:geant4-build`.
- **Analysis runs on the host**, not in the container. ROOT files are read
  with `uproot`, which requires only `pip install uproot numpy matplotlib`.

## Component contracts

### `bin/g4run`

```
bin/g4run build <src_dir> <build_dir>     # CMake-build user source inside the container
bin/g4run exec  <executable> [args…]      # run any binary inside the container
bin/g4run shell                           # interactive shell inside the container
bin/g4run root  <args…>                   # forward to ROOT inside the container
bin/g4run validate-gdml <file>            # xmllint a GDML file inside the container
bin/g4run pull / info                     # image management & status
```

`build` and `exec` are content-neutral — `bin/g4run` knows nothing about
the user's CMake target name, output schema, or argument shape. Slash
commands carry the workspace conventions; the wrapper just runs the
container.

Internally each subcommand:

1. ensures the `.sif` for the pinned tag exists at `<cache>/sif/…`, pulling
   on first use. The cache resolves to `$GEANT4_CLAUDE_CACHE` (explicit
   override) or `$CLAUDE_PLUGIN_DATA/cache` (auto-set by Claude Code when
   the plugin is installed) — both unset is a fatal error rather than a
   silent fallback to `$HOME`. To insulate against `CLAUDE_PLUGIN_DATA`
   not being propagated into Bash subshells in some Claude Code
   configurations, every slash command prepends
   `GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache"` to its g4run call;
2. invokes `apptainer exec --bind <project>,<cache> <sif> bash -lc
   'source /usr/local/bin/docker-entrypoint.sh && <cmd>'`.

The image tag is the only place it appears. Bumping the tag is a minor-version
bump for the plugin.

### Example main (`templates/example/src/geant4_claude_main.cc`)

Shipped as a **template**, not a contract — but it is the **default
binary** for the NL-detector flow. `/geant4-claude:geant4-detector`
emits standalone GDML; this main reads any GDML at runtime, attaches
sensitive detectors to volumes tagged in the GDML, and writes a flat
`Hits` TTree. Together they form the no-C++ default loop: describe →
run → analyze, with geometry iterations not requiring a rebuild.

Users get it in their workspace by running `/geant4-claude:geant4-example`;
from that point on it's their copy to edit. The plugin ships no compiled
code itself — every build is the user's build, in their workspace's
`./build/`. Users who bring their own `main.cc` skip this template
entirely.

CLI: `geant4_claude_main <geometry.gdml> <run.mac> <output.root>`.

Behavior:

- Loads `geometry.gdml` via `G4GDMLParser`.
- Default physics list: `FTFP_BERT` (the user can swap this in their copy).
- Attaches a generic sensitive detector to every logical volume tagged with
  GDML `auxiliary` `<auxiliary auxtype="sensitive" auxvalue="true"/>`.
- Writes one flat TTree `Hits` with branches:
  `event/I, volume/C, edep/D, x/D, y/D, z/D, t/D, pdg/I`.
- Runs the macro, then writes and closes the TFile.

That schema is the **example's** contract — `/geant4-claude:geant4-analyze` checks for
it and falls back to a custom-script path when the user's binary writes
something different.

### Run record (`runs/<id>/config.json`)

The provenance schema is generic — it captures *what was run*, not *what
the macro said*. Macro semantics (particle, energy, n_events) live in the
macro file, not here; analysis scripts that need them parse the macro.

```json
{
  "run_id":      "20260508-221045-a3f9c0",
  "executable":  "build/geant4_claude_main",
  "args":        ["geometries/example.gdml", "macros/run.mac", "runs/20260508-221045-a3f9c0/hits.root"],
  "image":       "ghcr.io/gemc/g4install:11.4.0-almalinux-9.4",
  "git_sha":     "<workspace HEAD or null>",
  "started_utc": "2026-05-08T22:10:45Z",
  "duration_s":  8.2,
  "exit_status": 0
}
```

Analysis tools read this, *not* the surrounding directory structure. It is
the provenance record.

## Slash command surface

The four core commands operate on **the user's own simulation** (any
`main.cc`, any output schema). One additional command drops in a working
demo, and one helper writes GDML.

| Command | One-line purpose |
|---------|------------------|
| `/geant4-claude:geant4-init` | Scaffold an empty workspace skeleton (`src/`, `geometries/`, `macros/`, `runs/`, `analysis/` plus `CLAUDE.md`, `.gitignore`, `log.md`, `result.md`); pull the pinned image. On first run, also offers (one prompt, plugin-wide) to download the Geant4 source tarball from GitHub releases into `${CLAUDE_PLUGIN_DATA}/geant4-src/` for offline citation verification. |
| `/geant4-claude:geant4-build` | CMake-build the user's source tree (`./src` → `./build` by default) inside the container. |
| `/geant4-claude:geant4-run` | Execute the user's binary inside the container; allocate `runs/<id>/`; capture generic provenance (executable, args, image, git_sha, duration, exit status). Substitutes `{run_dir}`/`{run_id}` placeholders and exports `RUN_DIR`/`RUN_ID` so the binary can write into the run dir. |
| `/geant4-claude:geant4-analyze` | Inspect the run's ROOT file. Schema-aware fast-path (canned per-event edep histogram) when a `Hits` TTree matching the example schema is found; otherwise generates a custom analysis script tailored to the actual branches. |
| `/geant4-claude:geant4-detector` | Translate a natural-language detector spec into a validated standalone GDML file under `geometries/`. The output is consumable by any `main.cc` that calls `G4GDMLParser::Read(...)`. |
| `/geant4-claude:geant4-example` | Drop the GDML-loading `main.cc` + `CMakeLists.txt` + a sample geometry/macro/analysis into the workspace. The shipped main is the default consumer for `/geant4-claude:geant4-detector` output, and is also runnable as-is for users who haven't yet described their own detector. Users who bring their own `main.cc` skip this command. |

Each command's full contract lives in its `.md` file under `commands/`.

## Skill split

| Skill | Owns |
|-------|------|
| `geant4` | **Full-flow orchestrator (the highlighted entry point).** Auto-loads on "simulate / build / run a Geant4 …" requests; gap-checks the user's spec across six fields (goal, geometry, beam, sensitive, output, analysis); presents a brief plan; on approval drives `init → detector → build → run → analyze` in sequence. The only skill in the plugin that drives a workflow rather than describing one. |
| `geant4-geometry` | GDML structure, units, materials, common shapes, validation, `auxiliary` tags for sensitive detectors. |
| `geant4-physics-list` | Choosing among FTFP_BERT / QGSP_BIC / etc.; range cuts; what to set for EM-only vs hadronic. |
| `geant4-analysis` | `uproot` recipes (read `Hits` TTree → numpy), common plots (edep histogram, hit map, per-volume sums). |

The reference skills (geometry, physics-list, analysis) are syntax +
judgment, never workflow — they're loaded on demand by the commands or
by `geant4` itself when it needs to make a specific decision. The
orchestrator skill is the one deliberate exception: it sequences
commands so a single user message can fan out into a planned run.

## Workspace conventions

`/geant4-claude:geant4-init` writes a **generic skeleton**:

```
my-project/
├── CLAUDE.md            # rules for Claude inside this workspace
├── .gitignore           # excludes runs/, *.root, build/, __pycache__/
├── log.md               # chronological work log; Claude appends after each run
├── result.md            # per-run findings; Claude updates after a noteworthy analyze
├── src/                 # /geant4-claude:geant4-example fills this (default), or drop in your own main.cc + CMakeLists.txt
├── geometries/          # GDML files, one per detector (optional)
├── macros/              # Geant4 macro files
├── runs/                # one subdir per /geant4-claude:geant4-run invocation (gitignored)
└── analysis/            # python analysis scripts
```

`/geant4-claude:geant4-example` adds the demo on top:

```
my-project/
├── src/
│   ├── geant4_claude_main.cc    # GDML loader + GenericSD + Hits TTree
│   └── CMakeLists.txt           # find_package(Geant4 / ROOT), add_executable
├── geometries/example.gdml      # 1×1×10 cm lead block in air world; sensitive
├── macros/run.mac               # 1 GeV e-, /run/beamOn 1000
└── analysis/example.py          # uproot → per-event edep histogram
```

`/geant4-claude:geant4-build` writes:

```
my-project/build/<binary>        # gitignored
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

**Impact on users:** Users of the example main with non-standard physics needs (HP neutrons, optical photons, radioactive decay, medical dosimetry) must edit their copy of `src/geant4_claude_main.cc` (placed by `/geant4-claude:geant4-example`) and re-run `/geant4-claude:geant4-build`. Users with their own `main.cc` already wire whatever physics list they need. This friction is the single biggest barrier for new users coming in via `/geant4-claude:geant4-example`.

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

**Walk** (in `templates/example/src/geant4_claude_main.cc::ConstructSDandField`, ~lines 120–143):

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

**Self-hosted marketplace.** The plugin repo doubles as a single-plugin Claude Code marketplace via `.claude-plugin/marketplace.json` (alongside `plugin.json`). The marketplace entry points back at the same repo with `"source": "./"` so `/plugin marketplace add zhaozhiwen/geant4_claude` + `/plugin install geant4-claude@geant4-claude` is the supported install path; manual `git clone` still works as a fallback. Marketplace name matches the plugin name (`geant4-claude`) — both fields require kebab-case per the Claude Code plugin spec, and keeping them identical means users only have one identifier to remember. Don't change either after release; renaming breaks every existing user's install command.

**Optional Geant4 source clone.** The wiki's `sources/geant4-code/synthesis/` pages cite `.cc:line` ranges. Those citations are only verifiable if the Geant4 source tree is locally present. The canonical location is `${CLAUDE_PLUGIN_DATA}/geant4-src/` so the tree survives plugin version bumps (the plugin checkout at `${CLAUDE_PLUGIN_ROOT}` is replaced on update; `${CLAUDE_PLUGIN_DATA}` is not). `/geant4-claude:geant4-init` maintains a symlink at `${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src` pointing at the canonical tree so wiki pages can keep using the relative `wiki/raw/geant4-src/...` path; the symlink is recreated on every `/geant4-claude:geant4-init` run because plugin updates wipe the previous checkout. To keep fresh-clone size small, the tree is **gitignored** and not shipped. `/geant4-claude:geant4-init` step 6 detects whether the tree is already there and, if missing, asks the user once whether to download the matching source tarball from GitHub releases (`https://github.com/Geant4/geant4/archive/refs/tags/v<VERSION>.tar.gz`). The tag is derived from `bin/g4run`'s pinned image (single source of truth) so a container bump automatically asks for a matching source bump. Idempotent: subsequent `/geant4-claude:geant4-init` calls in other workspaces detect the existing tree and skip the prompt; pre-relocation installs (real directory at the legacy path) are auto-migrated on the next call when the destination is empty.
