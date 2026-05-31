---
layout: page
title: Architecture
description: "geant4_claude — architecture, contracts, and the MVP boundary."
permalink: /DESIGN/
---

# DESIGN.md — `geant4_claude`

## Goal

Let any Claude Code user, on any machine with apptainer and Python, **design
a Geant4 detector, run a simulation, and analyze the output** without writing
C++ for the common case. The plugin is **skill-driven and dual-CLI** — it runs
on both Claude Code and Codex from one shared skill set. It contributes:

- a set of skills that drive the full loop (no slash commands — every
  procedure is a skill so it loads on both CLIs),
- a generic Geant4 main that loads any GDML and writes a flat hits TTree,
- a single apptainer wrapper (`bin/g4run`) so the runtime is one swap away,
- focused reference skills with the syntactic knowledge (GDML, physics
  lists, uproot) Claude needs to make good choices.

> **Codex/Claude port (v0.1.0):** all slash commands and the `commands/` and
> `agents/` directories were dropped; every procedure is now a skill. See the
> **Dual-CLI engine contract** subsection for the `.g4c/` pointer mechanism
> that lets one skill set reach `bin/g4run` on a CLI with no plugin-root env
> var and no hooks. Antigravity support remains deferred.

## Non-goals (MVP)

- Replacing a full simulation framework like GEMC or G4Beamline.
- Autonomous experiment optimization or parameter sweeps. (A user's project can
  build that on top.)
- A graphical UI. Visualization happens via Geant4's own viewers inside the
  container, or via post-hoc Python plots.
- Supporting Geant4 versions other than the one pinned in `bin/g4run`.

## User journey (the MVP smoke test)

Each step is a skill. The user describes intent in natural language and the
matching skill loads; there are no slash commands to type on either CLI.

```
$ cd ~/projects/my-detector
$ claude          # or: codex

> set up a Geant4 workspace                       # → geant4-init skill
✓ wrote workspace skeleton (src/, geometries/, macros/, runs/, analysis/, CLAUDE.md, log.md, result.md)
✓ wrote .g4c/ engine pointer (g4run shim + env)
✓ pulled ghcr.io/gemc/g4install:11.4.0-almalinux-9.4 (cached at ${GEANT4_CLAUDE_CACHE}/sif)

> design a 1×1×10 cm lead block in an air world,  # → geant4-detector skill
  tag the lead as sensitive
✓ wrote geometries/lead_block.gdml (validated)

# write src/main.cc + src/CMakeLists.txt for your simulation
# (Claude can draft these from a description of the physics list,
#  sensitive detectors, and output schema you want)

> build my source                                 # → geant4-build skill
✓ built build/<your-binary>

> run it on macros/<your>.mac                      # → geant4-run skill
✓ run 20260508-221045-a3f9c0 finished in 8.2 s
  → runs/20260508-221045-a3f9c0/{<output>.root, log.txt, config.json}

> analyze the latest run                           # → geant4-analyze skill
✓ edep_hist.png  (or analysis/<run_id>.py + tailored plot if the
                   schema isn't `Hits`)
```

The user journey above is the **manual** path — one skill at a time. The
`geant4` orchestrator skill collapses these steps behind a single
natural-language request — see Skill surface below. The orchestrator adds
`geant4-preview` after `geant4-detector` and `geant4-validate` at the
end when a closure validator covers the physics (Cherenkov: Frank-Tamm).
Separately, the `geant4-example` skill drops a self-contained smoke
test into the workspace; useful for confirming the toolchain works on a
fresh install but *not* part of the user's real-simulation journey.

## Architecture

