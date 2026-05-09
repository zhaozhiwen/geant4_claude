#!/usr/bin/env bash
# tests/phase-b-drive.sh — drive Phase B (clean Claude Code install) via tmux.
#
# Spawns a sandboxed Claude Code in a tmux session and types the slash
# commands from tests/CLEAN-INSTALL-CHECKLIST.md, then verifies post-
# conditions with Bash assertions. Symlinks the .sif and (if present) the
# Geant4 source tree from the operator's real plugin data dir into the
# sandbox so we don't re-download ~600 MB.
#
# Scope (what this script automates):
#   - Sandbox isolation (HOME= override; real credentials symlinked,
#     ~/.claude.json copied so no re-login or first-run setup).
#   - Plugin install via /plugin marketplace add + /plugin install
#     (handles the user-scope confirmation prompt).
#   - Exit + relaunch claude after install so the SessionStart hook fires
#     and the plugin's pdg venv gets created.
#   - /geant4-claude:geant4-init, including the AskUserQuestion source-
#     clone prompt (picks "Yes" — but with the symlink in place, it
#     detects the existing tree and no-ops).
#   - /geant4-claude:geant4-example, geant4-build, geant4-run, geant4-analyze.
#   - On-disk post-condition checks at each gate (workspace skeleton,
#     binary, run outputs, generic config.json schema, edep plot).
#
# MCP approval: in this script the deepwiki MCP approval doesn't fire
# because we copy the operator's ~/.claude.json into the sandbox, which
# already records the approval. If you wipe ~/.claude.json before running,
# expect a y/n prompt that the script does not currently handle — drive
# Phase B manually via CLEAN-INSTALL-CHECKLIST.md in that case.
#
# What this script does NOT do (run manually if needed):
#   - Phase 5 (custom flow) — needs operator-written src/main.cc.
#   - Phase 6 (idempotency) — re-running for cache invariants is better
#     covered by tests/clean-smoke.sh.
#
# Honest caveat:
#   This script auto-clicks through the deepwiki MCP approval and the
#   /geant4-init AskUserQuestion. That's safe for re-running known flows,
#   but on the *first* run after a release lands an unexpected prompt,
#   you should drive Phase B manually following CLEAN-INSTALL-CHECKLIST.md
#   so a human reviews what's being approved.
#
# Usage:
#   tests/phase-b-drive.sh [SESSION_NAME]
#
#   SESSION_NAME defaults to "g4c_phase_b". The sandbox lives at
#   /tmp/${SESSION_NAME}/ and is removed on success (preserved on failure
#   for inspection).
#
# Requires: tmux, claude (logged in), apptainer, an existing .sif on this
# host. Optional: an existing geant4-src tree (saves a 36 MB tarball
# download).

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESSION="${1:-g4c_phase_b}"
SANDBOX="/tmp/${SESSION}"
SANDBOX_CLAUDE="${SANDBOX}/.claude"
PLUGIN_DATA_SANDBOX="${SANDBOX_CLAUDE}/plugins/data/geant4-claude-geant4-claude"
WS="${SANDBOX}/ws"

# Plugin id format follows Claude Code's <plugin-name>-<marketplace-name> convention.
PLUGIN_ID="geant4-claude-geant4-claude"
SIF_NAME="g4install_11.4.0-almalinux-9.4.sif"

# --- helpers ----------------------------------------------------------------
log()  { printf '\n--- %s ---\n' "$*"; }
note() { printf '    %s\n' "$*"; }
fail() { printf '\n[FAIL] %s\n' "$*" >&2; exit 1; }
require() { command -v "$1" >/dev/null 2>&1 || fail "$1 not on PATH"; }

# Send a string + Enter to the tmux session.
send() {
  tmux send-keys -t "${SESSION}" "$1" Enter
}

# Send a literal key (no Enter) — for arrow keys, y/n, etc.
key() {
  tmux send-keys -t "${SESSION}" "$1"
}

# Capture the bottom of the tmux pane.
pane_tail() {
  tmux capture-pane -t "${SESSION}" -p | tail -"${1:-30}"
}

