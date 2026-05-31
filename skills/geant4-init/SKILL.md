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
   CLI-neutrally and write the pointer the other skills read. Both files resolve
   the plugin root **live** so a plugin version bump never strands the workspace:
   each CLI installs every version under its own dir (`$CLAUDE_PLUGIN_ROOT` on
   Claude; a per-version dir under `$CODEX_HOME/plugins/cache/` on Codex), so a
   frozen path would dangle after an update. `DATA`/`CACHE` live under `~/.cache`
   (or the plugin data dir) and are stable, so they stay frozen.
   ```bash
   DATA="${GEANT4_CLAUDE_DATA:-${CLAUDE_PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/geant4_claude}}"
   mkdir -p .g4c "$DATA"
   # .g4c/env — sourced by every skill (and by the shim below). ROOT is resolved
   # live each time: Claude's live env -> newest Codex install (by mtime; the
   # cache leaf is a hash, not a sortable version) -> the path recorded here at
   # init (bare-clone / standalone fallback).
   cat > .g4c/env <<EOF
   export GEANT4_CLAUDE_DATA="${DATA}"
   export GEANT4_CLAUDE_CACHE="${DATA}/cache"
   _g4c_root="\${CLAUDE_PLUGIN_ROOT:-}"
   if [ ! -x "\${_g4c_root}/bin/g4run" ]; then
     _g4c_root="\$(ls -td "\${CODEX_HOME:-\$HOME/.codex}"/plugins/cache/*/geant4-claude/*/ 2>/dev/null | head -1)"
     _g4c_root="\${_g4c_root%/}"
   fi
   [ -x "\${_g4c_root}/bin/g4run" ] || _g4c_root="${PLUGIN_ROOT}"
   export GEANT4_CLAUDE_ROOT="\${_g4c_root}"
   unset _g4c_root
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
   echo "[g4c] data dir    : ${GEANT4_CLAUDE_DATA}"
   echo "[g4c] image cache : ${GEANT4_CLAUDE_CACHE}/sif"
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
   First-run downloads ~1–2 GB into `${GEANT4_CLAUDE_CACHE}/sif/`. Reruns no-op.

8. **Offer the Geant4 source checkout (one-time, plugin-wide).** The wiki's
   `sources/geant4-code/synthesis/` pages cite specific `.cc:line` ranges, only
   verifiable if the Geant4 source tree is present. Canonical location is
   `${GEANT4_CLAUDE_DATA}/geant4-src/` (survives plugin version bumps); a symlink
   at `${PLUGIN_ROOT}/wiki/raw/geant4-src` points at it.

   Migrate any pre-relocation tree and (re)create the symlink:
   ```bash
   . .g4c/env
   GEANT4_SRC="${GEANT4_CLAUDE_DATA}/geant4-src"
   LEGACY_SRC="${GEANT4_CLAUDE_ROOT}/wiki/raw/geant4-src"
   if [ -d "${LEGACY_SRC}" ] && [ ! -L "${LEGACY_SRC}" ]; then
     if [ -e "${GEANT4_SRC}" ]; then
       echo "[g4c] note: both ${LEGACY_SRC} and ${GEANT4_SRC} exist; skipping auto-migration."
     else
       mkdir -p "$(dirname "${GEANT4_SRC}")"; mv "${LEGACY_SRC}" "${GEANT4_SRC}"
       echo "[g4c] migrated geant4-src -> ${GEANT4_SRC}"
     fi
   fi
   if [ -d "${GEANT4_SRC}" ]; then
     mkdir -p "$(dirname "${LEGACY_SRC}")"
     if [ -L "${LEGACY_SRC}" ] || [ ! -e "${LEGACY_SRC}" ]; then
       ln -sfn "${GEANT4_SRC}" "${LEGACY_SRC}"
     elif [ -d "${LEGACY_SRC}" ]; then
       echo "[g4c] warning: ${LEGACY_SRC} is a real directory; refusing to overwrite."
     fi
   fi
   test -d "${GEANT4_SRC}/source" && echo "[g4c] geant4-src already present at ${GEANT4_SRC}"
   ```

   If missing, derive the matching tag from the pinned image and ask the user:
   ```bash
   . .g4c/env
   G4_VERSION=$(sed -n 's/^IMAGE_TAG=.*g4install:\([0-9.]*\)-.*/\1/p' "${GEANT4_CLAUDE_ROOT}/bin/g4run")
   TARBALL_URL="https://github.com/Geant4/geant4/archive/refs/tags/v${G4_VERSION}.tar.gz"
   echo "[g4c] would download Geant4 v${G4_VERSION} source (~36 MB compressed, ~200 MB extracted) into ${GEANT4_CLAUDE_DATA}/geant4-src"
   ```
   Then use AskUserQuestion (Claude) or ask in prose (Codex):
   - **Yes, fetch tarball** — recommended; ~36 MB download, ~200 MB on disk; no git history.
   - **Skip for now** — wiki synthesis still readable, but `.cc:line` citations can't be cross-checked locally.

   On **Yes**, fetch the matching tag, extract, and (re)create the symlink:
   ```bash
   . .g4c/env
   GEANT4_SRC="${GEANT4_CLAUDE_DATA}/geant4-src"; LEGACY_SRC="${GEANT4_CLAUDE_ROOT}/wiki/raw/geant4-src"
   mkdir -p "${GEANT4_SRC}" "$(dirname "${LEGACY_SRC}")"
   TMPFILE=$(mktemp -t geant4-src.XXXXXX.tar.gz); trap 'rm -f "${TMPFILE}"' EXIT
   if command -v curl >/dev/null 2>&1; then curl -fL --progress-bar -o "${TMPFILE}" "${TARBALL_URL}"
   elif command -v wget >/dev/null 2>&1; then wget -O "${TMPFILE}" "${TARBALL_URL}"
   else echo "[g4c] neither curl nor wget found"; rmdir "${GEANT4_SRC}" 2>/dev/null || true; exit 1; fi
   tar -xzf "${TMPFILE}" -C "${GEANT4_SRC}" --strip-components=1
   ln -sfn "${GEANT4_SRC}" "${LEGACY_SRC}"
   ```
   On **Skip**, continue; re-running this skill later is idempotent.

9. **Report status:**
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
- A cached `.sif` at `${GEANT4_CLAUDE_CACHE}/sif/`.
- (Optional, on consent) Geant4 source tree at `${GEANT4_CLAUDE_DATA}/geant4-src/`
  with the `wiki/raw/geant4-src` symlink.

## Failure modes

| Symptom | Likely cause | Fix |
|--------|--------------|-----|
| `apptainer: command not found` | Apptainer not installed. | Install apptainer; rerun. |
| `cp: cannot stat '…/templates/…'` | Plugin not properly installed, or `PLUGIN_ROOT` wrong. | Re-check step 1's `PLUGIN_ROOT`; re-install the plugin. |
| `apptainer pull` auth/network error | Offline or registry unreachable. | Retry with network; or point `GEANT4_CLAUDE_CACHE` at a dir that already has the `.sif`. |
| Existing files refuse to be touched | Workspace already initialized. | Re-run with `--force` (after confirming with the user). |
| Geant4 source download 404/network | Offline, GitHub unreachable, or version not yet tagged. | Skip; re-run later. |

## Notes

- Idempotent: re-running in an empty dir pulls once and copies once; re-running
  in a populated dir without `--force` is a no-op (but it always refreshes
  `.g4c/` and the `wiki/raw/geant4-src` symlink, which is cheap and correct).
- The image tag is pinned in `bin/g4run` and only there.
