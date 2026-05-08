---
description: Scaffold a Geant4 workspace in the current directory and pull the runtime container.
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# /geant4-init

## Purpose

Set up a fresh Geant4 simulation workspace in the user's current working
directory, and pre-pull the pinned apptainer image so later commands run
without surprise downloads. The workspace is **generic** — it has empty
`src/`, `geometries/`, `macros/`, `runs/`, `analysis/` directories ready
for your own simulation. Run `/geant4-example` afterwards if you want a
ready-to-build sample dropped in.

## Inputs

Optional argument: `--force` (overwrite existing workspace files).

## Steps

1. **Confirm environment.** Check apptainer is on PATH:
   ```bash
   command -v apptainer >/dev/null && apptainer --version
   ```
   If missing, stop and tell the user to install apptainer
   (https://apptainer.org). Do not proceed.

2. **Detect collisions.** List existing entries that would be touched:
   ```bash
   ls -A 2>/dev/null | grep -E '^(CLAUDE\.md|\.gitignore|src|geometries|macros|runs|analysis)$' || true
   ```
   - If the list is non-empty and `--force` was *not* passed: stop, show the
     user what's already there, and ask whether to re-run with `--force`.
   - If `--force` was passed, proceed and overwrite.
   - If the list is empty, proceed.

3. **Copy the workspace template** from the plugin into `.`:
   ```bash
   cp -r "${CLAUDE_PLUGIN_ROOT}/templates/workspace/." .
   ```
   The template ships:
   - `CLAUDE.md` — workspace rules for future Claude sessions.
   - `.gitignore` — excludes `runs/`, `*.root`, `build/`, `__pycache__/`.
   - `src/.gitkeep` — empty source directory (your `main.cc` and
     `CMakeLists.txt` go here, or `/geant4-example` will populate it).
   - `geometries/.gitkeep`, `macros/.gitkeep`, `analysis/.gitkeep` —
     empty directories with the conventional names that the rest of the
     plugin's commands expect.
   - `runs/.gitkeep`.

4. **Pull the runtime image** through the wrapper. This is the *only* sanctioned
   way to invoke the Geant4 runtime; all later commands also go through it:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/bin/g4run" pull
   ```
   First-run downloads ~1–2 GB into `${CLAUDE_PLUGIN_DATA}/cache/sif/`
   (override with `GEANT4_CLAUDE_CACHE`). Reruns no-op.

5. **Offer the Geant4 source checkout (one-time, plugin-wide).** The wiki's
   `sources/geant4-code/synthesis/` pages cite specific `.cc:line` ranges.
   Those citations are only verifiable if the Geant4 source tree is locally
   present.

   The canonical location is `${CLAUDE_PLUGIN_DATA}/geant4-src/` so the
   tree survives plugin version bumps (the plugin checkout at
   `${CLAUDE_PLUGIN_ROOT}` is replaced on update; `${CLAUDE_PLUGIN_DATA}` is
   not). A symlink at `${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src` points at
   the canonical tree so wiki pages can keep using the relative
   `wiki/raw/geant4-src/...` references.

   First, migrate any pre-relocation tree and (re)create the symlink:
   ```bash
   GEANT4_SRC="${CLAUDE_PLUGIN_DATA}/geant4-src"
   LEGACY_SRC="${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src"

   # One-time migration: a real directory at LEGACY_SRC is from a
   # pre-relocation install. Move it into CLAUDE_PLUGIN_DATA.
   if [ -d "${LEGACY_SRC}" ] && [ ! -L "${LEGACY_SRC}" ]; then
     if [ -e "${GEANT4_SRC}" ]; then
       echo "[g4c] note: both ${LEGACY_SRC} and ${GEANT4_SRC} exist; skipping auto-migration. Inspect manually."
     else
       mkdir -p "$(dirname "${GEANT4_SRC}")"
       mv "${LEGACY_SRC}" "${GEANT4_SRC}"
       echo "[g4c] migrated geant4-src -> ${GEANT4_SRC}"
     fi
   fi

   # (Re)create the symlink. Plugin updates wipe ${CLAUDE_PLUGIN_ROOT},
   # so /geant4-init must rebuild this link each run.
   if [ -d "${GEANT4_SRC}" ]; then
     mkdir -p "$(dirname "${LEGACY_SRC}")"
     if [ -L "${LEGACY_SRC}" ] || [ ! -e "${LEGACY_SRC}" ]; then
       ln -sfn "${GEANT4_SRC}" "${LEGACY_SRC}"
     elif [ -d "${LEGACY_SRC}" ]; then
       echo "[g4c] warning: ${LEGACY_SRC} is a real directory; refusing to overwrite. Resolve manually."
     fi
   fi
   ```

   Skip the prompt silently if the tree is already present:
   ```bash
   test -d "${GEANT4_SRC}/source" && echo "[g4c] geant4-src already checked out at ${GEANT4_SRC}"
   ```

   If missing, derive the matching tag from the pinned image and ask the user:
   ```bash
   G4_VERSION=$(sed -n 's/^IMAGE_TAG=.*g4install:\([0-9.]*\)-.*/\1/p' "${CLAUDE_PLUGIN_ROOT}/bin/g4run")
   echo "[g4c] would clone Geant4 v${G4_VERSION} source (~150 MB shallow) into ${GEANT4_SRC}"
   ```

   Then use `AskUserQuestion`:
   - **Question**: `Clone Geant4 v<G4_VERSION> source into the plugin's data dir for offline citation verification?`
   - **Options**:
     1. *Yes, shallow clone* — recommended; ~150 MB; no git history.
     2. *Skip for now* — wiki synthesis pages still readable, but `.cc:line` citations cannot be cross-checked locally.

   On **Yes**, clone the tag matching the container's Geant4 version, then
   create the symlink so wiki references resolve:
   ```bash
   mkdir -p "$(dirname "${GEANT4_SRC}")"
   git clone --depth 1 --branch "v${G4_VERSION}" \
       https://github.com/Geant4/geant4.git \
       "${GEANT4_SRC}"
   mkdir -p "$(dirname "${LEGACY_SRC}")"
   ln -sfn "${GEANT4_SRC}" "${LEGACY_SRC}"
   ```
   On **Skip**, continue. The user can re-trigger this step later by running
   `/geant4-init` again from any workspace (or `--force`); the check is
   idempotent.

6. **Report status:**
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/bin/g4run" info
   ```
   Then summarize for the user, in this order:
   - workspace files written,
   - image cached at,
   - what to do next: either drop in your own `src/main.cc` +
     `src/CMakeLists.txt` and run `/geant4-build`, or run
     `/geant4-example` to populate the workspace with a working sample
     (GDML detector + macro + main + analysis script).

## Outputs

- A populated workspace under `cwd`: `CLAUDE.md`, `.gitignore`, `src/`,
  `geometries/`, `macros/`, `runs/`, `analysis/` (all empty except
  `CLAUDE.md` and `.gitignore`).
- A cached `.sif` at `${CLAUDE_PLUGIN_DATA}/cache/sif/g4install_11.4.0-almalinux-9.4.sif`
  (resolved by `bin/g4run`; override with `GEANT4_CLAUDE_CACHE`).
- (Optional, on user consent) Geant4 source tree at
  `${CLAUDE_PLUGIN_DATA}/geant4-src/` matching the container's Geant4
  version, with a symlink at `${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src`
  pointing at it so wiki page references continue to resolve.

## Failure modes

| Symptom | Likely cause | Fix |
|--------|--------------|-----|
| `apptainer: command not found` | Apptainer not installed. | Install apptainer; rerun. |
| `cp: cannot stat '${CLAUDE_PLUGIN_ROOT}/templates/...'` | Plugin not properly installed. | Re-install the `geant4_claude` plugin. |
| `apptainer pull` fails with auth/network error | Offline or registry unreachable. | Retry with network; or set `GEANT4_CLAUDE_CACHE` to a directory that already has the `.sif`. The default cache lives at `${CLAUDE_PLUGIN_DATA}/cache/` (plugin-scoped). |
| Existing files refuse to be touched | Workspace already initialized. | Re-run with `/geant4-init --force` (only after confirming with the user). |
| `git clone` of Geant4 source fails (network, tag missing) | Offline, GitHub unreachable, or the image's Geant4 version is not yet tagged on `Geant4/geant4`. | User can skip; re-run `/geant4-init` later. Manual fallback: `git clone --depth 1 --branch v<G4_VERSION> https://github.com/Geant4/geant4.git ${CLAUDE_PLUGIN_DATA}/geant4-src && ln -sfn ${CLAUDE_PLUGIN_DATA}/geant4-src ${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src`. |
| `wiki/raw/geant4-src` exists as a real directory after a plugin update | Pre-relocation install left a real dir at the legacy path; auto-migration was skipped because the new canonical path was also present. | Inspect both, keep the desired one, remove the other, then re-run `/geant4-init` to recreate the symlink. |

## Notes

- This command is idempotent: running it twice in an empty directory pulls
  once and copies once; running it twice in a populated directory without
  `--force` is a no-op.
- The image tag is pinned in `bin/g4run` and only there. Do not hardcode it
  in any future command.
