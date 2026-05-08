---
description: Scaffold a Geant4 workspace in the current directory and pull the runtime container.
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# /geant4-init

## Purpose

Set up a fresh Geant4 simulation workspace in the user's current working
directory, and pre-pull the pinned apptainer image so later commands run
without surprise downloads.

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
   ls -A 2>/dev/null | grep -E '^(CLAUDE\.md|\.gitignore|geometries|macros|runs|analysis)$' || true
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
   - `geometries/example.gdml` — 1×1×10 cm Pb block in air.
   - `macros/run.mac` — 1 GeV e- gun, 1000 events.
   - `runs/.gitkeep`
   - `analysis/example.py` — uproot read + edep histogram.

4. **Pull the runtime image** through the wrapper. This is the *only* sanctioned
   way to invoke the Geant4 runtime; all later commands also go through it:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/bin/g4run" pull
   ```
   First-run downloads ~1–2 GB into `~/.geant4_claude/sif/`. Reruns no-op.

5. **Validate the example geometry** to confirm the container works:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/bin/g4run" validate-gdml geometries/example.gdml
   ```

6. **Offer the Geant4 source checkout (one-time, plugin-wide).** The wiki's
   `sources/geant4-code/synthesis/` pages cite specific `.cc:line` ranges. Those
   citations are only verifiable if the Geant4 source tree is present at
   `${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src/`. The tree is gitignored (large,
   regenerable) so a fresh-clone install does not ship it.

   Skip this step silently if the tree is already present:
   ```bash
   test -d "${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src/source" && echo "[g4c] geant4-src already checked out"
   ```

   If missing, derive the matching tag from the pinned image and ask the user:
   ```bash
   G4_VERSION=$(sed -n 's/^IMAGE_TAG=.*g4install:\([0-9.]*\)-.*/\1/p' "${CLAUDE_PLUGIN_ROOT}/bin/g4run")
   echo "[g4c] would clone Geant4 v${G4_VERSION} source (~150 MB shallow) into ${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src/"
   ```

   Then use `AskUserQuestion`:
   - **Question**: `Clone Geant4 v<G4_VERSION> source into the plugin's wiki/raw/ for offline citation verification?`
   - **Options**:
     1. *Yes, shallow clone* — recommended; ~150 MB; no git history.
     2. *Skip for now* — wiki synthesis pages still readable, but `.cc:line` citations cannot be cross-checked locally.

   On **Yes**, clone the tag matching the container's Geant4 version:
   ```bash
   git clone --depth 1 --branch "v${G4_VERSION}" \
       https://github.com/Geant4/geant4.git \
       "${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src"
   ```
   On **Skip**, continue. The user can re-trigger this step later by running
   `/geant4-init` again from any workspace (or `--force`); the check is
   idempotent.

7. **Report status:**
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/bin/g4run" info
   ```
   Then summarize for the user, in this order:
   - workspace files written,
   - image cached at,
   - what to do next (`/geant4-detector` or edit `geometries/example.gdml`,
     then `/geant4-run`).

## Outputs

- A populated workspace under `cwd`: `CLAUDE.md`, `.gitignore`, `geometries/`,
  `macros/`, `runs/`, `analysis/`.
- A cached `.sif` at `~/.geant4_claude/sif/g4install_11.4.0-almalinux-9.4.sif`.
- (Optional, on user consent) Geant4 source tree at
  `${CLAUDE_PLUGIN_ROOT}/wiki/raw/geant4-src/` matching the container's
  Geant4 version.

## Failure modes

| Symptom | Likely cause | Fix |
|--------|--------------|-----|
| `apptainer: command not found` | Apptainer not installed. | Install apptainer; rerun. |
| `cp: cannot stat '${CLAUDE_PLUGIN_ROOT}/templates/...'` | Plugin not properly installed. | Re-install the `geant4_claude` plugin. |
| `apptainer pull` fails with auth/network error | Offline or registry unreachable. | Retry with network; or set `GEANT4_CLAUDE_CACHE` to a directory that already has the `.sif`. |
| Existing files refuse to be touched | Workspace already initialized. | Re-run with `/geant4-init --force` (only after confirming with the user). |
| `validate-gdml` fails | Container exec broken or template corrupted. | Run `g4run shell`, manually `xmllint` the file; report the error. |
| `git clone` of Geant4 source fails (network, tag missing) | Offline, GitHub unreachable, or the image's Geant4 version is not yet tagged on `Geant4/geant4`. | User can skip; re-run `/geant4-init` later. Manual fallback: `git clone --depth 1 --branch v<G4_VERSION> https://github.com/Geant4/geant4.git <plugin>/wiki/raw/geant4-src`. |

## Notes

- This command is idempotent: running it twice in an empty directory pulls
  once and copies once; running it twice in a populated directory without
  `--force` is a no-op.
- The image tag is pinned in `bin/g4run` and only there. Do not hardcode it
  in any future command.
