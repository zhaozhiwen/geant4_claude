# AGENTS.md — Geant4 project

This directory is a **Geant4 project**: it manages and records multiple
simulation **tasks**, each in its own subdirectory. Works on both Claude Code
and OpenAI Codex. The `geant4_claude` plugin scaffolded this project. Describe
what you want in natural language and the matching skill runs — there are no
slash commands.

## Layout

| Path | Role |
|------|------|
| `log.md` | The project record — a **Tasks** table plus a chronological log of every simulation task (name, goal, status, headline result). Update it whenever a task is created or finishes. |
| `<task>/` | One simulation task, created by the **geant4-task** skill from the task skeleton. Holds its own `src/ geometries/ macros/ runs/ analysis/` and its own `log.md`/`result.md`/`report.html` (that task's detailed record). |
| `.g4c/` | Shared engine pointer (**gitignored**): the `g4run` shim + `env`. Every skill reaches the runtime by walking up to this dir. Written once by **geant4-init**. |
| `cache/` | Shared container image (`.sif`, **gitignored**). |
| `venv/` | Shared Python venv (**gitignored**). |

## Non-negotiables

1. **All Geant4 / ROOT calls go through `g4run`** (resolved by walking up from
   the current dir to `.g4c/`). Never invoke `apptainer`, `geant4`, or `root`
   directly.
2. **One task per subdirectory.** Create tasks with the **geant4-task** skill;
   never scatter `src/`, `runs/`, or `geometries/` at the project root.
3. **Record every task in this `log.md`.** Each task gets a row in the Tasks
   table and a dated log entry (goal → decision → outcome). The per-task
   `log.md` inside each subdir keeps that task's detailed run log.
4. **The shared engine (`.g4c/ cache/ venv/`) is created once** by
   **geant4-init** and shared by all tasks — never duplicate it per task.

## Typical flow

1. **geant4-init** (once) — scaffold this project + the shared engine.
2. **geant4-task** — create a task subdir (e.g. `lead-block-edep/`); it `cd`s in.
3. Inside the task: **geant4-detector** → **geant4-example** → **geant4-build**
   → **geant4-run** → **geant4-analyze** (or bring your own `src/main.cc`).
4. The task's progress is recorded in this project `log.md` and in the task's
   own handoff docs.
