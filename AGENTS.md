# AGENTS.md — `geant4_claude` plugin

You are working **on the plugin**, not on a user's simulation. This file is the
maintainer's rulebook (`CLAUDE.md` is a symlink to it, so Claude Code reads the
same rules). Rules for the assistant when *using* the plugin live in the
generated workspace's own `AGENTS.md` (see `templates/workspace/AGENTS.md`).

## Project

`geant4_claude` is a public plugin for **both Claude Code and OpenAI Codex** that
helps any user **build, run, and analyze their own Geant4 simulation** through a
set of skills (no slash commands — skills run on both CLIs). Geant4 and ROOT are
accessed through the apptainer image
`docker://ghcr.io/gemc/g4install:11.4.0-almalinux-9.4`. The plugin ships no
compiled code, only the two manifests, skills, a workspace skeleton, and an
opt-in example (a generic GDML-driven `main.cc` plus a sample
geometry/macro/analysis) the user copies in with the `geant4-example` skill.

This repo will be published on GitHub. Treat every commit as if a stranger
will clone it on a fresh machine.

## Non-negotiables

1. **Single runtime entry point.** All Geant4, CMake, g++, and ROOT
   invocations go through `bin/g4run`. Commands and skills must never call
   `apptainer exec` (or `singularity`, or `docker`) directly. This keeps the
   runtime swappable in one place.
2. **Pinned image, one source of truth.** The container tag lives in
   `bin/g4run` only. Anywhere else that needs to display it reads it from that
   script. Do not hardcode the tag in commands, skills, READMEs, or CI.
3. **No host-side ROOT requirement.** The default analysis path is Python
   (`uproot` + `numpy` + `matplotlib`). Anything that *needs* ROOT must run
   inside the container via `bin/g4run root`. Never document a workflow that
   expects ROOT on the user's host.
4. **Fresh-clone reproducibility.** Every command must work after `git clone`
   on a machine with apptainer and Python; nothing may rely on cached state in
   the maintainer's home directory or absolute paths under `/home/$USER`.
5. **Generated artifacts are gitignored at the source.** Templates the plugin
   writes into a user workspace (`runs/`, `*.root`, `build/`, `__pycache__/`)
   must come with a `.gitignore` that excludes them. Don't rely on the user
   noticing.
6. **No leakage.** No JLab-internal hostnames, no absolute home paths, no API
   tokens, no personal email in committed files. Pre-publish check (below)
   enforces this.
7. **Idempotent skills.** Running any skill twice in a row must not corrupt
   state. The `geant4-init` skill re-detects existing files and refuses to
   overwrite without `--force`.
8. **Skills stay CLI-neutral.** The plugin ships for both Claude Code and Codex.
   Skills are the one surface both run, so **no `skills/*` file may reference
   `CLAUDE_*`/`CODEX_*` env vars or `/geant4-claude:` slash-command names** —
   they reach the engine only via the `.g4c/` pointer
   (`[ -f .g4c/env ] && . .g4c/env; G4RUN="${G4RUN:-$PWD/.g4c/g4run}"`).
   **The one exception is `geant4-init`**, the keystone that *writes* `.g4c/`: it
   must read the CLI-native plugin root (`$CLAUDE_PLUGIN_ROOT` on Claude; the
   injected skill dir on Codex) to bootstrap. `tests/clean-smoke.sh` phase 0d
   enforces this (CLAUDE_* allowed only in `geant4-init`; slash refs banned
   everywhere). Both manifests (`.claude-plugin/` + `.codex-plugin/`) bump
   version together.

## Repository conventions

