# geant4_claude

A plugin that lets you **build, run, and analyze your own Geant4
simulation** by describing what you want in plain language — no slash
commands, no menu. You say "set up a Geant4 workspace" or "simulate a
1 GeV e⁻ on a lead block" and the matching **skill** auto-triggers.
Works on **both Claude Code and OpenAI Codex CLI** with the same skills,
the same engine, and the same analysis stack. Geant4 and ROOT live in a
pinned apptainer image; analysis runs on the host with
[`uproot`](https://github.com/scikit-hep/uproot5).

> Status: **v0.1.0**. Everything is a skill now — the plugin ships no
> slash commands. Twelve skills cover the flow: **geant4** (the
> orchestrator / front door), **geant4-init**, **geant4-detector**,
> **geant4-example**, **geant4-preview**, **geant4-build**,
> **geant4-run**, **geant4-analyze**, **geant4-validate**, plus the
> reference skills **geant4-geometry**, **geant4-physics-list**, and
> **geant4-analysis**. The procedural skills are content-neutral — they
> accept any user-supplied `main.cc` and any output schema. The
> geant4-detector skill writes standalone GDML (including an
> optical/RINDEX path) for use with whatever `main.cc` you bring. The
> geant4-example skill is a self-contained smoke test that drops a
> working demo into the workspace so you can confirm the toolchain works
> on your machine before writing any of your own code.

## Works on Claude Code and Codex CLI

Same skills, same engine (`bin/g4run` via apptainer), same host-side
`uproot` analysis. You drive the plugin by describing tasks in natural
language; the relevant skill triggers on its own.

**Claude Code:**

```text
/plugin marketplace add zhaozhiwen/geant4_claude
/plugin install geant4-claude@geant4-claude
```

**Codex CLI:**

```text
codex plugin marketplace add zhaozhiwen/geant4_claude
codex plugin add geant4-claude@geant4-claude
```

> **Codex one-command install is a work in progress.** Codex's marketplace only
> packages a plugin from a `plugins/<name>/` subdirectory of *real files*, and
> this plugin currently lives at the repo root — so the `plugin add` above won't
> snapshot it as-is. Until a Codex packaging step lands, install by copying the
> plugin into a subdir the marketplace points at (`plugins/geant4-claude/`).
> **Once installed, the plugin runs fully on Codex** — skill discovery, the
> `.g4c/` engine pointer, and the `ensure_venv.sh` venv bootstrap are all
> verified on `codex` v0.135.0.

How skills find the engine, CLI-neutrally: the **geant4-init** skill
scaffolds your workspace and records an engine pointer at `.g4c/` (a
symlink to `bin/g4run` plus an `env` file), so every other skill locates
the runtime the same way on either CLI. On both CLIs, geant4-init also
bootstraps the Python venv on first scaffold — the plugin ships no
session-start hook, so the install is skill-driven and lazy.

## Requirements

- [apptainer](https://apptainer.org) ≥ 1.4 on Linux.
- Python 3.9+ on the host with `uproot numpy matplotlib`
  (only needed for the geant4-analyze skill).
- ~2.5 GB of disk for the cached container image.
- Claude Code or OpenAI Codex CLI with plugin support.

The plugin will pull
`docker://ghcr.io/gemc/g4install:11.4.0-almalinux-9.4` on first use; the
tag is pinned in [`bin/g4run`](bin/g4run) and nowhere else (read it back
with `bin/g4run image-tag`).

## Install

See [**Works on Claude Code and Codex CLI**](#works-on-claude-code-and-codex-cli)
above for the install lines. On Claude Code, the marketplace-add command
registers this repo as a marketplace (it ships
`.claude-plugin/marketplace.json` alongside the plugin manifest) and the
install command pulls the plugin from it; `/plugin update` handles
upgrades.

Manual git clone (either CLI):

```bash
git clone https://github.com/zhaozhiwen/geant4_claude.git ~/.claude/plugins/geant4_claude
# then enable it in your CLI's plugin manager
```

> If you cloned a fork, replace `zhaozhiwen` accordingly. The plugin manifest is at `.claude-plugin/plugin.json`.

## What happens when you enable the plugin

Two things get set up automatically — neither needs your action beyond approving once. The first is registered when the CLI loads the plugin; the second is seeded lazily on first use:

1. **deepwiki MCP server** is registered from `.mcp.json`. Claude Code prompts once to approve the external server (`https://mcp.deepwiki.com/mcp`, no auth, no key); approve it and Claude gains three tools (`mcp__deepwiki__ask_question`, `read_wiki_structure`, `read_wiki_contents`) for asking Geant4 questions in-loop. Used by the plugin as orientation only — answers are LLM-grounded and must be verified against actual Geant4 source before they land in any synthesis. See [docs/DESIGN.md](docs/DESIGN.md) §"deepwiki MCP".

2. **`pdg` Python package** is seeded into a managed venv at `~/.claude/plugins/data/<plugin-id>/venv/` by `scripts/ensure_venv.sh`, which the skills that need Python call directly — the first `geant4-init`/analyze/preview/validate triggers it. This works identically on both CLIs: there is no `SessionStart` hook and no session-start pip-approval prompt. The first such call takes ~10–30 s while pip pulls `pdg` + `sqlalchemy` (~50 MB on disk); later calls are a 3 ms diff/no-op. The venv lives outside this repo, survives plugin updates, and is deleted automatically when you uninstall the plugin. Used by the plugin to look up PDG particle data on demand. See [docs/DESIGN.md](docs/DESIGN.md) §"Python deps via `scripts/ensure_venv.sh`".

If you'd rather opt out: remove `.mcp.json` and/or `requirements.txt` from your local clone before enabling the plugin. Neither is required for the skills to work.

On both CLIs the venv is bootstrapped by the **geant4-init** skill the first time you scaffold a workspace (it's idempotent), and re-checked by analyze/preview/validate on first use.

The first time you run the **geant4-init** skill it will additionally **ask once** whether to download the Geant4 source tarball (matching the pinned container's version, ~36 MB compressed / ~200 MB extracted) from GitHub releases into `${CLAUDE_PLUGIN_DATA}/geant4-src/`, with a symlink at `<plugin>/wiki/raw/geant4-src` so wiki page references keep working. The data-dir location means the tree survives plugin version bumps. Optional — say *Skip* and the skills still work. Saying *Yes* is what lets the assistant verify the wiki's `.cc:line` citations against actual Geant4 code when you ask Geant4-mechanics questions. Re-run the geant4-init skill later to be asked again.

## Quickstart — describe the task, the skill runs

There is no slash menu and no command to memorize. You describe what you
want in plain language; the matching skill auto-triggers (on both Claude
Code and Codex). The **geant4** orchestrator skill is the front door for
any "simulate / build / run a Geant4 …" request — it captures the spec,
asks targeted clarifying questions if anything's missing, shows a brief
plan for your approval, and then drives the step skills in sequence:
`init → detector → preview → build → run → analyze → validate`.

### A. Describe what you want to simulate (recommended)

Just say what you want. Example prompt:

```text
> Create a Cherenkov simulation: a 1×1×1 m CO2 gas radiator at 1 atm,
  1 GeV e- beam along the central axis, ideal downstream flux backplate
  collects photons, ROOT output, then analyze with a 1-D photon-count
  histogram and a 2-D photon (x, y) distribution. Finally use Cherenkov
  physics analytic calculation to predict the photon distribution and
  compare to the simulation result.

[The geant4 orchestrator skill loads, fills in defaults (FTFP_BERT +
optical physics, 1000 events, 2 m air world), shows a plan, asks for
approval, then runs the flow end-to-end by triggering each step skill.]
```

A clear input is what makes the difference between a working sim and a
dozen clarifying turns. Six fields the skill needs from you: **physics
goal**, **geometry**, **beam**, **sensitive surfaces**, **output**, and
**analysis**. If any of those are missing or ambiguous, the skill asks
before doing anything destructive.

### B. Try the shipped example end-to-end (smoke test)

The shortest path to seeing the whole flow work. Drops a complete,
runnable demo (1 × 1 × 10 cm lead block, 1 GeV e⁻ beam, edep
histogram) into a fresh workspace and runs it as-is. Useful **once**
on a clean install to confirm apptainer, the cached image, and the
host-side Python stack all work; not a flow you'd use for your real
simulation. Just describe each step — the named skill triggers:

```text
> Set up a Geant4 workspace.
  → the geant4-init skill runs
✓ wrote workspace skeleton (src/, geometries/, macros/, runs/, analysis/, CLAUDE.md, log.md, result.md, report.html)
✓ recorded engine pointer .g4c/  (symlink to bin/g4run + env)
✓ pulled image  → ${CLAUDE_PLUGIN_DATA}/cache/sif/g4install_11.4.0-almalinux-9.4.sif

> Drop in the shipped example.
  → the geant4-example skill runs
✓ wrote src/{geant4_claude_main.cc, CMakeLists.txt}, geometries/example.gdml,
  macros/run.mac, analysis/example.py

> Build it.
  → the geant4-build skill runs
✓ build/geant4_claude_main

> Run it.
  → the geant4-run skill runs
[g4c] attached SD to 1 sensitive volume(s)
[g4c] run ended: 1000 events written to runs/<run_id>/hits.root

> Analyze the latest run.
  → the geant4-analyze skill runs
✓ runs/<run_id>/edep_hist.png
  events = 1000, total hits = 1.2M, mean edep = 640 MeV/event
```

The example files are self-contained — keep them as reference or
delete them when you start writing your own.

### C. Build your own simulation manually

For your real simulation. Write the `main.cc` that implements your
physics; ask for geometry from a natural-language detector spec and the
**geant4-detector** skill handles it. Name the steps explicitly, or let
the **geant4** orchestrator sequence them for you:

```text
> Set up a Geant4 workspace.          → geant4-init (one-time: skeleton + .g4c/ + image pull)

> Build a detector: <plain-English geometry spec>.   → geant4-detector writes geometries/<name>.gdml
# write src/main.cc + src/CMakeLists.txt for your simulation
# (you can ask the assistant to draft these from a description of the
#  physics list, sensitive detectors, and output schema you want)

> Build my simulation.                → geant4-build
> Run it on <your args>.              → geant4-run
> Analyze the latest run.             → geant4-analyze
```

The **geant4-detector** skill writes standalone GDML that any Geant4
application can load via `G4GDMLParser::Read`. The **geant4-run** skill
is content-neutral: it allocates `runs/<id>/`, exports `RUN_DIR`/`RUN_ID`,
substitutes `{run_dir}` / `{run_id}` placeholders in your args, captures
provenance, and runs whatever binary you point at inside the pinned
container. The **geant4-analyze** skill inspects the resulting ROOT
file's schema and either uses the canned `Hits`-TTree plot (if your
`main.cc` happens to use that schema) or generates a custom analysis
script in `analysis/<run_id>.py` tailored to whatever branches it
actually found.

## Layout

```
geant4_claude/
├── CLAUDE.md                     plugin maintainer rules
├── docs/DESIGN.md                architecture + MVP boundary
├── .claude-plugin/plugin.json    plugin manifest
├── .mcp.json                     deepwiki MCP server (auto-loaded)
├── requirements.txt              Python deps (pdg) installed by scripts/ensure_venv.sh (called by the skills)
├── scripts/ensure_venv.sh        CLI-neutral venv bootstrap (no session-start hook)
├── bin/g4run                     the only bridge to apptainer
├── skills/                       all 12 skills — geant4 (orchestrator), -init, -detector,
│                                 -example, -preview, -build, -run, -analyze, -validate,
│                                 + reference: -geometry, -physics-list, -analysis
├── agents/geant4-runner.md       subagent for long sims
├── templates/workspace/          empty skeleton the geant4-init skill copies in
├── templates/example/            opt-in demo the geant4-example skill copies in
│   └── src/                      geant4_claude_main.cc + CMakeLists.txt
└── wiki/                         Geant4 + physics knowledge base (Obsidian vault)
```

## Knowledge base (`wiki/`)

The plugin ships a curated knowledge base on Geant4 mechanics and the physics it implements (toolkit lifecycle, GDML wiring, sensitive-detector dispatch, EM/optical/hadronic processes, the PDG "Passage of Particles Through Matter" review chapter mapped to specific Geant4 model classes, and more). It's structured as an Obsidian vault: open `wiki/` in [Obsidian](https://obsidian.md) to get backlinks, graph view, and `[[wikilink]]` autocomplete; or read it as plain markdown. See `wiki/index.md` for the full catalog. The assistant pulls from this wiki when answering Geant4 questions through any of the skills.

## What goes in the user's project

The **geant4-init** skill scaffolds an empty skeleton:

```
my-project/
├── CLAUDE.md          rules for Claude inside this workspace
├── .gitignore         excludes runs/, *.root, build/, __pycache__/
├── log.md             chronological work log (Claude appends after each run)
├── result.md          per-run findings (Claude updates after a noteworthy analyze)
├── report.html        single-page browser-friendly summary (overview + runs table + plots + interpretation)
├── embed_html.py      stdlib helper: convert report.html into a single-file report_portable.html (images base64-embedded) for emailing
├── src/               your main.cc + CMakeLists.txt go here
├── geometries/        GDML files (optional; if you load geometry at runtime)
├── macros/            Geant4 .mac files
├── .g4c/              engine pointer (symlink to bin/g4run + env; gitignored)
├── runs/              one sub-dir per geant4-run (gitignored)
└── analysis/          uproot scripts
```

It also writes a `CLAUDE.md` symlink to `AGENTS.md` (the canonical
in-workspace rules) so Claude Code reads the same rules, and records
`.g4c/` — the engine pointer every
other skill reads to locate `bin/g4run` and the cache, CLI-neutrally.

The **geant4-example** skill is independent of the manual flow
above. It drops a self-contained demo (GDML + macro + a generic
GDML-loading `main.cc` + analysis script) into the workspace, useful
for confirming the toolchain works on your machine before you write
any of your own code. Treat the dropped files as smoke-test fixtures
or reference material — when you're ready, write your own
`src/main.cc` and your own `analysis/*.py`.

The directory layout is opinionated — the skills assume those
names. `log.md`, `result.md`, and `report.html` are starter handoff
documents the assistant maintains as the project evolves: the two
markdown files are the authoritative records (versioned, easy to diff);
`report.html` is the browser-friendly presentation layer derived from
them — open it locally with `file://` to share a snapshot of the
project with a collaborator who isn't in the CLI.

## Design highlights

- **Everything is a skill — no slash commands.** You describe the task in
  natural language and the matching skill auto-triggers, identically on
  Claude Code and Codex. The `.g4c/` engine pointer written by geant4-init
  is what lets every skill find `bin/g4run` CLI-neutrally.
- **`geant4` orchestrator skill is the highlighted entry point.** Auto-loads
  on natural-language simulation requests; gap-checks the user's spec across
  six fields (goal, geometry, beam, sensitive, output, analysis); presents
  a brief plan; on approval drives the step skills end-to-end with
  stop-on-failure post-condition checks at each step.
- **NL-driven geometry as a first-class step.** The **geant4-detector**
  skill turns a plain-English detector spec into a standalone, validated
  GDML file that any Geant4 `main.cc` can `G4GDMLParser::Read`. Geometry
  edits don't trigger a rebuild — change the GDML, re-run.
- **Single runtime seam.** Every Geant4, ROOT, CMake, or g++ call goes
  through `bin/g4run`. The container tag lives in that script alone.
- **Content-neutral wrapper.** `bin/g4run` knows nothing about the user's
  CMake target name, output schema, or argument shape. It just CMake-builds
  whatever source you point at, and execs whatever binary you point at,
  inside the pinned container.
- **Per-user data dir.** The runtime cache (`.sif`) and any optional
  Geant4 source clone live under `${CLAUDE_PLUGIN_DATA}/`, so they
  survive plugin version bumps.
- **Schema-aware analysis.** The **geant4-analyze** skill inspects the ROOT
  file and either uses the canned `Hits`-TTree plot (example schema) or
  generates a custom analysis script tailored to the actual branches.
- **Analysis on the host with `uproot`.** No host-side ROOT install
  required. ROOT remains available inside the container via
  `g4run root <macro>`.

For the full architecture, see [docs/DESIGN.md](docs/DESIGN.md).

## Troubleshooting

| Symptom | Try |
|---------|-----|
| `apptainer: command not found` | Install apptainer first. |
| `pull` hangs or 401 | Check network; `ghcr.io/gemc/g4install` is public. |
| `G4GDML: ERROR: ...` | `g4run validate-gdml <file>`; consult the `geant4-geometry` skill. |
| `ModuleNotFoundError: uproot` (analyze step) | Re-run the geant4-analyze skill — it seeds the plugin-managed venv (`${CLAUDE_PLUGIN_DATA}/venv`) automatically. On Codex, re-run geant4-init to bootstrap the venv. Do not `pip install --user` (pollutes host site-packages). |
| Empty `Hits` tree | No volume has the sensitive aux tag, or gun energy is zero. |
| Build fails | `g4run shell` and try `cmake -S /…/src -B /tmp/build` manually to see the real cmake error. |
| `TGeoManager::Import` returns null in container ROOT | The pinned image's ROOT 6.38 is built without `root-geom`. To preview geometry, load the GDML inside Geant4's own viewer via `g4run shell` and a `vis.mac` macro, not via ROOT. |
| `g4run: command not found` in a plain shell | The plugin doesn't touch your shell `$PATH`. Inside a workspace, the geant4-init skill records `.g4c/g4run` (a symlink to the installed `bin/g4run`); skills resolve it from there. For ad-hoc use, invoke `.g4c/g4run` by path or symlink it to `~/.local/bin/g4run`. |
| `g4run validate-gdml` passes but the run crashes on the GDML | The validator does an xmllint pass plus a `G4GDMLParser::Read` pass, but the parser does not do schema validation (the schema is hosted on the web and not always reachable in sandboxes), so a typo'd unit name like `unit="milimeter"` can still slip through as a warning. Check `runs/<id>/log.txt` for the underlying Geant4 message. |

## License

[MIT](LICENSE) — © 2026 Zhiwen Zhao.

## Acknowledgments

- **Geant4** — the simulation toolkit this plugin drives. See
  [geant4.web.cern.ch/about](https://geant4.web.cern.ch/about) for the
  project's history, scope, and citation policy. Any publication that
  uses simulation output produced through this plugin should cite the
  Geant4 Collaboration's references (NIM A 506 (2003) 250-303;
  IEEE-TNS 53 (2006) 270-278; NIM A 835 (2016) 186-225).
- **`g4install` container** — built and maintained at Jefferson Lab;
  see [jeffersonlab.github.io/g4home](https://jeffersonlab.github.io/g4home).
  The plugin pins a specific tag of that image; bumping the tag is a
  minor version bump for `geant4_claude`.
