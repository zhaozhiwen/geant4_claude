---
name: geant4-init
description: Use when the user wants to set up / scaffold / initialize a new Geant4 simulation workspace in the current directory. Creates the generic workspace skeleton, records the engine pointer (.g4c/), bootstraps the Python venv, and pre-pulls the runtime container. Run this once before build/run/analyze.
---

# geant4-init — scaffold a Geant4 workspace

Sets up a fresh, generic Geant4 workspace in the user's current directory and
records how the rest of the plugin reaches its engine. **This is the keystone
step: it writes `.g4c/`, the per-workspace pointer every other skill reads to
locate `bin/g4run` and the cache — CLI-neutrally, on both Claude Code and Codex.**

## Inputs

Optional: `--force` (overwrite existing workspace files).

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

3. **Detect collisions.** List existing entries that would be touched:
   ```bash
   ls -A 2>/dev/null | grep -E '^(CLAUDE\.md|AGENTS\.md|\.gitignore|src|geometries|macros|runs|analysis|log\.md|result\.md)$' || true
   ```
   - Non-empty and `--force` *not* passed: stop, show what's there, ask whether
     to re-run with `--force`.
   - `--force` passed: proceed and overwrite.
   - Empty: proceed.

4. **Copy the workspace template** into `.`:
   ```bash
   cp -r "${PLUGIN_ROOT}/templates/workspace/." .
   ```
   The template ships `AGENTS.md` (+ a `CLAUDE.md` symlink to it so Claude Code
   reads the same rules), `.gitignore`, `log.md`, `result.md`, `report.html`,
   `embed_html.py`, and the empty `src/ geometries/ macros/ runs/ analysis/`
   dirs. Treat the three handoff docs (log.md / result.md / report.html) as
   load-bearing, not decorative.

