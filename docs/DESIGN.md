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

> /geant4-claude:geant4-detector            # optional: NL detector spec → standalone GDML
  describe your detector: a 1×1×10 cm lead block in an air world,
                          tag the lead as sensitive
✓ wrote geometries/lead_block.gdml (validated)

# write src/main.cc + src/CMakeLists.txt for your simulation
# (Claude can draft these from a description of the physics list,
#  sensitive detectors, and output schema you want)

> /geant4-claude:geant4-build
✓ built build/<your-binary>

> /geant4-claude:geant4-run --exe build/<your-binary> -- geometries/lead_block.gdml macros/<your>.mac {run_dir}/<output>.root
✓ run 20260508-221045-a3f9c0 finished in 8.2 s
  → runs/20260508-221045-a3f9c0/{<output>.root, log.txt, config.json}

> /geant4-claude:geant4-analyze runs/20260508-221045-a3f9c0
✓ edep_hist.png  (or analysis/<run_id>.py + tailored plot if the
                   schema isn't `Hits`)
```

The user journey above is the **manual** path. The `geant4`
orchestrator skill collapses these steps behind a single
natural-language request — see Skill split below. Separately,
`/geant4-claude:geant4-example` drops a self-contained smoke test
into the workspace; useful for confirming the toolchain works on
a fresh install but *not* part of the user's real-simulation
journey.

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
bin/g4run validate-gdml <file>            # xmllint + G4GDMLParser parse check
bin/g4run preview <file.gdml> [out_dir]   # RayTracer JPEG previews (3 views)
bin/g4run pull / info                     # image management & status
```

`validate-gdml` and `preview` build tiny cached helper binaries
(`${CACHE_DIR}/bin/validate_gdml`, `…/preview_gdml`) from
`templates/validate/` and `templates/preview/` on first use; rebuilds
are triggered automatically when the relevant source files change.

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

Shipped as a **smoke-test fixture** and a piece of reference code,
not as a workflow component. `/geant4-claude:geant4-example` drops
this main + a sample geometry/macro/analysis into a fresh workspace
so the user can run `init → build → run → analyze` end-to-end on a
clean install and confirm the toolchain works. It is **not** the
default binary for users' real simulations — the manual flow
expects the user to write their own `main.cc`. The orchestrator skill
*may* compose this main with `/geant4-claude:geant4-detector` output
when the spec is simple enough that no custom physics or schema is
needed; that's an internal optimization of the orchestrator, not a
documented user-facing path.

Once dropped into the workspace it is the user's copy to keep,
delete, or edit. The plugin ships no compiled code itself — every
build is the user's build, in their workspace's `./build/`.

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
  "exit_status": 0,
  "parent_run":  null,
  "diff_reason": null
}
```

Analysis tools read this, *not* the surrounding directory structure. It is
the provenance record.

`parent_run` + `diff_reason` together capture **run lineage**: when a
user re-runs with `--from runs/<prev> --reason "bumped sensor to off-axis"`,
both fields are populated and the chain is walkable from
`runs/B/config.json` → `parent_run = "A"` → `runs/A/config.json`. The
two fields are an additive contract change to the run record — old
analysis tools that don't read them keep working.

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
| `/geant4-claude:geant4-preview` | Render headless 3-view JPEG previews of a GDML file via Geant4's RayTracer driver. Builds a cached helper inside the container on first use. The orchestrator inserts this step after `geant4-detector` so geometry mistakes surface before a simulation runs. |
| `/geant4-claude:geant4-example` | Drop a self-contained smoke test (GDML + macro + a generic GDML-loading `main.cc` + analysis script) into the workspace. Independent of the manual user flow — used once on a fresh install to confirm the toolchain works, or as reference code when writing your own simulation. The orchestrator skill may compose the example main with detector output for simple-physics specs as an internal shortcut, but the manual flow expects the user to bring their own `main.cc`. |
| `/geant4-claude:geant4-validate` | Run a physics closure test (Frank-Tamm Cherenkov yield in v1) against a `runs/<id>/` directory. Reads the output ROOT file, compares simulated yield to the analytic prediction, prints PASS/FAIL with sigma, writes a machine-readable summary at `runs/<id>/validate_<topic>.json`. Topics live under `scripts/validators/<topic>.py`. |

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
├── src/                 # your main.cc + CMakeLists.txt go here (or `/geant4-claude:geant4-example` fills it for the smoke test)
├── geometries/          # GDML files, one per detector (optional)
├── macros/              # Geant4 macro files
├── runs/                # one subdir per /geant4-claude:geant4-run invocation (gitignored)
└── analysis/            # python analysis scripts
```

