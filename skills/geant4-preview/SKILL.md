---
name: geant4-preview
description: Use when the user wants to visually inspect a GDML geometry before running — render three headless orthographic projection images (XY/YZ/XZ) to catch overlaps, off-axis offsets, missing volumes, or a sensor in the forward-flux path. Requires geant4-init to have run.
---

# geant4-preview — headless GDML projection previews

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
  that. See [docs/DESIGN.md §Hardening backlog](../../docs/DESIGN.md).

## Inputs

| Arg | Required? | Meaning |
|-----|-----------|---------|
| `<file.gdml>`  | yes | Path to the GDML file to preview. |
| `<out_dir>`    | no  | Directory for the images. Default: `<file.gdml>.preview/` next to the GDML (e.g., `geometries/foo.gdml` → `geometries/foo.preview/`). |
| `--backend`    | no  | `sketch` (default) or `raytracer`. |

## Steps

1. **Resolve the engine** (every skill starts with this; written by geant4-init):
   ```bash
   [ -f .g4c/env ] && . .g4c/env; G4RUN="${G4RUN:-$PWD/.g4c/g4run}"
   ```
   If `.g4c/` is missing, stop and tell the user to run the **geant4-init**
   skill first.

2. **Validate first.** A broken GDML can't be previewed.
   ```bash
   "${G4RUN}" validate-gdml <file.gdml>
   ```
   Stop on failure — surface the parser error and ask the user to fix.

3. **Bootstrap the Python venv** (the default sketch backend renders with
   matplotlib; the venv is seeded explicitly here — an idempotent no-op once
   the venv is in sync. There is no SessionStart hook on either CLI):
   ```bash
   . .g4c/env; "${GEANT4_CLAUDE_ROOT}/scripts/ensure_venv.sh"
   ```

4. **Render the previews.** The default `sketch` backend is host-side
   Python — run it with the managed venv's interpreter (where
   `ensure_venv.sh` installed matplotlib + numpy) on the bundled script.
   The script takes the GDML and an explicit output dir (when the user
   omits one, use the default `<file.gdml>.preview/` next to the GDML):
   ```bash
   "${GEANT4_CLAUDE_VENV}/bin/python" \
     "${GEANT4_CLAUDE_ROOT}/scripts/preview_gdml.py" <file.gdml> <out_dir>
   ```
   It reads `<solids>` + `<structure>` with the stdlib XML parser,
   projects each placed physvol onto three planes, and writes PNGs via
   matplotlib.

   To use the RayTracer backend instead, go through the runtime bridge —
   it builds and caches the C++ helper on first use:
   ```bash
   "${G4RUN}" preview <file.gdml> [out_dir] --backend=raytracer
   ```

5. **Show the user** the three image paths with one short sentence each:
   - `preview_xy.png` — end view, camera at +z; see beam-axis projection.
   - `preview_yz.png` — side view, camera at +x; see beam-direction layout.
   - `preview_xz.png` — top view,  camera at +y; catches left-right asymmetries.
   If the geometry is small relative to the world volume, note that
   the world box is suppressed automatically (only daughters draw).

6. **Sanity-check the result.** If the spec involved a sensor in the
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
| `.g4c/` missing | Workspace not initialized. | Run the geant4-init skill first. |
| `validate-gdml` step fails | GDML has a parse error. | Fix the GDML and retry. |
| `missing dep: matplotlib` | Managed venv not yet populated. | Re-run the venv bootstrap: `. .g4c/env; "${GEANT4_CLAUDE_ROOT}/scripts/ensure_venv.sh"`. Do not `pip install --user`. |
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
- The full-flow **geant4** orchestrator skill inserts a preview step
  between the **geant4-detector** and **geant4-build** skills by default.
  Skip it with `--no-preview` if you've already eyeballed the geometry.