# Wait until pane contains a literal substring; fail on timeout.
wait_for() {
  local marker="$1" timeout="${2:-60}"
  local i
  for ((i=0; i<timeout; i++)); do
    tmux capture-pane -t "${SESSION}" -p | grep -qF "${marker}" && return 0
    sleep 1
  done
  pane_tail 40
  fail "timeout (${timeout}s) waiting for: ${marker}"
}

# --- prereqs ----------------------------------------------------------------
require tmux
require claude
require apptainer

[ -f ~/.claude/.credentials.json ] \
  || fail "~/.claude/.credentials.json missing — log in to Claude Code first"
[ -f ~/.claude.json ] \
  || fail "~/.claude.json missing — log in to Claude Code at least once first (it stores the post-first-run state needed to skip the theme picker + account selection in the sandbox)"

# Locate a real .sif to symlink (avoid 600 MB pull)
SIF_SRC=""
for cand in \
  "${HOME}/.claude/plugins/data/${PLUGIN_ID}/cache/sif/${SIF_NAME}" \
  "${HOME}/.geant4_claude/sif/${SIF_NAME}" \
  ; do
  [ -f "$cand" ] && { SIF_SRC="$cand"; break; }
done
[ -n "$SIF_SRC" ] || fail "no ${SIF_NAME} found on host. Run /geant4-claude:geant4-init once in real ~/.claude to seed it, then re-run this script."

# Optional: locate a real geant4-src to symlink (avoid 36 MB tarball)
G4SRC_SRC=""
for cand in \
  "${HOME}/.claude/plugins/data/${PLUGIN_ID}/geant4-src" \
  ; do
  [ -d "$cand/source" ] && { G4SRC_SRC="$cand"; break; }
done

# Optional: locate a populated venv to symlink (avoid pdg pip install)
VENV_SRC=""
for cand in \
  "${HOME}/.claude/plugins/data/${PLUGIN_ID}/venv" \
  ; do
  [ -d "$cand/bin" ] && { VENV_SRC="$cand"; break; }
done

# --- sandbox setup ----------------------------------------------------------
log "sandbox: ${SANDBOX}"
rm -rf "${SANDBOX}"
mkdir -p "${SANDBOX_CLAUDE}" "${WS}" "${PLUGIN_DATA_SANDBOX}/cache/sif"

# Why HOME= override (not just CLAUDE_CONFIG_DIR=):
# Claude Code keeps post-first-run state in ~/.claude.json (in $HOME, NOT
# under ~/.claude/). Without that file, a sandboxed instance triggers the
# theme picker + account-type selection. CLAUDE_CONFIG_DIR alone would
# require sharing the operator's real .claude.json, which would let the
# sandbox's plugin install bleed into operator state. HOME override
# isolates both ~/.claude/ and ~/.claude.json under ${SANDBOX}.
#
# Preserve auth + post-first-run state by:
#   - SYMLINK .credentials.json (token refreshes propagate to operator)
#   - COPY .claude.json (sandbox writes don't bleed back)
#   - COPY settings.json (preserves theme/keybindings without sharing writes)
ln -s ~/.claude/.credentials.json "${SANDBOX_CLAUDE}/.credentials.json"
[ -f ~/.claude/settings.json ] && cp ~/.claude/settings.json "${SANDBOX_CLAUDE}/settings.json"
cp ~/.claude.json "${SANDBOX}/.claude.json"

# Symlink .sif into sandboxed plugin data dir (saves the pull).
ln -s "${SIF_SRC}" "${PLUGIN_DATA_SANDBOX}/cache/sif/${SIF_NAME}"
note "linked .sif: ${SIF_SRC}"

if [ -n "${G4SRC_SRC}" ]; then
  ln -s "${G4SRC_SRC}" "${PLUGIN_DATA_SANDBOX}/geant4-src"
  note "linked geant4-src: ${G4SRC_SRC}"
else
  note "geant4-src: no host copy; tarball will download (~36 MB) during init"
fi

if [ -n "${VENV_SRC}" ]; then
  ln -s "${VENV_SRC}" "${PLUGIN_DATA_SANDBOX}/venv"
  note "linked venv: ${VENV_SRC}"
