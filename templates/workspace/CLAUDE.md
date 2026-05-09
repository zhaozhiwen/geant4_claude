# CLAUDE.md — Geant4 workspace

Rules for Claude when working in this Geant4 simulation workspace. The
`geant4_claude` plugin scaffolded these directories. The plugin's slash
commands (`/geant4-claude:geant4-build`, `/geant4-claude:geant4-run`, `/geant4-claude:geant4-analyze`,
`/geant4-claude:geant4-detector`) operate on the layout below.

This workspace can hold either:

- **Your own simulation** — your `src/main.cc` (or whatever you name it)
  with whatever physics list, geometry strategy, and output schema you
  choose; or
- **The plugin's example** — drop it in with `/geant4-claude:geant4-example` to get a
  ready-to-build GDML-driven simulation that uses an `Hits` TTree.

The four runtime commands work the same in both cases.

## Layout

| Directory | Role |
|-----------|------|
| `src/`        | C++ source for your Geant4 application. Plus `CMakeLists.txt`. |
| `build/`      | CMake build output. **Gitignored.** Re-create with `/geant4-claude:geant4-build`. |
| `geometries/` | GDML files (if you use GDML). Versioned. Optional. |
| `macros/`     | Geant4 macro files (`*.mac`). Versioned. |
| `runs/`       | One sub-directory per `/geant4-claude:geant4-run`. **Gitignored.** |
| `analysis/`   | Python scripts that read `runs/<id>/*.root`. |

## Non-negotiables

1. **All Geant4 / ROOT calls go through the plugin's `g4run` wrapper.**
   Never invoke `apptainer`, `geant4`, or `root` directly. The wrapper
   pins the container image and the entrypoint.
2. **Run directories are immutable.** Once a run finishes, treat
   `runs/<id>/` as read-only. New analysis = new script in `analysis/`,
   not edits in the run directory.
3. **`runs/<id>/config.json` is the provenance record.** Read it to know
   what produced the data (executable, args, container image, git SHA).
   Never hand-edit it.
4. **Default analysis stack: `uproot` + `numpy` + `matplotlib`.** Anything
   that needs ROOT runs inside the container via `g4run root <args>`.
5. **Geometry vs. rebuild.** If you use GDML loaded at runtime, geometry
   edits don't require a rebuild — change the file, run again. If you
   hard-code geometry in C++, every change needs `/geant4-claude:geant4-build`.

## Typical loop

1. Edit `src/main.cc` (and any helpers) for your simulation logic; or
   `geometries/<name>.gdml` if you load geometry at runtime
   (use `/geant4-claude:geant4-detector` for natural-language → GDML).
2. `/geant4-claude:geant4-build` — compiles `src/` into `./build/<target>`.
3. Edit `macros/<name>.mac` for primary particle, energy, event count.
4. `/geant4-claude:geant4-run --exe build/<target> -- macros/<name>.mac [your args]`.
5. `/geant4-claude:geant4-analyze runs/<id>` — auto-detects the output schema and
   plots; or write your own script in `analysis/`.

## When something fails

- Build error → `g4run shell`, `cd build`, `cmake --build .` manually;
  read the full error.
- GDML parse error → `g4run validate-gdml geometries/<name>.gdml` first.
- Geant4 crash at runtime → look at `runs/<id>/log.txt`; the last 50
  lines almost always point at the failing volume, material, or process.
- Missing `g4run` → the plugin isn't installed or its `bin/` isn't on
  PATH. Re-install or add it.
