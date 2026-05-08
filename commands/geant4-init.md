---
description: Scaffold a Geant4 workspace in the current directory and pull the runtime container.
allowed-tools: Bash, Read, Write, Glob
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

6. **Report status:**
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

## Failure modes

| Symptom | Likely cause | Fix |
|--------|--------------|-----|
| `apptainer: command not found` | Apptainer not installed. | Install apptainer; rerun. |
| `cp: cannot stat '${CLAUDE_PLUGIN_ROOT}/templates/...'` | Plugin not properly installed. | Re-install the `geant4_claude` plugin. |
| `apptainer pull` fails with auth/network error | Offline or registry unreachable. | Retry with network; or set `GEANT4_CLAUDE_CACHE` to a directory that already has the `.sif`. |
| Existing files refuse to be touched | Workspace already initialized. | Re-run with `/geant4-init --force` (only after confirming with the user). |
| `validate-gdml` fails | Container exec broken or template corrupted. | Run `g4run shell`, manually `xmllint` the file; report the error. |

## Notes

- This command is idempotent: running it twice in an empty directory pulls
  once and copies once; running it twice in a populated directory without
  `--force` is a no-op.
- The image tag is pinned in `bin/g4run` and only there. Do not hardcode it
  in any future command.