else
  note "venv: no host copy; SessionStart hook will pip install pdg (~10-30 s)"
fi

# --- tmux launch ------------------------------------------------------------
# Helper: launch claude in the sandbox, tolerantly handle the
# workspace-trust dialog (fires only on first launch in a path), and
# wait for the welcome card before returning.
launch_claude() {
  tmux send-keys -t "${SESSION}" \
    "cd '${WS}' && HOME='${SANDBOX}' claude" Enter
  local i pane
  for ((i=0; i<15; i++)); do
    pane=$(tmux capture-pane -t "${SESSION}" -p)
    if printf '%s' "${pane}" | grep -qF "trust this folder"; then
      key Enter   # default option 1: trust
    fi
    if printf '%s' "${pane}" | grep -qF "Welcome"; then
      return 0
    fi
    sleep 1
  done
  pane_tail 30
  fail "claude TUI didn't reach welcome state within 15 s"
}

log "tmux: starting session ${SESSION}"
tmux kill-session -t "${SESSION}" 2>/dev/null || true
tmux new-session -d -s "${SESSION}" -x 200 -y 50

log "phase 0: launch claude (first time in sandbox; trust dialog fires)"
launch_claude
note "✓ TUI ready in sandbox"

# --- phase 1: plugin install ------------------------------------------------
log "phase 1: install plugin via marketplace"
send "/plugin marketplace add zhaozhiwen/geant4_claude"
wait_for "Successfully added marketplace" 60

send "/plugin install geant4-claude@geant4-claude"
# /plugin install pauses on a scope-confirmation prompt. Default option
# (user scope) is right for solo testing.
wait_for "user scope" 30
key Enter
wait_for "Installed geant4-claude" 120

[ -f "${SANDBOX_CLAUDE}/plugins/installed_plugins.json" ] \
  || fail "installed_plugins.json missing"
grep -q "geant4-claude" "${SANDBOX_CLAUDE}/plugins/installed_plugins.json" \
  || fail "geant4-claude not in installed_plugins.json"
note "✓ plugin recorded in installed_plugins.json"

# --- phase 2: SessionStart hook (requires exit + restart) -----------------
# /reload-plugins picks up the new commands but does NOT fire SessionStart
# hooks. The hook only fires on a fresh `claude` invocation. So: exit and
# relaunch.
#
# MCP approval: on first install of a new MCP, Claude Code shows an
# approve-once prompt. In our flow it doesn't fire because the operator's
# .claude.json (which we copied into the sandbox) already has the deepwiki
# MCP approval cached. If you re-run after wiping .claude.json, expect a
# y/n prompt and adapt accordingly.
log "phase 2: exit + relaunch claude → SessionStart hook → venv creation"
send "/exit"
sleep 4
launch_claude
# Give the hook 30 s to finish pip-installing pdg.
sleep 30

if [ -d "${PLUGIN_DATA_SANDBOX}/venv/bin" ]; then
  "${PLUGIN_DATA_SANDBOX}/venv/bin/python" -c "import pdg" 2>/dev/null \
    && note "✓ pdg installed in sandbox venv" \
    || fail "venv exists but pdg not importable"
else
  fail "SessionStart hook did not create venv at ${PLUGIN_DATA_SANDBOX}/venv"
fi

# --- phase 3: /geant4-claude:geant4-init -----------------------------------
log "phase 3: /geant4-claude:geant4-init (workspace skeleton + image pull)"
send "/geant4-claude:geant4-init"

# AskUserQuestion for source clone may fire. With our symlink, it detects
# the existing tree and skips. If it doesn't (no host copy), pick "Yes".
sleep 30
if tmux capture-pane -t "${SESSION}" -p | grep -qE "Clone|Download.*Geant4 v"; then
  note "AskUserQuestion fired; selecting 'Yes' (option 1)"
  key "Enter"  # default is option 1 (Yes)
fi

wait_for "ready" 120 || wait_for "info" 120 || wait_for "✓" 120 || true

