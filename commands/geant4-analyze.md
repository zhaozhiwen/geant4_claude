---
description: Inspect a run's output schema, plot/summarize it (canned fast-path for the example, custom script otherwise).
allowed-tools: Bash, Read, Write, Glob
---

# /geant4-claude:geant4-analyze

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

1. **Sanity checks.**
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

2. **Pick a python with uproot+numpy+matplotlib.** Try in priority order:

   ```bash
   # (a) host python (no install needed)
   if python3 -c "import uproot, numpy, matplotlib" 2>/dev/null; then
     PY="$(command -v python3)"

   # (b) plugin's managed venv (no install needed if previously seeded)
   elif "${CLAUDE_PLUGIN_DATA}/venv/bin/python" \
        -c "import uproot, numpy, matplotlib" 2>/dev/null; then
     PY="${CLAUDE_PLUGIN_DATA}/venv/bin/python"

   # (c) install into the plugin venv (preferred — survives plugin updates,
   #     isolated from system site-packages, cleaned with the plugin).
   else
     # The SessionStart hook normally seeds the venv. It may be absent
     # (hook not approved / failed / never ran, or the venv was removed
     # after a prior run) — create+seed it via the hook itself
     # (idempotent, single source of venv-creation logic), then re-resolve.
     bash "${CLAUDE_PLUGIN_ROOT}/hooks/install-deps.sh" || true
     PY="${CLAUDE_PLUGIN_DATA}/venv/bin/python"
     if ! "${PY}" -c "import uproot, numpy, matplotlib" 2>/dev/null; then
       echo "analyze: could not provision uproot/numpy/matplotlib in the" \
            "plugin venv (${PY}). Check hooks/install-deps.sh output and" \
            "network; do not pip install --user." >&2
       exit 1
     fi
   fi
   ```

   In normal operation the SessionStart hook has already seeded the venv
   from `requirements.txt` (which now includes `uproot`), so branch (b)
   hits and (c) is the rare network-was-down recovery path.

   Auto-installing into the **plugin venv** is the recommended fallback:
   the venv is per-user, plugin-scoped, and removed when the plugin is
   uninstalled. Do **not** silently `pip install --user` into the host's
   site-packages — that pollutes the user's global environment without
   their consent. If the plugin venv is unavailable for some reason
   (network down, etc.), stop and tell the user the install line.

3. **Inspect the schema** (Python one-liner; preserves the exact branch
   types and dtypes for later codegen). Use the `${PY}` resolved in
   step 2:
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

4. **Pick the analysis path.**
   - If `--script` was passed → use it. Skip to step 6.
   - Else if the file has a TTree named `Hits` with branches `event`,
     `edep`, and at least `volume` or `pdg` → **fast path**: use
     `analysis/example.py` if present in the workspace, else materialize
     a copy from `${CLAUDE_PLUGIN_ROOT}/templates/example/analysis/example.py`.
   - Else → **custom path**: generate a fresh script at
     `analysis/<run_id>.py` that:
     - opens the ROOT file,
     - loads each branch as a numpy array,
     - prints the branch min/mean/max,
     - histograms the most plausible "energy"/"signal" branch (any
       branch named `edep`, `e`, `energy`, `signal`, or the first
       float-typed branch with name length ≥ 3),
     - writes a PNG into `${RUN_DIR}/`.

   Use the `geant4-analysis` skill for the uproot recipes.

5. **Run the script.** Use the resolved `${PY}` so the script picks up
   the venv that has `uproot`:
   ```bash
   "${PY}" "${SCRIPT}" "${RUN_DIR}"
   ```

6. **Show the user:**
   - the schema dump from step 3,
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

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `ModuleNotFoundError: uproot` (after step 2's auto-install path) | Network blocked, or the plugin venv is missing/broken. | Inspect `${CLAUDE_PLUGIN_DATA}/venv/`; repair with `bash "${CLAUDE_PLUGIN_ROOT}/hooks/install-deps.sh"`, or reinstall the plugin. Never `pip install --user` (pollutes host site-packages). |
| `no .root file in runs/<id>` | Binary didn't produce a ROOT file (or wrote elsewhere). | Inspect `runs/<id>/log.txt`; check the binary's args / `RUN_DIR` handling. |
| `KeyError: 'Hits'` (custom schema) | The fast-path script was forced on a non-`Hits` file. | Don't pass `--script`; let the command auto-detect, or pass a script that matches your schema. |
| Empty histogram | All entries zero, or selected branch is wrong. | Check the schema dump; explicitly pick the branch via a custom script. |

## Notes

- The canned `example.py` in `analysis/` is a starting point, not sacred.
  Edit it freely; the command keeps using it as long as it accepts the
  run dir as `argv[1]`.
- ROOT-specific tools (TBrowser, RooFit) run inside the container via
  `g4run root <macro.C>` — see the `geant4-analysis` skill.
- The custom-path script is generated *once per run id*; rerun the
  command on the same run to overwrite it, or hand-edit it freely.
