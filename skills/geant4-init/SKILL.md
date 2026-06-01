---
name: geant4-init
description: Use when the user wants to set up / scaffold / initialize a new Geant4 project in the current directory — the top-level dir that manages multiple simulation tasks. Writes the project docs (AGENTS.md, log.md) and the shared engine pointer (.g4c/), bootstraps the Python venv, and pre-pulls the runtime container. Run this once per project; then create each simulation task with the geant4-task skill.
---

# geant4-init — scaffold a Geant4 project

Sets up a fresh Geant4 **project** in the user's current directory: the project
docs that manage and record its simulation tasks, plus the **shared engine**
every task uses. **This is the keystone step: it writes `.g4c/` at the project
root — the pointer every other skill reaches by walking up the tree to locate
`bin/g4run`, the cache, and the venv — CLI-neutrally, on both Claude Code and
Codex.** Individual simulation tasks are created *inside* this project by the
**geant4-task** skill (one subdirectory each).

## Inputs

Optional: `--force` (overwrite existing project files).

## Steps

1. **Resolve the plugin root (CLI-neutral).** You need the absolute path to this
   plugin's checkout:
   - **Claude Code:** it is `${CLAUDE_PLUGIN_ROOT}`.
   - **Codex:** the directory of *this skill* is provided to you in context. The
     plugin root is its parent's parent (`…/skills/geant4-init/` → `…/`).

   Set `PLUGIN_ROOT` to that absolute path for the commands below.

