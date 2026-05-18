# geant4_claude

A Claude Code plugin that lets you **build, run, and analyze your
own Geant4 simulation** through five slash commands plus a `geant4`
orchestrator skill that turns a natural-language description of a
simulation into a planned end-to-end run. Geant4 and ROOT live in a
pinned apptainer image; analysis runs on the host with
[`uproot`](https://github.com/scikit-hep/uproot5).

> Status: **v0.0.6**. Eight commands (`init`, `detector`, `preview`,
> `example`, `build`, `run`, `analyze`, `validate`) are content-neutral —
> they accept any user-supplied `main.cc` and any output schema.
> `/geant4-claude:geant4-detector` writes standalone GDML (including an
> optical/RINDEX path) for use with whatever `main.cc` you bring.
> `/geant4-claude:geant4-example` is a self-contained smoke test that
> drops a working demo into the workspace so you can confirm the
> toolchain works on your machine before writing any of your own code.

## Requirements

- [apptainer](https://apptainer.org) ≥ 1.4 on Linux.
- Python 3.9+ on the host with `uproot numpy matplotlib`
  (only needed for `/geant4-claude:geant4-analyze`).
- ~2.5 GB of disk for the cached container image.
- Claude Code with plugin support.

The plugin will pull
`docker://ghcr.io/gemc/g4install:11.4.0-almalinux-9.4` on first use; tag
is pinned in [`bin/g4run`](bin/g4run).

## Install

### Option A — via Claude Code marketplace (recommended)

In Claude Code:

```text
/plugin marketplace add zhaozhiwen/geant4_claude
/plugin install geant4-claude@geant4-claude
```

The first command registers this repo as a marketplace (it ships
`.claude-plugin/marketplace.json` alongside the plugin manifest). The
second installs the plugin from it. `/plugin update` handles upgrades.

### Option B — manual git clone

```bash
git clone https://github.com/zhaozhiwen/geant4_claude.git ~/.claude/plugins/geant4_claude
# then enable it in Claude Code's plugin manager
```

> If you cloned a fork, replace `zhaozhiwen` accordingly. The plugin manifest is at `.claude-plugin/plugin.json`.

## What happens when you enable the plugin

Two things install automatically the first time Claude Code loads the plugin — neither needs your action beyond approving once:

1. **deepwiki MCP server** is registered from `.mcp.json`. Claude Code prompts once to approve the external server (`https://mcp.deepwiki.com/mcp`, no auth, no key); approve it and Claude gains three tools (`mcp__deepwiki__ask_question`, `read_wiki_structure`, `read_wiki_contents`) for asking Geant4 questions in-loop. Used by the plugin as orientation only — answers are LLM-grounded and must be verified against actual Geant4 source before they land in any synthesis. See [docs/DESIGN.md](docs/DESIGN.md) §"deepwiki MCP".

2. **`pdg` Python package** auto-installs into a managed venv at `~/.claude/plugins/data/<plugin-id>/venv/` via a `SessionStart` hook (`hooks/install-deps.sh`). First session takes ~10–30 s while pip pulls `pdg` + `sqlalchemy` (~50 MB on disk); later sessions are a 3 ms diff/no-op. Claude Code may ask you to approve the hook running `pip install` on your machine. The venv lives outside this repo, survives plugin updates, and is deleted automatically when you uninstall the plugin. Used by the plugin to look up PDG particle data on demand. See [docs/DESIGN.md](docs/DESIGN.md) §"Python deps via SessionStart hook".

If you'd rather opt out: remove `.mcp.json` and/or `requirements.txt` from your local clone before enabling the plugin. Neither is required for the commands to work.

The first `/geant4-claude:geant4-init` you run will additionally **ask once** whether to download the Geant4 source tarball (matching the pinned container's version, ~36 MB compressed / ~200 MB extracted) from GitHub releases into `${CLAUDE_PLUGIN_DATA}/geant4-src/`, with a symlink at `<plugin>/wiki/raw/geant4-src` so wiki page references keep working. The data-dir location means the tree survives plugin version bumps. Optional — say *Skip* and the commands still work. Saying *Yes* is what lets Claude verify the wiki's `.cc:line` citations against actual Geant4 code when you ask Geant4-mechanics questions. Re-run `/geant4-claude:geant4-init` later to be asked again.

## Quickstart

The plugin offers three independent paths to a working simulation —
pick whichever matches what you're trying to do.

### A. Describe what you want to simulate (recommended)

Tell Claude what you want — the `geant4` skill auto-loads on any
"simulate / build / run a Geant4 …" request, asks targeted clarifying
questions if the spec is incomplete, shows a brief plan for your
approval, and then drives `init → detector → build → run → analyze`
in sequence.

```text
> Create a Cherenkov simulation: a 1×1×1 m CO2 gas radiator at 1 atm,
  1 GeV e- beam along the central axis, ideal downstream flux backplate
  collects photons, ROOT output, then analyze with a 1-D photon-count
  histogram and a 2-D photon (x, y) distribution. Finally use Cherenkov
  physics analytic calculation to predict the photon distribution and
  compare to the simulation result.

[Claude reads your request, fills in defaults (FTFP_BERT + optical physics,
1000 events, 2 m air world), shows a plan, asks for approval, then runs
the flow end-to-end.]
```

A clear input is what makes the difference between a working sim and a
dozen clarifying turns. Six fields the skill needs from you: **physics
goal**, **geometry**, **beam**, **sensitive surfaces**, **output**, and
**analysis**. If any of those are missing or ambiguous, the skill asks
before doing anything destructive.

### B. Try the shipped example end-to-end (smoke test)

The shortest path to seeing all five commands work. Drops a complete,
runnable demo (1 × 1 × 10 cm lead block, 1 GeV e⁻ beam, edep
histogram) into a fresh workspace and runs it as-is. Useful **once**
on a clean install to confirm apptainer, the cached image, and the
host-side Python stack all work; not a flow you'd use for your real
simulation.

```text
> /geant4-claude:geant4-init
✓ wrote workspace skeleton (src/, geometries/, macros/, runs/, analysis/, CLAUDE.md, log.md, result.md, report.html)
✓ pulled image  → ${CLAUDE_PLUGIN_DATA}/cache/sif/g4install_11.4.0-almalinux-9.4.sif

> /geant4-claude:geant4-example
✓ wrote src/{geant4_claude_main.cc, CMakeLists.txt}, geometries/example.gdml,
  macros/run.mac, analysis/example.py

> /geant4-claude:geant4-build
✓ build/geant4_claude_main

> /geant4-claude:geant4-run --exe build/geant4_claude_main -- geometries/example.gdml macros/run.mac {run_dir}/hits.root
[g4c] attached SD to 1 sensitive volume(s)
[g4c] run ended: 1000 events written to runs/<run_id>/hits.root

> /geant4-claude:geant4-analyze runs/<run_id>
✓ runs/<run_id>/edep_hist.png
  events = 1000, total hits = 1.2M, mean edep = 640 MeV/event
```

The example files are self-contained — keep them as reference or
delete them when you start writing your own.

### C. Build your own simulation manually

For your real simulation. Write the `main.cc` that implements your
physics; let `/geant4-claude:geant4-detector` handle the geometry if
you want a natural-language detector spec.

```text
> /geant4-claude:geant4-init                        # one-time: skeleton + image pull

> /geant4-claude:geant4-detector                    # optional: NL spec → geometries/<name>.gdml
# write src/main.cc + src/CMakeLists.txt for your simulation
# (you can ask Claude to draft these from a description of the
#  physics list, sensitive detectors, and output schema you want)

> /geant4-claude:geant4-build
> /geant4-claude:geant4-run --exe build/<your-binary> -- <your args> {run_dir}/<output>.root
> /geant4-claude:geant4-analyze runs/<run_id>
```

`/geant4-claude:geant4-detector` writes standalone GDML that any
Geant4 application can load via `G4GDMLParser::Read`.
`/geant4-claude:geant4-run` is content-neutral: it allocates
`runs/<id>/`, exports `RUN_DIR`/`RUN_ID`, substitutes `{run_dir}` /
`{run_id}` placeholders in your args, captures provenance, and runs
whatever binary you point it at inside the pinned container.
`/geant4-claude:geant4-analyze` inspects the resulting ROOT file's
schema and either uses the canned `Hits`-TTree plot (if your `main.cc`
happens to use that schema) or generates a custom analysis script in
`analysis/<run_id>.py` tailored to whatever branches it actually
found.

## Layout

```
geant4_claude/
├── CLAUDE.md                     plugin maintainer rules
├── docs/DESIGN.md                architecture + MVP boundary
├── .claude-plugin/plugin.json    plugin manifest
├── .mcp.json                     deepwiki MCP server (auto-loaded)
├── requirements.txt              Python deps (pdg) installed by SessionStart hook
├── hooks/                        hooks.json + install-deps.sh
├── bin/g4run                     the only bridge to apptainer
├── commands/                     /geant4-{init, build, run, analyze, detector, example}
├── skills/                       geant4 (full-flow orchestrator), geant4-geometry, -physics-list, -analysis
├── agents/geant4-runner.md       subagent for long sims
├── templates/workspace/          empty skeleton /geant4-claude:geant4-init copies in
├── templates/example/            opt-in demo /geant4-claude:geant4-example copies in
│   └── src/                      geant4_claude_main.cc + CMakeLists.txt
└── wiki/                         Geant4 + physics knowledge base (Obsidian vault)
```

## Knowledge base (`wiki/`)

The plugin ships a curated knowledge base on Geant4 mechanics and the physics it implements (toolkit lifecycle, GDML wiring, sensitive-detector dispatch, EM/optical/hadronic processes, the PDG "Passage of Particles Through Matter" review chapter mapped to specific Geant4 model classes, and more). It's structured as an Obsidian vault: open `wiki/` in [Obsidian](https://obsidian.md) to get backlinks, graph view, and `[[wikilink]]` autocomplete; or read it as plain markdown. See `wiki/index.md` for the full catalog. Claude pulls from this wiki when answering Geant4 questions through any of the slash commands.

## What goes in the user's project

`/geant4-claude:geant4-init` scaffolds an empty skeleton:

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
├── runs/              one sub-dir per /geant4-claude:geant4-run (gitignored)
└── analysis/          uproot scripts
```

`/geant4-claude:geant4-example` is independent of the manual flow
above. It drops a self-contained demo (GDML + macro + a generic
GDML-loading `main.cc` + analysis script) into the workspace, useful
for confirming the toolchain works on your machine before you write
any of your own code. Treat the dropped files as smoke-test fixtures
or reference material — when you're ready, write your own
`src/main.cc` and your own `analysis/*.py`.

The directory layout is opinionated — skills and commands assume those
names. `log.md`, `result.md`, and `report.html` are starter handoff
documents Claude maintains as the project evolves: the two markdown
files are the authoritative records (versioned, easy to diff);
`report.html` is the browser-friendly presentation layer derived from
them — open it locally with `file://` to share a snapshot of the
project with a collaborator who isn't in Claude Code.

## Design highlights

- **`geant4` orchestrator skill is the highlighted entry point.** Auto-loads
  on natural-language simulation requests; gap-checks the user's spec across
  six fields (goal, geometry, beam, sensitive, output, analysis); presents
  a brief plan; on approval drives the five commands end-to-end with
  stop-on-failure post-condition checks at each step.
- **NL-driven geometry as a first-class step.**
  `/geant4-claude:geant4-detector` turns a plain-English detector spec
  into a standalone, validated GDML file that any Geant4 `main.cc` can
  `G4GDMLParser::Read`. Geometry edits don't trigger a rebuild — change
  the GDML, re-run.
- **Single runtime seam.** Every Geant4, ROOT, CMake, or g++ call goes
  through `bin/g4run`. The container tag lives in that script alone.
- **Content-neutral wrapper.** `bin/g4run` knows nothing about the user's
  CMake target name, output schema, or argument shape. It just CMake-builds
  whatever source you point at, and execs whatever binary you point at,
  inside the pinned container.
- **Per-user data dir.** The runtime cache (`.sif`) and any optional
  Geant4 source clone live under `${CLAUDE_PLUGIN_DATA}/`, so they
  survive plugin version bumps.
- **Schema-aware analysis.** `/geant4-claude:geant4-analyze` inspects the ROOT file
  and either uses the canned `Hits`-TTree plot (example schema) or
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
| `ModuleNotFoundError: uproot` (analyze step) | `pip install --user uproot numpy matplotlib`, or use a venv. |
| Empty `Hits` tree | No volume has the sensitive aux tag, or gun energy is zero. |
| Build fails | `g4run shell` and try `cmake -S /…/src -B /tmp/build` manually to see the real cmake error. |
| `TGeoManager::Import` returns null in container ROOT | The pinned image's ROOT 6.38 is built without `root-geom`. To preview geometry, load the GDML inside Geant4's own viewer via `g4run shell` and a `vis.mac` macro, not via ROOT. |
| `g4run: command not found` outside slash commands | `g4run` lives at `${CLAUDE_PLUGIN_ROOT}/bin/g4run` (set only inside Claude Code's command context); the plugin doesn't touch your shell `$PATH`. For ad-hoc use, find the installed path with `claude plugin list` and either invoke it by full path or symlink it to `~/.local/bin/g4run`. |
| `g4run validate-gdml` passes but `geant4-run` crashes on the GDML | The validator does an xmllint pass plus a `G4GDMLParser::Read` pass, but the parser does not do schema validation (the schema is hosted on the web and not always reachable in sandboxes), so a typo'd unit name like `unit="milimeter"` can still slip through as a warning. Check `runs/<id>/log.txt` for the underlying Geant4 message. |

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
