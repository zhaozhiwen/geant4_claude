#!/usr/bin/env bash
# SessionStart hook: idempotently install Python deps from requirements.txt
# into ${CLAUDE_PLUGIN_DATA}/venv. Pattern follows the official Claude Code
# plugins reference (https://code.claude.com/docs/en/plugins-reference).
#
# - Diffs bundled requirements.txt against a stored copy in DATA.
# - On match: silent no-op (~10ms).
# - On mismatch (first install or update): creates venv if needed, installs deps,
#   then mirrors requirements.txt into DATA. If install fails, DATA copy is
#   never updated, so the next session retries.
#
# Uses `uv` when available (fast); falls back to `python3 -m venv` + pip.

set -eu

ROOT="${CLAUDE_PLUGIN_ROOT:?must be set by Claude Code}"
DATA="${CLAUDE_PLUGIN_DATA:?must be set by Claude Code}"
REQ="$ROOT/requirements.txt"
STORED="$DATA/requirements.txt"
VENV="$DATA/venv"

# Idempotency check — exit fast if already in sync.
if diff -q "$REQ" "$STORED" >/dev/null 2>&1; then
    exit 0
fi

mkdir -p "$DATA"

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
# STORED is unchanged, so next session retries.
cp "$REQ" "$STORED"

echo "[geant4_claude] Python deps ready."