# Verify workspace created
[ -f "${WS}/CLAUDE.md" ]      || fail "workspace CLAUDE.md missing"
[ -f "${WS}/.gitignore" ]      || fail "workspace .gitignore missing"
for d in src geometries macros runs analysis; do
  [ -d "${WS}/${d}" ] || fail "workspace ${d}/ missing"
done
[ -f "${PLUGIN_DATA_SANDBOX}/cache/sif/${SIF_NAME}" ] || \
  fail ".sif missing (symlink broken?)"
note "✓ workspace skeleton + cached .sif present"

# --- phase 4a: /geant4-claude:geant4-example -------------------------------
log "phase 4a: /geant4-claude:geant4-example (drop demo)"
send "/geant4-claude:geant4-example"
wait_for "validated" 60 || wait_for "well-formed" 60

[ -f "${WS}/src/geant4_claude_main.cc" ] || fail "example src/main missing"
[ -f "${WS}/src/CMakeLists.txt" ]        || fail "example CMakeLists missing"
[ -f "${WS}/geometries/example.gdml" ]   || fail "example GDML missing"
[ -f "${WS}/macros/run.mac" ]            || fail "example macro missing"
[ -f "${WS}/analysis/example.py" ]       || fail "example analysis missing"
note "✓ example files in place"

# --- phase 4b: /geant4-claude:geant4-build ---------------------------------
log "phase 4b: /geant4-claude:geant4-build"
send "/geant4-claude:geant4-build"
wait_for "built" 300

[ -x "${WS}/build/geant4_claude_main" ] || fail "binary not built"
note "✓ binary built"

# --- phase 4c: /geant4-claude:geant4-run -----------------------------------
log "phase 4c: /geant4-claude:geant4-run"
send "/geant4-claude:geant4-run --exe build/geant4_claude_main -- geometries/example.gdml macros/run.mac {run_dir}/hits.root"
wait_for "finished" 600 || wait_for "run ended" 600

# Find the run dir
RUN_DIR=$(ls -d "${WS}"/runs/*/  | head -1)
RUN_DIR="${RUN_DIR%/}"
[ -n "${RUN_DIR}" ] || fail "no runs/<id> dir"
[ -s "${RUN_DIR}/hits.root" ]   || fail "hits.root empty"
[ -s "${RUN_DIR}/log.txt" ]     || fail "log.txt empty"
[ -s "${RUN_DIR}/config.json" ] || fail "config.json missing"

# Spot-check provenance schema
python3 -c "
import json, sys
cfg = json.load(open('${RUN_DIR}/config.json'))
need = {'run_id','executable','args','image','started_utc','duration_s','exit_status'}
missing = need - set(cfg)
forbidden = {'particle','energy_MeV','n_events','geometry','macro'} & set(cfg)
assert not missing, f'config.json missing: {missing}'
assert not forbidden, f'config.json has stale fields: {forbidden}'
print('config.json schema ok')
" || fail "config.json schema check"

# --- phase 4d: /geant4-claude:geant4-analyze -------------------------------
log "phase 4d: /geant4-claude:geant4-analyze (fast-path on Hits TTree)"
# Note: if the host python lacks uproot+numpy+matplotlib, the analyze
# command may auto-install them into the plugin's venv (~120 MB, ~60–90 s).
# That's the documented behavior since v0.0.2 — bumping the timeout here
# to accommodate.
RUN_ID="${RUN_DIR##*/}"
send "/geant4-claude:geant4-analyze runs/${RUN_ID}"
wait_for "edep_hist" 240 || wait_for "MeV" 240

[ -f "${RUN_DIR}/edep_hist.png" ] || fail "edep_hist.png not produced"
note "✓ analyze produced ${RUN_DIR}/edep_hist.png"

# --- exit Claude Code & cleanup --------------------------------------------
log "exit: send /exit and tear down tmux"
send "/exit"
sleep 3
tmux kill-session -t "${SESSION}" 2>/dev/null || true

log "✓ Phase B passed"
note "Sandbox at ${SANDBOX} can be removed:  rm -rf '${SANDBOX}'"
