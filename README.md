# geant4_claude

A Claude Code plugin that lets you **describe a detector in plain
English, run it, and analyze the output** without touching C++.
`/geant4-claude:geant4-detector` writes standalone GDML; the bundled
example main loads it; `/geant4-claude:geant4-build`, `…run`, and
`…analyze` finish the loop. Bringing your own `main.cc` is the
alternative path for users who need hard-coded geometry, custom
physics, or a custom output schema. Geant4 and ROOT live in a pinned
apptainer image; analysis runs on the host with
[`uproot`](https://github.com/scikit-hep/uproot5).

> Status: **v0.0.2**. The four core commands (`init`, `build`, `run`,
> `analyze`) are content-neutral — they work equally well with the
> example's GDML-loading main and with any user-supplied `main.cc`.

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

### Default flow — describe a detector in plain English, then run it

In a fresh project directory:

```text
> /geant4-claude:geant4-init
✓ wrote workspace skeleton (src/, geometries/, macros/, runs/, analysis/, CLAUDE.md, log.md, result.md)
✓ pulled image  → ${CLAUDE_PLUGIN_DATA}/cache/sif/g4install_11.4.0-almalinux-9.4.sif

> /geant4-claude:geant4-detector
  describe your detector: a 1×1×10 cm lead block in an air world,
                          tag the lead as sensitive
✓ wrote geometries/lead_block.gdml (validated)

> /geant4-claude:geant4-example
✓ wrote src/{geant4_claude_main.cc, CMakeLists.txt}, geometries/example.gdml,
  macros/run.mac, analysis/example.py
  (the main is GDML-driven — point it at any /geant4-claude:geant4-detector output)

> /geant4-claude:geant4-build
✓ build/geant4_claude_main

> /geant4-claude:geant4-run --exe build/geant4_claude_main -- geometries/lead_block.gdml macros/run.mac {run_dir}/hits.root
[g4c] attached SD to 1 sensitive volume(s)
[g4c] run ended: 1000 events written to runs/<run_id>/hits.root
✓ runs/<run_id>/{hits.root, log.txt, config.json}

> /geant4-claude:geant4-analyze runs/<run_id>
✓ runs/<run_id>/edep_hist.png
  events = 1000, total hits = 1.2M, mean edep = 640 MeV/event
```

`/geant4-claude:geant4-detector` is natural-language → standalone GDML; the
example main shipped by `/geant4-claude:geant4-example` loads whatever
GDML you point it at, so the two compose into a no-C++ default loop.
Skip `/geant4-claude:geant4-detector` (and run `/geant4-claude:geant4-example` alone) to use
the bundled `geometries/example.gdml` instead.

### Alternative — bring your own `main.cc`

For users who already have a Geant4 application, want to hard-code geometry
in C++, or write to a non-`Hits` output schema:

```text
> /geant4-claude:geant4-init                        # one-time: skeleton + image pull
# drop your own src/main.cc and src/CMakeLists.txt into the workspace

> /geant4-claude:geant4-build
> /geant4-claude:geant4-run --exe build/<your-binary> -- <your args> {run_dir}/<your-output>
> /geant4-claude:geant4-analyze runs/<run_id>
```

`/geant4-claude:geant4-run` is content-neutral: it allocates `runs/<id>/`, exports
`RUN_DIR`/`RUN_ID`, substitutes `{run_dir}` / `{run_id}` placeholders in
your args, captures provenance, and runs whatever binary you point it at
inside the pinned container. `/geant4-claude:geant4-analyze` inspects the resulting
ROOT file's schema; if it matches the example's `Hits` TTree it uses the
canned plot, otherwise it generates a custom analysis script in
`analysis/<run_id>.py` based on what it actually found.

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
├── skills/                       geant4-geometry, -physics-list, -analysis
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
├── src/               your main.cc + CMakeLists.txt go here
├── geometries/        GDML files (optional; if you load geometry at runtime)
├── macros/            Geant4 .mac files
├── runs/              one sub-dir per /geant4-claude:geant4-run (gitignored)
└── analysis/          uproot scripts
```

`/geant4-claude:geant4-example` drops a generic GDML-driven `main.cc` plus a
sample geometry/macro/analysis on top — the same `main.cc` powers the default
NL-detector flow above (it loads any GDML you hand it, including the output of
`/geant4-claude:geant4-detector`). Bring your own `src/main.cc` only when you need
non-default physics, geometry hard-coded in C++, or an output schema that
isn't the example's `Hits` TTree.

The directory layout is opinionated — skills and commands assume those
names. `log.md` and `result.md` are starter handoff documents Claude
maintains as the project evolves.

## Design highlights

- **NL-driven geometry as the default.** `/geant4-claude:geant4-detector`
  turns a plain-English detector spec into standalone, validated GDML.
  Combined with the GDML-loading `main.cc` shipped by
  `/geant4-claude:geant4-example`, you get a no-C++ default loop:
  describe → run → analyze. Bring your own `main.cc` only when you need
  hard-coded geometry, custom physics, or a custom output schema.
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

## License

[MIT](LICENSE) — © 2026 Zhiwen Zhao.

## Acknowledgments

The container image is built and maintained at
[github.com/gemc/g4install](https://github.com/gemc/g4install). The
plugin pins a specific tag of that image; bumping it is a minor
version bump for `geant4_claude`.
