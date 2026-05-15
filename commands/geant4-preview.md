---
description: Render headless preview images of a GDML file — three orthographic projections to spot geometry mistakes before running a simulation.
allowed-tools: Read, Bash, Glob
---

# /geant4-claude:geant4-preview

## Purpose

Produce three preview images of a GDML geometry **before** running a
simulation, so geometry mistakes (sensor in the forward-flux path,
overlapping placements, off-axis offsets, missing-volume bugs) surface
visually instead of after a 1000-event run.

Two backends ship; pick with `--backend`:

- **`sketch` (default)** — host-side Python: parses the GDML XML, walks
  `<structure>`, and renders three orthographic projections (XY, YZ,
  XZ) with matplotlib. No container call, ~1 s for a typical geometry.
  Supports `box`, `tube`, `cone`, `polycone`, and full 3D rotations.
  Boolean solids (union/subtraction/intersection) and parameterised
  volumes render as bounding boxes with a "!" badge so you see *that*
  they exist without seeing their exact silhouette.
- **`raytracer` (alpha)** — Geant4 RayTracer via a cached C++ helper.
  Currently hangs in the v11.4 container; opt-in for when we crack
  that. See [docs/DESIGN.md §Hardening backlog](../docs/DESIGN.md).

## Inputs

| Arg | Required? | Meaning |
|-----|-----------|---------|
| `<file.gdml>`  | yes | Path to the GDML file to preview. |
| `<out_dir>`    | no  | Directory for the images. Default: `<file.gdml>.preview/` next to the GDML (e.g., `geometries/foo.gdml` → `geometries/foo.preview/`). |
| `--backend`    | no  | `sketch` (default) or `raytracer`. |

## Steps

1. **Validate first.** A broken GDML can't be previewed.
   ```bash
   GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache" \
     "${CLAUDE_PLUGIN_ROOT}/bin/g4run" validate-gdml <file.gdml>
   ```
   Stop on failure — surface the parser error and ask the user to fix.

2. **Render the previews.**
   ```bash
   GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache" \
     "${CLAUDE_PLUGIN_ROOT}/bin/g4run" preview <file.gdml> [out_dir]
   ```
   The default `sketch` backend reads `<solids>` + `<structure>` with
   the stdlib XML parser, projects each placed physvol onto three
   planes, and writes PNGs via matplotlib. Matplotlib + numpy live in
   the plugin venv (installed by the `SessionStart` hook from
   `requirements.txt`); the wrapper picks them up automatically.

   To use the RayTracer backend instead, add `--backend=raytracer`.

3. **Show the user** the three image paths with one short sentence each:
   - `preview_xy.png` — end view, camera at +z; see beam-axis projection.
   - `preview_yz.png` — side view, camera at +x; see beam-direction layout.
   - `preview_xz.png` — top view,  camera at +y; catches left-right asymmetries.
   If the geometry is small relative to the world volume, note that
   the world box is suppressed automatically (only daughters draw).

4. **Sanity-check the result.** If the spec involved a sensor in the
   forward direction of a beam, this is your last chance to catch a
   forward-flux trap before running. The `yz` view is usually the
   right one for that.

## Outputs

```
<out_dir>/
├── preview_xy.png    # end view  (camera at +z, looking at origin)
├── preview_yz.png    # side view (camera at +x)
└── preview_xz.png    # top view  (camera at +y)
```

All three are 8×6 inches at 120 dpi, white background, colour-coded by
solid type with a legend.

(RayTracer backend writes JPEGs named `preview_iso.jpg / preview_xy.jpg
/ preview_yz.jpg` once it stops hanging.)

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `validate-gdml` step fails | GDML has a parse error. | Fix the GDML and retry. |
| `missing dep: matplotlib` | Plugin venv not yet populated. | Re-launch Claude Code to fire the `SessionStart` hook, or `pip install --user matplotlib numpy` and retry. |
| `unsupported solid drawn as bounding box` notice | Geometry uses booleans, replicas, or solids the sketch backend doesn't know. | Acceptable for layout sanity-check; switch to `--backend=raytracer` (once unhung) for exact silhouettes. |
| Sketch output looks empty | The world volume is gigantic and the daughters are 1000× smaller — the world is suppressed automatically, but if it's the only volume there's nothing left to draw. | Confirm `<structure>` has at least one daughter `physvol`. |
| RayTracer hang on `--backend=raytracer` | Known issue with the v11.4 container; see DESIGN.md. | Use the default sketch backend; track the hardening backlog. |

## Notes

- Preview is **stateless** — it does not modify `runs/`, `log.md`, or
  anything else. Re-run as often as needed while iterating on geometry.
- The sketch backend projects 32-point boundary samples per circular
  cross-section, then draws the 2D convex hull per silhouette. This
  is a layout sanity check, not a CAD viewer — for exact curved
  surfaces, use `--backend=raytracer`.
- The orchestrator skill (`skills/geant4`) inserts a preview step
  between `/geant4-claude:geant4-detector` and
  `/geant4-claude:geant4-build` by default. Skip it with
  `--no-preview` if you've already eyeballed the geometry.
