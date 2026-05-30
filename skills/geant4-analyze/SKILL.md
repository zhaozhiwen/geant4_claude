---
name: geant4-analyze
description: Use when the user wants to inspect a Geant4 run's output schema and plot/summarize it — reads runs/<id>/, dumps the ROOT tree branches, and produces a histogram + summary (canned fast-path for the example schema, generated script otherwise). Runs uproot/numpy/matplotlib. Requires geant4-init to have run.
---

# geant4-analyze — inspect a run's output and plot it

## Purpose

Read what the user's binary wrote into `runs/<id>/` and produce a useful
plot + summary. Two paths:

- **Fast path** — if a `Hits` TTree with the example schema exists
  (`event/I`, `volume/C`, `edep/D`, `x,y,z,t/D`, `pdg/I`), use the canned
  per-event energy-deposit histogram.
- **Custom path** — for any other schema, inspect the file, generate an
  analysis script tailored to the actual branches, and run it.

Either way the output lands in `runs/<id>/` (plots, summary), with
optional reusable scripts dropped in `analysis/`.

## Inputs

- `runs/<id>` (required, positional) — the run directory.
- `--script <path>` (optional) — bypass the schema check; use this script.
- `--root-file <name>` (optional) — pick a specific `.root` if the run
  has more than one (default: pick the only `.root`, or stop if
  multiple).

## Steps

1. **Resolve the engine** (every skill starts with this; written by geant4-init):
   ```bash
   [ -f .g4c/env ] && . .g4c/env; G4RUN="${G4RUN:-$PWD/.g4c/g4run}"
   ```
   If `.g4c/` is missing, stop and tell the user to run the **geant4-init** skill
   first.

2. **Provision the Python venv** (this skill needs uproot/numpy/matplotlib;
   the venv is seeded here (idempotent); there is no SessionStart hook on
   either CLI):
   ```bash
   . .g4c/env; "${GEANT4_CLAUDE_ROOT}/scripts/ensure_venv.sh"
   ```

3. **Sanity checks.**
   ```bash
   test -d "${RUN_DIR}" || { echo "no such run dir"; exit 1; }
   ```
   Find the ROOT file:
   ```bash
   if [[ -n "${ROOT_FILE:-}" ]]; then
     RF="${RUN_DIR}/${ROOT_FILE}"
   else
     mapfile -t roots < <(find "${RUN_DIR}" -maxdepth 1 -name '*.root')
     case ${#roots[@]} in
       0) echo "no .root file in ${RUN_DIR}"; exit 1 ;;
       1) RF="${roots[0]}" ;;
       *) echo "multiple .root files; pass --root-file <name>"; printf '  %s\n' "${roots[@]}"; exit 1 ;;
     esac
   fi
   test -s "${RF}" || { echo "${RF}: empty"; exit 1; }
   ```

4. **Pick a python with uproot+numpy+matplotlib.** Try in priority order:

   ```bash
   # (a) host python (no install needed)
   if python3 -c "import uproot, numpy, matplotlib" 2>/dev/null; then
     PY="$(command -v python3)"

   # (b) plugin's managed venv (seeded by ensure_venv.sh in step 2)
   elif "${GEANT4_CLAUDE_DATA}/venv/bin/python" \
        -c "import uproot, numpy, matplotlib" 2>/dev/null; then
     PY="${GEANT4_CLAUDE_DATA}/venv/bin/python"

   # (c) re-provision the venv (idempotent; single source of venv-creation
   #     logic), then re-resolve. Reaches here only if step 2 was skipped
   #     or the venv was removed/broken since.
   else
     . .g4c/env; "${GEANT4_CLAUDE_ROOT}/scripts/ensure_venv.sh" || true
     PY="${GEANT4_CLAUDE_DATA}/venv/bin/python"
     if ! "${PY}" -c "import uproot, numpy, matplotlib" 2>/dev/null; then
       echo "analyze: could not provision uproot/numpy/matplotlib in the" \
            "plugin venv (${PY}). Check ensure_venv.sh output and" \
            "network; do not pip install --user." >&2
       exit 1
     fi
   fi
   ```

   In normal operation step 2's `ensure_venv.sh` has already seeded the venv
   from `requirements.txt` (which includes `uproot`), so branch (b)
   hits and (c) is the rare network-was-down recovery path.

   Re-provisioning the **plugin venv** is the recommended fallback:
   the venv is per-user, plugin-scoped, and removed when the plugin is
   uninstalled. Do **not** silently `pip install --user` into the host's
   site-packages — that pollutes the user's global environment without
   their consent. If the plugin venv is unavailable for some reason
   (network down, etc.), stop and tell the user the install line.

5. **Inspect the schema** (Python one-liner; preserves the exact branch
   types and dtypes for later codegen). Use the `${PY}` resolved in
   step 4:
   ```bash
   "${PY}" - "${RF}" <<'PY'
import sys, uproot
with uproot.open(sys.argv[1]) as f:
    for k, t in f.items():
        if hasattr(t, "keys"):
            print(f"{k}:")
            for b in t.keys():
                print(f"  {b}  {t[b].typename}")
PY
   ```

