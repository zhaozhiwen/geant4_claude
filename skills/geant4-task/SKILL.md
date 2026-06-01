---
name: geant4-task
description: Use when the user wants to start a new simulation task (a new study, geometry, or run series) inside an already-initialized Geant4 project. Creates a task subdirectory from the task skeleton, registers it in the project log, and cd's into it. Run geant4-init once first — it creates the project and the shared engine.
---

# geant4-task — create a simulation task subproject

Creates one simulation **task** as a subdirectory of the current Geant4 project
(scaffolded by **geant4-init**). The task gets its own `src/ geometries/ macros/
runs/ analysis/` and handoff docs, and **shares the project's engine** (`.g4c/`,
`cache/`, `venv/`) by walking up to `.g4c/` — nothing is duplicated per task.

## Inputs

- A task name (kebab-case, e.g. `lead-block-edep`). Ask if not given; derive a
  sensible default from the physics goal (`cherenkov-co2`, `proton-range-water`).
- Optional: `--force` (overwrite an existing task dir of the same name).

## Steps

1. **Resolve the engine** (walk up to the project's `.g4c/`):
   ```bash
   G4C="$PWD"; while [ "$G4C" != "/" ] && [ ! -d "$G4C/.g4c" ]; do G4C="$(dirname "$G4C")"; done
   [ -f "$G4C/.g4c/env" ] && . "$G4C/.g4c/env"; G4RUN="${G4RUN:-$G4C/.g4c/g4run}"
   ```
   If no `.g4c/` is found up-tree, stop and tell the user to run **geant4-init**
   first (it scaffolds the project + shared engine). `$G4C` is the project root.

2. **Pick a task name.** Kebab-case, one task per name. If the user didn't give
   one, ask or derive it from the physics goal. Create tasks *inside the project
   root* (`$G4C`), not nested in another task.

3. **Create the task dir from the skeleton:**
   ```bash
   TASK="<name>"
   if [ -e "${G4C}/${TASK}" ] && [ "${FORCE:-0}" != "1" ]; then
     echo "[g4c] task '${TASK}' already exists — re-run with --force to overwrite"; exit 1
   fi
   mkdir -p "${G4C}/${TASK}"
   cp -r "${GEANT4_CLAUDE_ROOT}/templates/workspace/." "${G4C}/${TASK}/"
   ```
   The skeleton ships `AGENTS.md` (+ `CLAUDE.md`→`AGENTS.md`), `log.md`,
   `result.md`, `report.html`, `embed_html.py`, a task `.gitignore`, and the
   empty `src/ geometries/ macros/ runs/ analysis/` dirs. It carries **no**
   `.g4c/`/`cache/`/`venv/` — those are the project's, reached by walking up.

4. **Register the task in the project `log.md`** (`${G4C}/log.md`):
   - Replace the `_none yet_` placeholder row (or append a new row) in the
     **Tasks** table: `| <name> | <one-line goal> | created | — |`.
   - Prepend a dated entry under `## Log`:
     `## <YYYY-MM-DD> — <name>` / `- **Created** from the task skeleton.` /
     `- **Goal:** <one line>.`
   Use UTC date. Keep the per-task detail in the task's own `log.md`.

5. **Enter the task and report:**
   ```bash
   cd "${G4C}/${TASK}"
   ```
   Tell the user the task is ready and recommend the **default flow** (run from
   *inside* this task dir — each step reaches the shared engine by walking up to
   `.g4c/`): **geant4-detector** → **geant4-example** → **geant4-build** →
   **geant4-run** → **geant4-analyze**. Alternative: bring your own
   `src/main.cc` + `src/CMakeLists.txt`, then **geant4-build**.

## Outputs

- `<project>/<name>/` populated from the task skeleton (its own `src/`,
  `geometries/`, `macros/`, `runs/`, `analysis/` + handoff docs).
- A Tasks-table row + a dated entry in the project `log.md`.
- cwd left inside the new task dir.

## Failure modes

| Symptom | Likely cause | Fix |
|--------|--------------|-----|
| No `.g4c/` found walking up | Project not initialized. | Run **geant4-init** in the project root first. |
| `cp: cannot stat '…/templates/workspace/…'` | `GEANT4_CLAUDE_ROOT` unresolved (engine pointer stale). | Re-run **geant4-init** to refresh `.g4c/`. |
| Task dir already exists | Name already used. | Pick another name, or re-run with `--force` (after confirming). |