5. **Record the engine pointer `.g4c/` (the keystone).** Resolve the data dir
   CLI-neutrally and write the pointer the other skills read. `.g4c/env`
   resolves the plugin root **live** so a plugin version bump never strands the
   workspace (each CLI installs every version under its own dir), and exports a
   **workspace-rooted** venv. The `.sif` cache is *not* recorded here — the
   wrapper resolves it from the workspace (the `.g4c/` marker) so it is
   workspace-rooted too. `GEANT4_CLAUDE_DATA` is the one shared dir (under
   `~/.cache` or the plugin data dir): it holds the plugin-wide Geant4 source
   tree (step 8), identical across workspaces, so it stays there.
   ```bash
   DATA="${GEANT4_CLAUDE_DATA:-${CLAUDE_PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/geant4_claude}}"
   mkdir -p .g4c "$DATA"
   # .g4c/env — sourced by every skill (and by the shim below).
   #  - GEANT4_CLAUDE_DATA: frozen shared data dir (standalone venv fallback base).
   #  - GEANT4_CLAUDE_ROOT: plugin root, resolved live — Claude's live env ->
   #    newest Codex install (by mtime; the cache leaf is a hash, not a sortable
   #    version) -> the path recorded here at init (standalone fallback).
   #  - GEANT4_CLAUDE_VENV: <workspace-root>/venv, found by walking up to .g4c/
   #    so a moved workspace or a subdir invocation still resolves. (The .sif
   #    cache is resolved the same way by the wrapper itself: <root>/cache.)
   cat > .g4c/env <<EOF
   export GEANT4_CLAUDE_DATA="${DATA}"
   _g4c_root="\${CLAUDE_PLUGIN_ROOT:-}"
   if [ ! -x "\${_g4c_root}/bin/g4run" ]; then
     _g4c_root="\$(ls -td "\${CODEX_HOME:-\$HOME/.codex}"/plugins/cache/*/geant4-claude/*/ 2>/dev/null | head -1)"
     _g4c_root="\${_g4c_root%/}"
   fi
   [ -x "\${_g4c_root}/bin/g4run" ] || _g4c_root="${PLUGIN_ROOT}"
   export GEANT4_CLAUDE_ROOT="\${_g4c_root}"
   _g4c_ws="\$PWD"
   while [ "\${_g4c_ws}" != "/" ] && [ ! -d "\${_g4c_ws}/.g4c" ]; do _g4c_ws="\$(dirname "\${_g4c_ws}")"; done
   [ -d "\${_g4c_ws}/.g4c" ] || _g4c_ws="\$PWD"
   export GEANT4_CLAUDE_VENV="\${_g4c_ws}/venv"
   unset _g4c_root _g4c_ws
   EOF
   # .g4c/g4run — a shim (not a symlink): defers to .g4c/env's live ROOT, so the
   # wrapper path is never frozen. Skills still just call .g4c/g4run unchanged.
   cat > .g4c/g4run <<'EOF'
   #!/bin/sh
   . "$(dirname "$0")/env"
   exec "${GEANT4_CLAUDE_ROOT}/bin/g4run" "$@"
   EOF
   chmod +x .g4c/g4run
   ```
   `.g4c/` is gitignored by the workspace `.gitignore`. Every later skill begins
   with `[ -f .g4c/env ] && . .g4c/env; G4RUN="${G4RUN:-$PWD/.g4c/g4run}"` —
   unchanged; all CLI-native resolution lives inside the generated `.g4c/` files,
   so skill bodies stay CLI-neutral.

   Then report where the workspace resolves everything, so the user sees it
   before the multi-GB pull below:
   ```bash
   . .g4c/env
   echo "[g4c] plugin root : ${GEANT4_CLAUDE_ROOT}"
   echo "[g4c] shared data : ${GEANT4_CLAUDE_DATA}   (venv fallback)"
   echo "[g4c] venv        : ${GEANT4_CLAUDE_VENV}"
   echo "[g4c] image cache : ${PWD}/cache/sif   (workspace-rooted)"
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
   First-run downloads ~1–2 GB into the workspace cache (`<workspace>/cache/sif/`,
   resolved by the wrapper from the `.g4c/` marker). Reruns no-op.

8. **Report status:**
   ```bash
   . .g4c/env; .g4c/g4run info
   ```
   Then summarize: workspace files written, image cached at, and what to do next.
   Recommend the **default flow** first: the **geant4-detector** skill (describe
   a detector → standalone GDML), then **geant4-example** (drops in a GDML-loading
   `main.cc` + macro + analysis), then **geant4-build** → **geant4-run** →
   **geant4-analyze**. Mention the **alternative**: bring your own `src/main.cc` +
   `src/CMakeLists.txt` for hard-coded geometry, custom physics, or a non-`Hits`
   output schema, then **geant4-build**.

## Outputs

- A populated workspace under `cwd` (`AGENTS.md`, `CLAUDE.md`→`AGENTS.md`,
  `.gitignore`, `log.md`, `result.md`, `report.html`, `embed_html.py`, and the
  empty `src/ geometries/ macros/ runs/ analysis/` dirs).
- `.g4c/g4run` (shim) + `.g4c/env` — the engine pointer the other skills read;
  both resolve the current `bin/g4run` live, so a plugin update doesn't strand
  the workspace.
- A cached `.sif` at `<workspace>/cache/sif/` (workspace-rooted; override with
  `GEANT4_CLAUDE_CACHE` to share one across workspaces).
- A workspace venv at `<workspace>/venv/` (`GEANT4_CLAUDE_VENV`).

## Failure modes

| Symptom | Likely cause | Fix |
|--------|--------------|-----|
| `apptainer: command not found` | Apptainer not installed. | Install apptainer; rerun. |
| `cp: cannot stat '…/templates/…'` | Plugin not properly installed, or `PLUGIN_ROOT` wrong. | Re-check step 1's `PLUGIN_ROOT`; re-install the plugin. |
| `apptainer pull` auth/network error | Offline or registry unreachable. | Retry with network; or point `GEANT4_CLAUDE_CACHE` at a dir that already has the `.sif`. |
| Existing files refuse to be touched | Workspace already initialized. | Re-run with `--force` (after confirming with the user). |

## Notes

- Idempotent: re-running in an empty dir pulls once and copies once; re-running
  in a populated dir without `--force` is a no-op (but it always refreshes
  `.g4c/`, which is cheap and correct).
- The image tag is pinned in `bin/g4run` and only there.
