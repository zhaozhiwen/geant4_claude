---
name: geant4-example
description: Use when the user wants to drop a working end-to-end sample (GDML-loading main + sample geometry/macro/analysis) into the current task — the default binary for the natural-language detector flow. Copies from the plugin's example template and validates the GDML. Run from inside a task dir created by geant4-task (after geant4-init).
---

# geant4-example — drop the GDML-loading main + sample into the workspace

## Purpose

Populate the workspace with the **default binary** for the NL-detector
flow: a generic GDML-driven main (`geant4_claude_main.cc`) that loads
any `.gdml` you point it at, auto-attaches a sensitive detector to
volumes tagged `<auxiliary auxtype="sensitive" auxvalue="true"/>`, and
writes a flat `Hits` TTree. The companion `geometries/example.gdml` /
`macros/run.mac` / `analysis/example.py` give the workspace a working
end-to-end pipeline out of the box, but the main is designed to consume
arbitrary GDML — including whatever the **geant4-detector** skill just
wrote.

Run this once per workspace as part of the default flow. The
**alternative** is to skip this and bring your own `src/main.cc`
+ `src/CMakeLists.txt` — useful when you need hard-coded geometry,
custom physics, or an output schema that isn't `Hits`.

## Inputs

- `--force` (optional) — overwrite existing files under `src/`,
  `geometries/`, `macros/`, `analysis/` if they collide with the example.

## Steps

1. **Resolve the engine** (every skill starts with this; written by geant4-init):
   ```bash
   G4C="$PWD"; while [ "$G4C" != "/" ] && [ ! -d "$G4C/.g4c" ]; do G4C="$(dirname "$G4C")"; done
   [ -f "$G4C/.g4c/env" ] && . "$G4C/.g4c/env"; G4RUN="${G4RUN:-$G4C/.g4c/g4run}"
   ```
   If `.g4c/` is missing, stop and tell the user to run the **geant4-init**
   skill first.

2. **Refuse to run outside a task dir.** This builds on the task skeleton
   created by the **geant4-task** skill (run from *inside* a task subdir, not
   the project root):
   ```bash
   for d in src geometries macros analysis runs; do
     test -d "${d}" || { echo "no ${d}/; run the geant4-task skill first (from inside the task dir)"; exit 1; }
   done
   ```

3. **Detect collisions.** List files in `templates/example/` that would
   land on top of existing workspace files:
   ```bash
   ( cd "${GEANT4_CLAUDE_ROOT}/templates/example" \
       && find . -type f -printf '%P\n' ) \
     | while read -r rel; do test -e "./${rel}" && echo "${rel}"; done
   ```
   - If non-empty and `--force` not passed → stop, list the collisions,
     ask the user whether to re-run with `--force`.
   - Otherwise proceed.

4. **Copy the example.** This drops:
   - `src/geant4_claude_main.cc` and `src/CMakeLists.txt`,
   - `geometries/example.gdml` (1×1×10 cm Pb block in a 50 cm air world,
     sensitive),
   - `macros/run.mac` (1 GeV e- gun, 1000 events),
   - `analysis/example.py` (per-event edep histogram via uproot).
   ```bash
   cp -r "${GEANT4_CLAUDE_ROOT}/templates/example/." .
   ```
   With `--force`, prefix with `cp -rf` to overwrite.

5. **Validate the GDML** to confirm everything copied cleanly:
   ```bash
   "${G4RUN}" validate-gdml geometries/example.gdml
   ```

6. **Tell the user the next three steps**, in order:
   ```
   ✓ example dropped into ./{src,geometries,macros,analysis}/

   Next:
     the geant4-build skill
     the geant4-run skill: --exe build/geant4_claude_main -- geometries/example.gdml macros/run.mac {run_dir}/hits.root
     the geant4-analyze skill: runs/<the-id-from-the-geant4-run-skill>
   ```

## Outputs

A workspace populated with the example's source, geometry, macro, and
analysis. Nothing else changes — `CLAUDE.md`, `.gitignore`, `runs/` are
untouched.

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `.g4c/` missing | Workspace not initialized. | Run the geant4-init skill first. |
| `no src/; run the geant4-task skill first` | Not inside a task dir (the task skeleton isn't here). | Run the **geant4-task** skill (after **geant4-init**), then run this from inside the task dir. |
| Collision: `src/main.cc` already exists | The workspace already has user code. | Pass `--force` only after confirming with the user that the file is safe to overwrite — most likely they want to keep their own. |
| `validate-gdml` fails | The example template is corrupted. | Re-install the plugin. |

## Notes

- The example main is the default binary for the NL-detector flow; in
  most cases you don't need to edit it — point it at any GDML
  (yours or the **geant4-detector** skill's output). Treat the
  copied files as your own to rename, edit, or delete when you outgrow
  them.
- The `geant4_claude_main.cc` in this template is intentionally
  minimal: GDML loader, FTFP_BERT physics list, generic SD,
  `Hits` TTree. For non-standard physics (HP neutrons, optical photons,
  radioactive decay, etc.) edit it and rebuild.