| Path | Role |
|------|------|
| `.claude-plugin/plugin.json` | Claude Code manifest. Version bumped on every release (in lockstep with `.codex-plugin/`). |
| `.codex-plugin/plugin.json` | Codex manifest (requires an `interface{}` block, strict semver, no `hooks` field — Codex's validator rejects it). Validate with `~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py .`. |
| `.agents/plugins/marketplace.json` | Codex marketplace entry (`codex plugin marketplace add`). Its local source path is `./plugins/geant4-claude` — a symlink → repo root, because Codex resolves declared plugins under `plugins/<name>/`. `.claude-plugin/marketplace.json` is the Claude counterpart. |
| `.mcp.json` | Plugin-shipped MCP servers (currently: deepwiki), bundled by both manifests. Add servers here only if they are free, no-auth, and clearly useful for Geant4 work. |
| `requirements.txt` | Python deps installed by `scripts/ensure_venv.sh`. Currently: `pdg`, `matplotlib`, `numpy` (used by `scripts/preview_gdml.py` and the canned analyze plots). Touch this file to trigger reinstall. Add packages only when something in `skills/`/`scripts/` actually imports them. |
| `scripts/ensure_venv.sh` | CLI-neutral, idempotent venv bootstrap (uv first, `python3 -m venv` fallback). The fast-exit gates on the venv interpreter existing **and** the requirements snapshot matching, so a half-deleted venv (snapshot survives, python gone) self-heals instead of leaving analyze/preview/validate pointed at a dead python. Called directly by the skills that need Python (`geant4-init` + `geant4-analyze`/`preview`/`validate`) — identically on both CLIs. There is **no** `SessionStart` hook (Codex can't bundle one; dropped on Claude too for one bootstrap path). |
| `skills/<name>/SKILL.md` | The plugin's entire surface — 8 task skills (`geant4-init/detector/example/preview/build/run/analyze/validate`), the `geant4` orchestrator (front door), and 3 reference skills (`geant4-geometry/physics-list/analysis`). No slash commands. |
| `AGENTS.md` | **Canonical** agent-instructions file (vendor-neutral; what Codex reads). `CLAUDE.md` is a symlink → `AGENTS.md` so Claude Code reads the same rules. One pair per location (root, `templates/workspace/`, `wiki/`). New instruction files are `AGENTS.md` with a `CLAUDE.md` symlink alongside. |
| `bin/g4run` | The only allowed bridge to apptainer (and the host-side dispatcher for the sketch preview backend). Subcommands: `pull`, `info`, `shell`, `build <src> <build>`, `exec <executable> [args…]`, `root`, `validate-gdml`, `preview <gdml> [out_dir] [--backend=sketch|raytracer]`, `image-tag`, `sif-name` (echo the pinned tag / `.sif` name — the single-source accessors docs and tests derive from). |
| `templates/workspace/` | Generic skeleton the `geant4-init` skill copies into a user's project (empty `src/`, `geometries/`, `macros/`, `runs/`, `analysis/` plus `CLAUDE.md` and `.gitignore`). |
| `templates/example/` | The opt-in demo the `geant4-example` skill copies in (`src/geant4_claude_main.cc` + `src/CMakeLists.txt` + `geometries/example.gdml` + `macros/run.mac` + `analysis/example.py`). |
| `templates/validate/` | Tiny Geant4 program (`main.cc` + `CMakeLists.txt`) built by `bin/g4run` on first `validate-gdml` call and cached at `${CACHE_DIR}/bin/validate_gdml`. Runs `G4GDMLParser::Read` so semantic errors xmllint misses get caught. |
| `templates/preview/` | Tiny Geant4 program ditto — built on first `preview --backend=raytracer` call, cached at `${CACHE_DIR}/bin/preview_gdml`. Headless GDML preview via RayTracer. **Alpha** — rendering hangs in the v11.4 container; see DESIGN.md hardening backlog. The default sketch backend (no container call) lives in `scripts/preview_gdml.py`. |
| `scripts/preview_gdml.py` | Host-side sketch backend for the `geant4-preview` skill (default). Stdlib XML parse of `<solids>`/`<structure>` + matplotlib projections. Supports box/tube/cone/polycone + full 3D rotations; unknown solids render as bounding boxes with a "!" badge. |
| `scripts/validators/` | Host-side Python validators driven by the `geant4-validate` skill (`<topic>`). Each is a self-contained `<topic>.py` reading a `runs/<id>/` directory and writing `validate_<topic>.json`. v1: `cherenkov.py` (Frank-Tamm closure). |
| `tests/lint-skill-frontmatter.py`, `tests/lint-agents-mirror.sh` | Pure lints — run standalone, in `clean-smoke.sh` (phase 0f/0g), and in CI (`.github/workflows/lint.yml`). Guard the strict-YAML frontmatter invariant (a colon-space in an unquoted `description:` silently drops the whole skill on Codex) and the `CLAUDE.md`→`AGENTS.md` symlink invariant. |
| `docs/DESIGN.md` | Architecture, contracts, MVP boundary. Update whenever a contract changes. |

Naming:

- Task skills: `geant4-<verb>` (`geant4-init`, `geant4-build`, `geant4-run`,
  `geant4-analyze`, `geant4-detector`, `geant4-example`, `geant4-preview`,
  `geant4-validate`).
- Reference skills: `geant4-<topic>` (`geant4-geometry`, `geant4-physics-list`,
  `geant4-analysis`). Orchestrator: `geant4`.
- Run IDs: `YYYYMMDD-HHMMSS-<6char>` (UTC). Generated by the `geant4-run` skill.
- Cached helper binaries (built from `templates/<name>/`): `<name>` →
  `${CACHE_DIR}/bin/<name>`. Currently used for `validate_gdml` and `preview_gdml`.

## When adding a task skill

There are no slash commands — every procedure is a skill (so it runs on both
Claude Code and Codex).

1. Directory `skills/geant4-<verb>/` with `SKILL.md`. Frontmatter:
   ```yaml
   ---
   name: geant4-<verb>
   description: <a *trigger* — "Use when the user wants to …". Keep it disjoint
     from sibling skills so triggering is reliable.>
   ---
   ```
2. Body sections, in order: **Purpose**, **Inputs**, **Steps**, **Outputs**,
   **Failure modes**.
3. The first bash step is the engine preamble
   (`[ -f .g4c/env ] && . .g4c/env; G4RUN="${G4RUN:-$PWD/.g4c/g4run}"`); any
   Geant4/ROOT/CMake call is `"${G4RUN}" …`. No `CLAUDE_*`/`CODEX_*` env, no
   `/geant4-claude:` names (phase 0d gate).
4. Skills that run Python must first call
   `. .g4c/env; "${GEANT4_CLAUDE_ROOT}/scripts/ensure_venv.sh"` and run via
   `"${GEANT4_CLAUDE_DATA}/venv/bin/python"` (Codex has no venv hook).
5. Must work from an empty workspace (the `geant4-init` skill runs first) and
   from a populated one (nothing destructive without `--force`).
6. Update `docs/DESIGN.md`'s **Skill surface** with the new one-liner.

## When adding a skill

1. Directory `skills/<name>/` with `SKILL.md`. Frontmatter:
   ```yaml
   ---
   name: <name>
   description: <when to load this skill — be specific so triggering is reliable>
   ---
   ```
2. Skills are *reference material*, not workflows — with one deliberate
   exception, `skills/geant4/SKILL.md`, the full-flow orchestrator that
   sequences `init → detector → build → run → analyze` from a single user
   request. The orchestrator exists because skills auto-load on natural-
   language triggers and commands don't; that's the only reason to make a
   workflow-bearing skill. Don't add a second one without a comparable
   reason. All other skills explain *how* to do a piece (GDML units,
   picking a physics list, an `uproot` recipe).
3. Cross-link from any command that should pull the skill in.

## Testing the plugin (dogfooding)

Three layers, in order of cost.

### 1. `tests/clean-smoke.sh` — fast plumbing test (~3–8 min)

**Use:** every commit that touches `bin/g4run`, `templates/`, the
example main, `scripts/ensure_venv.sh`, or any `skills/*/SKILL.md`.

Exercises `bin/g4run` + the workspace/example templates end-to-end
against a sandboxed `CLAUDE_PLUGIN_DATA`, plus the pure-bash gates
(incl. phase 0d's CLI-neutral skills check; phase 0e/0e2's `ensure_venv.sh`
bootstrap **and** stale-snapshot self-heal; phase 0f's strict-YAML
frontmatter lint; phase 0g's `CLAUDE.md`↔`AGENTS.md` mirror; and phase 0h's
`.g4c/` live-resolution check, which runs `geant4-init`'s actual step-5 recipe
extracted from the SKILL — no drift). Doesn't go through Claude Code or Codex,
so it doesn't catch skill-dispatch / MCP / AskUserQuestion regressions —
those need layer 2 or 3 (the bootstrap itself is covered by phase 0e). Catches
everything else (wrapper plumbing, build, run, schema-detection,
idempotency, the no-fallback cache resolution, the tracked-files
`/home/$USER` leakage scan, the optical fixture's Frank-Tamm closure,
plus pure-bash gates: exit-capture, recipe↔fixture drift, the
`g4run-unit` helper tests, and the README/`_config.yml`↔`g4run`
image-tag sync check). The two lints (`lint-skill-frontmatter.py`,
`lint-agents-mirror.sh`) also run standalone and in CI
(`.github/workflows/lint.yml`).

```bash
# Reuse an existing .sif (fast):
G4C_REUSE_SIF=~/.claude/plugins/data/geant4-claude-geant4-claude/cache/sif/g4install_*.sif \
  tests/clean-smoke.sh

# Or fresh pull:
tests/clean-smoke.sh
```

### 2. `tests/clean-install-test.sh` — automated clean-install (~5 min)

**Use:** before pushing a release tag, when the prompt-flow hasn't
changed since the last manual checklist pass. **Don't use** as the
first run after landing a change that may add or alter a prompt — an
auto-clicked unknown prompt is exactly what you don't want.

Spawns a sandboxed Claude Code in tmux (HOME-overridden so the real
`~/.claude` is untouched), drives `/plugin marketplace add` →
`/plugin install` → exit/relaunch (to load the installed plugin) →
`geant4-init` (which seeds the venv via `ensure_venv.sh`) → `…example` → `…build` → `…run` →
`…analyze`, and verifies on-disk post-conditions at each gate.
Symlinks the host's `.sif` and (if present) `geant4-src` and `venv`
into the sandbox to skip downloads.

```bash
tests/clean-install-test.sh
```

### 3. `tests/CLEAN-INSTALL-CHECKLIST.md` — manual checklist (~10 min)

**Use:** the first time you run after a release that may have
introduced a new prompt, or when you want a human review of every
step. The definitive pre-publish gate.

Covers what layer 2 also covers, plus phase 5 (custom flow with an
operator-written `src/main.cc`) and phase 6 (idempotency edge cases).

---

If any layer fails on a fresh machine, that's a bug, not a user error.

## Pre-publish checks

Before tagging a release or pushing the public branch:

- `git grep -In "/home/$USER\|jlab\.org\|jefflab" -- ':!tests/clean-smoke.sh'`
  returns nothing (run with the maintainer's actual `$USER` expanded).
  Tracked files only — matches `clean-smoke.sh` phase 7; an untracked
  local scratch file (e.g. a gitignored `BUILD_LOG.md`) is intentionally
  not scanned and is not a leak.
- `grep -RIn "TODO\|FIXME\|XXX" .` is reviewed; nothing critical left.
- `bin/g4run` tag matches `.claude-plugin/plugin.json` version expectations
  (image tag may lag plugin version, but bumping the image bumps minor).
- Smoke test passes on a fresh clone.
- `LICENSE` (MIT) present; `README.md` shows the four-step smoke test with
  real output.
- Plugin version in `.claude-plugin/plugin.json` bumped per semver.

## Style

- English only in code, commands, and prose.
- Lead with the conclusion, then the reasoning.
- Default to no comments in code; only add when the *why* is non-obvious.
- Keep command and skill bodies tight. If a section grows past ~40 lines, it's
  probably two things — split it.
