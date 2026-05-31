#!/usr/bin/env bash
# Idempotently install Python deps from requirements.txt into a managed venv.
#
# Idempotent venv bootstrap, called by the skills that need Python
# (geant4-init, and geant4-analyze/preview/validate) on both Claude Code and
# Codex. There is no SessionStart hook.
#
# - Diffs bundled requirements.txt against a stored copy under DATA.
# - On match: silent no-op (~10ms).
# - On mismatch (first install or update): create venv if needed, install deps,
#   then mirror requirements.txt into DATA. If install fails, DATA copy is never
#   updated, so the next call retries.
# - Uses `uv` when available (fast); falls back to `python3 -m venv` + pip.
#
# Env (all optional; resolved CLI-neutrally):
#   GEANT4_CLAUDE_ROOT  plugin root (else CLAUDE_PLUGIN_ROOT, else this script's ../)
#   GEANT4_CLAUDE_VENV  workspace venv dir (set by .g4c/env). If unset, falls back
#                       to GEANT4_CLAUDE_DATA/venv (else CLAUDE_PLUGIN_DATA, else
#                       ${XDG_CACHE_HOME:-$HOME/.cache}/geant4_claude/venv) — for
#                       standalone/CI use with no workspace.

set -eu

ROOT="${GEANT4_CLAUDE_ROOT:-${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}}"
DATA="${GEANT4_CLAUDE_DATA:-${CLAUDE_PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/geant4_claude}}"
# Venv is workspace-rooted: .g4c/env exports GEANT4_CLAUDE_VENV=<workspace>/venv.
VENV="${GEANT4_CLAUDE_VENV:-$DATA/venv}"
REQ="$ROOT/requirements.txt"
# Snapshot lives inside the venv (not a shared dir) — with per-workspace venvs a
# shared snapshot would wrongly gate a second workspace's first build.
STORED="$VENV/requirements.snapshot"

# Idempotency check — exit fast only when the venv actually works AND
# requirements are unchanged. Gating on the interpreter (not just the snapshot)
# keeps this self-healing if the venv was partially deleted or its python moved:
# a stale snapshot alone must never short-circuit the rebuild.
if [ -x "$VENV/bin/python" ] && diff -q "$REQ" "$STORED" >/dev/null 2>&1; then
    exit 0
fi

mkdir -p "$(dirname "$VENV")"

echo "[geant4_claude] installing Python deps into $VENV (one-time, ~30s)..."

# Create venv if it doesn't exist (or if it's stale and broken).
if [ ! -x "$VENV/bin/python" ]; then
    rm -rf "$VENV"
    if command -v uv >/dev/null 2>&1; then
        uv venv "$VENV" --python 3.11 >/dev/null
    else
        python3 -m venv "$VENV"
    fi
fi

PY="$VENV/bin/python"

# Install / upgrade deps. uv is faster but optional.
if command -v uv >/dev/null 2>&1; then
    uv pip install --python "$PY" -r "$REQ" >/dev/null
else
    "$PY" -m pip install --upgrade pip >/dev/null
    "$PY" -m pip install -r "$REQ" >/dev/null
fi

# Mark success only on successful install. On failure (set -e exits earlier),
# STORED is unchanged, so next call retries.
cp "$REQ" "$STORED"

echo "[geant4_claude] Python deps ready."
