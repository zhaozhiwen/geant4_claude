# geant4_claude

A Claude Code plugin that lets you **design a Geant4 detector, run a
simulation, and analyze the output** through four slash commands. Geant4
and ROOT live in a pinned apptainer image; analysis runs on the host with
[`uproot`](https://github.com/scikit-hep/uproot5).

> Status: **MVP / v0.0.1**. The four commands work end-to-end. C++
> `DetectorConstruction`, scoring meshes, and physics-list flags are not
> in this release — see [docs/DESIGN.md](docs/DESIGN.md) §"Open questions".

## Requirements

- [apptainer](https://apptainer.org) ≥ 1.4 on Linux.
- Python 3.9+ on the host with `uproot numpy matplotlib`
  (only needed for `/geant4-analyze`).
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

If you'd rather opt out: remove `.mcp.json` and/or `requirements.txt` from your local clone before enabling the plugin. Neither is required for the four-command demo to work.

The first `/geant4-init` you run will additionally **ask once** whether to shallow-clone the Geant4 source tree (matching the pinned container's version, ~150 MB) into `<plugin>/wiki/raw/geant4-src/`. This is optional — say *Skip* and the four-command demo still works. Saying *Yes* is what lets Claude verify the wiki's `.cc:line` citations against actual Geant4 code when you ask Geant4-mechanics questions. Re-run `/geant4-init` later to be asked again.

## Quickstart (the four-command demo)

In a fresh project directory:

```text
> /geant4-init
✓ wrote workspace (CLAUDE.md, .gitignore, geometries/, macros/, runs/, analysis/)
✓ pulled image  → ${CLAUDE_PLUGIN_DATA}/cache/sif/g4install_11.4.0-almalinux-9.4.sif
✓ validated     geometries/example.gdml

> /geant4-detector "1×1×10 cm lead block in a 50 cm air world, sensitive"
✓ wrote geometries/det.gdml

> /geant4-run --particle e- --energy 1 GeV --events 1000
[g4c] attached SD to 1 sensitive volume(s)
[g4c] run ended: 1000 events written to runs/<run_id>/hits.root
✓ runs/<run_id>/{hits.root, log.txt, config.json, run.mac}

> /geant4-analyze runs/<run_id>
✓ runs/<run_id>/edep_hist.png
  mean = 640 MeV  std = 78 MeV  hits = 1.2 M
```

That's the loop. Edit GDML or macros, run again, analyze.

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
├── commands/                     /geant4-init, -detector, -run, -analyze
├── skills/                       geant4-geometry, -physics-list, -analysis
├── agents/geant4-runner.md       subagent for long sims
├── src/                          generic Geant4 main + CMakeLists
├── templates/workspace/          what /geant4-init writes into a project
└── wiki/                         Geant4 + physics knowledge base (Obsidian vault)
```

## Knowledge base (`wiki/`)

The plugin ships a curated knowledge base of 69 pages on Geant4 mechanics and the physics it implements (toolkit lifecycle, GDML wiring, sensitive-detector dispatch, EM/optical/hadronic processes, the PDG "Passage of Particles Through Matter" review chapter mapped to specific Geant4 model classes, and more). It's structured as an Obsidian vault: open `wiki/` in [Obsidian](https://obsidian.md) to get backlinks, graph view, and `[[wikilink]]` autocomplete; or read it as plain markdown. See `wiki/index.md` for the full catalog. Claude pulls from this wiki when answering Geant4 questions through any of the slash commands.

## What goes in the user's project

`/geant4-init` scaffolds:

```
my-project/
├── CLAUDE.md          rules for Claude inside this workspace
├── .gitignore         excludes runs/, *.root, build/, __pycache__/
├── geometries/        GDML, one per detector design
├── macros/            Geant4 .mac files
├── runs/              one sub-dir per /geant4-run (gitignored)
└── analysis/          uproot scripts (template: example.py)
```

The workspace is opinionated. Skills and commands assume this layout;
don't rename the four directories.

## Design highlights

- **Single runtime seam.** Every Geant4, ROOT, CMake, or g++ call goes
  through `bin/g4run`. The container tag lives in that script alone.
- **GDML for geometry.** No recompile per geometry change. Volumes
  marked `<auxiliary auxtype="sensitive" auxvalue="true"/>` get a
  generic SD attached automatically and stream hits into a flat TTree.
- **Flat TTree contract.** `Hits` with branches
  `event/volume/edep/x/y/z/t/pdg`. Stable across the v0.x series.
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

## License

[MIT](LICENSE) — © 2026 Zhiwen Zhao.

## Acknowledgments

The container image is built and maintained at
[github.com/gemc/g4install](https://github.com/gemc/g4install). The
plugin pins a specific tag of that image; bumping it is a minor
version bump for `geant4_claude`.
