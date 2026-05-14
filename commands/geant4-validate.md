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
| `--refractive-index` | yes | — | Refractive index of the radiator (constant `n`). |
| `--wavelength-min`   | no  | `200nm` | Lower wavelength bound of the photon count. |
| `--wavelength-max`   | no  | `800nm` | Upper wavelength bound. |
| `--beam-beta`        | no  | `1.0` | `v/c` of the primary (1.0 = ultra-relativistic). |
| `--photon-pdg`       | no  | `-22` | PDG code for optical photons in the TTree. |
| `--tree`             | no  | `Hits` | Name of the TTree to read. |
| `--root`             | no  | autodetect | Explicit `.root` file path (use when run dir has multiple). |
| `--tolerance-sigma`  | no  | `3.0` | PASS if `|observed − predicted| < N · sigma`. |

The TTree must have `event/I` and `pdg/I` branches at minimum — this
matches the example main's `Hits` schema. Photon counts per event are
derived by binning on `event` after filtering by `pdg == -22`.

## Steps

1. **Run the topic-specific validator.** The plugin ships these under
   `scripts/validators/`:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/validators/<topic>.py" <run_dir> <flags…>
   ```

   For `cherenkov`:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/validators/cherenkov.py" \
     runs/<id> \
     --radiator-length 1m \
     --refractive-index 1.000449 \
     --beam-beta 1.0
   ```

2. **Echo the validator's output back** to the user. The script prints
   the predicted/observed/sigma/result block to stdout; show that
   verbatim. Don't paraphrase.

3. **On FAIL**, do not silently continue. Surface the result, suggest a
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
| `missing dep: uproot` | Host Python doesn't have uproot/numpy. | `pip install --user uproot numpy`. |
| `tree 'Hits' not in <root>` | Output schema isn't the example schema. | Pass `--tree <name>`; check available trees with `python3 -c "import uproot; print(uproot.open('<root>').keys())"`. |
| `predicted yield is 0 — beam is below Cherenkov threshold` | `beta * n` <= 1. | Use a more relativistic beam or a higher-`n` radiator; sanity-check inputs. |
| FAIL by many sigma | Wrong material properties, missing `G4OpticalPhysics`, sensor outside the forward cone, wrong wavelength range. | Investigate — that's the whole point of the test. Don't reach for a wider tolerance. |

## Notes

- v1 only ships the `cherenkov` validator. Adding a new validator =
  drop a `<topic>.py` next to `cherenkov.py`, document it in this file,
  and link from the orchestrator skill.
- The cherenkov validator assumes constant refractive index. If `n(λ)`
  varies meaningfully across `[λ_min, λ_max]`, use a tighter wavelength
  window so the constant-`n` approximation holds.
- Validators read `.root` files but **never** modify the run dir except
  to write their `validate_<topic>.json` summary. Re-running is safe.
