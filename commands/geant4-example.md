---
description: Drop a ready-to-build Geant4 example (GDML detector + macro + main + analysis) into the workspace.
allowed-tools: Bash, Read, Write, Glob
---

# /geant4-claude:geant4-example

## Purpose

Populate the workspace with a complete, runnable demo so the user can
exercise the build → run → analyze pipeline before writing any of their
own code. The example uses a generic GDML-driven main
(`geant4_claude_main.cc`) that auto-attaches a sensitive detector to any
volume tagged `<auxiliary auxtype="sensitive" auxvalue="true"/>` and
writes a flat `Hits` TTree.

This command is for **learning** and **smoke-testing**. Once you're
ready to write your own simulation, edit `src/main.cc` (rename if you
like) and rebuild with `/geant4-claude:geant4-build`.

## Inputs

- `--force` (optional) — overwrite existing files under `src/`,
  `geometries/`, `macros/`, `analysis/` if they collide with the example.

## Steps

1. **Refuse to run on an empty workspace.** This command builds on the
   skeleton from `/geant4-claude:geant4-init`:
   ```bash
   for d in src geometries macros analysis runs; do
     test -d "${d}" || { echo "no ${d}/; run /geant4-claude:geant4-init first"; exit 1; }
   done
   ```

2. **Detect collisions.** List files in `templates/example/` that would
   land on top of existing workspace files:
   ```bash
   ( cd "${CLAUDE_PLUGIN_ROOT}/templates/example" \
       && find . -type f -printf '%P\n' ) \
     | while read -r rel; do test -e "./${rel}" && echo "${rel}"; done
   ```
   - If non-empty and `--force` not passed → stop, list the collisions,
     ask the user whether to re-run with `--force`.
   - Otherwise proceed.

3. **Copy the example.** This drops:
   - `src/geant4_claude_main.cc` and `src/CMakeLists.txt`,
   - `geometries/example.gdml` (1×1×10 cm Pb block in a 50 cm air world,
     sensitive),
   - `macros/run.mac` (1 GeV e- gun, 1000 events),
   - `analysis/example.py` (per-event edep histogram via uproot).
   ```bash
   cp -r "${CLAUDE_PLUGIN_ROOT}/templates/example/." .
   ```
   With `--force`, prefix with `cp -rf` to overwrite.

4. **Validate the GDML** to confirm everything copied cleanly:
   ```bash
   GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache" \
     "${CLAUDE_PLUGIN_ROOT}/bin/g4run" validate-gdml geometries/example.gdml
   ```

5. **Tell the user the next three commands**, in order:
   ```
   ✓ example dropped into ./{src,geometries,macros,analysis}/

   Next:
     /geant4-claude:geant4-build
     /geant4-claude:geant4-run --exe build/geant4_claude_main -- geometries/example.gdml macros/run.mac {run_dir}/hits.root
     /geant4-claude:geant4-analyze runs/<the-id-from-/geant4-claude:geant4-run>
   ```

## Outputs

A workspace populated with the example's source, geometry, macro, and
analysis. Nothing else changes — `CLAUDE.md`, `.gitignore`, `runs/` are
untouched.

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `no src/; run /geant4-claude:geant4-init first` | The workspace skeleton isn't there. | `/geant4-claude:geant4-init`. |
| Collision: `src/main.cc` already exists | The workspace already has user code. | Pass `--force` only after confirming with the user that the file is safe to overwrite — most likely they want to keep their own. |
| `validate-gdml` fails | The example template is corrupted. | Re-install the plugin. |

## Notes

- The example is a **starting point**, not a contract. Once the smoke
  test passes, treat the copied files as your own — rename, edit, delete
  as needed.
- The `geant4_claude_main.cc` in this template is intentionally
  minimal: GDML loader, FTFP_BERT physics list, generic SD,
  `Hits` TTree. For non-standard physics (HP neutrons, optical photons,
  radioactive decay, etc.) edit it and rebuild.
