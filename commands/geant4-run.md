---
description: Execute a user-built Geant4 binary inside the container; capture provenance into runs/<id>/.
allowed-tools: Bash, Read, Write, Glob
---

# /geant4-claude:geant4-run

## Purpose

Run **the user's compiled Geant4 application** inside the pinned
container, with full provenance capture into a fresh `runs/<id>/`
directory. Content-neutral: works with any binary the user built via
`/geant4-claude:geant4-build`, regardless of CLI shape or output schema.

## Inputs

| Flag            | Required? | Meaning |
|-----------------|-----------|---------|
| `--exe <path>`  | yes (or auto-detect) | Path to the executable. Default: if exactly one executable exists under `./build/`, use it; otherwise stop and ask. |
| `--name <slug>` | no        | Human-readable suffix appended to the run id. |
| `--`            | no        | Everything after `--` is forwarded as positional args to the executable. |

Two placeholders are substituted in forwarded args:

- `{run_dir}` → the absolute path of the just-allocated `runs/<id>/`.
- `{run_id}`  → just the id string.

The same path is also exported as `RUN_DIR` in the executable's
environment, so a binary that reads `getenv("RUN_DIR")` will see it.

## Steps

1. **Pick the executable.** If `--exe` is set, use it. Else:
   ```bash
   mapfile -t exes < <(find build -maxdepth 3 -type f -executable -not -path '*CMakeFiles*' 2>/dev/null)
   ```
   - 0 executables → stop, suggest `/geant4-claude:geant4-build` (or `/geant4-claude:geant4-example`).
   - 1 executable  → use it.
   - >1            → stop, list them, ask the user to pass `--exe`.

   ```bash
   test -x "${EXE}" || { echo "${EXE}: not executable"; exit 1; }
   ```

2. **Allocate a run id.**
   ```bash
   RUN_ID="$(date -u +%Y%m%d-%H%M%S)-$(head -c3 /dev/urandom | xxd -p)"
   [[ -n "${NAME:-}" ]] && RUN_ID="${RUN_ID}-${NAME}"
   RUN_DIR="$(pwd -P)/runs/${RUN_ID}"
   mkdir -p "${RUN_DIR}"
   ```

3. **Substitute placeholders** in the forwarded args:
   ```bash
   resolved_args=()
   for a in "${ARGS[@]}"; do
     a="${a//\{run_dir\}/${RUN_DIR}}"
     a="${a//\{run_id\}/${RUN_ID}}"
     resolved_args+=("${a}")
   done
   ```

4. **Write provenance** at `${RUN_DIR}/config.json`:
   ```json
   {
     "run_id":      "<RUN_ID>",
     "executable":  "<EXE>",
     "args":        [<resolved_args ...>],
     "image":       "<IMAGE_TAG read from g4run info>",
     "git_sha":     "<git rev-parse HEAD, or null>",
     "started_utc": "<ISO-8601>",
     "duration_s":  null,
     "exit_status": null
   }
   ```

5. **Run the executable.** Stream stdout+stderr to `log.txt`. Export
   `RUN_DIR` and `RUN_ID` for the binary's benefit.
   ```bash
   START=$(date +%s)
   ( export RUN_DIR RUN_ID
     export GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache"
     "${CLAUDE_PLUGIN_ROOT}/bin/g4run" exec "${EXE}" "${resolved_args[@]}"
   ) 2>&1 | tee "${RUN_DIR}/log.txt"
   STATUS=${PIPESTATUS[0]}
   END=$(date +%s)
   ```

6. **Patch `config.json`** with `duration_s = $((END-START))` and
   `exit_status = ${STATUS}`.

7. **Verify and report.**
   - Don't assert anything about output files — the binary may write
     `hits.root`, `tracks.root`, `summary.json`, or nothing at all. Just
     list whatever's in `${RUN_DIR}` after the run.
   - On `STATUS != 0`: show the user the last 30 lines of `log.txt` and
     stop. Do not delete the run dir — the log + config are the
     debugging trail.
   - On success, summarize:
     ```
     ✓ run <RUN_ID> finished in <duration>s
       → runs/<RUN_ID>/{log.txt, config.json, ...whatever the binary wrote}
     Next: /geant4-claude:geant4-analyze runs/<RUN_ID>
     ```

## Outputs

```
runs/<run_id>/
├── log.txt        # full stdout+stderr from the executable
├── config.json    # generic provenance (the file analysis tools must read)
└── ...            # whatever your binary wrote (hits.root, etc.)
```

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `not an executable: <path>` | Binary missing or not built. | Run `/geant4-claude:geant4-build`. |
| `more than one executable under build/` | Ambiguous default. | Pass `--exe build/<your-binary>`. |
| Binary segfaults or `G4Exception` | Bug in user's main, missing GDML reference, OOM. | Inspect `runs/<id>/log.txt`. |
| Output file missing where you expected it | Binary wrote relative to its own CWD or a hardcoded path. | Either pass `{run_dir}/<filename>` as an arg, or read `RUN_DIR` from env in your `main.cc`. |
| Run hangs | Macro never reaches `/run/beamOn`, or beam count is huge. | Inspect `log.txt`; reduce events; consider the `geant4-runner` agent for long sims. |

## Notes

- Run directories are immutable by convention. Re-run = new id.
- For runs expected to take more than a few minutes, dispatch the
  `geant4-runner` agent so context doesn't bloat with the live log.
- Don't capture macro semantics (particle, energy, n_events) here —
  those live inside the macro file, not in the run wrapper. Analysis
  scripts should parse the macro themselves if they need them.
