#!/usr/bin/env bash
# Claude Code SessionStart hook: delegate to the CLI-neutral venv bootstrap.
# Claude exports CLAUDE_PLUGIN_ROOT/CLAUDE_PLUGIN_DATA, which ensure_venv.sh reads.
# Codex has no plugin hook, so on Codex the geant4-init / analyze / preview skills
# call scripts/ensure_venv.sh directly instead.
set -eu
ROOT="${CLAUDE_PLUGIN_ROOT:?must be set by Claude Code}"
exec "$ROOT/scripts/ensure_venv.sh"
