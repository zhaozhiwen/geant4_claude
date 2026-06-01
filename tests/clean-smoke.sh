#!/usr/bin/env bash
# tests/clean-smoke.sh — plumbing smoke test for geant4_claude.
#
# Exercises bin/g4run + the workspace/example templates against a sandboxed
# CLAUDE_PLUGIN_DATA. Does NOT go through Claude Code, so it does not test
# slash-command dispatch, the SessionStart hook, MCP approval, or
# AskUserQuestion — see tests/CLEAN-INSTALL-CHECKLIST.md for the manual
# flow that covers those.
#
# Usage:
#   tests/clean-smoke.sh
#       Fresh state. May pull the pinned image (~600 MB) on first run.
#
#   G4C_REUSE_SIF=/path/to/<sif-from: bin/g4run sif-name> tests/clean-smoke.sh
#       Symlinks an existing .sif into the sandbox to skip the pull.
#       Useful for fast iteration; doesn't compromise the test (every
#       other path is sandboxed).
#
# Requires: apptainer, curl OR wget, tar, bash >= 4.
# Optional: python3 with uproot+numpy+matplotlib. Without them the analyze
# fast-path verification is skipped (the rest still runs).

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIF_NAME="$("${PLUGIN_ROOT}/bin/g4run" sif-name)"

# --- helpers ----------------------------------------------------------------
log()  { printf '\n--- %s ---\n' "$*"; }
fail() { printf '\n[FAIL] %s\n' "$*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 not found on PATH"
}

require bash
require apptainer
require tar
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 \
  || fail "neither curl nor wget on PATH"

# --- sandbox ----------------------------------------------------------------
SCRATCH=$(mktemp -d -t g4c-smoke.XXXXXX)
KEEP_ON_FAIL=1
cleanup() {
  local rc=$?
  if [[ $rc -ne 0 && $KEEP_ON_FAIL -eq 1 ]]; then
    printf '\n[smoke] preserved scratch for inspection: %s\n' "${SCRATCH}" >&2
  else
    rm -rf "${SCRATCH}"
  fi
}
trap cleanup EXIT

CLAUDE_PLUGIN_ROOT="${PLUGIN_ROOT}"
CLAUDE_PLUGIN_DATA="${SCRATCH}/data"
mkdir -p "${CLAUDE_PLUGIN_DATA}/cache/sif"

if [[ -n "${G4C_REUSE_SIF:-}" && -f "${G4C_REUSE_SIF}" ]]; then
  log "reusing .sif: ${G4C_REUSE_SIF}"
  ln -s "${G4C_REUSE_SIF}" \
    "${CLAUDE_PLUGIN_DATA}/cache/sif/${SIF_NAME}"
fi

g4run() {
  GEANT4_CLAUDE_CACHE="${CLAUDE_PLUGIN_DATA}/cache" \
  CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}" \
  CLAUDE_PLUGIN_DATA="${CLAUDE_PLUGIN_DATA}" \
    "${PLUGIN_ROOT}/bin/g4run" "$@"
}

# --- phase 0: exit-capture unit test ---------------------------------------
log "exit-capture: sentinel-file pattern unit test"
bash "${PLUGIN_ROOT}/tests/exit-capture-test.sh" \
  || fail "exit-capture-test.sh failed"

# --- phase 0b: optical recipe ↔ fixture drift gate -------------------------
log "recipe-sync: OpticalSD in skill must match the CI fixture verbatim"
fixture_sd="$(sed -n '/class OpticalSD/,/^};/p' "${PLUGIN_ROOT}/tests/fixtures/optical/main.cc")"
recipe_sd="$(sed -n '/class OpticalSD/,/^};/p' "${PLUGIN_ROOT}/skills/geant4-physics-list/SKILL.md")"
[ -n "${fixture_sd}" ] || fail "phase 0b: OpticalSD block not found in tests/fixtures/optical/main.cc — anchor broke"
[ -n "${recipe_sd}" ] || fail "phase 0b: OpticalSD block not found in skills/geant4-physics-list/SKILL.md — anchor broke"
if [ "${fixture_sd}" != "${recipe_sd}" ]; then
  fail "OpticalSD drifted between tests/fixtures/optical/main.cc and skills/geant4-physics-list/SKILL.md — re-sync them"
fi

