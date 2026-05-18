---
description: Run a physics closure test against a finished run — compares simulated output to a known analytic prediction and emits PASS/FAIL.
allowed-tools: Bash, Read, Glob
---

# /geant4-claude:geant4-validate

## Purpose

Run a **physics closure test** against a `runs/<id>/` directory. Compares
the simulated output against a known analytic prediction (e.g.
Frank-Tamm for Cherenkov yield) and emits a PASS/FAIL with the numbers
and tolerance written to `runs/<id>/validate_<topic>.json`.

The point is to confirm a simulation is *physically sane* before
drawing scientific conclusions from it. A simulation can run without
crashing while quietly producing wrong physics (wrong physics list,
broken material properties, sensor in the forward-flux path); a closure
test catches that.

## Inputs

| Arg | Required? | Meaning |
|-----|-----------|---------|
| `<topic>` | yes | Which validator to run. v1 ships: `cherenkov`. |
| `<run_dir>` | yes | Path to `runs/<id>/`. |
| `--<topic-specific>` | varies | Topic-specific parameters (see below). |

### `cherenkov`

Compares simulated optical-photon counts to the Frank-Tamm prediction
for a constant-`n` radiator.

| Flag | Required? | Default | Meaning |
|------|-----------|---------|---------|
| `--radiator-length`  | yes | — | Track length through the radiator, e.g. `1m`, `50cm`. |
| `--wavelength-min`   | no  | `200nm` | Lower wavelength bound of the photon count. |
| `--wavelength-max`   | no  | `800nm` | Upper wavelength bound. |
| `--beam-beta`        | no  | `1.0` | `v/c` of the primary (1.0 = ultra-relativistic). |
| `--tree`             | no  | `Hits` | Name of the TTree to read. |
| `--root`             | no  | autodetect | Explicit `.root` file path (use when run dir has multiple). |
| `--tolerance-sigma`  | no  | `3.0` | PASS if `|observed − predicted| < N · sigma`. |

**Refractive-index flags** — pick one of the two paths. Required.

*Constant n (cheaper, less accurate)*: a single number applied across
the whole wavelength window. Fine for radiators where `n(λ)` varies
<0.5% across `[λ_min, λ_max]` (e.g. low-density gases over narrow
ranges); biased by 2-5% for dense radiators over visible light.

| Flag | Meaning |
|------|---------|
| `--refractive-index` | Single dimensionless `n`. |

*Dispersive n from GDML (recommended)*: reads the `RINDEX` matrix off
the radiator material in your GDML and trapezoidally integrates
Frank-Tamm in energy. The matrix's energy column is in Geant4 internal
units (MeV), so 6.2 eV reads as `6.2e-06`.

| Flag | Meaning |
|------|---------|
| `--rindex-from-gdml` | Path to a GDML file containing the material with a `RINDEX` matrix. |
| `--rindex-material`  | Name of that material (must match the `<material name="…"/>` attribute). |

Passing both is an error. Passing neither is an error.

**Schema flags** — pick one of these two modes depending on how your
TTree was written. The validator supports both because the example main
writes per-hit rows but a custom main may write per-event rows.

*Filtered mode (default)* — TTree has one row per hit with the photon
PDG code stored; the validator filters and bins by event index.

| Flag | Default | Meaning |
|------|---------|---------|
| `--event-branch` | `event` | Branch holding the event index. |
| `--pdg-branch`   | `pdg`   | Branch holding the particle PDG code. |
| `--photon-pdg`   | `-22`   | PDG code for optical photons in the TTree. |

*Direct mode* — TTree has one row per event with a precomputed photon
count. Use this when your custom main aggregates inside Geant4 (cheaper
output, no PDG filtering on the host).

| Flag | Default | Meaning |
|------|---------|---------|
| `--count-branch` | — (mode trigger) | Branch with per-event photon counts. When set, switches the validator to direct mode and ignores `--event-branch / --pdg-branch / --photon-pdg`. |

The example main's `Hits` TTree (with `event/I` + `pdg/I` branches)
works out-of-the-box with the filtered defaults. A custom main that
stores Cherenkov yield in `Events.n_photons` would run with
`--tree Events --count-branch n_photons`.

## Steps

