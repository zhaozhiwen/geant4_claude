# Clean-install checklist

A pre-release smoke test that exercises the parts of the plugin that
`tests/clean-smoke.sh` *can't* reach: Claude Code's natural-language
skill triggering, the deepwiki MCP approval prompt, the `AskUserQuestion`
flow in the `geant4-init` skill, and plugin install. Steps are triggered
by plain-language requests that should auto-fire the matching
`geant4-<verb>` skill — there are no slash commands anymore.

**Run this before tagging any release.** ~10 minutes.

> **See also:** `tests/clean-install-test.sh` automates this checklist
> via tmux + sandboxed Claude Code. Use the script to re-run a known
> flow quickly; use this manual checklist when a release may have
> introduced a new prompt that an auto-clicked script shouldn't blindly
> approve, or when you want to confirm by hand that each plain-language
> request fires the right skill.

## Prerequisites

- A host with `apptainer` installed and on PATH.
- Claude Code with the plugin marketplace feature enabled.
- ~2.5 GB of free disk for the cached `.sif` if a fresh pull is needed.
- Either:
  - **(preferred)** the plugin not installed yet on this host — phases 0–1
    cover install from scratch, or
  - the plugin installed previously — phase 0 wipes per-user state to
    simulate a clean install on the same host.

## Phase 0 — Reset state

Goal: make the host look (functionally) like one that has never seen
the plugin before.

```bash
# In Claude Code, if the plugin is currently installed:
> /plugin uninstall geant4-claude

# Wipe per-user runtime + reference data:
rm -rf ~/.claude/plugins/data/geant4-claude-geant4-claude
rm -rf ~/.claude/plugins/cache/geant4-claude            # marketplace install
rm -rf ~/.geant4_claude                                  # legacy cache (now removed by code)

# Confirm plugin not registered:
grep -q geant4-claude ~/.claude/plugins/installed_plugins.json && echo NOT clean || echo clean
```

Pass: `clean`.

## Phase 1 — Install

In Claude Code:

```text
> /plugin marketplace add zhaozhiwen/geant4_claude
> /plugin install geant4-claude@geant4-claude
```

Pass:
- Both commands report success.
- `~/.claude/plugins/cache/geant4-claude/geant4-claude/<version>/.claude-plugin/plugin.json`
  exists and has the expected version (`grep version` it).
- `installed_plugins.json` lists `geant4-claude@geant4-claude`.

## Phase 2 — Plugin load + MCP approval

Exit and relaunch Claude Code so the freshly-installed plugin's
commands/skills and MCP server load. Open it in **any** directory (a
workspace will be made later).

Pass:
- Claude Code prompts once to approve the `deepwiki` MCP server.
  Approve it.
- In Claude Code, `mcp__deepwiki__ask_question` is now an available tool
  (verifiable by listing tools or asking Claude to call it).

> The pdg venv is **not** created at session start — there is no
> SessionStart hook on either CLI. It is seeded later, when the
> `geant4-init` skill runs `scripts/ensure_venv.sh` (checked in phase 3).

## Phase 3 — Set up workspace (geant4-init skill)

```bash
mkdir /tmp/g4c_clean_smoke && cd /tmp/g4c_clean_smoke
```

In Claude Code, ask in plain language (this should auto-trigger the
`geant4-init` skill):

```text
> Set up a Geant4 workspace in the current directory.
```

Pass:
- Workspace skeleton appears: `CLAUDE.md`, `.gitignore`, plus empty
  `src/`, `geometries/`, `macros/`, `runs/`, `analysis/`.
- `<workspace>/venv/bin/python -c "import pdg"` succeeds (the `geant4-init`
  skill ran `scripts/ensure_venv.sh`, which installed `pdg` into the
  workspace-rooted managed venv).
- `.sif` lands at `<workspace>/cache/sif/g4install_11.4.0-almalinux-9.4.sif`
  (workspace-rooted; **not** under the plugin install or `~/.geant4_claude`).
- No Geant4-source prompt fires (the source-clone step was removed; the wiki
  links to the Geant4 source on GitHub instead).

## Phase 4 — Example flow

In Claude Code, in `/tmp/g4c_clean_smoke`, ask in plain language (each
request should auto-trigger the matching skill):

```text
> Drop in the shipped example (GDML + main.cc + macro + analysis).
> Build the simulation from src/ into build/.
> Run the simulation: ./build/geant4_claude_main on geometries/example.gdml with macros/run.mac, writing the output to {run_dir}/hits.root.
> Analyze run runs/<id>.
```

Pass at each step:

| Command | Verify |
|---|---|
| `geant4-example` | `src/{geant4_claude_main.cc, CMakeLists.txt}`, `geometries/example.gdml`, `macros/run.mac`, `analysis/example.py` materialize. |
| `geant4-build` | `build/geant4_claude_main` (~80 KB ELF) produced. |
| `geant4-run` | `runs/<id>/{hits.root, log.txt, config.json}` produced. `config.json` shape: `executable`, `args`, `image`, `git_sha`, `started_utc`, `duration_s`, `exit_status`. **No** `particle`/`energy_MeV`/`n_events`/`geometry`/`macro` fields (those were removed in v0.0.2). |
| `geant4-analyze` | `runs/<id>/edep_hist.png` produced. Summary prints ~1000 events / ~1.2M hits / ~640 MeV/event mean. |