Plugin-internal scripts and templates (live in the plugin checkout,
*not* in any user workspace):

```
geant4_claude/
├── templates/validate/      C++ harness for /geant4-claude:geant4-validate-gdml.
│                            Built on first use; cached under CLAUDE_PLUGIN_DATA.
├── templates/preview/       C++ harness for /geant4-claude:geant4-preview
│                            (alpha; see Hardening backlog).
└── scripts/validators/      Python validators driven by /geant4-claude:geant4-validate.
    └── cherenkov.py         v1: Frank-Tamm closure test.
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

## Hardening backlog (post-v0.0.3)

Items below were surfaced by dogfooding the plugin on a real Cherenkov
study. Each is actionable and scoped — listed here so the maintainer can
pick them up in order of leverage. None of them block any current user
flow; they're sharp edges around what already works.

### 1. Real GDML validation (not just xmllint)

**Current:** `bin/g4run validate-gdml <file>` runs `xmllint --noout`,
catching XML syntax errors only. Missing materials, malformed
`<auxiliary>` tags, bad unit names (`mm` vs `millimeter`), and undefined
volume references slip past and surface as a crash deep inside
`/geant4-claude:geant4-run`.

**Fix:** ship a tiny C++ harness (e.g. `templates/validate/main.cc`)
that does `G4GDMLParser::Read()` against the file, prints any parser
error, and exits non-zero on failure. Build it on first use inside the
container, cache the binary at `${CLAUDE_PLUGIN_DATA}/cache/bin/`, and
call it from `cmd_validate_gdml` after the xmllint pass.

**Impact:** Geometry errors surface before `/geant4-claude:geant4-build`
/`-run`, when the fix is "edit the GDML" rather than "read the run log."

### 2. Headless GDML preview (`/geant4-claude:geant4-preview`) *(alpha — rendering open)*

**Current:** Infrastructure shipped — `templates/preview/{main.cc,
CMakeLists.txt}`, `bin/g4run preview <gdml> [out_dir]` subcommand,
`commands/geant4-preview.md`, and a cached helper binary built on
first use at `${CACHE_DIR}/bin/preview_gdml`. The helper builds and
loads the GDML cleanly. **Rendering does not work yet.** With the
v11.4 container's RayTracer driver, three different command sequences
(combinations of `/vis/open`, `/vis/scene/create`, `/vis/sceneHandler/
create`, `/vis/viewer/create`, then `/vis/rayTracer/trace`) all
trigger `G4RTMessenger::SetNewValue: No valid current viewer. Using
default RayTracer.` and the subsequent `/vis/rayTracer/trace` hangs
indefinitely. The orchestrator skill therefore does NOT call preview
automatically; the slash command exists but is documented as alpha.

**Suspect:** `ApplyCommand`-driven RayTracer setup may not match what
the messenger expects in non-interactive (no G4UIsession) mode. Worth
investigating: (a) install a `G4UIsession` before issuing vis
commands; (b) load the commands via `/control/execute <macro.mac>`
instead of direct `ApplyCommand`; (c) call vis manager APIs
(`vis->CreateSceneHandler`, `vis->CreateViewer`) directly in C++
instead of going through the messenger.

**Workaround until rendering works:** `g4run shell`, then inside the
container:

```
$Geant4_DIR/bin/geant4-vis-config --help  # check available drivers
# Then a manual vis macro through any user binary that initializes
# G4VisExecutive, e.g. /geant4-claude:geant4-example's main with
# UI handed an extra macro.
```

**Impact when working:** the forward-flux-sensor class of bug is
visible at first glance instead of after a 1000-event run.

### 3. `/geant4-claude:geant4-run` writes a `log.md` stub

**Current:** The orchestrator skill prepends a full dated section to
`log.md`. Four of the Outcome fields (run id, status, output path,
duration) are 100% derivable from `runs/<id>/config.json`, so the
skill hand-types values the command already wrote.

**Fix:** `geant4-run` writes a stub `log.md` block at the top with the
mechanical fields filled in and the narrative fields left as `<…>`
placeholders. The orchestrator/Claude fills only Request, Plan,
Decision, and the Notes line.

**Impact:** Removes a mechanical step from post-run housekeeping, and
guarantees the log entry exists even if the session ends before Claude
writes the narrative.

### 4. Run lineage (`--from <prev>` flag + `parent_run` in config.json)

**Current:** `--name <slug>` lets a user mark a re-run, but there's no
machine-readable link from `runs/B/config.json` back to `runs/A/`. The
v1 → v2 → v3 chain lives only in filename suffixes and `log.md` prose.

**Fix:** add `--from runs/<prev>` (and optional `--reason "<text>"`) to
`geant4-run`. When set, record `"parent_run": "<prev_run_id>"` and
`"diff_reason": "<text>"` in `config.json`. This is a contract change
to `config.json` → minor version bump.

**Impact:** Analysis tools and `log.md` readers can walk the chain
mechanically. The orchestrator can render run trees.

### 5. Physics closure validators (`/geant4-claude:geant4-validate <topic>`)

**Current:** Validation of physics correctness (Frank-Tamm yield for
Cherenkov, Bethe-Bloch dE/dx for ionization, Compton edge position,
etc.) happens by hand in `result.md`. The highest-signal part of the
Cherenkov dogfooding session was that closure check — and it was
manual.

**Fix:** new command with a library of canned closure tests. v1
candidates:

- `cherenkov` — Frank-Tamm yield vs. simulated count for a given
  radiator + beam (Poisson agreement).
- `bethe-bloch` — dE/dx of a charged particle through a thin foil
  vs. PDG table value.
- `compton` — Compton edge position in a γ-on-target spectrum.

Each validator reads `runs/<id>/`, makes documented schema
assumptions, and prints PASS/FAIL with the number and tolerance.

**Impact:** The orchestrator (and the user) can confirm a simulation
is physically sane before drawing scientific conclusions.

### 6. ROOT in the pinned image lacks `root-geom` *(accepted, resolved by #2)*

**Current:** `g4run root` works, but `TGeoManager::Import` returns null
— the image is built without `-Droot-geom=ON`. Documented in the
README troubleshooting table.

**Decision:** accept the gap. Users who want a headless geometry view
now have `/geant4-claude:geant4-preview` (item 2), which goes through
Geant4's own viewer and matches what the user sees in interactive vis
sessions. There's no reason to add a parallel ROOT-based renderer.

### 7. `g4run` discoverability outside slash commands

**Current:** `g4run` lives at `${CLAUDE_PLUGIN_ROOT}/bin/g4run`, which
is only set inside slash-command execution. Ad-hoc debugging from a
plain shell requires finding the installed plugin path manually.
Documented in README troubleshooting now.

**Fix (cheap):** at install time, offer to symlink `g4run` into
`~/.local/bin/`. The symlink target uses the plugin's stable install
path (under `~/.claude/plugins/.../geant4-claude/bin/g4run`). Idempotent;
removed on plugin uninstall.

**Impact:** `g4run shell`, `g4run validate-gdml`, and `g4run info` all
become usable from anywhere — particularly useful when debugging an
issue raised by a slash command without leaving the failing terminal.

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