# --- phase 0c: g4run pure-bash unit tests ----------------------------------
log "g4run-unit: path containment + tag accessors"
bash "${PLUGIN_ROOT}/tests/g4run-unit-test.sh" \
  || fail "g4run-unit-test.sh failed"

# --- phase 0d: skills must stay CLI-neutral (Claude + Codex) ----------------
# Skills are the one surface both CLIs run. A CLAUDE_* env ref or a
# /geant4-claude: slash-command name breaks the Codex path. geant4-init is the
# ONE exception: as the keystone that *writes* .g4c/, it must read the
# CLI-native plugin-root env ($CLAUDE_PLUGIN_ROOT) to resolve the plugin root.
# Every other skill reads .g4c/ and stays neutral. Slash refs are banned anywhere.
log "cli-neutral: no CLAUDE_* env (outside geant4-init) in skills/"
if git -C "${PLUGIN_ROOT}" grep -nE "CLAUDE_PLUGIN" -- skills/ ':!skills/geant4-init/' >/dev/null 2>&1; then
  git -C "${PLUGIN_ROOT}" grep -nE "CLAUDE_PLUGIN" -- skills/ ':!skills/geant4-init/'
  fail "skills/ (outside geant4-init) references CLAUDE_* env — read .g4c/env instead"
fi
log "cli-neutral: no /geant4-claude: slash refs anywhere in skills/"
if git -C "${PLUGIN_ROOT}" grep -nE "/geant4-claude:" -- skills/ >/dev/null 2>&1; then
  git -C "${PLUGIN_ROOT}" grep -nE "/geant4-claude:" -- skills/
  fail "skills/ contains /geant4-claude: slash-command refs"
fi

# --- phase 0e: ensure_venv.sh honors GEANT4_CLAUDE_VENV, no CLAUDE_* env -----
# The venv is workspace-rooted: ensure_venv must build at GEANT4_CLAUDE_VENV
# (set by .g4c/env), write its snapshot INSIDE the venv, and not touch the
# shared GEANT4_CLAUDE_DATA dir (now just the standalone venv fallback base).
log "ensure-venv: builds at GEANT4_CLAUDE_VENV (workspace), no CLAUDE_* env"
EV_DATA="${SCRATCH}/ev-data"
EV_VENV="${SCRATCH}/ev-ws/venv"
if env -u CLAUDE_PLUGIN_ROOT -u CLAUDE_PLUGIN_DATA \
     GEANT4_CLAUDE_ROOT="${PLUGIN_ROOT}" GEANT4_CLAUDE_DATA="${EV_DATA}" \
     GEANT4_CLAUDE_VENV="${EV_VENV}" \
     bash "${PLUGIN_ROOT}/scripts/ensure_venv.sh" >/dev/null 2>&1; then
  [ -x "${EV_VENV}/bin/python" ] \
    || fail "ensure_venv.sh did not create the venv at GEANT4_CLAUDE_VENV"
  [ -f "${EV_VENV}/requirements.snapshot" ] \
    || fail "ensure_venv.sh did not write the snapshot inside the venv"
  [ ! -e "${EV_DATA}/venv" ] \
    || fail "ensure_venv.sh built under GEANT4_CLAUDE_DATA; must honor GEANT4_CLAUDE_VENV"
else
  log "ensure-venv: SKIPPED venv creation (no uv/python3 venv support here)"
fi

# --- phase 0e2: ensure_venv self-heals a missing interpreter (stale snapshot) -
# The idempotency check must gate on the venv python existing, not just the
# requirements snapshot. If the snapshot survives but the venv is gone, a
# rebuild must still happen — otherwise analyze/preview/validate hit a dead python.
if [ -x "${EV_VENV}/bin/python" ]; then
  log "ensure-venv: rebuilds when snapshot matches but venv python is gone"
  rm -rf "${EV_VENV}/bin"   # snapshot (inside the venv) stays behind
  env -u CLAUDE_PLUGIN_ROOT -u CLAUDE_PLUGIN_DATA \
    GEANT4_CLAUDE_ROOT="${PLUGIN_ROOT}" GEANT4_CLAUDE_DATA="${EV_DATA}" \
    GEANT4_CLAUDE_VENV="${EV_VENV}" \
    bash "${PLUGIN_ROOT}/scripts/ensure_venv.sh" >/dev/null 2>&1 || true
  [ -x "${EV_VENV}/bin/python" ] \
    || fail "ensure_venv.sh did not rebuild a venv whose python was removed (stale-snapshot bug)"
