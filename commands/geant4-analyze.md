---
description: Plot and summarize a run; produces edep_hist.png plus a one-paragraph summary.
allowed-tools: Bash, Read, Write, Glob
---

# /geant4-analyze

## Purpose

Turn `runs/<id>/hits.root` into a default histogram + a short text summary
so the user can sanity-check a run without writing any analysis code.

For richer plots, the **`geant4-analysis`** skill has the recipes; users
should write their own scripts under `analysis/` once the default plot
isn't enough.

## Inputs

- `runs/<id>` (required, positional) — the run directory written by
  `/geant4-run`.
- `--script <path>` (optional) — use a custom analysis script instead
  of the default `analysis/example.py`. Script must accept the run
  directory as its single positional arg.

## Steps

1. **Sanity checks.**
   ```bash
   test -d "${RUN_DIR}"           || { echo "no such run dir"; exit 1; }
   test -s "${RUN_DIR}/hits.root" || { echo "hits.root missing or empty"; exit 1; }
   test -s "${RUN_DIR}/config.json" || { echo "config.json missing"; exit 1; }
   ```

2. **Verify the host has uproot.**
   ```bash
   python3 -c "import uproot, numpy, matplotlib" 2>/dev/null \
     || { cat <<EOF
[geant4-analyze] missing Python deps. Install with one of:
  pip install --user uproot numpy matplotlib
or
  python3 -m venv .venv && . .venv/bin/activate && pip install uproot numpy matplotlib
EOF
        exit 1; }
   ```
   Stop if missing — do not auto-install. Tell the user the two install
   options above and let them pick.

3. **Pick the script.**
   - If `--script` was passed, use it.
   - Else, if `analysis/example.py` exists in the workspace, use it
     (the workspace template ships one).
   - Else, write a minimal default script to `analysis/example.py`
     (same contents as the workspace template) and use that.

4. **Run the script.**
   ```bash
   python3 "${SCRIPT}" "${RUN_DIR}"
   ```
   The default script reads `config.json`, opens `hits.root`,
   aggregates per-event edep, and writes `${RUN_DIR}/edep_hist.png`
   alongside a few summary statistics on stdout.

5. **Show the user:**
   - the path to `edep_hist.png`,
   - the printed summary (mean, std, total hits),
   - a hint:
     ```
     For per-volume sums, hit maps, or longitudinal profiles, see the
     geant4-analysis skill. Scripts go in analysis/.
     ```

## Outputs

- `runs/<id>/edep_hist.png` (created by the script).
- Stdout summary: `mean`, `std`, `hits`.
- No state changes outside `analysis/` (only if the default script
  needed to be created) and `runs/<id>/`.

## Failure modes

| Symptom | Likely cause | Fix |
|--------|--------------|-----|
| `ModuleNotFoundError: uproot` | Host Python doesn't have the analysis stack. | Run the install line printed in step 2. |
| `FileNotFoundError: hits.root` | Wrong run id or the sim never wrote output. | Check `runs/<id>/log.txt` for an error from `/geant4-run`. |
| `ValueError: minlength must be non-negative` (per-event histogram) | `n_events` in `config.json` is missing or wrong. | Open `config.json` and confirm; rerun the sim if the record was lost. |
| Empty histogram (mean = 0) | No volume tagged sensitive in the GDML. | Add `<auxiliary auxtype="sensitive" auxvalue="true"/>` to the volume of interest; rerun. |

## Notes

- `analysis/example.py` is a template, not sacred. Edit it freely; the
  command will keep using it as long as it accepts the run dir as
  argv[1] and writes `edep_hist.png` next to `hits.root`.
- Anything ROOT-specific (TBrowser, RooFit) can be invoked with
  `g4run root <macro.C>` — see the `geant4-analysis` skill.
