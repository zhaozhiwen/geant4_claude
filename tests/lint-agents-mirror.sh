#!/usr/bin/env bash
# Assert the CLAUDE.md / AGENTS.md single-source invariant.
#
# AGENTS.md is the canonical project-rules file (a real file); CLAUDE.md is a
# symlink → AGENTS.md in the same directory. One source, zero drift by
# construction. This direction is deliberate: `codex plugin add` copies files
# and DROPS symlinks, so the Codex package keeps the real AGENTS.md (which
# Codex reads) and drops the CLAUDE.md symlink (which Codex doesn't need).
# Claude Code installs via git clone, which preserves the symlink, so it reads
# CLAUDE.md through the link. There is one such pair per location (repo root,
# templates/workspace/, wiki/).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
while IFS= read -r agents; do
  dir="$(dirname "$agents")"
  claude="$dir/CLAUDE.md"
  if [[ -L "$agents" ]]; then
    echo "[FAIL] $agents is a symlink — AGENTS.md must be the real (canonical) file"
    fail=1; continue
  fi
  if [[ ! -L "$claude" ]]; then
    echo "[FAIL] $claude must be a symlink → AGENTS.md (codex plugin add keeps the real AGENTS.md, drops the symlink)"
    fail=1; continue
  fi
  target="$(readlink "$claude")"
  if [[ "$target" != "AGENTS.md" ]]; then
    echo "[FAIL] $claude → '$target', expected 'AGENTS.md' (relative, same dir)"
    fail=1; continue
  fi
  echo "[ok]   $claude → AGENTS.md (real $(stat -c%s "$agents") b)"
done < <(find . -path ./.git -prune -o -name AGENTS.md -print)

[[ $fail -eq 0 ]] && echo "all CLAUDE.md symlink to their canonical AGENTS.md" || exit 1