fi

# --- phase 0f: strict-YAML frontmatter lint (Codex silent-load guard) --------
# Codex parses SKILL.md frontmatter with a strict YAML parser; a colon-space in
# an unquoted description silently drops the whole skill. Guard every skill.
log "frontmatter: every SKILL.md parses under strict YAML"
fm_rc=0; python3 "${PLUGIN_ROOT}/tests/lint-skill-frontmatter.py" >/dev/null 2>&1 || fm_rc=$?
case "${fm_rc}" in
  0) ;;
  2) log "frontmatter: SKIPPED (PyYAML not installed)";;
  *) python3 "${PLUGIN_ROOT}/tests/lint-skill-frontmatter.py" || true
     fail "a SKILL.md frontmatter block is not strict-YAML clean (breaks Codex skill load)";;
esac

# --- phase 0g: CLAUDE.md ↔ AGENTS.md single-source invariant -----------------
log "agents-mirror: every CLAUDE.md is a symlink → its canonical AGENTS.md"
bash "${PLUGIN_ROOT}/tests/lint-agents-mirror.sh" >/dev/null 2>&1 \
  || { bash "${PLUGIN_ROOT}/tests/lint-agents-mirror.sh" || true
       fail "CLAUDE.md/AGENTS.md mirror invariant broken"; }

# --- phase 0h: .g4c/ engine pointer resolves bin/g4run live (Design X) -------
# Run geant4-init's actual step-5 recipe (extracted from SKILL.md, so no drift)
# and assert the shim resolves the wrapper via the live env AND via the recorded
# fallback — a plugin version bump must never strand an initialized workspace.
log "g4c-resolve: .g4c shim resolves the wrapper live + via recorded fallback"
g4c_recipe="$(awk '
  /^[[:space:]]*```bash/ {buf=""; inblk=1; next}
  /^[[:space:]]*```/ && inblk {if (buf ~ /cat > \.g4c\/env/) {printf "%s", buf; exit} inblk=0; next}
  inblk {buf = buf $0 "\n"}