1. **Resolve a Python with uproot+numpy.** The validators read the ROOT
   file with `uproot`, so use the *same* resolution as
   `/geant4-claude:geant4-analyze` step 2 — never bare `python3`, and
   never `pip install --user` (that pollutes the host site-packages):

   ```bash
   # (a) host python   (b) plugin venv   (c) install into the plugin venv
   if python3 -c "import uproot, numpy" 2>/dev/null; then
     PY="$(command -v python3)"
   elif "${CLAUDE_PLUGIN_DATA}/venv/bin/python" -c "import uproot, numpy" 2>/dev/null; then
     PY="${CLAUDE_PLUGIN_DATA}/venv/bin/python"
   else
     # The SessionStart hook normally seeds the venv. It may be absent
     # (hook not approved / failed / never ran, or the venv was removed
     # after a prior run) — create+seed it via the hook itself
     # (idempotent, single source of venv-creation logic), then re-resolve.
     bash "${CLAUDE_PLUGIN_ROOT}/hooks/install-deps.sh" || true
     PY="${CLAUDE_PLUGIN_DATA}/venv/bin/python"
     if ! "${PY}" -c "import uproot, numpy" 2>/dev/null; then
       echo "validate: could not provision uproot/numpy in the plugin" \
            "venv (${PY}). Check hooks/install-deps.sh output and" \
            "network; do not pip install --user." >&2
       exit 2
     fi
   fi
   ```

   In normal operation the SessionStart hook already seeded the venv
   from `requirements.txt`, so (b) hits.

2. **Run the topic-specific validator** with the resolved `${PY}`:

   ```bash
   "${PY}" "${CLAUDE_PLUGIN_ROOT}/scripts/validators/<topic>.py" <run_dir> <flags…>
   ```

   For `cherenkov`:

   ```bash
   "${PY}" "${CLAUDE_PLUGIN_ROOT}/scripts/validators/cherenkov.py" \
     runs/<id> \
     --radiator-length 1m \
     --refractive-index 1.000449 \
     --beam-beta 1.0
   ```

3. **Echo the validator's output back** to the user. The script prints
   the predicted/observed/sigma/result block to stdout; show that
   verbatim. Don't paraphrase.

4. **On FAIL**, do not silently continue. Surface the result, suggest a
   follow-up (likely an investigation — wrong material properties,
   wrong physics list, sensor geometry) and stop. The user decides
   whether to re-run with different parameters or to dig in.

## Outputs

- Stdout: human-readable PASS/FAIL summary with numbers.
- `runs/<id>/validate_<topic>.json`: machine-readable summary
  (parameters, predicted, observed, sigma, pass).
- Process exit: `0` PASS, `1` FAIL, `2` bad input / missing data.

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `missing dep: uproot` | Neither host Python nor the plugin venv has uproot/numpy (SessionStart hook hasn't run, or its install failed). | Re-resolve `${PY}` via step 1 (installs into the plugin venv). Never `pip install --user` — it pollutes the host site-packages. |
| `tree 'Hits' not in <root>` | Output schema isn't the example schema. | Pass `--tree <name>`; check available trees with `python3 -c "import uproot; print(uproot.open('<root>').keys())"`. |
| `predicted yield is 0 — beam is below Cherenkov threshold` | `beta * n` <= 1. | Use a more relativistic beam or a higher-`n` radiator; sanity-check inputs. |
| FAIL by many sigma | Wrong material properties, missing `G4OpticalPhysics`, sensor outside the forward cone, wrong wavelength range. | Investigate — that's the whole point of the test. Don't reach for a wider tolerance. |

## Notes

- v1 only ships the `cherenkov` validator. Adding a new validator =
  drop a `<topic>.py` next to `cherenkov.py`, document it in this file,
  and link from the orchestrator skill.
- If `n(λ)` varies meaningfully across `[λ_min, λ_max]`, prefer
  `--rindex-from-gdml`. Falling back to `--refractive-index` is fine
  when the geometry has no RINDEX matrix (the radiator material was
  defined without optical properties), with the understanding that
  predictions then carry a 2-5% bias on the upper bound.
- Validators read `.root` files but **never** modify the run dir except
  to write their `validate_<topic>.json` summary. Re-running is safe.
