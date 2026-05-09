# Clean-install checklist

A pre-release smoke test that exercises the parts of the plugin that
`tests/clean-smoke.sh` *can't* reach: Claude Code's slash-command
dispatch, the `SessionStart` hook, the deepwiki MCP approval prompt,
the `AskUserQuestion` flow in `/geant4-init`, and namespace lookup.

**Run this before tagging any release.** ~10 minutes.

> **See also:** `tests/clean-install-test.sh` automates this checklist
> via tmux + sandboxed Claude Code. Use the script to re-run a known
> flow quickly; use this manual checklist when a release may have
> introduced a new prompt that an auto-clicked script shouldn't blindly
> approve.

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

## Phase 2 — `SessionStart` side effects

Open Claude Code in **any** directory (a workspace will be made later).

Pass:
- Claude Code prompts once to approve the `deepwiki` MCP server.
  Approve it.
- `~/.claude/plugins/data/geant4-claude-geant4-claude/venv/bin/python -c "import pdg"`
  succeeds (the SessionStart hook installed `pdg` into the managed venv).
- In Claude Code, `mcp__deepwiki__ask_question` is now an available tool
  (verifiable by listing tools or asking Claude to call it).

## Phase 3 — `/geant4-claude:geant4-init`

```bash
mkdir /tmp/g4c_clean_smoke && cd /tmp/g4c_clean_smoke
```

In Claude Code:

```text
> /geant4-claude:geant4-init
```

Pass:
- Workspace skeleton appears: `CLAUDE.md`, `.gitignore`, plus empty
  `src/`, `geometries/`, `macros/`, `runs/`, `analysis/`.
- `.sif` lands at
  `~/.claude/plugins/data/geant4-claude-geant4-claude/cache/sif/g4install_11.4.0-almalinux-9.4.sif`.
- `AskUserQuestion` for the optional Geant4 source clone fires. Pick
  **Yes**.
- The tarball downloads (~36 MB compressed) and extracts to
  `~/.claude/plugins/data/geant4-claude-geant4-claude/geant4-src/`.
- A symlink at
  `~/.claude/plugins/cache/geant4-claude/geant4-claude/<version>/wiki/raw/geant4-src`
  resolves to the canonical tree.

## Phase 4 — Example flow

In Claude Code, in `/tmp/g4c_clean_smoke`:

```text
> /geant4-claude:geant4-example
> /geant4-claude:geant4-build
> /geant4-claude:geant4-run --exe build/geant4_claude_main -- geometries/example.gdml macros/run.mac {run_dir}/hits.root
> /geant4-claude:geant4-analyze runs/<id>
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

In Claude Code:

```text
> /geant4-claude:geant4-init
```

Then **outside** Claude Code (or with Claude's help), hand-write a
minimal `src/main.cc` + `src/CMakeLists.txt` whose binary writes a
non-`Hits` schema (e.g. a `Tracks` TTree). Then:

```text
> /geant4-claude:geant4-build
> /geant4-claude:geant4-run --exe build/<your-binary> -- <your args> {run_dir}/<output>.root
> /geant4-claude:geant4-analyze runs/<id>
```

Pass:
- `geant4-analyze` takes the **custom path** (no `Hits` TTree found),
  generates a fresh script at `analysis/<run_id>.py`, runs it, and
  produces a plot tailored to the actual branches.

## Phase 6 — Idempotency

Back in `/tmp/g4c_clean_smoke`:

```text
> /geant4-claude:geant4-init
> /geant4-claude:geant4-build
```

Pass:
- `geant4-init` (without `--force`) detects the populated workspace and
  no-ops.
- `geant4-build` is incremental (finishes in seconds, doesn't recompile
  unchanged sources).
- The `.sif` is **not** re-pulled. Spot-check the mtime.

## Phase 7 — Cache propagation regression

This guards against the bug fixed in `37361d9` (CLAUDE_PLUGIN_DATA not
making it into Bash subshells, causing silent re-pull from
`$HOME/.geant4_claude`).

Pass:
- Throughout phases 3–6, no `.sif` ever appears in `~/.geant4_claude/`
  (the legacy path; should not exist or be touched).
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

## Pass criteria for the release

All eight phases pass without manual workarounds. Any phase that needed
a workaround is a release blocker.