' "${PLUGIN_ROOT}/skills/geant4-init/SKILL.md" | sed 's/^   //')"
[ -n "${g4c_recipe}" ] || fail "phase 0h: could not extract the .g4c/ recipe from geant4-init/SKILL.md"
G4C_WS="${SCRATCH}/g4c-ws"; mkdir -p "${G4C_WS}"
( cd "${G4C_WS}" && eval "${g4c_recipe}" ) || fail "phase 0h: the .g4c/ recipe failed to run"
[ -x "${G4C_WS}/.g4c/g4run" ] || fail "phase 0h: .g4c/g4run shim not created/executable"
exp_tag="$("${PLUGIN_ROOT}/bin/g4run" image-tag)"
got=$(cd "${G4C_WS}" && env CLAUDE_PLUGIN_ROOT="${PLUGIN_ROOT}" sh -c '. .g4c/env; .g4c/g4run image-tag')
[ "${got}" = "${exp_tag}" ] || fail "phase 0h: shim did not resolve via live CLAUDE_PLUGIN_ROOT (got '${got}')"
got=$(cd "${G4C_WS}" && env -u CLAUDE_PLUGIN_ROOT CODEX_HOME="${SCRATCH}/no-codex" sh -c '. .g4c/env; .g4c/g4run image-tag')
[ "${got}" = "${exp_tag}" ] || fail "phase 0h: shim recorded-fallback did not resolve (got '${got}')"
# .g4c/env exports a project-rooted venv (walked up to the .g4c/ marker).
got=$(cd "${G4C_WS}" && env CLAUDE_PLUGIN_ROOT="${PLUGIN_ROOT}" sh -c '. .g4c/env; echo "$GEANT4_CLAUDE_VENV"')
[ "${got}" = "${G4C_WS}/venv" ] || fail "phase 0h: .g4c/env GEANT4_CLAUDE_VENV != <project>/venv (got '${got}')"
# Two-tier linchpin: the flow-skill walk-up preamble resolves the engine from a
# TASK SUBDIR by walking up to the project's .g4c/.
mkdir -p "${G4C_WS}/task/deep"
got=$(cd "${G4C_WS}/task/deep" && env CLAUDE_PLUGIN_ROOT="${PLUGIN_ROOT}" sh -c '
  G4C="$PWD"; while [ "$G4C" != "/" ] && [ ! -d "$G4C/.g4c" ]; do G4C="$(dirname "$G4C")"; done
  [ -f "$G4C/.g4c/env" ] && . "$G4C/.g4c/env"; G4RUN="${G4RUN:-$G4C/.g4c/g4run}"
  "$G4RUN" image-tag')
[ "${got}" = "${exp_tag}" ] || fail "phase 0h: walk-up preamble did not resolve from a task subdir (got '${got}')"

# --- phase 1: project + task scaffold (two-tier) ---------------------------
# geant4-init scaffolds the PROJECT (project docs + shared .g4c/); geant4-task
# creates each task subdir from templates/workspace. The smoke renders both
# tiers directly (it doesn't run the skills) and runs the flow inside the task.
log "init: project docs (templates/AGENTS.md, log.md) + shared .g4c/ marker"
PROJECT="${SCRATCH}/proj"
mkdir -p "${PROJECT}/.g4c"
cp "${PLUGIN_ROOT}/templates/AGENTS.md" "${PLUGIN_ROOT}/templates/log.md" "${PROJECT}/"
( cd "${PROJECT}" && ln -sfn AGENTS.md CLAUDE.md )
[ -f "${PROJECT}/AGENTS.md" ] || fail "project AGENTS.md missing"
[ -f "${PROJECT}/log.md" ]    || fail "project log.md missing"
[ -L "${PROJECT}/CLAUDE.md" ] || fail "project CLAUDE.md symlink missing"

log "task: copy task skeleton from templates/workspace/ into a task subdir"
WS="${PROJECT}/task-smoke"
mkdir -p "${WS}" && cd "${WS}"
cp -r "${PLUGIN_ROOT}/templates/workspace/." .
[ -f CLAUDE.md ]   || fail "task CLAUDE.md missing"
[ -f .gitignore ]  || fail "task .gitignore missing"
for d in src geometries macros runs analysis; do
  [ -d "$d" ] || fail "task skeleton missing $d/"
done
# the task .gitignore must NOT carry the shared-engine entries (project-level now)
grep -qxE '\.g4c/|cache/|venv/' .gitignore \
  && fail "task .gitignore should not list .g4c/ cache/ venv/ (those are project-level)" || true

log "init: pull pinned image (skipped if .sif already present)"
g4run pull
[ -f "${CLAUDE_PLUGIN_DATA}/cache/sif/${SIF_NAME}" ] \
  || fail ".sif missing after pull"

# --- phase 2: example flow --------------------------------------------------
log "example: copy demo on top of skeleton"
cp -r "${PLUGIN_ROOT}/templates/example/." .
[ -f src/geant4_claude_main.cc ] || fail "templates/example/src/main missing"
[ -f src/CMakeLists.txt ]        || fail "templates/example/src/CMakeLists.txt missing"
[ -f geometries/example.gdml ]   || fail "templates/example/geometries/example.gdml missing"
[ -f macros/run.mac ]            || fail "templates/example/macros/run.mac missing"
[ -f analysis/example.py ]       || fail "templates/example/analysis/example.py missing"

log "example: validate GDML"
g4run validate-gdml geometries/example.gdml >/dev/null
log "example: validate-gdml tolerates a quote in the filename (F4 regression)"
cp geometries/example.gdml "geometries/wei'rd.gdml"
g4run validate-gdml "geometries/wei'rd.gdml" >/dev/null \
  || fail "validate-gdml broke on an apostrophe in the filename"
rm -f "geometries/wei'rd.gdml"

log "example: build"
g4run build src build
[ -x build/geant4_claude_main ] || fail "build/geant4_claude_main not produced"

log "example: run"
RUN_ID="$(date -u +%Y%m%d-%H%M%S)-smoke"
RUN_DIR="${WS}/runs/${RUN_ID}"
mkdir -p "${RUN_DIR}"
g4run exec ./build/geant4_claude_main \
  geometries/example.gdml macros/run.mac "${RUN_DIR}/hits.root" \
  > "${RUN_DIR}/log.txt" 2>&1
[ -s "${RUN_DIR}/hits.root" ] || fail "hits.root not produced or empty"
grep -q "run ended" "${RUN_DIR}/log.txt" \
  || fail "log.txt missing end-of-run banner"

# --- phase 3: example analyze fast-path (needs python+uproot) --------------
if python3 -c "import uproot, numpy, matplotlib" 2>/dev/null; then
  log "analyze: schema check (Hits TTree with expected branches)"
  python3 - "${RUN_DIR}/hits.root" <<'PY' || exit 1
import sys, uproot
with uproot.open(sys.argv[1]) as f:
    keys = {k.split(";")[0] for k in f.keys()}
    assert "Hits" in keys, f"Hits TTree missing; got {keys}"
    branches = set(f["Hits"].keys())
    need = {"event", "volume", "edep", "x", "y", "z", "t", "pdg"}
    missing = need - branches
    assert not missing, f"branches missing from Hits: {missing}"
print("schema ok")
PY

  log "analyze: run example.py (fast-path)"
  python3 analysis/example.py "${RUN_DIR}"
  [ -f "${RUN_DIR}/edep_hist.png" ] || fail "analyze did not produce edep_hist.png"

  # --- phase 4: custom-schema routing ---
  log "custom: synthesize Tracks TTree, verify it routes off the fast-path"
  CUSTOM_RUN="${WS}/runs/${RUN_ID}-custom"
  mkdir -p "${CUSTOM_RUN}"
  python3 - "${CUSTOM_RUN}/output.root" <<'PY' || exit 1
import sys, numpy as np, uproot
rng = np.random.default_rng(42)
n = 200
data = {
    "px":     rng.normal(0, 100, n),
    "py":     rng.normal(0, 100, n),
    "pz":     rng.normal(1000, 50, n),
    "n_hits": rng.integers(1, 20, n).astype(np.int32),
}
with uproot.recreate(sys.argv[1]) as f:
    f["Tracks"] = data
PY

  python3 - "${CUSTOM_RUN}/output.root" <<'PY' || exit 1
import sys, uproot
with uproot.open(sys.argv[1]) as f:
    keys = {k.split(";")[0] for k in f.keys()}
    assert "Tracks" in keys, f"Tracks missing; got {keys}"
    assert "Hits" not in keys, "fast-path would incorrectly trigger"
print("custom-schema correctly distinct from example fast-path")
PY
else
  log "analyze: SKIPPED — host lacks uproot+numpy+matplotlib"
  log "         install uproot numpy matplotlib into a venv (not --user)"
fi

# --- phase 4b: optical-photon chain (fixture, not a user template) ----------
log "optical: build fixture optical main"
OPT="${SCRATCH}/opt"
mkdir -p "${OPT}/src"
cp "${PLUGIN_ROOT}/tests/fixtures/optical/main.cc"       "${OPT}/src/main.cc"
cp "${PLUGIN_ROOT}/tests/fixtures/optical/CMakeLists.txt" "${OPT}/src/CMakeLists.txt"
cp "${PLUGIN_ROOT}/tests/fixtures/optical/radiator.gdml"  "${OPT}/radiator.gdml"
cp "${PLUGIN_ROOT}/tests/fixtures/optical/run.mac"        "${OPT}/run.mac"
cd "${OPT}"
g4run validate-gdml radiator.gdml >/dev/null
g4run build src build
[ -x build/g4c_optical_fixture ] || fail "optical fixture binary not produced"

log "optical: run fixture"
OPT_RUN="${OPT}/runs/opt"
mkdir -p "${OPT_RUN}"
g4run exec ./build/g4c_optical_fixture \
  radiator.gdml run.mac "${OPT_RUN}/hits.root" \
  > "${OPT_RUN}/log.txt" 2>&1
[ -s "${OPT_RUN}/hits.root" ] || fail "optical hits.root not produced or empty"

if python3 -c "import uproot, numpy" 2>/dev/null; then
  # Closure is a deterministic gate: fixed RNG seed (run.mac) + pinned
  # container image ⇒ a fixed sigma, not a resample. The ~1.4% observed
  # excess over Frank-Tamm is the expected delta-ray Cherenkov excess;
  # do NOT widen --tolerance-sigma or raise event count to "fix" it
  # (raising events shrinks sigma and makes the fixed bias FAIL).
  log "optical: Frank-Tamm closure via cherenkov validator"
  python3 "${PLUGIN_ROOT}/scripts/validators/cherenkov.py" \
    "${OPT_RUN}" \
    --radiator-length 1m \
    --rindex-from-gdml "${OPT}/radiator.gdml" \
    --rindex-material CO2gas \
    --beam-beta 1.0 \
    --wavelength-min 200nm \
    --wavelength-max 800nm \
    || fail "cherenkov closure FAILed on the optical fixture"
  [ -f "${OPT_RUN}/validate_cherenkov.json" ] \
    || fail "validate_cherenkov.json not written"
else
  log "optical: closure SKIPPED — host lacks uproot+numpy"
fi
cd "${WS}"

# --- phase 5: idempotency — pull again, .sif must not change ---------------
log "idempotency: re-pull (must not modify the .sif)"
sif="${CLAUDE_PLUGIN_DATA}/cache/sif/${SIF_NAME}"
sif_before=$(stat -c%Y -L "${sif}")
g4run pull
sif_after=$(stat -c%Y -L "${sif}")
[ "${sif_before}" = "${sif_after}" ] || fail "re-pull modified .sif mtime"

# --- phase 6: workspace-rooted cache resolution (marker walk) ---------------
# With no GEANT4_CLAUDE_CACHE override, g4run walks up from $PWD to the .g4c/
# marker and anchors the cache at <root>/cache; with no marker it falls back to
# $PWD/cache. (No env no longer means "die" — the cache is workspace-rooted.)
log "cache: bare g4run resolves <project-root>/cache via the .g4c/ marker"
WSR="${SCRATCH}/wsroot"; mkdir -p "${WSR}/.g4c" "${WSR}/proj/deep"
info_out=$(cd "${WSR}/proj/deep" && env -i HOME="${HOME}" PATH="${PATH}" \
            "${PLUGIN_ROOT}/bin/g4run" info 2>&1)
got=$(printf '%s\n' "${info_out}" | awk '/^cache:/{print $2}')
[ "${got}" = "${WSR}/cache" ] \
  || fail "cache did not resolve to the .g4c/ marker dir; got '${got}', want '${WSR}/cache'"
printf '%s\n' "${info_out}" | grep -qF '[project (<root>/cache)]' \
  || fail "cache info not tagged [project (<root>/cache)]"
# No marker up-tree -> $PWD/cache fallback (bare clone), still no error.
BARE="${SCRATCH}/bare"; mkdir -p "${BARE}"
got=$(cd "${BARE}" && env -i HOME="${HOME}" PATH="${PATH}" \
        "${PLUGIN_ROOT}/bin/g4run" info 2>&1 | awk '/^cache:/{print $2}')
[ "${got}" = "${BARE}/cache" ] \
  || fail "bare-dir cache fallback should be \$PWD/cache; got '${got}'"

# --- phase 6b: image-tag single-source check -------------------------------
# CLAUDE.md non-negotiable: the tag lives in bin/g4run only. Static docs that
# DISPLAY it (README, Pages config) must match it; CHANGELOG/design history is
# point-in-time and intentionally NOT checked here.
log "tag-sync: README + docs/_config.yml must match g4run's pinned tag"
want_tag="$("${PLUGIN_ROOT}/bin/g4run" image-tag)"
grep -qF "${want_tag}" "${PLUGIN_ROOT}/README.md" \
  || fail "README.md does not display g4run's pinned image tag (${want_tag})"
grep -qF "${want_tag}" "${PLUGIN_ROOT}/docs/_config.yml" \
  || fail "docs/_config.yml image_tag != g4run's pinned tag (${want_tag})"

# --- phase 7: leakage scan --------------------------------------------------
# Hard-block: the actual user's home path slipping into committed files. Scan
# git-TRACKED files only — an untracked local scratch file (e.g. a maintainer's
# BUILD_LOG.md) is not a leak, won't exist on a fresh clone, and must not fail
# CI. .git/ and gitignored content are excluded for free by ls-files. JLab
# hostnames / shared-FS paths are softer — they
# sometimes legitimately appear in CHANGELOG/CLAUDE.md as bug-fix narrative;
# that's pre-publish manual review territory, not a unit test.
log "leakage: scan tracked files for /home/${USER}"
strays=$(git -C "${PLUGIN_ROOT}" grep -Il -e "/home/${USER}" -- \
           ':!tests/clean-smoke.sh' 2>/dev/null || true)
if [ -n "${strays}" ]; then
  echo "leaks found in tracked files:"
  echo "${strays}"
  fail "leakage scan failed — replace with /home/\$USER placeholder"
fi

log "✓ all smoke checks passed"
KEEP_ON_FAIL=0
