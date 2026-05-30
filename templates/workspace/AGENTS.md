# AGENTS.md — Geant4 workspace

Rules for the AI assistant when working in this Geant4 simulation
workspace (works on both Claude Code and OpenAI Codex). The
`geant4_claude` plugin scaffolded these directories. The plugin's
skills (**geant4-build**, **geant4-run**, **geant4-analyze**,
**geant4-detector**) operate on the layout below. There are no slash
commands — describe what you want in natural language and the matching
skill runs.

The default flow uses the **geant4-detector** skill to turn a
natural-language detector description into standalone GDML, paired with
the GDML-loading `main.cc` from the **geant4-example** skill. No C++
edits required to change the geometry — describe a new detector, run
again. The alternative is to bring your own `src/main.cc` (with
hard-coded geometry, custom physics, or a non-`Hits` output schema);
the four runtime skills work the same in both cases.

## Layout

| Directory | Role |
|-----------|------|
| `src/`        | C++ source for your Geant4 application. Plus `CMakeLists.txt`. |
| `build/`      | CMake build output. **Gitignored.** Re-create by running the **geant4-build** skill (e.g. ask to build). |
| `geometries/` | GDML files (if you use GDML). Versioned. Optional. |
| `macros/`     | Geant4 macro files (`*.mac`). Versioned. |
| `runs/`       | One sub-directory per **geant4-run** invocation. **Gitignored** (only the placeholder is kept). |
| `analysis/`   | Python scripts that read `runs/<id>/*.root`. |
| `log.md`      | Chronological work log — append at the top after each session. |
| `result.md`   | Per-run findings, with paths to `runs/<id>/` and `analysis/`. |
| `report.html` | Single-page browser-friendly summary of the study (overview, runs table, key numbers, plots, interpretation). Self-contained — open in any browser via `file://`. Derived from `log.md` + `result.md` + `runs/`; markdown is authoritative if they disagree. |
| `embed_html.py` | Stdlib-only helper that takes `report.html` (with relative `<img src="runs/...">` paths) and writes `report_portable.html` with each image base64-embedded inline. Run when you want to email or upload the report as a single self-contained file. Idempotent and traceable (preserves original paths in `data-source` attributes). Output is gitignored (`*_portable.html`). |

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
   hard-code geometry in C++, every change needs a rebuild via the
   **geant4-build** skill.
6. **Maintain `log.md`, `result.md`, and `report.html`.** Every
   simulation effort — orchestrator-driven *or* a single skill
   invocation — leaves a record. Prepend a new dated section to
   `log.md` capturing four things: the user's **original request**
   (verbatim, in their own words), the **plan** the assistant drew up (spec
   + step list), the user's **decision** (approved, edited the spec,
   or stop-and-just-write-the-plan), and the **outcome** (run id,
   exit status, one-line summary of what happened). After every
   **geant4-run**, refresh `report.html`'s Runs table,
   Beam &amp; physics, and header date so the browser report reflects
   the run even before it's analyzed. After a **geant4-analyze**
   that produced a noteworthy
   result, add or update a section in `result.md` with key numbers
   + plot paths, and update `report.html` to match (replace the
   placeholders in Summary / Setup / Runs table / Key numbers /
   Plots / Notes; preserve the section structure). The markdown
   files are authoritative — `report.html` is a presentation layer
   derived from them, so if they disagree the markdown wins. All
   three are load-bearing handoff documents — the user reads them
   to pick up where they left off, future assistant sessions read them
   to understand context, and `report.html` is what a collaborator
   or reviewer opens in a browser. Treat them as part of the
   deliverable, not as decoration.

## Typical loop (default — NL detector + example main)

1. Describe the detector (the **geant4-detector** skill runs); writes
   `geometries/<name>.gdml` (validated).
2. Ask for the example (the **geant4-example** skill, once per
   workspace) — drops in the GDML-loading `src/geant4_claude_main.cc`
   + `CMakeLists.txt` + a sample `macros/run.mac` you can edit.
3. Ask to build (the **geant4-build** skill) — compiles `src/` into
   `./build/geant4_claude_main`.
4. Edit `macros/<name>.mac` for primary particle, energy, event count.
5. Ask to run (the **geant4-run** skill) the executable
   `build/geant4_claude_main` with `geometries/<name>.gdml`,
   `macros/<name>.mac`, and a `hits.root` output.
6. Ask to analyze the run (the **geant4-analyze** skill) — auto-detects
   the output schema and plots; or write your own script in `analysis/`.

Optional: between steps 1 and 2 you can ask to preview the geometry
(the **geant4-preview** skill on `geometries/<name>.gdml`) to eyeball
it. The skill is currently alpha (rendering hangs in the v11.4
container — see its skill doc); when it does render, it
produces three JPEG views useful for catching forward-flux sensor
traps and other geometry mistakes before the simulation runs.

To iterate on geometry, repeat step 1 — no rebuild needed because the
example main loads GDML at runtime.

## Alternative loop (bring your own `main.cc`)

1. Edit `src/main.cc` (and `src/CMakeLists.txt`) for whatever physics
   list, geometry strategy, and output schema you want.
2. Ask to build (the **geant4-build** skill) — compiles `src/` into
   `./build/<target>`.
3. Edit `macros/<name>.mac`.
4. Ask to run (the **geant4-run** skill) `build/<target>` with your
   args and a `<output>.root` output.
5. Ask to analyze the run (the **geant4-analyze** skill).

## When something fails

- Build error → `g4run shell`, `cd build`, `cmake --build .` manually;
  read the full error.
- GDML parse error → `g4run validate-gdml geometries/<name>.gdml` first.
- Geant4 crash at runtime → look at `runs/<id>/log.txt`; the last 50
  lines almost always point at the failing volume, material, or process.
- Missing `g4run` → the plugin isn't installed or its `bin/` isn't on
  PATH. Re-install or add it.
