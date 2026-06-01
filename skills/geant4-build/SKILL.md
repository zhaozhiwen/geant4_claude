---
name: geant4-build
description: Use when the user wants to compile/build their Geant4 source tree (a src/ dir with CMakeLists.txt) into a runnable executable. Builds via CMake inside the pinned apptainer image into ./build/. Requires geant4-init to have run.
---

# geant4-build — compile a Geant4 app in the container

## Purpose

Compile the user's Geant4 application from `src/` into `./build/` using CMake
inside the pinned apptainer image. The single bridge from source to a runnable
executable — never call `cmake`, `g++`, or `make` on the host directly.

## Inputs (all optional)

| Flag | Default | Meaning |
|------|---------|---------|
| `--src <dir>` | `src` | Source dir; must contain a top-level `CMakeLists.txt`. |
| `--build <dir>` | `build` | Build dir; created if missing. |
| `--clean` | off | Delete `<build>` before configuring. |

## Steps

1. **Resolve the engine** (every skill starts with this; written by geant4-init):
   ```bash
   G4C="$PWD"; while [ "$G4C" != "/" ] && [ ! -d "$G4C/.g4c" ]; do G4C="$(dirname "$G4C")"; done
   [ -f "$G4C/.g4c/env" ] && . "$G4C/.g4c/env"; G4RUN="${G4RUN:-$G4C/.g4c/g4run}"
   ```
   If `.g4c/` is missing, stop and tell the user to run the **geant4-init** skill
   first.

2. **Validate source:**
   ```bash
   test -f "${SRC}/CMakeLists.txt" || { echo "no ${SRC}/CMakeLists.txt"; exit 1; }
   ```
   If missing, suggest the **geant4-example** skill (drops in a working sample) or
   bringing your own and pointing `--src` at it.

3. **Optional clean.** If `--clean`: `rm -rf "${BUILD}"`.

4. **Build:**
   ```bash
   "${G4RUN}" build "${SRC}" "${BUILD}"
   ```
   Both paths are passed to apptainer as canonical (symlink-resolved) paths and
   bound automatically — CWD-relative paths work.

5. **Report.** Show the build dir and the executables now under it
   (`find "${BUILD}" -maxdepth 3 -type f -executable -not -path '*CMakeFiles*'`),
   and point at the **geant4-run** skill. If the build wrote no executable, that's
   a likely missing `add_executable` in the user's `CMakeLists.txt`.

## Outputs

- `<build>/` populated with CMake artifacts and the compiled binary(ies).

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `.g4c/` missing | Workspace not initialized. | Run the geant4-init skill first. |
| `no src/CMakeLists.txt` | No source yet. | Use the geant4-example skill, or bring your own. |
| `Could not find a package configuration file provided by "Geant4"` | `find_package(Geant4 …)` missing or misspelled. | Mirror `${GEANT4_CLAUDE_ROOT}/templates/example/src/CMakeLists.txt`. |
| `error: 'FTFP_BERT.hh' file not found` | Header not in include path. | The container's `find_package(Geant4)` brings includes in; check typos and `include(${Geant4_USE_FILE})`. |
| Build succeeds but no executable | No `add_executable` directive. | Add it to `src/CMakeLists.txt` and rebuild. |
| Linker undefined references to `ROOT::*` | `find_package(ROOT …)` missing or wrong components. | Add `find_package(ROOT REQUIRED COMPONENTS Tree RIO)` and link `ROOT::Core ROOT::RIO ROOT::Tree`. |

## Notes

- `./build/` is gitignored by the workspace `.gitignore` from the geant4-init step.
- Idempotent. CMake's incremental builds rebuild only what changed; pass `--clean`
  for a from-scratch rebuild.
- Need a different toolchain or extra cmake flags? Use `"${G4RUN}" shell` to enter
  the container and run `cmake` by hand — this skill stays minimal.
