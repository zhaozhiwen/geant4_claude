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
| `--from <prev>` | no        | Path to a previous `runs/<id>/` directory this run derives from. Recorded as `parent_run` in `config.json` so the lineage is machine-readable. Useful for "v2 = v1 + this change" iteration. |
| `--reason <text>` | no      | One-liner explaining the diff from `--from`. Recorded as `diff_reason` in `config.json`. Required if `--from` is given. |
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
     "exit_status": null,
     "parent_run":  "<run_id parsed from --from, or null>",
     "diff_reason": "<--reason text, or null>"
   }
   ```

   If `--from <prev>` was passed, parse the run id out of `<prev>`
   (basename of the directory) and record it as `parent_run`. Require
   `--reason` in that case — refusing it forces the user to articulate
   *why* this run differs, which is the whole point of capturing lineage.
   If `--from` is absent, both fields are `null`.

5. **Run the executable.** Stream stdout+stderr to `log.txt`. Capture the executable's exit status via a sentinel file written outside the immutable run dir (`PIPESTATUS` is unreliable under a tcsh-login shell + subshell, and would let a failed run report as success). Export `RUN_DIR` and `RUN_ID` for the binary's benefit.
   ```bash
   EXIT_FILE="$(mktemp)"
   START=$(date +%s)
   ( export RUN_DIR RUN_ID
     export GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache"
     "${CLAUDE_PLUGIN_ROOT}/bin/g4run" exec "${EXE}" "${resolved_args[@]}"
     echo $? > "${EXIT_FILE}"
   ) 2>&1 | tee "${RUN_DIR}/log.txt"
   STATUS="$(cat "${EXIT_FILE}" 2>/dev/null || echo 1)"
   rm -f "${EXIT_FILE}"
   END=$(date +%s)
   ```

6. **Patch `config.json`** with `duration_s = $((END-START))` and
   `exit_status = ${STATUS}`.

7. **Prepend a `log.md` stub** (only if `log.md` exists in the cwd —
   created by `/geant4-claude:geant4-init`). The stub carries the four
   mechanical Outcome fields (run id, status, duration, output path),
   so the orchestrator skill or the user only has to fill in Request,
   Plan, Decision, and Notes. The stub is inserted above the
   `<!-- ENTRY TEMPLATE -->` comment so the most recent entry sits
   directly under the intro.

   ```bash
   if [[ -f log.md ]]; then
     TS="$(date -u +'%Y-%m-%d %H:%M UTC')"
     if [[ ${STATUS} -eq 0 ]]; then
       STATUS_DESC="succeeded"
     else
       STATUS_DESC="failed (exit ${STATUS})"
     fi
     # List what the binary wrote, excluding the wrapper-generated files.
     OUTPUTS="$(find "${RUN_DIR}" -maxdepth 1 -mindepth 1 -type f \
                  ! -name 'log.txt' ! -name 'config.json' \
                  -printf '  - runs/'"${RUN_ID}"'/%P\n' | head -5)"
     STUB="$(mktemp)"
     {
       echo "## ${TS} — <one-line headline>"
       echo
       echo "### Request"
       echo
       echo "> <verbatim user request, in their own words>"
       echo
       echo "### Plan"
       echo
       echo "- Goal:      <…>"
       echo "- Geometry:  <…>"
       echo "- Beam:      <…>"
       echo "- Sensitive: <…>"
       echo "- Output:    <…>"
       echo "- Analysis:  <…>"
       echo
       echo "### Decision"
       echo
       echo "<approved as-is | edited spec to <…> | plan-only>"
       echo
       echo "### Outcome"
       echo
       echo "- Run id:   \`runs/${RUN_ID}\`"
       echo "- Status:   ${STATUS_DESC} in $((END-START))s"
       if [[ -n "${OUTPUTS}" ]]; then
         echo "- Output:"
         echo "${OUTPUTS}"
       else
         echo "- Output:   runs/${RUN_ID}/ (no extra files written)"
       fi
       echo "- Notes:    <one or two lines: what worked, what surprised, what's next>"
       echo
     } > "${STUB}"
     # Insert above the <!-- entry-template --> comment block. Read the
     # stub via getline (not `-v`): an `awk -v` value interprets
     # backslash escapes, which would mangle a verbatim user request
     # containing \n, \t, or a Windows path in the load-bearing log.md.
     awk -v stubfile="${STUB}" '
       BEGIN { while ((getline l < stubfile) > 0) stub = stub l "\n" }
       /^<!--/ && !done { printf "%s\n", stub; done=1 }
       { print }
       END { if (!done) printf "%s", stub }
     ' log.md > log.md.new && mv log.md.new log.md
     rm -f "${STUB}"
   fi
   ```

8. **Verify and report.**
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

Plus, if the cwd contains a `log.md` (the workspace is `init`-ed): a
new dated entry prepended at the top with the four mechanical Outcome
fields filled in and Request / Plan / Decision / Notes left as
`<…>` placeholders for the orchestrator or user to fill.

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
