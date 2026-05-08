# CLAUDE.md — Geant4 workspace

Rules for Claude when working in this Geant4 simulation workspace. The
`geant4_claude` plugin scaffolded these directories; commands and skills
assume the layout below.

## Layout

| Directory | Role |
|-----------|------|
| `geometries/` | GDML files. One per detector design. Versioned. |
| `macros/`     | Geant4 macro files (`*.mac`). Versioned. |
| `runs/`       | One sub-directory per `/geant4-run`. **Gitignored.** |
| `analysis/`   | Python scripts that read `runs/<id>/hits.root`. |

## Non-negotiables

1. **All Geant4 / ROOT calls go through `g4run`** (provided by the plugin).
   Never invoke `apptainer`, `geant4`, or `root` directly.
2. **Geometry edits never require a rebuild.** GDML loads at runtime — change
   it, run again.
3. **Run directories are immutable.** Once a run finishes, treat
   `runs/<id>/` as read-only. New analysis = new script in `analysis/`,
   not edits in the run directory.
4. **`runs/<id>/config.json` is the provenance record.** Read it to know what
   produced the data. Never hand-edit it.
5. **Default analysis stack: `uproot` + `numpy` + `matplotlib`.** Anything
   that needs ROOT runs inside the container via `g4run root <args>`.

## Typical loop

1. Draft or edit `geometries/<name>.gdml` (use `/geant4-detector` to start).
2. Edit `macros/<name>.mac` for primary particle, energy, and number of events.
3. `/geant4-run --geometry geometries/<name>.gdml --macro macros/<name>.mac`.
4. `/geant4-analyze runs/<id>` for a default plot, or write a custom script
   in `analysis/`.

## When something fails

- GDML parse error → run `g4run validate-gdml geometries/<name>.gdml` first.
- Geant4 crash → look at `runs/<id>/log.txt`; the last 50 lines almost always
  point at the failing volume or material.
- Missing `g4run` → the plugin isn't installed or isn't on PATH; the plugin's
  `bin/` directory must be reachable.
