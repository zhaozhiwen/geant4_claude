# CLAUDE.md — Geant4 workspace

Rules for Claude when working in this Geant4 simulation workspace. The
`geant4_claude` plugin scaffolded these directories. The plugin's slash
commands (`/geant4-claude:geant4-build`, `/geant4-claude:geant4-run`, `/geant4-claude:geant4-analyze`,
`/geant4-claude:geant4-detector`) operate on the layout below.

The default flow uses `/geant4-claude:geant4-detector` to turn a
natural-language detector description into standalone GDML, paired with
the GDML-loading `main.cc` from `/geant4-claude:geant4-example`. No C++
edits required to change the geometry — describe a new detector, run
again. The alternative is to bring your own `src/main.cc` (with
hard-coded geometry, custom physics, or a non-`Hits` output schema);
the four runtime commands work the same in both cases.

## Layout

| Directory | Role |
|-----------|------|
| `src/`        | C++ source for your Geant4 application. Plus `CMakeLists.txt`. |
| `build/`      | CMake build output. **Gitignored.** Re-create with `/geant4-claude:geant4-build`. |
| `geometries/` | GDML files (if you use GDML). Versioned. Optional. |
| `macros/`     | Geant4 macro files (`*.mac`). Versioned. |
| `runs/`       | One sub-directory per `/geant4-claude:geant4-run`. **Gitignored** (only the placeholder is kept). |
| `analysis/`   | Python scripts that read `runs/<id>/*.root`. |
| `log.md`      | Chronological work log — append at the top after each session. |
| `result.md`   | Per-run findings, with paths to `runs/<id>/` and `analysis/`. |

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
6. **Maintain `log.md` and `result.md`.** After every successful
   `/geant4-claude:geant4-run`, append a one-line entry to the top of
   `log.md` (run id + one-line description). After a `/geant4-claude:geant4-analyze`
   that produced a noteworthy result, add or update a section in
   `result.md` with key numbers + plot paths. The user reads these to
   pick up where they left off; treat them as load-bearing, not
   decorative.

## Typical loop (default — NL detector + example main)

1. `/geant4-claude:geant4-detector` — describe the detector; writes
   `geometries/<name>.gdml` (validated).
2. `/geant4-claude:geant4-example` (once per workspace) — drops in the
   GDML-loading `src/geant4_claude_main.cc` + `CMakeLists.txt` + a
   sample `macros/run.mac` you can edit.
3. `/geant4-claude:geant4-build` — compiles `src/` into `./build/geant4_claude_main`.
4. Edit `macros/<name>.mac` for primary particle, energy, event count.
5. `/geant4-claude:geant4-run --exe build/geant4_claude_main -- geometries/<name>.gdml macros/<name>.mac {run_dir}/hits.root`.
6. `/geant4-claude:geant4-analyze runs/<id>` — auto-detects the output schema and
   plots; or write your own script in `analysis/`.

To iterate on geometry, repeat step 1 — no rebuild needed because the
example main loads GDML at runtime.

## Alternative loop (bring your own `main.cc`)

1. Edit `src/main.cc` (and `src/CMakeLists.txt`) for whatever physics
   list, geometry strategy, and output schema you want.
2. `/geant4-claude:geant4-build` — compiles `src/` into `./build/<target>`.
3. Edit `macros/<name>.mac`.
4. `/geant4-claude:geant4-run --exe build/<target> -- [your args] {run_dir}/<output>.root`.
5. `/geant4-claude:geant4-analyze runs/<id>`.

## When something fails

- Build error → `g4run shell`, `cd build`, `cmake --build .` manually;
  read the full error.
- GDML parse error → `g4run validate-gdml geometries/<name>.gdml` first.
- Geant4 crash at runtime → look at `runs/<id>/log.txt`; the last 50
  lines almost always point at the failing volume, material, or process.
- Missing `g4run` → the plugin isn't installed or its `bin/` isn't on
  PATH. Re-install or add it.