6. **Pick the analysis path.**
   - If `--script` was passed → use it. Skip to step 7.
   - Else if the file has a TTree named `Hits` with branches `event`,
     `edep`, and at least `volume` or `pdg` → **fast path**: use
     `analysis/example.py` if present in the workspace, else materialize
     a copy from `${GEANT4_CLAUDE_ROOT}/templates/example/analysis/example.py`.
   - Else → **custom path**: generate a fresh script at
     `analysis/<run_id>.py` that:
     - opens the ROOT file,
     - loads each branch as a numpy array,
     - prints the branch min/mean/max,
     - histograms the most plausible "energy"/"signal" branch (any
       branch named `edep`, `e`, `energy`, `signal`, or the first
       float-typed branch with name length ≥ 3),
     - writes a PNG into `${RUN_DIR}/`.

   Use the **geant4-analysis** skill for the uproot recipes.

7. **Run the script.** Use the resolved `${PY}` so the script picks up
   the venv that has `uproot`:
   ```bash
   "${PY}" "${SCRIPT}" "${RUN_DIR}"
   ```
   **Zero-signal guard.** If the tree is empty / the plotted branch has
   zero entries, do **not** silently emit a blank plot and proceed.
   Stop and warn loudly with the likely cause:
   - optical run (`pdg = -22` expected, none found): the radiator
     material lacks `RINDEX`, or the SD is on the wrong volume — for a
     Cherenkov **yield** spec the *radiator* must be sensitive (photons
     are counted as produced, not at a downstream plane);
   - non-optical: the beam missed the target, or no volume is tagged
     sensitive.
   An empty result is a failure to surface, not a finding to report —
   skip the doc refresh (step 8) until it's resolved.

8. **Refresh `report.html` and `result.md`** (only if they exist —
   created by the **geant4-init** skill). Per workspace `CLAUDE.md`
   non-negotiable #6, a noteworthy analyze must land in the handoff
   docs. Edit in place:
   - `result.md`: add/update the per-run findings section (key numbers,
     plot paths). Markdown is authoritative.
   - `report.html`: add a `<figure>` to the **Plots** grid for each PNG
     this analyze produced (`src` relative to the workspace root, e.g.
     `runs/<id>/edep_hist.png`); add **Key numbers** rows (value +
     source path, including any `runs/<id>/validate_*.json`); fill the
     **Summary** and **Notes &amp; interpretation** prose; refresh the
     header meta date.
   Preserve the section structure, replace placeholders only, keep
   `report.html` consistent with `result.md` (markdown wins on
   conflict). Idempotent: re-analyzing the same run updates its figures
   and rows instead of duplicating them.

9. **Show the user:**
   - the schema dump from step 5,
   - the path to the PNG and any other outputs,
   - the summary printed by the script,
   - a hint:
     `For per-volume sums, hit maps, longitudinal profiles, etc., see the geant4-analysis skill. Custom scripts go in analysis/.`

## Outputs

- `runs/<id>/<plot>.png` (canned `edep_hist.png` on the fast path; the
  generated script picks the name on the custom path).
- Stdout schema dump + summary statistics.
- Possibly a new `analysis/<run_id>.py` on the custom path (versioned;
  user can edit and re-run).
- If the workspace is `init`-ed: `result.md` and `report.html` refreshed
  with this run's plots, key numbers, and interpretation (step 8).

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `.g4c/` missing | Workspace not initialized. | Run the geant4-init skill first. |
| `ModuleNotFoundError: uproot` (after step 4's provisioning path) | Network blocked, or the plugin venv is missing/broken. | Inspect `${GEANT4_CLAUDE_DATA}/venv/`; repair with `. .g4c/env; "${GEANT4_CLAUDE_ROOT}/scripts/ensure_venv.sh"`, or reinstall the plugin. Never `pip install --user` (pollutes host site-packages). |
| `no .root file in runs/<id>` | Binary didn't produce a ROOT file (or wrote elsewhere). | Inspect `runs/<id>/log.txt`; check the binary's args / `RUN_DIR` handling. |
| `KeyError: 'Hits'` (custom schema) | The fast-path script was forced on a non-`Hits` file. | Don't pass `--script`; let the skill auto-detect, or pass a script that matches your schema. |
| Empty histogram | All entries zero, or selected branch is wrong. | Check the schema dump; explicitly pick the branch via a custom script. |

## Notes

- The canned `example.py` in `analysis/` is a starting point, not sacred.
  Edit it freely; the skill keeps using it as long as it accepts the
  run dir as `argv[1]`.
- ROOT-specific tools (TBrowser, RooFit) run inside the container via
  `"${G4RUN}" root <macro.C>` — see the **geant4-analysis** skill.
- The custom-path script is generated *once per run id*; rerun the
  skill on the same run to overwrite it, or hand-edit it freely.
