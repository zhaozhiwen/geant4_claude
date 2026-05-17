# Design: optical-photon support, orchestrator ordering, run-status fix

Date: 2026-05-17
Status: approved, ready for implementation plan

## Origin

Post-dogfooding feedback. Four items were proposed; the user selected
items 1, 2, 3, 4 and rejected item 5 (shared `config.json` rindex band —
too restrictive, and moot once RINDEX lives only in GDML).

Architectural decision by the user during brainstorming: **load-bearing
C++ is regenerated, not shipped as a frozen template**, because that is
the only way to stay flexible for arbitrary future projects. The
re-introduction-of-bugs risk is mitigated not by version-controlling the
main, but by a vetted, copy-pasteable recipe that every regeneration
follows.

## Goals

1. Make an optical-photon (Cherenkov / scintillation) simulation work
   end-to-end through the plugin without silent zero-photon failures.
2. Make the orchestrator drive the slash commands in their documented
   order, including `geant4-validate`, and explicitly report whenever it
   improvises around a command.
3. Fix run-status capture in `geant4-run` so a failed run can never be
   reported as success.

Non-goal: a `--physics-list` flag on a generic main; a committed optical
template; the shared-config rindex band (item 5).

## Item 1 + 2 — optical-aware geometry, RINDEX gate, regeneration recipe

### Why the obvious approaches fail

GDML alone cannot produce a working Cherenkov sim. Three things are
required; only the first is GDML's job:

1. `RINDEX` matrix on the radiator material — GDML.
2. `G4OpticalPhysics` registered — C++ only. The generic
   `geant4_claude_main.cc` hard-codes `FTFP_BERT`.
3. A photon-aware sensitive detector — C++ only. The generic
   `GenericSD::ProcessHits` returns `false` when
   `edep <= 0`. Optical photons deposit ~0 energy, so that early return
   discards **every** optical photon. Recording photons requires
   *inverting* the hit condition (record on photon arrival at the
   backplate, not on energy deposit) — a ~30-line replacement, not an
   additive patch.

Because the C++ change is a replacement, not an addition, a mechanical
in-command `Edit` patch is fragile. The mitigation is a single vetted
recipe (below) that the regeneration follows.

### `commands/geant4-detector.md` — optical-aware GDML + RINDEX gate

On a spec that mentions Cherenkov / scintillation / optical photons (or
an explicit `--optical`):

- Write the radiator material's refractive index as a
  `<matrix name="<mat>_RINDEX" coldim="2" values="… *eV …"/>` plus a
  `<property name="RINDEX" ref="<mat>_RINDEX"/>` on the material. Use the
  explicit `*eV` unit form (clearer than bare-MeV internal units;
  `scripts/validators/cherenkov.py` already parses both via
  `parse_energy_eV`).
- Add a downstream sensitive backplate volume, placed *after* the
  radiator along the beam axis, never inside or face-overlapping it
  (reuse the existing geometry-sanity logic in the command / orchestrator
  geometry gates).
- **RINDEX gate (item 2):** if the spec is optical and any radiator
  material the command marks has no RINDEX matrix, the command does
  **not** declare success. It stops and names the exact material missing
  RINDEX. Rationale: a zero-photon run can never be created in the first
  place — strictly stronger than a runtime warning before `beamOn`.

### `skills/geant4-physics-list/SKILL.md` — the optical main recipe

New section: a concrete, copy-pasteable recipe so every regeneration of
the optical main converges on the same correct code rather than a fresh
guess.

- Physics list:
  `auto* p = new FTFP_BERT(0); p->RegisterPhysics(new G4OpticalPhysics());`
  passed to `runManager->SetUserInitialization(p);`.
- A **photon-aware SD** replacing `GenericSD`'s `edep > 0` logic: record
  one row per optical photon (`pdg == -22`) arriving at the sensitive
  backplate. The SD writes the **same `Hits` TTree** the generic main
  writes (`event/I`, `volume/C`, `edep/D`, `x/y/z/t /D`, `pdg/I`), with
  `pdg = -22` and `edep` left 0 for photon rows.
- The ~10-line runtime RINDEX guard: before `beamOn`, if
  `G4OpticalPhysics` is registered, a sensitive volume exists, and no
  material in the built table carries a RINDEX property, emit one loud
  `G4cerr` line. Defense-in-depth for the case where the optical main is
  pointed at GDML that did **not** come from `geant4-detector`. Included
  in the recipe so every regenerated main carries it.
- The recipe restates the existing init-order contract (do not call
  `runManager->Initialize()` before the macro; the macro owns
  `/run/initialize`).

