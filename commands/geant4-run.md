---
description: Run a Geant4 simulation; produce runs/<id>/{hits.root, log.txt, config.json}.
allowed-tools: Bash, Read, Write, Glob
---

# /geant4-run

## Purpose

Execute one Geant4 simulation against a GDML geometry and a Geant4 macro,
storing the output and full provenance in a fresh `runs/<id>/` directory.

## Inputs (flags, all optional; sensible defaults)

| Flag          | Default                       | Meaning |
|---------------|-------------------------------|---------|
| `--geometry`  | `geometries/example.gdml`     | GDML file. |
| `--macro`     | `macros/run.mac`              | Pre-written Geant4 macro. Used as-is unless any of `--particle/--energy/--events` is also passed. |
| `--particle`  | (use macro)                   | e.g. `e-`, `gamma`, `mu-`, `pi+`. |
| `--energy`    | (use macro)                   | Numeric + unit, e.g. `1 GeV`, `500 MeV`. |
| `--events`    | (use macro)                   | Integer event count. |
| `--name`      | auto                          | Optional human-readable suffix appended to `run_id`. |

If any of `--particle / --energy / --events` is passed, a fresh macro is
synthesized at `runs/<id>/run.mac` (see step 3) and used in place of `--macro`.
Mixing partial overrides is allowed; missing fields are pulled from the
provided `--macro` defaults.

## Steps

1. **Sanity checks.**
   ```bash
   test -f "${GEOMETRY:-geometries/example.gdml}" || { echo "geometry not found"; exit 1; }
   "${CLAUDE_PLUGIN_ROOT}/bin/g4run" info | grep -q '\[built\]' \
     || "${CLAUDE_PLUGIN_ROOT}/bin/g4run" build
   "${CLAUDE_PLUGIN_ROOT}/bin/g4run" validate-gdml "${GEOMETRY:-geometries/example.gdml}"
   ```
   Build is idempotent — does nothing if `geant4_claude_main` is already
   present. Validation catches malformed GDML before the run starts.

2. **Allocate a run id.**
   ```bash
   RUN_ID="$(date -u +%Y%m%d-%H%M%S)-$(head -c3 /dev/urandom | xxd -p)"
   [[ -n "${NAME}" ]] && RUN_ID="${RUN_ID}-${NAME}"
   RUN_DIR="runs/${RUN_ID}"
   mkdir -p "${RUN_DIR}"
   ```

3. **Resolve the macro.** If any override is set, write
   `${RUN_DIR}/run.mac` from scratch:
   ```text
   /run/initialize
   /gun/particle <PARTICLE>
   /gun/energy <ENERGY>
   /gun/position 0 0 -200 mm
   /gun/direction 0 0 1
   /run/beamOn <EVENTS>
   ```
   For unspecified knobs, copy the corresponding line from the user's
   `--macro` (default `macros/run.mac`). Set `MACRO="${RUN_DIR}/run.mac"`.
   Otherwise `MACRO="${MACRO_FLAG:-macros/run.mac}"`.

4. **Write the provenance record** at `${RUN_DIR}/config.json`:
   ```json
   {
     "run_id":      "<RUN_ID>",
     "geometry":    "<GEOMETRY>",
     "macro":       "<MACRO>",
     "particle":    "<from macro or override>",
     "energy_MeV":  <numeric MeV>,
     "n_events":    <int>,
     "image":       "<IMAGE_TAG from g4run info>",
     "image_digest": "<sha256 from apptainer inspect, optional>",
     "git_sha":     "<git rev-parse HEAD, or null if not a repo>",
     "started_utc": "<ISO-8601>",
     "duration_s":  null
   }
   ```
   Parse `<energy_MeV>` and `<n_events>` from the resolved macro by
   grepping `/gun/energy` and `/run/beamOn`. Convert the energy to MeV
   (e.g. `1 GeV` → `1000`).

5. **Run the simulation.** Stream stdout+stderr to `log.txt`:
   ```bash
   START=$(date +%s)
   "${CLAUDE_PLUGIN_ROOT}/bin/g4run" sim \
     "${GEOMETRY}" "${MACRO}" "${RUN_DIR}/hits.root" \
     2>&1 | tee "${RUN_DIR}/log.txt"
   STATUS=${PIPESTATUS[0]}
   END=$(date +%s)
   ```

6. **Patch `config.json`** with `duration_s = $((END-START))`.

7. **Verify output and report.**
   - `[[ -s "${RUN_DIR}/hits.root" ]]` — file exists and is non-empty.
   - `grep -q "run ended" "${RUN_DIR}/log.txt"` — Geant4 wrote the
     end-of-run banner.
   - On failure (`STATUS != 0` or hits.root missing): show the user the
     last 30 lines of `log.txt` and stop. Do not delete the run directory
     — its `config.json` and `log.txt` are useful for debugging.
   - On success, summarize:
     ```
     ✓ run <RUN_ID> finished in <duration>s
       → runs/<RUN_ID>/hits.root, log.txt, config.json
     Next: /geant4-analyze runs/<RUN_ID>
     ```

## Outputs

```
runs/<run_id>/
├── hits.root      # TTree "Hits" with branches event/volume/edep/x/y/z/t/pdg
├── log.txt        # full Geant4 stdout+stderr
├── config.json    # provenance (the file analysis tools must read)
└── run.mac        # only present when overrides were used
```

## Failure modes

| Symptom | Likely cause | Fix |
|--------|--------------|-----|
| `geant4_claude_main: command not found` (after `g4run build`) | Container or src/ missing. | `g4run info`; check `src/CMakeLists.txt` is in the plugin root. |
| `G4GDML: ERROR: ...` | Geometry file invalid or material reference wrong. | Run `g4run validate-gdml <file>`; consult the `geant4-geometry` skill. |
| Empty `hits.root` (no entries) | No volume tagged sensitive, or no energy deposit. | Confirm the GDML has `<auxiliary auxtype="sensitive" auxvalue="true"/>` on at least one volume; check the gun energy is non-zero. |
| Run hangs | Macro never reaches `/run/beamOn`, or beam count is huge. | Inspect `log.txt`; reduce `--events`. |

## Notes

- Run directories are immutable by convention. To rerun with different
  parameters, invoke `/geant4-run` again — it allocates a new id.
- `config.json` is the canonical provenance record. Analysis scripts read
  `n_events`, `particle`, `energy_MeV` from there; do not hand-edit it.
