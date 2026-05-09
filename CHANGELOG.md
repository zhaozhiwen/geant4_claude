# Changelog

All notable user-facing changes to `geant4_claude` will be documented in
this file. The format is loosely based on
[Keep a Changelog](https://keepachangelog.com/), and this project
adheres to [Semantic Versioning](https://semver.org/).

A bump of the pinned container image tag is at minimum a **minor**
release. A breaking change to the `Hits` TTree schema or to the
`runs/<id>/config.json` provenance contract is a **major** release.

## [0.0.2] - 2026-05-08

### Breaking

- **Removed `$HOME/.geant4_claude` legacy fallback in `bin/g4run`.** The
  cache resolution is now strictly `$GEANT4_CLAUDE_CACHE` (override) or
  `$CLAUDE_PLUGIN_DATA/cache` (default); both unset is a fatal error
  with a clear remediation message. Reason: in some Claude Code
  configurations `CLAUDE_PLUGIN_DATA` isn't propagated into the Bash
  tool's environment, so g4run was silently falling back to
  `$HOME/.geant4_claude` and re-pulling a 4 GB image even when the .sif
  was already present at the correct plugin-data path. Loud failure
  beats silent waste. **Belt-and-suspenders mitigation:** every slash
  command now prepends `GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache"`
  to its g4run invocation, so the cache path lands in the subshell env
  via Claude Code's variable substitution regardless of whether
  `CLAUDE_PLUGIN_DATA` itself made it across.
- **Auto-migration helper (`maybe_migrate_legacy_cache`) deleted along
  with the legacy path.** Users with content at `$HOME/.geant4_claude`
  from earlier `[Unreleased]` builds can manually
  `mv $HOME/.geant4_claude/* "$CLAUDE_PLUGIN_DATA/cache/"` once.

- **Command surface generalized from "demo" to "toolchain".** The four
  core commands (`/geant4-init`, `/geant4-build`, `/geant4-run`,
  `/geant4-analyze`) now operate on **the user's own Geant4 simulation**
  — any `main.cc`, any output schema. Old shapes that assumed the
  plugin's specific binary, GDML-driven geometry, and `Hits`-schema
  output are gone:
    - `/geant4-init` now writes an **empty workspace skeleton**
      (`src/`, `geometries/`, `macros/`, `runs/`, `analysis/` plus
      `CLAUDE.md` and `.gitignore`). It no longer ships
      `geometries/example.gdml`, `macros/run.mac`, or
      `analysis/example.py`.
    - `/geant4-run` is now generic: `--exe <path> [-- args...]` with
      `{run_dir}` / `{run_id}` placeholder substitution and `RUN_DIR` /
      `RUN_ID` env vars exported to the binary. The old example-specific
      flags (`--particle`, `--energy`, `--events`, `--macro`, `--geometry`)
      are gone — drive your macro file yourself.
    - `/geant4-analyze` now inspects the run's ROOT file and either uses
      the canned `Hits`-TTree fast-path or generates a custom analysis
      script in `analysis/<run_id>.py` matching the actual schema.
    - `runs/<id>/config.json` is now a **generic provenance record**:
      `executable`, `args`, `image`, `git_sha`, `started_utc`,
      `duration_s`, `exit_status`. The example-specific fields
      (`geometry`, `macro`, `particle`, `energy_MeV`, `n_events`) are
      gone — analysis scripts that need them must parse the macro
      directly. **This is a major-bump-worthy change to the provenance
      schema, but happening pre-1.0.**
- **`bin/g4run` subcommands changed.**
    - `g4run build` now requires explicit `<src_dir> <build_dir>`
      arguments (was implicit plugin-internal paths).
    - `g4run sim <gdml> <mac> <out.root>` is **renamed** to
      `g4run exec <executable> [args...]` and is now content-neutral.
- **Plugin no longer ships a top-level `src/`.** The example main lived
  there in v0.0.1; it has moved to `templates/example/src/` and is
  copied into the user's workspace by `/geant4-example`.

### Added

- **`/geant4-build`** — CMake-builds any source tree (`./src` by default)
  into `./build/` inside the pinned container.
- **`/geant4-example`** — drops a complete working demo (GDML detector +
  macro + generic GDML-loading `main.cc` with `Hits` TTree + uproot
  analysis) into the workspace as a learning / smoke-test starting point.
  Idempotent; supports `--force` for re-copy.
- **Schema-aware `/geant4-analyze` fast-path** — automatically picks the
  canned per-event edep histogram when a `Hits` TTree matching the example
  schema is found; otherwise generates a custom analysis script tailored to
  the file's actual branches (writes into `analysis/<run_id>.py`).
- **Claude Code marketplace manifest** (`.claude-plugin/marketplace.json`) —
  this repo now doubles as a single-plugin marketplace pointing at itself
  (`"source": "./"`). Users can install with
  `/plugin marketplace add zhaozhiwen/geant4_claude` followed by
  `/plugin install geant4-claude@geant4-claude`, in addition to the
  existing manual `git clone` path.
- **deepwiki MCP server** (`.mcp.json` at plugin root) — auto-loaded when the
  plugin is enabled. Exposes `mcp__deepwiki__ask_question`,
  `read_wiki_structure`, `read_wiki_contents` for in-loop Geant4 Q&A against
  `https://mcp.deepwiki.com/mcp` (free, no auth). Treated as orientation only;
  every claim must be source-verified before landing in the wiki.
- **Python deps via `SessionStart` hook** (`requirements.txt` +
  `hooks/install-deps.sh` + `hooks/hooks.json`) — installs `pdg>=0.2.2` into
  `${CLAUDE_PLUGIN_DATA}/venv/` on first session (uv-first, `python3 -m venv`
  fallback). Idempotent diff/install pattern: ~3 ms no-op on subsequent
  sessions, ~10–30 s on first install, ~50 MB on disk.
- **Optional Geant4 source checkout offered by `/geant4-init`** — first time
  the user runs `/geant4-init`, the command asks whether to download the
  Geant4 source tarball (tag matched to the pinned container's Geant4
  version) from GitHub releases (`https://github.com/Geant4/geant4/archive/refs/tags/v<VERSION>.tar.gz`)
  into `${CLAUDE_PLUGIN_DATA}/geant4-src/`, with a symlink at
  `${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src` so wiki pages keep using the
  relative `wiki/raw/geant4-src/...` references. Tarball, not `git clone`
  — no `.git/` history, no extra dependencies. The data-dir location means
  the tree survives plugin version bumps. Plugin-wide and idempotent: later
  `/geant4-init` calls in other projects detect the existing tree and skip
  the prompt. Required only to verify the wiki's source-citing synthesis
  pages against actual Geant4 code.
- **Geant4 + physics wiki** (`wiki/`) — Obsidian vault covering Geant4
  toolkit mechanics (canonical example summaries + source-grounded
  synthesis pages), particle physics (PDG "Passage of Particles Through
  Matter" chapter ingested verbatim), and a cross-domain mapping linking
  PDG sections to specific `G4*Model`/`G4*Process` classes. Internal
  links use Obsidian
  `[[wikilink]]` syntax. Used by the plugin to answer Geant4 questions
  through slash commands.

### Changed

- **Auto-migration of any pre-existing `${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src/`
  directory** into the new canonical `${CLAUDE_PLUGIN_DATA}/geant4-src/` on
  the next `/geant4-init` run (when the destination is empty). Affects only
  early `[Unreleased]` adopters whose tree was at the legacy location; the
  v0.0.1 release never shipped the source-clone feature.
- **Runtime cache lives under the plugin's data dir.** `bin/g4run`
  resolves the cache directory to `$GEANT4_CLAUDE_CACHE` (explicit
  override) or `$CLAUDE_PLUGIN_DATA/cache` (auto-set by Claude Code).
  `g4run info` prints the resolution source. **User impact:** the `.sif`
  and build outputs live alongside the plugin's other per-user state
  under `~/.claude/plugins/data/<plugin-id>/cache/` and are cleaned up
  when the plugin is uninstalled. Trade-off: if a user uninstalls and
  reinstalls the plugin, the multi-GB image must be re-pulled — set
  `GEANT4_CLAUDE_CACHE` to a stable path to avoid that.
- **`DESIGN.md` moved to `docs/DESIGN.md`.** All references in `README.md`,
  `CLAUDE.md`, and `wiki/CLAUDE.md` updated. The file now also contains the
  MVP boundary section (5 things real Geant4 apps do that v0.0.1 doesn't)
  and a "How the plugin extends Geant4" section documenting the GenericSD
  via GDML auxiliary tags, the Python-deps SessionStart pattern, and the
  deepwiki MCP install/usage.
- **Wiki separated from plugin self-documentation.** The wiki is now strictly
  a Geant4-and-physics knowledge base *used by* the plugin, not *about* the
  plugin. Plugin-specific content (GenericSD implementation, Hits TTree
  schema, MVP boundary, auto-install patterns) lives in `docs/DESIGN.md`.
- **`plugin.json` enriched.** Added `keywords`, `homepage`, and `repository`
  fields for marketplace discovery.

### Fixed

- **`bin/g4run` now uses canonical (symlink-resolved) paths for the
  apptainer bind and working directory.** All three `apptainer exec` sites
  (`in_container`, `cmd_shell`, `cmd_root`) now pass `pwd -P` to both
  `--bind` and `--pwd`, and `readlink -f "${CACHE_DIR}"` for the cache
  bind. Without this, on hosts where `$HOME` or `$(pwd)` traverses a
  symlink chain (e.g. `~/work_solid` → `/work/halla/...` →
  `/w/halla-scshelf2102/...` on JLab's shared filesystem), apptainer would
  bind the symlink path successfully but then fail to `chdir` inside the
  container, breaking every plugin command. Reported by a fresh-install
  smoke test on JLab; symptom was `validate-gdml` working only after
  `cd`-ing to the canonical `/w/...` path. **User impact:** the plugin now
  works regardless of how the user `cd`-s into their workspace.
- **`plugin.json` `repository` is now a string URL** (was an `{type, url}`
  object); the Claude Code plugin manifest schema requires a string, so
  the previous shape failed install with
  `"repository: Invalid input: expected string, received object"` on
  fresh clones.

### Documentation

- README now documents the auto-install side effects users see when first
  enabling the plugin (deepwiki MCP approval prompt, pip-install hook).
- README has a new "Knowledge base (`wiki/`)" section explaining the
  Obsidian vault.

## [0.0.1] — 2026-05-04

Initial public release. MVP scope: a single user with apptainer +
Python + Claude Code can run the four-step demo end-to-end.

### Added

- **Four slash commands**:
  - `/geant4-init` — scaffold an opinionated workspace and pre-pull
    the runtime container.
  - `/geant4-detector` — translate a natural-language detector spec
    into a validated GDML file.
  - `/geant4-run` — run a Geant4 simulation; produce
    `runs/<id>/{hits.root, log.txt, config.json}`.
  - `/geant4-analyze` — read `hits.root`, write `edep_hist.png`,
    print a summary.
- **Three skills**: `geant4-geometry`, `geant4-physics-list`,
  `geant4-analysis`.
- **One subagent**: `geant4-runner` for sims that take more than a few
  minutes.
- **Generic Geant4 main** (`src/geant4_claude_main.cc`): loads any
  GDML, attaches a sensitive detector to volumes tagged
  `<auxiliary auxtype="sensitive" auxvalue="true"/>`, writes a flat
  `Hits` TTree with branches `event/volume/edep/x/y/z/t/pdg`.
- **Apptainer wrapper** (`bin/g4run`) — the only sanctioned bridge to
  the runtime; subcommands `pull`, `info`, `shell`, `build`, `sim`,
  `root`, `validate-gdml`. Runtime cache at
  `~/.geant4_claude/` (override with `GEANT4_CLAUDE_CACHE`).
- **Workspace template** copied by `/geant4-init`: project
  `CLAUDE.md`, `.gitignore`, example GDML / macro / analysis script.

### Pinned

- Container: `ghcr.io/gemc/g4install:11.4.0-almalinux-9.4` (Geant4
  11.4.0, ROOT 6.38). The tag lives in `bin/g4run`; bumping it is at
  least a minor release.
- Default physics list: `FTFP_BERT`.
- Run mode: sequential (MT support deferred — see "Known limitations").

### Known limitations

- Physics list is hard-coded in the generic main. Workaround: fork
  `src/geant4_claude_main.cc`, replace the `FTFP_BERT` constructor,
  rebuild with `g4run build`. A `--physics-list` flag is planned.
- No C++ `DetectorConstruction` extension hook — geometry must be
  expressible in GDML, scoring must be expressible via the sensitive
  aux tag.
- No scoring meshes; only SD-based hit collection.
- Sequential run mode only. The TTree fill path is not thread-safe.
- No `/geant4-sweep` for parameter scans.
- No CI smoke test in this release.

### Requirements

- Apptainer ≥ 1.4 on Linux.
- ~2.5 GB of disk for the cached `.sif`.
- Python 3.9+ with `uproot numpy matplotlib` on the host (only for
  `/geant4-analyze`).