### Output schema decision

The optical main writes the **same `Hits` TTree** as the generic main,
with optical photons stored as per-hit rows where `pdg == -22`.

Rationale: `geant4-validate cherenkov` then runs with **zero extra
flags** — its filtered-mode defaults are exactly
`--event-branch event --pdg-branch pdg --photon-pdg -22`. A custom
per-event schema would force `--tree Events --count-branch n_photons`
and break `geant4-analyze`'s canned `Hits` plots. This shared schema is
the seam that lets the orchestrator chain run → analyze → validate with
no per-step flag wrangling.

### `commands/geant4-example.md`

No `--optical` flag, no optical template to drop. Unchanged. The optical
main is produced by regenerating `src/main.cc` from the recipe, which is
the orchestrator's "hand-write `src/main.cc`" branch (see item 3).

## Item 3 — orchestrator ordering and improvisation reporting

`skills/geant4/SKILL.md`:

- Default flow gains a closure step:
  `… → run → analyze → validate`. The Step 2 plan template gets a step:
  `/geant4-claude:geant4-validate cherenkov runs/<id> --rindex-from-gdml
  geometries/<name>.gdml --rindex-material <mat> --radiator-length <L>`
  whenever the spec has an analytic prediction (Cherenkov is the v1
  case). Step 3 post-conditions gain:
  `validate → runs/<id>/validate_<topic>.json exists; PASS/FAIL reported
  verbatim`.
- The "optical photons → BYO hand-written main" branch stays, but now
  points at the `geant4-physics-list` optical recipe instead of
  "improvise." HP neutrons and non-`Hits` schemas still force BYO.
- New explicit rule, verbatim intent: *"Use the slash commands in their
  documented order. If you cannot use a command as documented and must
  improvise — hand-write what a command would generate, skip a step, or
  work around a failure — say so to the user explicitly: name the command
  you bypassed, what you did instead, and why. Never silently substitute
  your own approach for a documented command."* This makes the optical
  regeneration (which bypasses the canned `geant4-example` main) a
  reported event, not a silent one.
- `commands/geant4-validate.md` added to the skill's cross-references
  list.

## Item 4 — robust run-status capture in `geant4-run`

`commands/geant4-run.md` step 5 currently captures
`STATUS=${PIPESTATUS[0]}` after `… | tee log.txt`. Under a tcsh-login
shell with the subshell wrapper, `PIPESTATUS` came back empty in the
field, which would let a failed run be reported as success (the
non-zero-status branch in step 8 would never fire).

Replace with a shell-agnostic sentinel file written **outside** the
immutable run dir:

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

No `PIPESTATUS` / `pipefail` dependency; does not touch the run dir
(keeps it immutable per the command's own convention); defaults to a
failure status if the sentinel is unreadable.

## Testing

`tests/clean-smoke.sh` has no Claude, so it cannot exercise a
model-regenerated optical main. It can deterministically cover the rest
of the optical chain:

- Ship a tiny **fixture** optical main under `tests/` (not `templates/` —
  it is not user-facing and must not be discoverable as a plugin
  artifact).
- Smoke path: `geant4-detector` (optical spec) → build the fixture →
  run → `geant4-validate cherenkov` returns PASS on a fresh clone.

This catches the GDML emission, the RINDEX gate, and the validator
chain. The recipe's C++ correctness is covered by
`tests/CLEAN-INSTALL-CHECKLIST.md` (manual), since only a real Claude
session regenerates the main.

## Affected files

| File | Change |
|------|--------|
| `commands/geant4-detector.md` | Optical-aware GDML path + RINDEX gate + `--optical` |
| `skills/geant4-physics-list/SKILL.md` | New optical-main recipe section |
| `skills/geant4/SKILL.md` | validate in flow; ordering/improvisation rule; recipe pointer; cross-ref |
| `commands/geant4-run.md` | Sentinel-file run-status capture |
| `tests/clean-smoke.sh` | Optical chain via a `tests/` fixture main |
| `tests/` (new fixture) | Minimal optical main for the smoke path |
| `docs/DESIGN.md` | Reflect the new optical flow + validate-in-orchestrator |
| `tests/CLEAN-INSTALL-CHECKLIST.md` | Manual step for recipe-regenerated optical main |

## Out of scope

Item 5 (shared `config.json` rindex band). Rejected as too restrictive.
Moot anyway: RINDEX now lives only in the GDML, and the validator reads
it via `--rindex-from-gdml`, so the C++ and the analytic calculation
already share one source.
