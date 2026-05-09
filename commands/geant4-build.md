---
description: Build a Geant4 source tree (CMake) inside the pinned container into ./build/.
allowed-tools: Bash, Read, Glob
---

# /geant4-claude:geant4-build

## Purpose

Compile the user's Geant4 application from `src/` (or any source tree
they point at) into `./build/` using CMake inside the pinned apptainer
image. This is the single bridge between the user's source code and a
runnable executable — never call `cmake`, `g++`, or `make` on the host
directly.

## Inputs (flags, all optional)

| Flag           | Default      | Meaning |
|----------------|--------------|---------|
| `--src <dir>`  | `src`        | Source directory; must contain a top-level `CMakeLists.txt`. |
| `--build <dir>`| `build`      | Build directory; created if missing. |
| `--clean`      | off          | Delete `<build>` before configuring. |

## Steps

1. **Validate source.**
   ```bash
   test -d "${SRC}/CMakeLists.txt" -o -f "${SRC}/CMakeLists.txt" \
     || { echo "no ${SRC}/CMakeLists.txt"; exit 1; }
   ```
   If the source dir doesn't exist or has no `CMakeLists.txt`, stop and
   suggest one of:
   - `/geant4-claude:geant4-example` to drop in a working sample (writes `src/main.cc`
     + `src/CMakeLists.txt`),
   - bring your own — point `--src` at the directory.

2. **Optional clean.** If `--clean`:
   ```bash
   rm -rf "${BUILD}"
   ```

3. **Build.** Hand off to the wrapper, which invokes
   `cmake -S <src> -B <build> && cmake --build <build> -j` inside the
   container:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/bin/g4run" build "${SRC}" "${BUILD}"
   ```
   Both paths are passed to apptainer as canonical (symlink-resolved)
   paths and bound automatically — CWD-relative paths work.

4. **Report.** Show:
   - the build directory and the executables now under it
     (`find "${BUILD}" -maxdepth 3 -type f -executable -not -path '*CMakeFiles*'`),
   - what to run next:
     `/geant4-claude:geant4-run --exe <build>/<your-binary> -- <its args...>`.
   If the build wrote no executables, surface that as a likely
   `add_executable` issue in the user's `CMakeLists.txt`.

## Outputs

- `<build>/` populated with CMake artifacts and the user's compiled
  binary(ies).

## Failure modes

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `no src/CMakeLists.txt` | Workspace has no source yet. | Run `/geant4-claude:geant4-example` for a starter, or bring your own `main.cc` + `CMakeLists.txt`. |
| `Could not find a package configuration file provided by "Geant4"` | `find_package(Geant4 …)` is missing or misspelled. | Inspect `src/CMakeLists.txt`; mirror the example at `${CLAUDE_PLUGIN_ROOT}/templates/example/src/CMakeLists.txt`. |
| `error: ‘FTFP_BERT.hh’ file not found` | Header not in include path. | The container's `find_package(Geant4)` brings the Geant4 includes in; check for typos and `include(${Geant4_USE_FILE})`. |
| Build succeeds but no executable | No `add_executable` directive. | Add it to `src/CMakeLists.txt` and rebuild. |
| Linker undefined references to `ROOT::*` | `find_package(ROOT …)` missing or wrong components. | Add `find_package(ROOT REQUIRED COMPONENTS Tree RIO)` and link `ROOT::Core ROOT::RIO ROOT::Tree`. |

## Notes

- `./build/` is gitignored by the workspace `.gitignore` shipped by
  `/geant4-claude:geant4-init`.
- This command is idempotent. CMake's incremental builds rebuild only
  what changed; pass `--clean` for a from-scratch rebuild.
- Need a different toolchain or extra cmake flags? Use
  `g4run shell` to enter the container, then run `cmake` by hand —
  this command intentionally stays minimal.
