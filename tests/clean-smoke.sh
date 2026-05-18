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
#   G4C_REUSE_SIF=/path/to/g4install_11.4.0-almalinux-9.4.sif tests/clean-smoke.sh
#       Symlinks an existing .sif into the sandbox to skip the pull.
#       Useful for fast iteration; doesn't compromise the test (every
#       other path is sandboxed).
#
# Requires: apptainer, curl OR wget, tar, bash >= 4.
# Optional: python3 with uproot+numpy+matplotlib. Without them the analyze
# fast-path verification is skipped (the rest still runs).

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

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
    "${CLAUDE_PLUGIN_DATA}/cache/sif/g4install_11.4.0-almalinux-9.4.sif"
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

# --- phase 1: init equivalent ----------------------------------------------
log "init: copy workspace skeleton from templates/workspace/"
WS="${SCRATCH}/ws"
mkdir -p "${WS}" && cd "${WS}"
cp -r "${PLUGIN_ROOT}/templates/workspace/." .
[ -f CLAUDE.md ]   || fail "workspace/CLAUDE.md missing"
[ -f .gitignore ]  || fail "workspace/.gitignore missing"
for d in src geometries macros runs analysis; do
  [ -d "$d" ] || fail "workspace skeleton missing $d/"
done

log "init: pull pinned image (skipped if .sif already present)"
g4run pull
[ -f "${CLAUDE_PLUGIN_DATA}/cache/sif/g4install_11.4.0-almalinux-9.4.sif" ] \
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
  log "         install with: pip install --user uproot numpy matplotlib"
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
sif="${CLAUDE_PLUGIN_DATA}/cache/sif/g4install_11.4.0-almalinux-9.4.sif"
sif_before=$(stat -c%Y -L "${sif}")
g4run pull
sif_after=$(stat -c%Y -L "${sif}")
[ "${sif_before}" = "${sif_after}" ] || fail "re-pull modified .sif mtime"

# --- phase 6: cache-resolution loud-fail check ------------------------------
log "cache: bare g4run (no env) must error, not fall back to \$HOME/.geant4_claude"
if env -i HOME="${HOME}" PATH="${PATH}" "${PLUGIN_ROOT}/bin/g4run" info >/tmp/g4c_smoke_info.out 2>&1; then
  fail "g4run info succeeded with no env vars set; should have errored"
fi
grep -q "no cache path" /tmp/g4c_smoke_info.out \
  || fail "wrong error message; expected 'no cache path'. Got:
$(cat /tmp/g4c_smoke_info.out)"
rm -f /tmp/g4c_smoke_info.out

# --- phase 7: leakage scan --------------------------------------------------
# Hard-block: the actual user's home path slipping into committed files. Scan
# git-TRACKED files only — an untracked local scratch file (e.g. a maintainer's
# BUILD_LOG.md) is not a leak, won't exist on a fresh clone, and must not fail
# CI. .git/ and gitignored content (wiki/raw/geant4-src/) are excluded for
# free by ls-files. JLab hostnames / shared-FS paths are softer — they
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