2. **Confirm environment.** Check apptainer is on PATH:
   ```bash
   command -v apptainer >/dev/null && apptainer --version
   ```
   If missing, stop and tell the user to install apptainer
   (https://apptainer.org). Do not proceed.

3. **Detect collisions.** List existing project entries that would be touched:
   ```bash
   ls -A 2>/dev/null | grep -E '^(CLAUDE\.md|AGENTS\.md|\.gitignore|log\.md|\.g4c)$' || true
   ```
   - Non-empty and `--force` *not* passed: stop, show what's there, ask whether
     to re-run with `--force`. (If `src/`/`geometries/`/`runs/` are present this
     looks like an old single-tier workspace — say so: this skill now scaffolds
     the *project* tier; tasks live in subdirs created by **geant4-task**.)
   - `--force` passed: proceed and overwrite.
   - Empty: proceed.

4. **Copy the project docs** into `.` and write the project `.gitignore`:
   ```bash
   cp "${PLUGIN_ROOT}/templates/AGENTS.md" "${PLUGIN_ROOT}/templates/log.md" .
   ln -sfn AGENTS.md CLAUDE.md
   cat > .gitignore <<'EOF'
   # geant4_claude project — shared engine (large, local; never committed)
   .g4c/
   cache/
   venv/
   EOF
   ```
   `AGENTS.md` is the project rulebook (+ a `CLAUDE.md` symlink to it so Claude
   Code reads the same rules), and `log.md` is the project record — a Tasks
   table + chronological log tracking every simulation task. Treat `log.md` as
   load-bearing, not decorative. The per-task `src/ geometries/ macros/ runs/
   analysis/` + handoff docs are *not* created here — each task gets them from
   the **geant4-task** skill.

5. **Record the engine pointer `.g4c/` (the keystone).** Resolve the data dir
   CLI-neutrally and write the pointer the other skills read. `.g4c/env`
   resolves the plugin root **live** so a plugin version bump never strands the
   project (each CLI installs every version under its own dir), and exports a
   **project-rooted** venv. The `.sif` cache is *not* recorded here — the
   wrapper resolves it from the project root (the `.g4c/` marker) so it is
   project-rooted too. `GEANT4_CLAUDE_DATA` is a frozen shared dir (under
   `~/.cache` or the plugin data dir), used only as the standalone venv
   fallback base.
   ```bash
   DATA="${GEANT4_CLAUDE_DATA:-${CLAUDE_PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/geant4_claude}}"
   mkdir -p .g4c "$DATA"
   # .g4c/env — sourced by every skill (and by the shim below).
   #  - GEANT4_CLAUDE_DATA: frozen shared data dir (standalone venv fallback base).
   #  - GEANT4_CLAUDE_ROOT: plugin root, resolved live each source — Claude's live
   #    env -> the install recorded at init (this project's own install) -> newest
   #    install by mtime across the Claude + Codex caches (handles a version bump
   #    that removed the recorded path).
   #  - GEANT4_CLAUDE_VENV: <project-root>/venv, found by walking up to .g4c/
   #    so a task subdir invocation resolves up to it. (The .sif cache is
   #    resolved the same way by the wrapper itself: <root>/cache.)
   cat > .g4c/env <<EOF
   export GEANT4_CLAUDE_DATA="${DATA}"
   _g4c_root="\${CLAUDE_PLUGIN_ROOT:-}"
   [ -x "\${_g4c_root}/bin/g4run" ] || _g4c_root="${PLUGIN_ROOT}"
   if [ ! -x "\${_g4c_root}/bin/g4run" ]; then
     _g4c_root="\$(ls -td "\${CLAUDE_CONFIG_DIR:-\$HOME/.claude}"/plugins/cache/*/geant4-claude/*/ "\${CODEX_HOME:-\$HOME/.codex}"/plugins/cache/*/geant4-claude/*/ 2>/dev/null | head -1)"
     _g4c_root="\${_g4c_root%/}"
   fi
   export GEANT4_CLAUDE_ROOT="\${_g4c_root}"
   _g4c_ws="\$PWD"
   while [ "\${_g4c_ws}" != "/" ] && [ ! -d "\${_g4c_ws}/.g4c" ]; do _g4c_ws="\$(dirname "\${_g4c_ws}")"; done
   [ -d "\${_g4c_ws}/.g4c" ] || _g4c_ws="\$PWD"
   export GEANT4_CLAUDE_VENV="\${_g4c_ws}/venv"
   unset _g4c_root _g4c_ws
   EOF
   # .g4c/g4run — a shim (not a symlink). It sources .g4c/env by ABSOLUTE path
   # (baked at init — no $0, no nested quotes, so it can't be mangled to
   # `dirname ""` and works from any cwd), and only when GEANT4_CLAUDE_ROOT isn't
   # already exported — the skill preamble sources .g4c/env first, so the normal
   # path doesn't depend on the baked path (survives a moved project).
   G4C_DIR="$(cd .g4c && pwd)"
   cat > .g4c/g4run <<EOF
   #!/bin/sh
   [ -n "\${GEANT4_CLAUDE_ROOT:-}" ] || . "${G4C_DIR}/env"
   exec "\${GEANT4_CLAUDE_ROOT}/bin/g4run" "\$@"
   EOF
   chmod +x .g4c/g4run
   ```
   `.g4c/` is gitignored by the project `.gitignore`. Every later skill begins by
   **walking up** from its current dir to the nearest `.g4c/` (so it resolves
   from any task subdir), then sourcing it:
   `G4C="$PWD"; while [ "$G4C" != / ] && [ ! -d "$G4C/.g4c" ]; do G4C="$(dirname "$G4C")"; done; [ -f "$G4C/.g4c/env" ] && . "$G4C/.g4c/env"; G4RUN="${G4RUN:-$G4C/.g4c/g4run}"`.
   All CLI-native resolution lives inside the generated `.g4c/` files, so skill
   bodies stay CLI-neutral.

   Then report where the workspace resolves everything, so the user sees it
   before the multi-GB pull below:
   ```bash
   . .g4c/env
   echo "[g4c] plugin root : ${GEANT4_CLAUDE_ROOT}"
   echo "[g4c] shared data : ${GEANT4_CLAUDE_DATA}   (venv fallback)"
   echo "[g4c] venv        : ${GEANT4_CLAUDE_VENV}"
   echo "[g4c] image cache : ${PWD}/cache/sif   (project-rooted)"
   ```

6. **Bootstrap the Python venv** (idempotent, and always run here — there is no
   SessionStart hook on either CLI):
   ```bash
   . .g4c/env; "${PLUGIN_ROOT}/scripts/ensure_venv.sh"
   ```

7. **Pull the runtime image** through the wrapper (the only sanctioned way to
   invoke the Geant4 runtime):
   ```bash
   . .g4c/env; .g4c/g4run pull
   ```
   First-run downloads ~1–2 GB into the project cache (`<project>/cache/sif/`,
   resolved by the wrapper from the `.g4c/` marker). Reruns no-op.

8. **Report status:**
   ```bash
   . .g4c/env; .g4c/g4run info
   ```
   Then summarize: project docs written, shared engine ready, image cached at.
   **Recommend creating the first task next** with the **geant4-task** skill (it
   makes a task subdir, e.g. `lead-block-edep/`, and `cd`s into it). Inside a
   task the **default flow** is: **geant4-detector** (describe a detector →
   standalone GDML) → **geant4-example** (GDML-loading `main.cc` + macro +
   analysis) → **geant4-build** → **geant4-run** → **geant4-analyze**; the
   **alternative** is to bring your own `src/main.cc` + `src/CMakeLists.txt`
   (hard-coded geometry, custom physics, or a non-`Hits` schema) → **geant4-build**.

## Outputs

- A Geant4 **project** under `cwd`: `AGENTS.md`, `CLAUDE.md`→`AGENTS.md`,
  `log.md` (the task record), and a project `.gitignore`. (No `src/`/
  `geometries/`/`runs/` here — those live in each task subdir, created by
  **geant4-task**.)
- `.g4c/g4run` (shim) + `.g4c/env` — the shared engine pointer every skill
  reaches by walking up to `.g4c/`; both resolve the current `bin/g4run` live,
  so a plugin update doesn't strand the project.
- A shared cached `.sif` at `<project>/cache/sif/` (override with
  `GEANT4_CLAUDE_CACHE` to share one across projects).
- A shared venv at `<project>/venv/` (`GEANT4_CLAUDE_VENV`).

## Failure modes

| Symptom | Likely cause | Fix |
|--------|--------------|-----|
| `apptainer: command not found` | Apptainer not installed. | Install apptainer; rerun. |
| `cp: cannot stat '…/templates/…'` | Plugin not properly installed, or `PLUGIN_ROOT` wrong. | Re-check step 1's `PLUGIN_ROOT`; re-install the plugin. |
| `apptainer pull` auth/network error | Offline or registry unreachable. | Retry with network; or point `GEANT4_CLAUDE_CACHE` at a dir that already has the `.sif`. |
| Existing files refuse to be touched | Project already initialized. | Re-run with `--force` (after confirming with the user). |

## Notes

- Idempotent: re-running in an empty dir pulls once and copies once; re-running
  in a populated dir without `--force` is a no-op (but it always refreshes
  `.g4c/`, which is cheap and correct).
- This scaffolds the **project** (top tier), not a simulation task. Run
  **geant4-task** to add tasks (one subdir each); they share this project's engine.
- The image tag is pinned in `bin/g4run` and only there.
