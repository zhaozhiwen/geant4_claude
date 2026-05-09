---
description: Drop the GDML-loading main + sample geometry/macro/analysis into the workspace (default consumer for /geant4-claude:geant4-detector output).
allowed-tools: Bash, Read, Write, Glob
---

# /geant4-claude:geant4-example

## Purpose

Populate the workspace with the **default binary** for the NL-detector
flow: a generic GDML-driven main (`geant4_claude_main.cc`) that loads
any `.gdml` you point it at, auto-attaches a sensitive detector to
volumes tagged `<auxiliary auxtype="sensitive" auxvalue="true"/>`, and
writes a flat `Hits` TTree. The companion `geometries/example.gdml` /
`macros/run.mac` / `analysis/example.py` give the workspace a working
end-to-end pipeline out of the box, but the main is designed to consume
arbitrary GDML — including whatever `/geant4-claude:geant4-detector`
just wrote.

Run this once per workspace as part of the default flow. The
**alternative** is to skip this command and bring your own `src/main.cc`
+ `src/CMakeLists.txt` — useful when you need hard-coded geometry,
custom physics, or an output schema that isn't `Hits`.

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

- The example main is the default binary for the NL-detector flow; in
  most cases you don't need to edit it — point it at any GDML
  (yours or `/geant4-claude:geant4-detector`'s output). Treat the
  copied files as your own to rename, edit, or delete when you outgrow
  them.
- The `geant4_claude_main.cc` in this template is intentionally
  minimal: GDML loader, FTFP_BERT physics list, generic SD,
  `Hits` TTree. For non-standard physics (HP neutrons, optical photons,
  radioactive decay, etc.) edit it and rebuild.
