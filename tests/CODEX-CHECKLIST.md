# Codex CLI manual checklist

`tests/clean-smoke.sh` covers the platform-neutral plumbing (`bin/g4run` + the
workspace/example templates + build/run/analyze + the pure-bash gates) with no
harness in the loop. `tests/clean-install-test.sh` + `CLEAN-INSTALL-CHECKLIST.md`
cover the **Claude Code** install path. This checklist covers what only a real
**Codex CLI** session exercises: plugin install, skill auto-activation, the
approval gate, and the live engine-pointer resolution across a plugin update.
Run it on a host with apptainer + git + curl/wget + python3.

> Cannot be automated here — Codex is interactive. Tick each box by hand.

> **Sandbox caveat:** apptainer typically cannot open its socket under Codex's
> `workspace-write` sandbox (`socket communication error: ... operation not
> permitted`). The container steps (`g4run pull`, `validate-gdml`, `build`,
> `run`) must run **outside** the sandbox — approve Codex's per-command
> escalation prompt, or launch with a full-access policy. Skill load, planning,
> the approval gate, scaffolding, and the host-side sketch preview all work
> under the sandbox; only the apptainer calls need the escalation.

## 1. Install

- [ ] `codex plugin marketplace add zhaozhiwen/geant4_claude` then
      `codex plugin add geant4-claude@geant4-claude`; confirm it caches under
      `~/.codex/plugins/cache/…` and the bundled skills load (ask "is the
      geant4 skill available?"). **No YAML load error** in the logs —
      frontmatter must be strict-YAML clean (the `lint` CI workflow guards this).
- [ ] `AGENTS.md` is present in the installed plugin as a **real file** (it is
      the canonical source; the `CLAUDE.md` symlink → `AGENTS.md` is dropped by
      `codex plugin add` — harmless, Codex reads `AGENTS.md`).
- [ ] No hook-trust prompt at session start (the plugin ships no hooks; the
      venv installs lazily on first Python-using skill).

## 2. Skill auto-activation

- [ ] A plain-language request — "set up a Geant4 simulation workspace" or
      "simulate a 1 GeV e- on a lead block" — activates the `geant4`
      orchestrator (not a generic response).
- [ ] The skill resolves the engine with **no `CLAUDE_PLUGIN_*` errors**:
      `geant4-init` writes `.g4c/`, and every later skill reaches the wrapper
      through `.g4c/g4run` (a shim resolving the current `bin/g4run` live).

## 3. Approval gate (no AskUserQuestion on Codex)

- [ ] The plan/approval gate appears as an explicit numbered **Approve / Edit /
      Plan-only** question — not prose ending in "let me know."
- [ ] Picking "Plan only" writes **no** files. Picking "Approve" proceeds.
- [ ] No artifact is created before an explicit approval in the same turn.

## 4. End-to-end run

- [ ] First request triggers `geant4-init` (workspace skeleton drops both
      `CLAUDE.md` and `AGENTS.md`; `.g4c/` engine pointer written; `.sif` pulled).
- [ ] `geant4-detector` → standalone GDML, or `geant4-example` drops in a
      GDML-loading `main.cc` + macro + analysis.
- [ ] `geant4-build` compiles inside the container; `geant4-run` produces
      `runs/<id>/{hits.root, log.txt, config.json}` (or the run's output schema).
- [ ] `geant4-analyze` installs the venv lazily on first use (no SessionStart
      hook on Codex) under `${GEANT4_CLAUDE_DATA}/venv`, and writes PNGs.
- [ ] `log.md` gets the verbatim run entry (user input → plan → decision → outcome).

## 5. Engine pointer survives a plugin update (Design X)

This is the reason `.g4c/g4run` is a live-resolving shim, not a frozen symlink.

- [ ] In an initialized workspace, `cat .g4c/g4run` shows a `/bin/sh` shim that
      sources `.g4c/env` and execs `${GEANT4_CLAUDE_ROOT}/bin/g4run`.
- [ ] `. .g4c/env; echo "$GEANT4_CLAUDE_ROOT"` prints the **currently installed**
      version dir under `~/.codex/plugins/cache/…/geant4-claude/…`.
- [ ] Install a newer plugin version (`codex plugin add geant4-claude@geant4-claude`
      after a version bump), then — **without re-running `geant4-init`** — run any
      skill in the same workspace. It resolves the **new** version automatically
      (the shim re-globs the newest install by mtime). No "cannot execute" error.

## 6. Path hygiene

- [ ] The `.sif` landed at `${GEANT4_CLAUDE_CACHE}/sif/` — i.e. under
      `~/.cache/geant4_claude/cache` (or `$GEANT4_CLAUDE_CACHE` if overridden),
      **not** under the version-pinned plugin install dir. This is what lets the
      cache survive a plugin update. Confirm with `. .g4c/env; .g4c/g4run info`.
- [ ] Re-running `geant4-init` is idempotent (existing files skipped without
      `--force`; `.g4c/` and the `wiki/raw/geant4-src` symlink are refreshed).