## Phase 5 — Custom flow (different schema)

In a second scratch dir:

```bash
mkdir /tmp/g4c_clean_custom && cd /tmp/g4c_clean_custom
```

In Claude Code, ask in plain language:

```text
> Set up a Geant4 workspace in the current directory.
```

Then **outside** Claude Code (or with Claude's help), hand-write a
minimal `src/main.cc` + `src/CMakeLists.txt` whose binary writes a
non-`Hits` schema (e.g. a `Tracks` TTree). Then ask in plain language:

```text
> Build the simulation from src/ into build/.
> Run the simulation: ./build/<your-binary> on <your args>, writing the output to {run_dir}/<output>.root.
> Analyze run runs/<id>.
```

Pass:
- `geant4-analyze` takes the **custom path** (no `Hits` TTree found),
  generates a fresh script at `analysis/<run_id>.py`, runs it, and
  produces a plot tailored to the actual branches.

## Phase 6 — Idempotency

Back in `/tmp/g4c_clean_smoke`, ask in plain language again:

```text
> Set up a Geant4 workspace in the current directory.
> Build the simulation from src/ into build/.
```

Pass:
- `geant4-init` (without `--force`) detects the populated workspace and
  no-ops.
- `geant4-build` is incremental (finishes in seconds, doesn't recompile
  unchanged sources).
- The `.sif` is **not** re-pulled. Spot-check the mtime.

## Phase 7 — Workspace-rooted cache regression

The cache + venv are anchored to the workspace (the wrapper walks up to the
`.g4c/` marker), not the plugin install, so a workspace is self-contained and
survives plugin updates. `g4run info` tags the cache `[workspace (<root>/cache)]`.

Pass:
- The `.sif` lives in `<workspace>/cache/sif/`, and the venv in
  `<workspace>/venv/` — **not** under `~/.claude/plugins/data/.../cache` or the
  legacy `~/.geant4_claude/`.
- `runs/<id>/log.txt` files contain no mention of pulling the image
  except on the very first `geant4-init` run.

## Phase 8 — Cleanup

Optional:

```bash
rm -rf /tmp/g4c_clean_smoke /tmp/g4c_clean_custom
# To uninstall the plugin again:
> /plugin uninstall geant4-claude
```

The data dir under `~/.claude/plugins/data/geant4-claude-*/` is removed
automatically when the plugin is uninstalled.

## Phase 9 — Optical-photon orchestrator (manual; clean-smoke can't reach this)

**Goal:** verify the full orchestrator flow for an optical spec, including
the RINDEX gate, the recipe-guided in-place edit, and the validate
closure step.

In a fresh scratch dir:

```bash
mkdir /tmp/g4c_optical_orch && cd /tmp/g4c_optical_orch
```

In Claude Code, send a single natural-language request:

```text
> Cherenkov yield from a 1 m CO₂ radiator, 10 GeV e⁻
```

The orchestrator skill should load, gap-check the spec, and present a
plan. Verify the plan shows `geant4-validate cherenkov` as the final
step.

Approve the plan and let the orchestrator run. Pass criteria:

| Check | Verify |
|---|---|
| **RINDEX gate — missing index** | Before approving, ask Claude to re-run with "a CO₂ radiator but don't add a refractive index". `geant4-detector` must stop and name the material that is missing RINDEX — do not write a success GDML. |
| **RINDEX gate — happy path** | When given a valid spec (n ≈ 1.00045), `geant4-detector` writes `geometries/<name>.gdml` containing a `<matrix>` and `<property name="RINDEX">` for the radiator material. |
| **Recipe-guided edit announced** | Claude tells the user explicitly that it is applying the optical-main recipe in place to `src/geant4_claude_main.cc` (the improvisation rule: it names `geant4-example` as the command bypassed, says it is applying the recipe instead, and says why). It does **not** silently drop in a different main. |
| **Edited main compiles** | Asking "Build the simulation from src/ into build/." succeeds. `build/<binary>` is present and executable. |
| **Run produces photons** | Asking to run the simulation completes with exit status 0. `runs/<id>/hits.root` is non-empty. `log.txt` contains `[g4c] attached optical SD` and no `WARNING: no material has a RINDEX property`. |
| **Validate PASS** | Asking "Physics-validate cherenkov for runs/<id> with --rindex-from-gdml geometries/<name>.gdml --rindex-material <radmat> --radiator-length 1m." prints `RESULT: PASS` and writes `runs/<id>/validate_cherenkov.json`. |
| **FAIL surfaced** | If the validate step returns FAIL, Claude stops and shows the PASS/FAIL block verbatim — it does **not** proceed to the final report as if the physics were sound. |

## Pass criteria for the release

All phases pass without manual workarounds. Any phase that needed
a workaround is a release blocker.