```
                ┌──────────────────────────────────────────────────────────────┐
                │                       user's project                        │
                │  .g4c/  src/  geometries/  macros/  build/  runs/<id>/  analysis/ │
                └──▲──────▲──────────────▲───────▲───────▲───────────────▲────┘
                   │      │              │       │       │ reads         │ writes plots
                   │      │              │       │       │               │
  ┌─────────┐  ┌───┴──┐  ┌┴─────────┐  ┌─┴────┐ ┌┴────┐ │           ┌────┴───────────┐
  │  init   │  │detec-│  │ build    │  │ run  │ │ run │ │           │ analyze        │
  │ skill   │  │ tor  │  │ skill    │  │skill │ │skill│ │           │  skill (host)  │
  └────┬────┘  └──┬───┘  └────┬─────┘  └──┬───┘ └─┬───┘ │           └────┬───────────┘
       │          │           │            │     │     │                │
       │  every skill sources .g4c/env, then calls "${G4RUN}" …         │ python
       │  (.g4c/g4run shim → live bin/g4run; CACHE from env)            │ (uproot,
       │                      │            │     │     │                │  numpy, mpl)
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
  Skills never call it directly by plugin path — they reach it through the
  per-workspace `.g4c/` pointer the `geant4-init` skill writes (see
  **Dual-CLI engine contract**). Everything else above the wrapper is Claude
  prompting + Python.
- **GDML decouples geometry from rebuilds (when the user opts in).** The
  example main parses GDML at runtime, so geometry changes don't require
  recompilation. Users with hardcoded geometry rebuild via the `geant4-build`
  skill.
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
bin/g4run preview <file.gdml> [out_dir]   # 3 orthographic PNGs; --backend=sketch (default, host matplotlib, no container) | raytracer (alpha)
bin/g4run pull / info                     # image management & status
bin/g4run image-tag / sif-name            # echo the pinned image tag / .sif filename (single source of truth)
```

`validate-gdml` (and `preview --backend=raytracer`) build tiny cached
helper binaries (`${CACHE_DIR}/bin/validate_gdml`, `…/preview_gdml`)
from `templates/validate/` and `templates/preview/` on first use;
rebuilds are triggered automatically when the relevant source files
change. The default `preview` sketch backend needs no helper — it is
host-side `scripts/preview_gdml.py`.

`build` and `exec` are content-neutral — `bin/g4run` knows nothing about
the user's CMake target name, output schema, or argument shape. The skills
carry the workspace conventions; the wrapper just runs the container.

`bin/g4run` itself is **unchanged by the dual-CLI port** — it still resolves
its cache from env, with no silent `$HOME` fallback. What changed is *who
sets the env*: instead of each slash command prepending
`GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache"`, every skill now sources
the workspace's `.g4c/env` (written once by `geant4-init`), which exports
`GEANT4_CLAUDE_CACHE` CLI-neutrally. See **Dual-CLI engine contract**.

Internally each subcommand:

1. ensures the `.sif` for the pinned tag exists at `<cache>/sif/…`, pulling
   on first use. The cache resolves to `$GEANT4_CLAUDE_CACHE` (explicit
   override, set by `.g4c/env`) or `$CLAUDE_PLUGIN_DATA/cache` (auto-set by
   Claude Code when the plugin is installed) — both unset is a fatal error
   rather than a silent fallback to `$HOME`. On Codex, where no
   `CLAUDE_PLUGIN_DATA` exists, `.g4c/env` is the *only* source of the cache
   path, which is exactly why `geant4-init` must run first;
2. invokes `apptainer exec --bind <project>,<cache> <sif> bash -lc
   'source /usr/local/bin/docker-entrypoint.sh && <cmd>'`.

The image tag is the only place it appears. Bumping the tag is a minor-version
bump for the plugin.

### Example main (`templates/example/src/geant4_claude_main.cc`)

Shipped as a **smoke-test fixture** and a piece of reference code,
not as a workflow component. The `geant4-example` skill drops
this main + a sample geometry/macro/analysis into a fresh workspace
so the user can run `init → build → run → analyze` end-to-end on a
clean install and confirm the toolchain works. It is **not** the
default binary for users' real simulations — the manual flow
expects the user to write their own `main.cc`. The orchestrator skill
*may* compose this main with `geant4-detector` output
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

That schema is the **example's** contract — the `geant4-analyze` skill checks
for it and falls back to a custom-script path when the user's binary writes
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

## Skill surface

Everything the plugin does is a **skill** — there are no slash commands on
either CLI. Twelve skills split into one orchestrator, eight procedure skills
(the workflow steps), and three reference skills (syntax + judgment, loaded on
demand). Skills auto-load on natural-language triggers; the user never types a
command name.

