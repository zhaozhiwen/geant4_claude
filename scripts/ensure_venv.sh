#!/usr/bin/env bash
# Idempotently install Python deps from requirements.txt into a managed venv.
#
# CLI-neutral bootstrap. Claude Code runs this from the SessionStart hook
# (hooks/install-deps.sh, which exports CLAUDE_PLUGIN_*). Codex has no plugin
# hook, so the geant4-init skill and the Python-using skills call this directly.
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
#   GEANT4_CLAUDE_DATA  data dir for venv (else CLAUDE_PLUGIN_DATA,
#                       else ${XDG_CACHE_HOME:-$HOME/.cache}/geant4_claude)

set -eu

ROOT="${GEANT4_CLAUDE_ROOT:-${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}}"
DATA="${GEANT4_CLAUDE_DATA:-${CLAUDE_PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/geant4_claude}}"
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
# STORED is unchanged, so next call retries.
cp "$REQ" "$STORED"

echo "[geant4_claude] Python deps ready."
