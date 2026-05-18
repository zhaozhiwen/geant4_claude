---
description: Translate a natural-language detector spec into a validated GDML file under geometries/.
allowed-tools: Read, Write, Edit, Bash, Glob
---

# /geant4-claude:geant4-detector

## Purpose

Turn a natural-language detector description (e.g. "1×1×10 cm lead block in
a 50 cm air world, sensitive") into a syntactically valid GDML file under
`geometries/`. Validation runs in-container before declaring success.

This command produces a **standalone GDML file**. Any Geant4 application
that calls `G4GDMLParser::Read("geometries/<name>.gdml")` can consume it.
The optional `<auxiliary auxtype="sensitive" auxvalue="true"/>` tag is a
hint — the example main shipped by `/geant4-claude:geant4-example` reads it to
auto-attach a sensitive detector, but the tag is harmless to other
applications that ignore it.

## Inputs

- The user's free-text description as the slash-command argument.
- Optional `--name <slug>` → output file is `geometries/<slug>.gdml`
  (default: `det.gdml`; auto-suffix with `_2`, `_3`, … if the file exists
  and `--force` was not passed).
- Optional `--optical` → force the optical-photon GDML path even if the
  free-text spec doesn't name Cherenkov/scintillation. The path is also
  auto-selected when the spec mentions Cherenkov, scintillation, or
  optical photons.

## Steps

1. **Parse the spec.** Extract:
   - shapes (box, tube/cylinder, sphere, cone),
   - dimensions and units (mm, cm, m — convert to mm in GDML attributes),
   - materials (use NIST names: `G4_Pb`, `G4_AIR`, `G4_WATER`, `G4_Cu`,
     `G4_PLASTIC_SC_VINYLTOLUENE`, `G4_lAr`, etc.),
   - placements (positions, rotations),
   - which volumes are sensitive (default: any non-world volume the user
     names "detector" or describes as a "block of <material>"; ask if
     unclear).

   When in doubt, **ask** the user before generating. Don't guess
   geometry that's load-bearing for physics.

2. **Consult the skill** `geant4-geometry` for GDML syntax (units,
   structure, NIST materials, the optional `<auxiliary auxtype="sensitive"
   auxvalue="true"/>` convention used by the example main). Don't
   reinvent the schema.

3. **Write the GDML** to `geometries/<name>.gdml`. Required structure:

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <gdml xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="http://service-spi.web.cern.ch/service-spi/app/releases/GDML/schema/gdml.xsd">
     <solids> … </solids>
     <structure>
       <volume name="..._lv">
         <materialref ref="G4_..."/>
         <solidref ref="..._solid"/>
         <auxiliary auxtype="sensitive" auxvalue="true"/>   <!-- only on sensitive volumes -->
       </volume>
       <volume name="world_lv">
         <materialref ref="G4_AIR"/>
         <solidref ref="world_solid"/>
         <physvol> <volumeref ref="..._lv"/> <position .../> </physvol>
       </volume>
     </structure>
     <setup name="Default" version="1.0">
       <world ref="world_lv"/>
     </setup>
   </gdml>
   ```

   Conventions:
   - Solid names end in `_solid`, logical-volume names end in `_lv`.
   - Always declare a world volume (typically `G4_AIR`, large enough to
     enclose all daughter volumes with a margin).
   - All `<box>`, `<tubs>`, etc. carry `lunit="mm"`.
   - Mark every volume the user wants scored with the `auxiliary` tag.

   **Optical path (Cherenkov / scintillation / `--optical`).** When the
   spec involves optical photons, the radiator material needs a `RINDEX`
   optical property or `G4OpticalPhysics` produces zero photons. For an
   optical spec:

   1. Define the radiator as an explicit `<material>` in a `<materials>`
      block (NIST materials carry no optical properties), with a
      `RINDEX` matrix in `<define>` and a `<property>` linking it.
      Energies use the explicit `*eV` form:

      ```xml
      <define>
        <matrix name="RAD_RINDEX" coldim="2"
                values="1.5*eV <n_lo> 6.2*eV <n_hi>"/>
      </define>
      <materials>
        <material name="<radmat>" formula="...">
          <D value="<density>" unit="g/cm3"/>
          <composite n="..." ref="..."/>
          <property name="RINDEX" ref="RAD_RINDEX"/>
        </material>
      </materials>
      ```
      Use the user-specified refractive index; for a non-dispersive
      radiator repeat the same `n` at both energies.

   2. Add a downstream sensitive backplate placed *after* the radiator
      along the beam axis (positive `z`), with a small gap — never
      inside or face-overlapping the radiator (geometry-sanity check 1
      and 2). Tag the backplate, not the radiator, with the
      `<auxiliary auxtype="sensitive" auxvalue="true"/>`.

   3. **RINDEX gate (mandatory).** Before declaring success, confirm the
      radiator material has both a `<matrix>` and a
      `<property name="RINDEX" .../>`. If it does not, **stop** — do not
      report success. Tell the user the exact material name that is
      missing RINDEX and that an optical run with it would silently
      produce zero photons. This gate is the plugin's primary protection
      against the zero-photon trap.

   The optical run also needs a main with `G4OpticalPhysics` + a
   photon-aware SD — that is `src/main.cc` regenerated from the recipe
   in `skills/geant4-physics-list/SKILL.md`, not the canned
   `geant4-example` main. Surface that in the next-step suggestion.

4. **Validate.**
   ```bash
   GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache" \
     "${CLAUDE_PLUGIN_ROOT}/bin/g4run" validate-gdml geometries/<name>.gdml
   ```
   If `xmllint` reports an error, fix the file and re-run validation. Do
   not declare success until validation passes.

5. **Show the user** the path to the GDML and a one-line summary of what
   was written (shapes, materials, sensitive volumes). Suggest the next
   step, depending on how their `main.cc` consumes geometry:
   - example main: rebuild if needed, then run with the GDML as the
     first positional arg —
     `/geant4-claude:geant4-run --exe build/geant4_claude_main -- geometries/<name>.gdml macros/<name>.mac {run_dir}/hits.root`;
   - their own main: load it via `G4GDMLParser::Read("geometries/<name>.gdml")`.
   - optical spec: regenerate `src/main.cc` from the optical recipe in
     `skills/geant4-physics-list/SKILL.md` (the canned `geant4-example`
     main has no `G4OpticalPhysics` and its SD discards photons), build,
     run, then `/geant4-claude:geant4-validate cherenkov runs/<id>
     --rindex-from-gdml geometries/<name>.gdml --rindex-material
     <radmat> --radiator-length <L>`.

## Outputs

- `geometries/<name>.gdml` — well-formed GDML. NIST material refs,
  `lunit`-tagged dimensions, optional `<auxiliary auxtype="sensitive"
  auxvalue="true"/>` on volumes meant to be scored.

## Failure modes

| Symptom | Likely cause | Fix |
|--------|--------------|-----|
| `xmllint: parser error` | Hand-written GDML is malformed. | Re-read the error; fix; re-validate. |
| `G4GDML: WARNING: material '...' not found` (only seen at run time) | A non-NIST material name was used. | Switch to a NIST name (`G4_<symbol>`) or add a `<materials>` block defining the custom material. |
| Volume not scored at run time | Missing `<auxiliary auxtype="sensitive" auxvalue="true"/>`. | Add the aux tag inside the `<volume>` element. |
| Optical run produces zero photons | Radiator material has no `RINDEX` property. | The RINDEX gate should have stopped generation; if you hit this at run time the GDML was hand-edited — add a `<matrix>` + `<property name="RINDEX">` to the radiator material. |

## Notes

- This command does not run a simulation. It only writes and validates GDML.
- For complex geometries (assemblies, replicas, parameterized volumes),
  prefer hand-editing or a Python GDML generator over a single
  natural-language prompt — and tell the user that's the case.
