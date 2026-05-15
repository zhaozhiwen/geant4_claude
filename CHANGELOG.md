# Changelog

All notable user-facing changes to `geant4_claude` will be documented in
this file. The format is loosely based on
[Keep a Changelog](https://keepachangelog.com/), and this project
adheres to [Semantic Versioning](https://semver.org/).

A bump of the pinned container image tag is at minimum a **minor**
release. A breaking change to the `Hits` TTree schema or to the
`runs/<id>/config.json` provenance contract is a **major** release.

## [Unreleased]

### Added

- **Preview sketch backend.** `/geant4-claude:geant4-preview` now ships
  a host-side matplotlib backend (`scripts/preview_gdml.py`) as the
  default. Parses GDML `<solids>` + `<structure>` with the stdlib XML
  parser, applies the full 3D transform per physvol, and renders three
  orthographic PNG projections (XY / YZ / XZ) via matplotlib. Handles
  box, tube, cone, polycone, and arbitrary rotations. Unknown solids
  (booleans, replicas) draw as bounding boxes with a "!" badge so they
  don't silently vanish. ~1 s per geometry, no container call. Selected
  via `g4run preview <gdml> [out_dir] [--backend=sketch|raytracer]` —
  `sketch` is default, `raytracer` is the existing alpha helper kept
  opt-in until the v11.4 RayTracer hang is resolved. The orchestrator
  skill now calls preview between `geant4-detector` and `geant4-build`
  by default (it previously skipped because the RayTracer backend was
  unusable). `matplotlib` and `numpy` added to `requirements.txt`.
- **Cherenkov validator: schema flags.** `scripts/validators/cherenkov.py`
  gains `--event-branch / --pdg-branch / --photon-pdg` (filtered mode,
  the existing per-hit schema; defaults unchanged) and a new
  `--count-branch` (per-event schema, one row per event with a
  precomputed photon count). Removes the contradiction where the
  orchestrator told Cherenkov users to write a custom main while the
  validator hardcoded the example main's TTree shape. Direct mode also
  skips the per-hit filter step, making validation cheaper for large
  runs.
- **Cherenkov validator: RINDEX from GDML.** New `--rindex-from-gdml
  <file> --rindex-material <name>` path reads the radiator material's
  `RINDEX` matrix directly out of the GDML and trapezoidally integrates
  Frank-Tamm in energy: `N/event = (2π·α·L/hc) · ∫ dE · (1 −
  1/(β²·n²(E)))`. Eliminates the 2-5% bias of feeding a single
  refractive index for a real dispersive radiator. The constant-`n`
  path via `--refractive-index` stays available as fallback when the
  GDML has no optical properties. Summary JSON records source,
  effective-`n`, and the parsed matrix.

### Changed

- **Example main's init-order contract is now documented.** The
  shipped `templates/example/src/geant4_claude_main.cc` already
  delegates `/run/initialize` to the macro (so the macro can set
  `/run/numberOfThreads` in PreInit state without "Illegal application
  state" errors), but the contract wasn't written down. A header
  comment now spells it out, the example macro template marks where
  threading commands belong, and the orchestrator skill's "bring-your-
  own main" guidance warns against the common Geant4-tutorial pattern
  of calling `runManager->Initialize()` in main.

### Fixed

- `embed_html.py` no longer base64-embeds `<img>` tags that sit inside
  HTML comments — previously the regex matched placeholder examples in
  the `report.html` header and threw a "missing image" error on the
  shipped template.

- **`templates/workspace/embed_html.py`** — stdlib-only helper that
  takes `report.html` with relative `<img src="runs/...">` references
  and writes `report_portable.html` with each image base64-embedded
  inline. Usage: `python3 embed_html.py report.html`. Idempotent
  (negative-lookahead skips `src="data:..."` tags on re-run);
  preserves original paths in a `data-source` attribute for
  traceability. Output gitignored via `*_portable.html` in the
  workspace `.gitignore`. Use case: emailing or uploading the report
  as a single self-contained file when the `runs/` directory can't
  travel with it.
- **`templates/workspace/report.html`** — single-page browser-friendly
  summary of a Geant4 study. Joins `log.md` (chronological work log)
  and `result.md` (per-run findings) as a third handoff document in
  the scaffolded workspace skeleton. Self-contained HTML (inline CSS,
  no JavaScript, no external resources); relative paths resolve from
  the workspace root so opening it via `file://` Just Works offline.
  Sections: project header, summary, geometry + beam/physics setup,
  runs table (read from `runs/<id>/config.json`), key-numbers table,
  plot grid (auto-laid via CSS), interpretation, provenance footer.
  Print-friendly via `@media print`. Updated alongside `result.md`
  after a noteworthy `/geant4-claude:geant4-analyze` — the markdown
  files stay authoritative; `report.html` is a presentation layer
  derived from them.
- **GitHub Pages landing page** at
  [zhaozhiwen.github.io/geant4_claude](https://zhaozhiwen.github.io/geant4_claude/).
  Built from `docs/` with the Jekyll Cayman theme — two files
  (`docs/_config.yml`, `docs/index.md`), no Actions workflow,
  no Gemfile. README, DESIGN, CHANGELOG continue to live at the repo
  root and on GitHub; the landing page is a separate one-page
  entry surface for casual visitors.

## [0.0.4] - 2026-05-14

### Added

- **`bin/g4run validate-gdml` upgraded to a two-layer check.** The
  existing xmllint pass now runs alongside a `G4GDMLParser::Read` pass
  via a tiny cached helper built once at
  `${CLAUDE_PLUGIN_DATA}/cache/bin/validate_gdml` from
  `templates/validate/{main.cc,CMakeLists.txt}`. Catches the class of
  error xmllint can't: undefined materials (`G4_NOT_A_MAT`), undefined
  solid/volume refs, malformed `<auxiliary>` tags. Custom exception
  handler translates fatal `G4Exception` into a clean `exit 1` with a
  one-line error message instead of `SIGABRT` (no more "core dumped"
  shouting in the user's terminal).
- **`bin/g4run preview <gdml> [out_dir]` + `/geant4-claude:geant4-preview`
  command (alpha).** Infrastructure: `templates/preview/{main.cc,
  CMakeLists.txt}` ships a tiny Geant4 program that loads the GDML and
  drives the RayTracer driver to produce three JPEG views (iso, xy,
  yz) into `<gdml>.preview/`. Cached helper binary at
  `${CACHE_DIR}/bin/preview_gdml` is built on first use, same pattern
  as `validate_gdml`. **Status: alpha — rendering hangs.** Three
  different vis-command sequences all trigger
  `G4RTMessenger::SetNewValue: No valid current viewer` and the
  `/vis/rayTracer/trace` step hangs. Documented in
  `commands/geant4-preview.md` and `docs/DESIGN.md` hardening backlog
  item #2 with three suspected fixes; orchestrator skill does NOT
  call preview automatically.
- **`/geant4-claude:geant4-validate <topic> <run_dir>` command.** Runs
  a physics closure test against a finished run, prints PASS/FAIL with
  numbers and tolerance, writes `runs/<id>/validate_<topic>.json`.
  Exit code: `0` PASS, `1` FAIL, `2` bad input. v1 ships `cherenkov`
  (Frank-Tamm yield vs simulation, Poisson-tolerance gate). Validator
  Python scripts live at `scripts/validators/<topic>.py`; new
  validators are a one-file addition. Frank-Tamm closure verified
  against known references (CO₂ 1m → 154 photons/event, quartz 10mm
  → 913 photons/event).
- **`scripts/validators/`** — new directory for host-side closure-test
  Python scripts driven by `/geant4-claude:geant4-validate`. v1
  contents: `cherenkov.py`. Listed in `CLAUDE.md` repo conventions.
- **`/geant4-claude:geant4-run --from <prev>` + `--reason <text>`
  flags.** Records `parent_run` and `diff_reason` in `runs/<id>/config.json`
  so re-run lineage is machine-readable instead of living only in
  filename suffixes / `log.md` prose. Additive contract change to
  `config.json` (`parent_run`, `diff_reason`); old analysis tools
  that don't read the fields keep working.
- **`/geant4-claude:geant4-run` now prepends a `log.md` stub.** If
  `log.md` exists in the workspace (created by `geant4-init`), the
  run command writes a new dated entry block at the top with the four
  mechanical Outcome fields (run id, status, output paths, duration)
  prefilled. The orchestrator skill (or the user) only needs to fill
  Request, Plan, Decision, and Notes. Stub is inserted above the
  `<!-- ENTRY TEMPLATE -->` marker comment.

### Changed

- **`templates/workspace/log.md` template wrapped in an HTML comment.**
  The entry-template block previously sat at the bottom of the file
  as a literal stub with `<verbatim user request, …>` angle-bracket
  placeholders. After the orchestrator prepended its first real entry,
  the stub stayed mid-file and looked like an unfilled entry — confusing
  for anyone reading `log.md` to pick up where they left off. Now
  wrapped in `<!-- … -->` so it's invisible in any markdown render but
  still available to future Claude sessions as a structural reference.
  Orchestrator skill's log.md-handling instructions updated to insert
  new entries above the comment.
- **Orchestrator skill (`skills/geant4`) gains a "Geometry-sanity
  gates" subsection.** Four explicit checks Claude runs against the
  captured spec before presenting the plan: sensor in the forward-flux
  path (the Cherenkov + reflector trap), overlapping placements,
  sensor not tagged sensitive, beam origin on/outside the world
  boundary. Each carries a concrete fix to propose rather than a
  generic warning. Replaces the previous "list real risks" guidance
  that was easy to satisfy with `Risks: none`.

### Fixed

- **`bin/g4run validate-gdml` usage text was misleading.** It described
  the command as xmllint-only and warned that "missing materials, bad
  units, or undefined refs slip past." That's no longer true now that
  the G4GDMLParser layer is in place — usage rewritten.

### Documentation

- **README troubleshooting** has three new rows: `TGeoManager::Import
  returns null in container ROOT` (root-geom is not compiled in;
  preview goes through the Geant4 viewer instead — hardening backlog
  item #6 *accepted, resolved by #2*), `g4run: command not found
  outside slash commands` (the wrapper lives at
  `${CLAUDE_PLUGIN_ROOT}/bin/g4run`, which is only set inside
  slash-command execution; symlink to `~/.local/bin/g4run` for ad-hoc
  shell use), and a note on the residual `validate-gdml` limitation
  (schema validation requires reaching the web-hosted XSD).
- **`docs/DESIGN.md` gains a "Hardening backlog (post-v0.0.3)"
  section** listing seven actionable follow-up items surfaced by the
  Cherenkov dogfooding session: real GDML validation (#1, shipped),
  headless preview (#2, alpha), log.md stub (#3, shipped), run
  lineage (#4, shipped), physics closure validators (#5, shipped),
  root-geom (#6, accepted), `g4run` symlink (#7, deferred). Each
  item carries motivation + concrete fix + expected impact.
- **README quickstart restructured into three independent paths** so the
  shipped example flow is cleanly separated from the user's manual flow:
  *A. Describe what you want to simulate* (orchestrator skill, recommended),
  *B. Try the shipped example end-to-end* (smoke test only — drops the
  bundled demo into the workspace and runs it as-is), *C. Build your own
  simulation manually* (init + optional `geant4-detector` + your own
  `main.cc` + build + run + analyze). Headline, status, "What goes in
  the user's project", and Design highlights bullets rewritten so the
  example is consistently positioned as familiarity tooling, not as a
  default workflow component. The previous v0.0.3 framing had the example
  main acting as the "default binary for `/geant4-claude:geant4-detector`
  output" and presented BYO-`main.cc` as the alternative to that
  combined flow; this rework corrects the conflation.
- **`docs/DESIGN.md` mirrors the README split** — user-journey
  walkthrough, Example main section, slash-command table row for
  `/geant4-claude:geant4-example`, and the workspace tree comment all
  reframed. The "default binary / no-C++ default loop" language is gone;
  the orchestrator skill's option to compose detector output with the
  example main is now described as an internal shortcut rather than a
  documented user-facing path.

## [0.0.3] - 2026-05-09

### Added

- **`geant4` orchestrator skill** (`skills/geant4/SKILL.md`) — the
  highlighted entry point. Auto-loads on natural-language simulation
  requests ("simulate / build / run a Geant4 …"); gap-checks the user's
  spec across six required fields (physics goal, geometry, beam,
  sensitive surfaces, output, analysis); presents a brief plan; on
  approval drives `init → detector → build → run → analyze` end-to-end
  with stop-on-failure post-condition checks at each step. Routes onto
  the BYO-`main.cc` path automatically when the spec needs optical
  photons, HP neutrons, polarization, or a non-`Hits` output schema.
  This is the only skill in the plugin that drives a workflow rather
  than describing one — a deliberate single carve-out of the "skills
  are reference, not workflows" maintainer rule.
- **`templates/workspace/log.md` and `templates/workspace/result.md`** —
  handoff documents now ship in the workspace skeleton.
  - `log.md` is a chronological work log; each entry has the four
    sections **Request** (verbatim user ask), **Plan** (six-field spec
    + step list), **Decision** (approved / edited / plan-only), and
    **Outcome** (run id, status, one-line summary).
  - `result.md` is the per-run findings document (key numbers + plot
    paths).
  - `templates/workspace/CLAUDE.md` non-negotiable #6 broadened: every
    simulation effort — orchestrator-driven *or* manual command flow —
    prepends a dated `log.md` entry, so manual users get the same
    logging discipline as orchestrator-driven ones.

### Changed

- **NL-detector flow promoted to default; BYO-`main.cc` reframed as
  alternative.** README, `docs/DESIGN.md`, `commands/geant4-init.md`,
  `commands/geant4-example.md`, and `templates/workspace/CLAUDE.md`
  rewritten so the headlined path is `geant4-detector` (natural
  language → standalone GDML) paired with `geant4-example`'s
  GDML-loading `main.cc` — a no-C++ default loop. Bringing your own
  `main.cc` is explicit alternative for hard-coded geometry, custom
  physics, or non-`Hits` output schemas. Behavioral surface unchanged;
  this is a positioning change.
- **`/geant4-claude:geant4-example` repositioned.** Previously framed
  as an opt-in demo / starting point; now framed as the **default
  binary** for the NL-detector flow (the shipped main consumes any
  GDML, including `/geant4-claude:geant4-detector` output).
- **Workspace `CLAUDE.md` "Typical loop" split into two named loops** —
  default (orchestrator / NL-detector + example main) and alternative
  (BYO main.cc) — so the doc surfaces both paths explicitly.

### Fixed

- **Slash commands now correctly cross-referenced as
  `/geant4-claude:<verb>`** (commit `9ed511e`). Previously bare
  `/geant4-init` etc. appeared in commands, skills, and docs; on a
  clean install Claude Code requires the namespaced form, so the
  bare references were misleading.
- **Workspace skeleton's `runs/.gitkeep` placeholder now ships**
  (commit `b26275e`). The repo's top-level `.gitignore` had unanchored
  `runs/`, which silently dropped the placeholder during
  `cp -r templates/workspace/.`. Anchored to `/runs/` so the ignore
  applies only to the repo root.
- **`/geant4-claude:geant4-analyze` may now auto-install
  `uproot/numpy/matplotlib` into the plugin-managed venv at
  `${CLAUDE_PLUGIN_DATA}/venv/`** (commit `8daf15b`). Previously it
  refused, leaving the user to run `pip install` themselves.

### Documentation

- README leads with an **"Easiest entry point — just describe what
  you want to simulate"** section above the two manual flows,
  showing the orchestrator skill's invocation pattern with a
  worked Cherenkov example.
- `docs/DESIGN.md` skill-split table documents the orchestrator
  carve-out and the rationale (skills auto-load on natural language
  triggers; commands don't).

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