| Skill | Kind | One-line purpose |
|-------|------|------------------|
| `geant4` | orchestrator | **Full-flow entry point.** Auto-loads on "simulate / build / run / set up a Geant4 …" requests; gap-checks the spec across six fields (goal, geometry, beam, sensitive, output, analysis); presents a brief plan; on approval drives `init → detector → preview → build → run → analyze → validate` in sequence (validate runs when a closure validator covers the physics). The one skill that *drives* a workflow rather than describing one. |
| `geant4-init` | procedure | Scaffold the generic workspace skeleton (`src/`, `geometries/`, `macros/`, `runs/`, `analysis/` plus `CLAUDE.md`/`AGENTS.md`, `.gitignore`, `log.md`, `result.md`, `report.html`); **write the `.g4c/` engine pointer**; bootstrap the venv (`ensure_venv.sh`); pull the pinned image. On first run, also offers (one prompt, plugin-wide) to download the matching Geant4 source tarball into `${GEANT4_CLAUDE_DATA}/geant4-src/`. The keystone — must run before any other procedure skill. |
| `geant4-detector` | procedure | Translate a natural-language detector spec into a validated standalone GDML file under `geometries/` (validated in-container). Output is consumable by any `main.cc` that calls `G4GDMLParser::Read(...)`. Optical specs get RINDEX GDML, gated at parse time. |
| `geant4-example` | procedure | Drop a self-contained smoke test (GDML + macro + generic GDML-loading `main.cc` + analysis script) into the workspace. Used once on a fresh install to confirm the toolchain, or as reference code; also the default binary the orchestrator composes for simple-physics specs. |
| `geant4-preview` | procedure | Render three orthographic PNG previews (XY/YZ/XZ) of a GDML file. Default sketch backend reads `<solids>` + `<structure>` and draws with matplotlib (no container, ~1 s, box/tube/cone/polycone + rotations); raytracer backend is the alpha Geant4-rendered fallback. Orchestrator inserts this after `geant4-detector`. |
| `geant4-build` | procedure | CMake-build the user's source tree (`./src` → `./build`) inside the container via `bin/g4run build`. |
| `geant4-run` | procedure | Execute the user's binary inside the container; allocate `runs/<id>/`; capture generic provenance (executable, args, image, git_sha, duration, exit status). Substitutes `{run_dir}`/`{run_id}` and exports `RUN_DIR`/`RUN_ID`. Includes a **Monitoring long runs** section (the folded-in runner agent) for background runs. |
| `geant4-analyze` | procedure | Inspect the run's ROOT file. Schema-aware fast-path (canned per-event edep histogram) when a `Hits` TTree matching the example schema is found; otherwise generates a custom analysis script tailored to the actual branches. Runs uproot/numpy/matplotlib on the host. |
| `geant4-validate` | procedure | Run a physics closure test (Frank-Tamm Cherenkov yield in v1) against a `runs/<id>/` directory. Compares simulated yield to the analytic prediction, prints PASS/FAIL with sigma, writes `runs/<id>/validate_<topic>.json`. Topics live under `scripts/validators/<topic>.py`. |
| `geant4-geometry` | reference | GDML structure, units, NIST materials, common shapes, placement, validation, `auxiliary sensitive` tags. |
| `geant4-physics-list` | reference | Choosing among FTFP_BERT / QGSP_BIC / etc.; range/step cuts; EM-only vs hadronic vs optical. Holds the in-place optical-main regeneration recipe `geant4-detector`/orchestrator use. |
| `geant4-analysis` | reference | `uproot` recipes (read `Hits` TTree → numpy), common plots (edep histogram, hit map, per-volume sums); adapt branch names for custom schemas. |

Each skill's full contract lives in its `SKILL.md` under `skills/<name>/`. The
reference skills (geometry, physics-list, analysis) are syntax + judgment,
never workflow — loaded on demand by a procedure skill or by `geant4` when it
needs a specific decision. The orchestrator is the one deliberate exception
that sequences the others into a planned run.

### Dual-CLI engine contract

This is the load-bearing design of the v0.1.0 port. The plugin runs on both
**Claude Code** and **Codex** from one skill set, but the two CLIs expose the
runtime differently, and the skills must reach `bin/g4run` without caring which
CLI they're on.

**The constraint (verified on codex v0.135.0):** Codex exposes **no
plugin-root or plugin-data env var** (no `CLAUDE_PLUGIN_ROOT`/`_DATA`
equivalent) and **cannot bundle hooks** — its plugin validator rejects a
`hooks` field outright. So the "find `bin/g4run` via env" trick doesn't work on
Codex. And since the plugin ships no session-start hook on Claude either, the
venv bootstrap is skill-driven on both CLIs (see **venv bootstrap** below).

