---
description: Render headless preview images of a GDML file via Geant4's RayTracer driver — three views to spot geometry mistakes before running.
allowed-tools: Read, Bash, Glob
---

# /geant4-claude:geant4-preview

## Purpose

Produce three preview images of a GDML geometry **before** running a
simulation, so geometry mistakes (sensor in the forward-flux path,
overlapping placements, off-axis offsets, missing-volume bugs) surface
visually instead of after a 1000-event run.

Rendering uses Geant4's `RayTracer` visualization driver — pure CPU
ray tracing, no OpenGL, X11, or framebuffer needed. Works inside the
pinned container with no extra dependencies.

> **Status: alpha.** The infrastructure (cached helper binary, slash
> command, orchestrator wiring) ships in v0.0.4. In the v11.4
> container, `RayTracer` driven via `ApplyCommand` from C++ prints
> `G4RTMessenger::SetNewValue: No valid current viewer.` and the
> `/vis/rayTracer/trace` step hangs indefinitely — three different
> command sequences reproduced this. Until that's resolved, the
> orchestrator does NOT call preview automatically; you can invoke
> it manually but expect a hang on the first `trace` command. A
> workaround using an interactive `g4run shell` + a vis macro is in
> [docs/DESIGN.md §Hardening backlog](../docs/DESIGN.md).

## Inputs

| Arg | Required? | Meaning |
|-----|-----------|---------|
| `<file.gdml>` | yes | Path to the GDML file to preview. |
| `<out_dir>`   | no  | Directory for the JPEGs. Default: `<file.gdml>.preview/` next to the GDML (e.g., `geometries/foo.gdml` → `geometries/foo.preview/`). |

## Steps

1. **Validate first.** A broken GDML can't be previewed.
   ```bash
   GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache" \
     "${CLAUDE_PLUGIN_ROOT}/bin/g4run" validate-gdml <file.gdml>
   ```
   Stop on failure — surface the parser error and ask the user to fix.

2. **Render the previews.** First call builds and caches a tiny helper
   binary in `${CLAUDE_PLUGIN_DATA}/cache/bin/preview_gdml`
   (~30 s); subsequent calls reuse it.
   ```bash
   GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache" \
     "${CLAUDE_PLUGIN_ROOT}/bin/g4run" preview <file.gdml> [out_dir]
   ```

3. **Show the user** the three image paths and one short sentence
   describing what each view shows (iso = perspective, xy = top-down,
   yz = side). If the geometry is small relative to the world volume,
   warn that the world box will dominate the frame and suggest opening
   the iso view first.

4. **Sanity-check the result.** Look at the iso view if you can. If
   the spec involved a sensor in the forward direction of a beam, this
   is your last chance to catch a forward-flux trap before running.

## Outputs

```
<out_dir>/
├── preview_iso.jpg   # 30°/60° isometric (perspective)
├── preview_xy.jpg    # top-down (camera on +z, looking at origin)
└── preview_yz.jpg    # side (camera on +x, looking at origin)
```

All three are 800×600, white background, surface-style. A small set of
coordinate axes (10 cm) is drawn at the origin so the user can read
orientation.

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `validate-gdml` step fails | GDML has a parse error. | Fix the GDML and retry. |
| `preview_gdml` build fails | Container image lacks `vis_all` Geant4 component, or CMake/Geant4 install is broken. | Run `g4run info`; if the image looks fine, run `g4run shell` and try a manual CMake build under `${CLAUDE_PLUGIN_ROOT}/templates/preview` to see the actual error. |
| Output JPEGs are mostly black | View centred outside the geometry, or the geometry is much smaller than the world. | Crop or open the iso view; consider drawing only daughter volumes. |
| All three views look identical | The geometry is a single sphere or the camera was outside the world. | Confirm the world volume isn't dwarfing the active volume. |

## Notes

- Preview is **stateless** — it does not modify `runs/`, `log.md`, or
  anything else. Re-run as often as needed while iterating on geometry.
- For complex geometries, RayTracer can take 10–60 s per view. That's
  the cost of CPU ray tracing; the trade-off is the renderer works in
  any container with no GL/X infrastructure.
- The orchestrator skill (`skills/geant4`) inserts a preview step
  between `/geant4-claude:geant4-detector` and `/geant4-claude:geant4-build`
  by default. Skip it with `--no-preview` if you've already eyeballed
  the geometry.
