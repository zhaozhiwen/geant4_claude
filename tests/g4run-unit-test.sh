#!/usr/bin/env bash
# Unit tests for pure-bash bin/g4run helpers (sourced, no container).
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1090
source "${HERE}/bin/g4run"

fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

# F3: path containment must respect directory boundaries.
path_is_under /tmp/work        /tmp/work || fail "dir itself should be under itself"
path_is_under /tmp/work/a/b    /tmp/work || fail "child should be under"
path_is_under /tmp/work2       /tmp/work && fail "/tmp/work2 must NOT be under /tmp/work"
path_is_under /tmp/workshop    /tmp/work && fail "/tmp/workshop must NOT be under /tmp/work"

# F3: extra_binds_for emits a --bind only for paths outside wd and cache.
out="$(extra_binds_for /tmp/work /tmp/cache /tmp/work2/src 2>/dev/null)"
[[ "${out}" == $'--bind\n/tmp/work2/src' ]] \
  || fail "expected a bind for /tmp/work2/src, got: ${out}"
out="$(extra_binds_for /tmp/work /tmp/cache /tmp/work/inside 2>/dev/null || true)"
[[ -z "${out}" ]] || fail "path inside wd must not get a bind, got: ${out}"

# F5 (added by Task 5; stays red until then): accessors echo pinned constants.
[[ "$(image_tag_value)" == "ghcr.io/gemc/g4install:11.4.0-almalinux-9.4" ]] \
  || fail "image_tag_value mismatch: $(image_tag_value)"
[[ "$(sif_name_value)" == "g4install_11.4.0-almalinux-9.4.sif" ]] \
  || fail "sif_name_value mismatch: $(sif_name_value)"

echo "g4run-unit ok"