**The solution — a per-workspace pointer, `.g4c/` (gitignored):** the
`geant4-init` skill resolves the data dir *once*, records how to re-resolve the
plugin root *live*, and writes both into the workspace:

| `.g4c/` entry | What it is |
|---------------|------------|
| `.g4c/g4run` | A `/bin/sh` shim that sources `.g4c/env` and execs `${GEANT4_CLAUDE_ROOT}/bin/g4run` — so the wrapper path is resolved live, never frozen. |
| `.g4c/env` | Exports `GEANT4_CLAUDE_DATA`/`GEANT4_CLAUDE_CACHE` (frozen — under `CLAUDE_PLUGIN_DATA` on Claude or `${XDG_CACHE_HOME:-$HOME/.cache}/geant4_claude` on Codex, both stable across updates) and resolves `GEANT4_CLAUDE_ROOT` **live** every time it is sourced. |

**Why the root is resolved live, not frozen.** Each CLI installs every plugin
version under its own dir, so a path recorded at init would dangle after an
update. `.g4c/env` therefore re-resolves the root on each source, in order:
`CLAUDE_PLUGIN_ROOT` (Claude's live env) → the newest install under
`$CODEX_HOME/plugins/cache/*/geant4-claude/*/` (by mtime — the cache leaf is a
hash, not a sortable version) → the path recorded at init (bare-clone /
standalone fallback). On Claude the live env is authoritative; on Codex the glob
finds the current install with zero re-init. The recorded fallback is how
`geant4-init` itself learned the root: `${CLAUDE_PLUGIN_ROOT}` on Claude, or —
on Codex, which hands the skill its own directory in context — its parent's
parent (`…/skills/geant4-init/` → `…/`).

**The preamble.** Every other skill begins with:

```bash
[ -f .g4c/env ] && . .g4c/env; G4RUN="${G4RUN:-$PWD/.g4c/g4run}"
```

then calls `"${G4RUN}" …`. This sources the cache/root env and resolves the
wrapper through the workspace pointer — so the skill bodies are identical on
both CLIs and never name a CLI-specific env var or path.

**Cache flow keeps `bin/g4run` unchanged.** The wrapper still reads its cache
from `GEANT4_CLAUDE_CACHE` and still treats an unresolvable cache as a fatal
error (no silent `$HOME` fallback). `.g4c/env` is simply the new, CLI-neutral
*source* of that variable, replacing the per-command
`GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache"` prefix the old slash
commands carried. `bin/g4run` itself was not modified for the port.

**venv bootstrap, CLI-neutral.** The dep-install logic lives in
`scripts/ensure_venv.sh` (reads `GEANT4_CLAUDE_ROOT`/`_DATA` with the same
fallbacks). There is no session-start hook on either CLI; instead the skills
that need Python (`geant4-init`, `geant4-analyze`, `geant4-preview`,
`geant4-validate`) call `ensure_venv.sh` directly on first use. It is
idempotent, so repeat calls are a fast no-op. This is identical on Claude and
Codex — the first `geant4-init`/analyze triggers a one-time ~10–30 s install
instead of paying it at session start.

**The invariant (CI-enforced).** No `skills/*` file may reference a
`CLAUDE_*`/`CODEX_*` env var or a `/geant4-claude:` slash name — with one
deliberate exception: `geant4-init`, the keystone that *writes* `.g4c/`, must read
the CLI-native plugin root (`$CLAUDE_PLUGIN_ROOT` on Claude; the injected skill
dir on Codex) to bootstrap. A clean-smoke gate (phase 0d) enforces this:
`CLAUDE_*` is allowed only inside `skills/geant4-init/`, and slash names are
banned everywhere. It's what keeps the skill set genuinely CLI-neutral rather
than Claude-shaped with Codex bolted on.

## Workspace conventions

The `geant4-init` skill writes a **generic skeleton**:

```
my-project/
├── AGENTS.md            # canonical workspace rules (what Codex reads)
├── CLAUDE.md            # symlink → AGENTS.md (so Claude Code reads the same rules)
├── .g4c/                # engine pointer (gitignored): g4run shim + env (see Dual-CLI engine contract)
├── .gitignore           # excludes .g4c/, runs/, *.root, build/, __pycache__/
├── log.md               # chronological work log; Claude appends after each run
├── result.md            # per-run findings; Claude updates after a noteworthy analyze
├── report.html          # single-page browser-friendly summary (overview + runs table + plots + interpretation); self-contained, derived from log.md + result.md + runs/
├── embed_html.py        # stdlib helper: `python3 embed_html.py report.html` → report_portable.html (images base64-embedded for emailing)
├── src/                 # your main.cc + CMakeLists.txt go here (or the geant4-example skill fills it for the smoke test)
├── geometries/          # GDML files, one per detector (optional)
├── macros/              # Geant4 macro files
├── runs/                # one subdir per geant4-run invocation (gitignored)
└── analysis/            # python analysis scripts
```

Plugin-internal scripts and templates (live in the plugin checkout,
*not* in any user workspace):

```
geant4_claude/
├── scripts/ensure_venv.sh   CLI-neutral venv bootstrap. No session-start hook on
│                            either CLI; the skills that need Python call it on first use.
├── templates/validate/      C++ harness for the in-container GDML parse check.
│                            Built on first use; cached under GEANT4_CLAUDE_DATA.
├── templates/preview/       C++ harness for the alpha RayTracer backend
│                            of the geant4-preview skill
│                            (--backend=raytracer; see Hardening backlog).
│                            Default backend lives in scripts/preview_gdml.py.
├── scripts/preview_gdml.py  Host-side sketch backend for the geant4-preview skill.
│                            Stdlib XML + matplotlib. No container call.
└── scripts/validators/      Python validators driven by the geant4-validate skill.
    └── cherenkov.py         v1: Frank-Tamm closure test.
```

The `geant4-example` skill adds the demo on top:

```
my-project/
├── src/
│   ├── geant4_claude_main.cc    # GDML loader + GenericSD + Hits TTree
│   └── CMakeLists.txt           # find_package(Geant4 / ROOT), add_executable
├── geometries/example.gdml      # 1×1×10 cm lead block in air world; sensitive
├── macros/run.mac               # 1 GeV e-, /run/beamOn 1000
└── analysis/example.py          # uproot → per-event edep histogram
```

The `geant4-build` skill writes:

```
my-project/build/<binary>        # gitignored
```

Each directory has a single, well-defined role. Skills and commands assume
this layout. Users can extend it (e.g., `notes/`, `papers/`) but should not
rename these four.

## Versioning & compatibility

- Plugin version: semver, kept identical in **both** `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` (bump together). Currently 0.1.0.
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
the `geant4-run` skill.

**Fix:** ship a tiny C++ harness (e.g. `templates/validate/main.cc`)
that does `G4GDMLParser::Read()` against the file, prints any parser
error, and exits non-zero on failure. Build it on first use inside the
container, cache the binary at `${GEANT4_CLAUDE_CACHE}/bin/`, and
call it from `cmd_validate_gdml` after the xmllint pass.

**Impact:** Geometry errors surface before the `geant4-build`/`geant4-run`
skills, when the fix is "edit the GDML" rather than "read the run log."

### 2. Headless GDML preview (the `geant4-preview` skill)

**Status: shipping in the default sketch backend; RayTracer backend
still alpha.**

**Current:** Two backends behind one skill.

- `--backend=sketch` (default) — `scripts/preview_gdml.py`, pure host
  Python. Stdlib XML parses `<solids>` + `<structure>`, applies a 3D
  rotation+translation per physvol, projects to three orthographic
  planes (XY/YZ/XZ), and renders the 2D convex-hull silhouettes with
  matplotlib. Handles box, tube, cone, polycone, and arbitrary 3D
  rotations. Boolean solids / parameterised volumes draw as bounding
  boxes with a "!" badge so they don't silently disappear. Runs in
  ~1 s on a typical geometry; needs no container. The orchestrator
  skill calls this between `geant4-detector` and `geant4-build`.
- `--backend=raytracer` — `templates/preview/{main.cc, CMakeLists.txt}`,
  cached at `${CACHE_DIR}/bin/preview_gdml`. The helper builds and loads
  the GDML cleanly. **Rendering does not work yet.** With the v11.4
  container's RayTracer driver, three different command sequences
  (combinations of `/vis/open`, `/vis/scene/create`, `/vis/sceneHandler/
  create`, `/vis/viewer/create`, then `/vis/rayTracer/trace`) all
  trigger `G4RTMessenger::SetNewValue: No valid current viewer. Using
  default RayTracer.` and the subsequent `/vis/rayTracer/trace` hangs
  indefinitely.

**Why two backends.** The sketch backend solves the dogfooded user need
("can I tell at a glance whether the sensor is in the forward-flux
path?") without depending on Geant4 vis machinery. It deliberately does
*not* try to be a CAD viewer — convex-hull silhouettes per primitive
trade fidelity for stdlib XML + matplotlib, no GDML library link, no
container round-trip. The RayTracer backend stays in the design so we
can ship exact silhouettes (boolean solids, replicas) once the v11.4
viewer issue is resolved.

**Suspect (RayTracer):** `ApplyCommand`-driven RayTracer setup may not
match what the messenger expects in non-interactive (no G4UIsession)
mode. Worth investigating: (a) install a `G4UIsession` before issuing
vis commands; (b) load the commands via `/control/execute <macro.mac>`
instead of direct `ApplyCommand`; (c) call vis manager APIs
(`vis->CreateSceneHandler`, `vis->CreateViewer`) directly in C++
instead of going through the messenger.

**Impact (sketch shipped):** the forward-flux-sensor class of bug is
visible at first glance instead of after a 1000-event run. Catching
one geometry trap saves the cost of a build + run + analyze cycle and
the user's mental model of "why is the photon count wrong?".

### 3. The `geant4-run` skill writes a `log.md` stub

**Current:** The orchestrator skill prepends a full dated section to
`log.md`. Four of the Outcome fields (run id, status, output path,
duration) are 100% derivable from `runs/<id>/config.json`, so the
skill hand-types values the `geant4-run` skill already wrote.

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

### 5. Physics closure validators (the `geant4-validate` skill, `<topic>`)

**Current:** Validation of physics correctness (Frank-Tamm yield for
Cherenkov, Bethe-Bloch dE/dx for ionization, Compton edge position,
etc.) happens by hand in `result.md`. The highest-signal part of the
Cherenkov dogfooding session was that closure check — and it was
manual.

**Fix:** new skill with a library of canned closure tests. v1
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
now have the `geant4-preview` skill (item 2), which goes through
Geant4's own viewer and matches what the user sees in interactive vis
sessions. There's no reason to add a parallel ROOT-based renderer.

### 7. `g4run` discoverability outside an initialized workspace

**Largely addressed by the port.** Inside any initialized workspace,
`.g4c/g4run` is a shim that resolves the current `bin/g4run` live and `.g4c/env`
carries the cache path, so ad-hoc debugging is just `. .g4c/env; .g4c/g4run
shell`. The old "the path only exists inside slash-command execution" problem is
gone, and a plugin update no longer strands the workspace.

**Remaining (cheap):** for use *outside* a workspace, optionally offer at
install time to symlink `g4run` into `~/.local/bin/` (target: the plugin's
stable install path). Idempotent; removed on plugin uninstall.

**Impact:** `g4run shell`, `g4run validate-gdml`, and `g4run info` become
usable from any directory, not just an initialized workspace.

### 8. `report.html` refresh is skill-driven, not deterministic

**Current:** `report.html` is a derived presentation layer, but nothing
refreshed it. The `geant4-run` skill only wrote a `log.md` stub; the
`geant4-analyze` skill never mentioned `report.html`; the sole "update it"
instruction lived in the workspace `CLAUDE.md` and was never triggered in
the skill flow. Result: the browser report stayed at placeholders forever.

**Fix:** the `geant4-run` and `geant4-analyze` skills now explicitly
instruct Claude to refresh `report.html` in place — run fills the Runs
table / Beam&physics / header date, analyze adds plots / key numbers /
interpretation. Idempotent (update the row/figure, don't duplicate).

**Tradeoff (accepted):** this is LLM-driven, not a deterministic
generator. It depends on Claude obeying the skill step, so it can
still be skipped under context pressure. A stdlib `build_report.py`
that regenerates the mechanical sections from `runs/*/config.json`
remains the robust alternative if drift recurs — parked here, not
built, by maintainer decision.

### 9. Cherenkov-yield topology + validator window correction

**Current (bug):** `geant4-detector` and orchestrator gate #1 steered
every optical spec to a *downstream sensitive backplate* with the
radiator left non-sensitive. The Frank-Tamm closure is a
**production-yield** check, so it can only close when photons are
counted *as produced* (inside the radiator). A backplate count is
production × acceptance × losses — never closable. CI passed only
because the fixture (correctly) tags the radiator sensitive — i.e. CI
tested a topology the docs told users *not* to build. Independently,
`cherenkov.py` integrated a fixed 200–800 nm window even with
`--rindex-from-gdml`, while Geant4 radiates over the full RINDEX-matrix
energy span → a spurious ~1% FAIL at high stats.

**Fix:** the SD/`OpticalSD` code and the fixture are correct as-is and
unchanged — the defect was guidance. `geant4-detector` now tags the
**radiator** sensitive for yield specs; a downstream plane is an
explicit opt-in for collection/ring-imaging specs only (and there, all
traversed volumes get a flat transport RINDEX so photons survive
boundary crossings — the long-standing #2 latent bug for that path).
Orchestrator gate #1 reworded: the forward-flux concern does not apply
to `OpticalSD` (it filters to optical photons). `cherenkov.py` now
defaults the integration window to the RINDEX matrix span when
`--rindex-from-gdml` is given; explicit `--wavelength-min/max` still
override; 200–800 nm remains the `--refractive-index` fallback.
Zero-hit runs are now a surfaced failure (analyze step 5 guard +
orchestrator postcondition), not a silent empty plot.

**Contract change:** optical specs default to radiator-sensitive (was
backplate-sensitive); `cherenkov.py` default window is data-derived
under `--rindex-from-gdml` (was fixed 200–800 nm). The smoke gate is
unaffected — it passes the window explicitly and the fixture topology
was already correct.

## Open questions (parked, do not block MVP)

- **Sensitive detectors via aux tags vs. C++.** Lean: aux tags only for MVP;
  expose a C++ extension hook in v2 so users with custom scoring can register
  their own SD without forking the main.
- **Scoring meshes vs. SD hits.** Lean: SD hits only for MVP. Adding scoring
  meshes would mean a second TTree contract; defer until a real user asks.
- **Experiment log / sweep skill.** Out of MVP. A `geant4-sweep` skill that
  parameterizes one knob across runs is the obvious next step, but it adds
  schema (sweep manifests, joined analysis) and is best added after one real
  user has lived with the current MVP.

## MVP boundary — what real Geant4 apps do that v0.0.1 doesn't

`geant4_claude` v0.0.1 is intentionally narrow. This section maps what real Geant4 apps do that the plugin does not yet support, synthesized from reading 38 canonical Geant4 examples. Each item is an honest gap, not a bug. They define the upgrade roadmap.

### 1. Runtime-selectable physics list

**What real apps do:** `G4PhysListFactory` keyed off `argv` or a `PHYSLIST` env var. See [physics-list-factory](../wiki/sources/geant4-code/synthesis/physics-list-factory.md) in the wiki.

**What we do:** Hard-code `new FTFP_BERT(0)`.

**Impact on users:** Users of the example main with non-standard physics needs (HP neutrons, optical photons, radioactive decay, medical dosimetry) must edit their copy of `src/geant4_claude_main.cc` (placed by the `geant4-example` skill) and re-run the `geant4-build` skill. Users with their own `main.cc` already wire whatever physics list they need. This friction is the single biggest barrier for new users coming in via `geant4-example`.

**Upgrade path:** `--physics-list <name>` input to the `geant4-run` skill, plus `--extra-physics <comma-list>` for additive constructors. Logged in `config.json`. Single CLI surface. Estimated: ~50 lines of C++ + skill update.

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

### Python deps via `scripts/ensure_venv.sh` (currently: `pdg`)

`requirements.txt` at the plugin root is installed into a managed venv by the
**CLI-neutral** bootstrap `scripts/ensure_venv.sh`. It diffs the bundled
`requirements.txt` against a stored copy under the data dir and reinstalls only
when they differ — so first call installs, later calls are a ~10 ms no-op. uv is
preferred when available; falls back to `python3 -m venv` + pip.

What triggers it is identical on both CLIs: the plugin ships **no session-start
hook**, so the `geant4-init`, `geant4-analyze`, `geant4-preview`, and
`geant4-validate` skills call `ensure_venv.sh` directly on first use. It's
idempotent, so it's a no-op once in sync. The first `geant4-init`/analyze pays
a one-time ~10–30 s install instead of it happening at session start.

The venv path resolves CLI-neutrally: `${GEANT4_CLAUDE_DATA}/venv` (from
`.g4c/env`), falling back to `${CLAUDE_PLUGIN_DATA}/venv`, then
`${XDG_CACHE_HOME:-$HOME/.cache}/geant4_claude/venv`. On Claude Code the venv
survives session restarts and plugin updates and is deleted on uninstall (plugin
lifecycle).

**Calling pattern** for skills or Bash (after sourcing `.g4c/env`):

```bash
"${GEANT4_CLAUDE_DATA}/venv/bin/python" -c "import pdg; ..."
```

The current `requirements.txt` carries `pdg>=0.2.2` only. Add a package only when something in `skills/`/`scripts/` actually imports it; touching `requirements.txt` triggers reinstall on the next `ensure_venv.sh` call.

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

### Distribution: dual manifest + marketplace + optional source-tree clone

**Dual manifest.** The port ships two plugin manifests so one repo installs on
both CLIs:

| File | For | Notes |
|------|-----|-------|
| `.claude-plugin/plugin.json` | Claude Code | Standard plugin manifest. |
| `.codex-plugin/plugin.json` | Codex | Adds an `interface` block (display name, category, default prompts). **No `hooks` field** — Codex's validator rejects it. Neither manifest ships a hook; `ensure_venv.sh` is called from the skills on both CLIs. |

Both are at version **0.1.0** and **must be bumped together** — a single semver
for the plugin regardless of CLI.

**Self-hosted marketplaces (one per CLI).** The repo doubles as a single-plugin
marketplace on both:

| File | For | Install path |
|------|-----|--------------|
| `.claude-plugin/marketplace.json` | Claude Code | `/plugin marketplace add zhaozhiwen/geant4_claude` + `/plugin install geant4-claude@geant4-claude`. Entry uses `"source": "./"`. |
| `.agents/plugins/marketplace.json` | Codex | Entry uses a `local` source (`"path": "."`). |

Marketplace name matches the plugin name (`geant4-claude`) everywhere — all four
files require kebab-case, and keeping the identifier identical means users
remember one name. Don't rename after release; it breaks every existing install.

**Known limitation — Codex one-command install (deferred).** Codex's marketplace
packages a plugin only from a `plugins/<name>/` **subdirectory of real files**
(its snapshot copies the subdir and silently skips symlinks; it refuses to
snapshot the marketplace root itself). This plugin lives at the repo root, so
`codex plugin add geant4-claude@geant4-claude` won't snapshot it as-is — the
`.agents/plugins/marketplace.json` `path: "."` documents intent but doesn't
package. The **runtime is fully validated** on `codex` v0.135.0 (skill discovery,
plugin-root resolution from the injected skill dir, the `.g4c/` pointer, and the
`ensure_venv.sh` bootstrap all work once installed). Closing the gap needs either
a release step that materializes `plugins/geant4-claude/` (real files) for Codex,
or moving the plugin into that subdir and pointing both marketplaces at it. See
the spec's "Codex packaging" decision.

**Optional Geant4 source clone.** The wiki's `sources/geant4-code/synthesis/` pages cite `.cc:line` ranges. Those citations are only verifiable if the Geant4 source tree is locally present. The canonical location is `${GEANT4_CLAUDE_DATA}/geant4-src/` (resolved CLI-neutrally via `.g4c/env`) so the tree survives plugin version bumps (the plugin checkout is replaced on update; the data dir is not). The `geant4-init` skill maintains a symlink at `${GEANT4_CLAUDE_ROOT}/wiki/raw/geant4-src` pointing at the canonical tree so wiki pages can keep using the relative `wiki/raw/geant4-src/...` path; the symlink is recreated on every `geant4-init` run because plugin updates wipe the previous checkout. To keep fresh-clone size small, the tree is **gitignored** and not shipped. `geant4-init` detects whether the tree is already there and, if missing, asks the user once whether to download the matching source tarball from GitHub releases (`https://github.com/Geant4/geant4/archive/refs/tags/v<VERSION>.tar.gz`). The tag is derived from `bin/g4run`'s pinned image (single source of truth) so a container bump automatically asks for a matching source bump. Idempotent: subsequent `geant4-init` runs in other workspaces detect the existing tree and skip the prompt; pre-relocation installs (real directory at the legacy path) are auto-migrated on the next call when the destination is empty.
