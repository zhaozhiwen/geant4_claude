# Review-Findings Burndown (F1–F4, F6 + scoped F5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix five verified pre-v0.0.6 review findings: broken fresh-install venv path (F1), `pip install --user` guidance contradicting the isolation policy (F2), an `extra_binds_for` path-prefix bug (F3), unsafe shell-quoting in `validate-gdml` (F4), stale README status (F6), and the tests/CI half of the image-tag single-source violation plus a pre-publish equality check (F5, scoped).

**Architecture:** Surgical fixes. F1/F2/F6 are command-spec + doc edits. F3/F4 modify `bin/g4run` (the single runtime entry point) — gated behind a new sourcing-guard so the pure-bash logic is unit-testable without a container, then verified end-to-end by `tests/clean-smoke.sh`. F5 adds two read-only accessor subcommands to `bin/g4run` (the existing source of truth) and makes tests + a new pre-publish check derive the tag from them instead of hardcoding.

**Tech Stack:** Bash (`bin/g4run`, smoke tests), Markdown command specs/skills, Python (`scripts/preview_gdml.py` error string), apptainer.

**Scope note:** F5 is deliberately partial per maintainer decision — de-hardcode tests/CI and add an equality check; do NOT rewrite CHANGELOG or design-doc history (point-in-time records). Findings are pre-existing, unrelated to the optical work already on `main`.

**Branch:** create `fix/review-findings-burndown` off `main` before Task 1.

---

## File structure

| File | Change | Finding |
|------|--------|---------|
| `bin/g4run` | sourcing guard; `path_is_under` helper; fix `extra_binds_for`; safe positional `validate-gdml`; remove orphaned `in_container`; add `sif-name`/`image-tag` subcommands | F3, F4, F5 |
| `tests/g4run-unit-test.sh` (new) | unit tests for `path_is_under`, `extra_binds_for`, `sif-name`, `image-tag` (sources `bin/g4run`) | F3, F5 |
| `tests/clean-smoke.sh` | run the new unit test (phase 0c); derive `SIF_NAME` from `g4run sif-name`; new phase 7b tag-equality check; quote-in-filename validate-gdml check | F3,F4,F5 |
| `tests/clean-install-test.sh` | derive `SIF_NAME` from `g4run sif-name` | F5 |
| `commands/geant4-analyze.md` | branch (c) calls `hooks/install-deps.sh`, re-verifies, errors clearly | F1 |
| `commands/geant4-validate.md` | same branch-(c) fix | F1 |
| `README.md` | status line → v0.0.6 + accurate command set; troubleshooting row drops `--user` | F6, F2 |
| `skills/geant4-analysis/SKILL.md` | `## Install` block → managed venv, not `--user` | F2 |
| `scripts/preview_gdml.py` | ImportError hint → managed venv, not `--user` | F2 |

---

## Task 1: F6 — sync README status line

**Files:**
- Modify: `README.md:10-16`

- [ ] **Step 1: Read the current status block**

Run: `sed -n '10,17p' README.md` and `grep '"version"' .claude-plugin/plugin.json`
Expected: README says `> Status: **v0.0.3**. The four core commands...`; manifest says `0.0.6`.

- [ ] **Step 2: Replace the status sentence**

In `README.md`, replace the line beginning `> Status: **v0.0.3**. The four core commands (` and its continuation describing only four commands, with:

```markdown
> Status: **v0.0.6**. Eight commands (`init`, `detector`, `preview`,
> `example`, `build`, `run`, `analyze`, `validate`) are content-neutral —
> they accept any user-supplied `main.cc` and any output schema.
> `/geant4-claude:geant4-detector` writes standalone GDML (including an
> optical/RINDEX path) for use with whatever `main.cc` you bring.
> `/geant4-claude:geant4-example` is a self-contained smoke test that
```

Keep the remainder of the blockquote (the sentence after "smoke test that …") exactly as-is — only the version number, the "four core commands" clause, and the command list change. Read lines 10–20 first and preserve the tail verbatim.

- [ ] **Step 3: Verify**

Run: `grep -n "Status: \*\*v0\.0\.6\*\*" README.md && ! grep -n "Status: \*\*v0\.0\.3\*\*" README.md && echo OK`
Expected: prints the matched line then `OK`.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): sync status to v0.0.6, correct command set (F6)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: F2 — remove `pip install --user` guidance

**Files:**
- Modify: `README.md:258`
- Modify: `skills/geant4-analysis/SKILL.md:42-47`
- Modify: `scripts/preview_gdml.py:51-54`

- [ ] **Step 1: Confirm the three sites**

Run:
```bash
grep -n "pip install --user" README.md skills/geant4-analysis/SKILL.md scripts/preview_gdml.py
```
Expected: `README.md:258`, `skills/geant4-analysis/SKILL.md:46`, `scripts/preview_gdml.py:53`.

- [ ] **Step 2: Fix `README.md:258` troubleshooting row**

Replace the table row:
```
| `ModuleNotFoundError: uproot` (analyze step) | `pip install --user uproot numpy matplotlib`, or use a venv. |
```
with:
```
| `ModuleNotFoundError: uproot` (analyze step) | Re-run `/geant4-claude:geant4-analyze` — it seeds the plugin-managed venv (`${CLAUDE_PLUGIN_DATA}/venv`) automatically. Do not `pip install --user` (pollutes host site-packages). |
```

- [ ] **Step 3: Fix `skills/geant4-analysis/SKILL.md` Install block**

Read `sed -n '40,48p' skills/geant4-analysis/SKILL.md`. Replace the `## Install` section's fenced block:
````
## Install

```bash
pip install --user uproot numpy matplotlib
```
````
with:
````
## Install

`/geant4-claude:geant4-analyze` resolves a Python with `uproot`/`numpy`/
`matplotlib` automatically: host Python if it already has them, else the
plugin-managed venv at `${CLAUDE_PLUGIN_DATA}/venv` (seeded by the
SessionStart hook from `requirements.txt`, or repaired on demand). Never
`pip install --user` — it pollutes the host site-packages the rest of the
plugin deliberately avoids. To force a manual repair:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/hooks/install-deps.sh"
```
````
Preserve any prose immediately following the original block (read further if the section continues) — only the heading's code block changes.

- [ ] **Step 4: Fix `scripts/preview_gdml.py` ImportError hint**

Read `sed -n '49,55p' scripts/preview_gdml.py`. Replace:
```python
    sys.exit(
        f"[preview-gdml] missing dep: {e}. "
        "Install with: pip install --user matplotlib numpy"
    )
```
with:
```python
    sys.exit(
        f"[preview-gdml] missing dep: {e}. "
        "Run this through /geant4-claude:geant4-preview, which uses the "
        "plugin-managed venv. To repair manually: "
        'bash "$CLAUDE_PLUGIN_ROOT/hooks/install-deps.sh". '
        "Do not pip install --user (pollutes host site-packages)."
    )
```

- [ ] **Step 5: Verify**

Run:
```bash
! grep -rn "pip install --user" README.md skills/geant4-analysis/SKILL.md scripts/preview_gdml.py && python3 -c "import ast; ast.parse(open('scripts/preview_gdml.py').read()); print('PYOK')"
```
Expected: no `pip install --user` matches, then `PYOK`.

- [ ] **Step 6: Commit**

```bash
git add README.md skills/geant4-analysis/SKILL.md scripts/preview_gdml.py
git commit -m "docs: replace pip install --user with managed-venv guidance (F2)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: F3 — `bin/g4run` sourcing guard + `path_is_under` + `extra_binds_for` fix

**Files:**
- Modify: `bin/g4run` (add sourcing guard before dispatch; add helper; fix `extra_binds_for` ~line 134-145)
- Create: `tests/g4run-unit-test.sh`

- [ ] **Step 1: Add the sourcing guard so g4run is testable**

In `bin/g4run`, find the dispatch section:
```bash
# --- dispatch ----------------------------------------------------------------
sub="${1:-}"; shift || true
```
Insert a guard immediately after the `# --- dispatch ---` comment line and before `sub="${1:-}"`:
```bash
# Allow `source bin/g4run` in unit tests to load the functions/constants
# without running a subcommand.
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  return 0 2>/dev/null || true
fi
```

- [ ] **Step 2: Write the failing unit test**

Create `tests/g4run-unit-test.sh`:
```bash
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

# F5: accessors echo the pinned constants verbatim.
[[ "$(image_tag_value)" == "ghcr.io/gemc/g4install:11.4.0-almalinux-9.4" ]] \
  || fail "image_tag_value mismatch: $(image_tag_value)"
[[ "$(sif_name_value)" == "g4install_11.4.0-almalinux-9.4.sif" ]] \
  || fail "sif_name_value mismatch: $(sif_name_value)"

echo "g4run-unit ok"
```
Make it executable: `chmod +x tests/g4run-unit-test.sh`.

- [ ] **Step 3: Run it — expect failure (helpers/accessors not defined yet)**

Run: `bash tests/g4run-unit-test.sh`
Expected: FAIL — `path_is_under: command not found` or similar (the helper and the `*_value` functions from Task 5 don't exist yet). This is expected; Task 3 Step 4 adds `path_is_under`; the `image_tag_value`/`sif_name_value` assertions stay red until Task 5. Note the failing line; proceed.

- [ ] **Step 4: Add `path_is_under` and fix `extra_binds_for`**

In `bin/g4run`, locate:
```bash
extra_binds_for() {
  local wd="$1" cache_real="$2"; shift 2
  local p
  for p in "$@"; do
    [[ -z "$p" ]] && continue
    if [[ "$p" != "${wd}"* && "$p" != "${cache_real}"* ]]; then
      printf -- '--bind\n%s\n' "$p"
    fi
  done
}
```
Replace it with (add the helper directly above it):
```bash
# True if $1 is the directory $2 itself or a path strictly inside it.
# String-prefix matching would treat /tmp/work2 as inside /tmp/work.
path_is_under() {
  local p="$1" dir="$2"
  [[ "$p" == "$dir" || "$p" == "$dir"/* ]]
}

# Echo the host paths that need an explicit --bind beyond the workspace and
# cache. A path is auto-covered only if it is the bound workdir/cache or a
# path strictly inside one of them.
extra_binds_for() {
  local wd="$1" cache_real="$2"; shift 2
  local p
  for p in "$@"; do
    [[ -z "$p" ]] && continue
    if ! path_is_under "$p" "$wd" && ! path_is_under "$p" "$cache_real"; then
      printf -- '--bind\n%s\n' "$p"
    fi
  done
}
```

- [ ] **Step 5: Re-run the unit test — F3 assertions pass, F5 ones still fail**

Run: `bash tests/g4run-unit-test.sh`
Expected: now fails only at the `image_tag_value`/`sif_name_value` assertions (added in Task 5). The four `path_is_under` lines and the two `extra_binds_for` lines must pass. Confirm by temporarily checking: `source bin/g4run; path_is_under /tmp/work2 /tmp/work && echo BUG || echo GOOD` → `GOOD`.

- [ ] **Step 6: Commit**

```bash
git add bin/g4run tests/g4run-unit-test.sh
git commit -m "fix(g4run): boundary-aware path containment in extra_binds_for (F3)

Adds a sourcing guard so pure-bash helpers are unit-testable.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: F4 — safe positional quoting in `validate-gdml`; drop orphaned `in_container`

**Files:**
- Modify: `bin/g4run` (`cmd_validate_gdml` ~line 304-318; remove `in_container` ~line 67-78)

- [ ] **Step 1: Confirm `in_container` has exactly one caller**

Run: `grep -n "in_container" bin/g4run`
Expected: the definition (~line 67) and exactly one call inside `cmd_validate_gdml` (~line 310). If there is more than one call site, STOP and report — the removal in Step 3 would break other callers.

- [ ] **Step 2: Replace the unsafe layer-1 call with a positional apptainer exec**

In `cmd_validate_gdml`, find:
```bash
  # Layer 1: XML well-formedness (xmllint, ~ms).
  in_container "xmllint --noout '${gdml}'"
```
Replace with (mirrors the safe positional pattern already used by `cmd_exec`/`cmd_root`):
```bash
  # Layer 1: XML well-formedness (xmllint, ~ms). Pass the path as a
  # positional arg — never interpolate it into a shell string (a quote
  # or shell metachar in the filename would break or inject).
  ensure_sif
  local wd cache_real
  wd="$(container_workdir)"
  cache_real="$(container_cache_dir)"
  apptainer exec \
    --env DOCKER_ENTRYPOINT_SOURCE_ONLY=1 \
    --bind "${wd}" \
    --bind "${cache_real}" \
    --pwd "${wd}" \
    "${SIF_PATH}" \
    bash -lc 'source "$0" && xmllint --noout "$1"' "${ENTRYPOINT}" "${gdml}"
```

- [ ] **Step 3: Remove the now-orphaned `in_container` function**

Delete the entire `in_container() { … }` definition (the function block starting `in_container() {` and ending at its closing `}` near line 78). It has no remaining callers after Step 2. Do not remove `container_workdir`/`container_cache_dir`/`ensure_sif` — those are still used.

- [ ] **Step 4: Static checks**

Run:
```bash
bash -n bin/g4run && echo "SYNTAX-OK"
grep -n "in_container" bin/g4run || echo "in_container fully removed"
grep -n "source \"\$0\" && xmllint --noout \"\$1\"" bin/g4run && echo "positional xmllint present"
```
Expected: `SYNTAX-OK`; `in_container fully removed`; the positional xmllint line is present.

- [ ] **Step 5: Behavioral check via the existing helper-built validate path (no full smoke yet)**

Run (uses the already-cached `.sif`; builds the `validate_gdml` helper on first call — a few minutes is normal):
```bash
mkdir -p /tmp/g4c-f4 && cp templates/example/geometries/example.gdml "/tmp/g4c-f4/wei'rd.gdml"
GEANT4_CLAUDE_CACHE=/tmp/g4c-f4-cache \
GEANT4_CLAUDE_CACHE="$(dirname "$(readlink -f /home/zwzhao/.geant4_claude/sif/g4install_11.4.0-almalinux-9.4.sif)")/.." \
  true   # (informational; real check below)
cd /tmp/g4c-f4 && GEANT4_CLAUDE_CACHE="${HOME}/.geant4_claude" \
  "$(git -C /home/zwzhao/claude/geant4_claude rev-parse --show-toplevel)/bin/g4run" \
  validate-gdml "wei'rd.gdml" ; echo "exit=$?"; cd -
```
Expected: the single-quote-in-filename path passes Layer 1 (xmllint) without a shell-quoting error and proceeds to Layer 2; `exit=0` and a `GDML parses cleanly` log line. The point is that the apostrophe filename no longer breaks the shell string. (If the cache/sif env differs on the run host, the implementer may instead defer this to the Task 7 smoke run, which includes an apostrophe-filename validate-gdml step — note that choice in the report.)

- [ ] **Step 6: Commit**

```bash
git add bin/g4run
git commit -m "fix(g4run): pass gdml path positionally to xmllint; drop in_container (F4)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: F5 (scoped) — tag accessors + de-hardcode tests + pre-publish equality check

**Files:**
- Modify: `bin/g4run` (add `image_tag_value`/`sif_name_value` helpers + `image-tag`/`sif-name` subcommands)
- Modify: `tests/clean-smoke.sh` (derive `SIF_NAME`; run unit test as phase 0c; add phase 7b equality check; apostrophe validate-gdml step)
- Modify: `tests/clean-install-test.sh:102` (derive `SIF_NAME`)

- [ ] **Step 1: Add accessor helpers + subcommands to `bin/g4run`**

Directly below the pinned-runtime block (after the `IMAGE_TAG`/`IMAGE_URI`/`ENTRYPOINT` / `SIF_NAME` constants — `SIF_NAME` is defined ~line 27), add:
```bash
# Read-only accessors so docs/tests/CI can derive the pinned identifiers
# from this single source of truth instead of hardcoding them.
image_tag_value() { printf '%s\n' "${IMAGE_TAG}"; }
sif_name_value()  { printf '%s\n' "${SIF_NAME}"; }
```
Then in the dispatch `case "${sub}" in` block, add two arms next to `info)`:
```bash
  image-tag)      image_tag_value ;;
  sif-name)       sif_name_value ;;
```

- [ ] **Step 2: Run the unit test — now fully green**

Run: `bash tests/g4run-unit-test.sh`
Expected: `g4run-unit ok` (the `image_tag_value`/`sif_name_value` assertions added in Task 3 Step 2 now pass).

Also smoke the subcommands:
```bash
bin/g4run image-tag   # → ghcr.io/gemc/g4install:11.4.0-almalinux-9.4
bin/g4run sif-name    # → g4install_11.4.0-almalinux-9.4.sif
```

- [ ] **Step 3: Derive `SIF_NAME` in `tests/clean-smoke.sh`**

Read `sed -n '25,30p' tests/clean-smoke.sh` (the `PLUGIN_ROOT=` definition). Immediately after `PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"` add:
```bash
SIF_NAME="$("${PLUGIN_ROOT}/bin/g4run" sif-name)"
```
Then replace the three hardcoded functional uses:
- line ~61: `"${CLAUDE_PLUGIN_DATA}/cache/sif/g4install_11.4.0-almalinux-9.4.sif"` → `"${CLAUDE_PLUGIN_DATA}/cache/sif/${SIF_NAME}"`
- line ~99: `[ -f "${CLAUDE_PLUGIN_DATA}/cache/sif/g4install_11.4.0-almalinux-9.4.sif" ]` → `[ -f "${CLAUDE_PLUGIN_DATA}/cache/sif/${SIF_NAME}" ]`
- line ~225: `sif="${CLAUDE_PLUGIN_DATA}/cache/sif/g4install_11.4.0-almalinux-9.4.sif"` → `sif="${CLAUDE_PLUGIN_DATA}/cache/sif/${SIF_NAME}"`

Leave the line-14 usage *comment* (`# G4C_REUSE_SIF=/path/to/g4install_11.4.0-almalinux-9.4.sif …`) as illustrative prose — comments are documentation, not a hardcoded operational dependency. Verify no functional literal remains:
```bash
grep -n 'g4install_11\.4\.0-almalinux-9\.4\.sif' tests/clean-smoke.sh
```
Expected: only the line-14 comment remains.

- [ ] **Step 4: Add phase 0c (unit test) and phase 7b (tag equality) to `tests/clean-smoke.sh`**

After the existing `# --- phase 0b: optical recipe ↔ fixture drift gate` block (it ends with its `fi`), add:
```bash
# --- phase 0c: g4run pure-bash unit tests ----------------------------------
log "g4run-unit: path containment + tag accessors"
bash "${PLUGIN_ROOT}/tests/g4run-unit-test.sh" \
  || fail "g4run-unit-test.sh failed"
```
Immediately before the `# --- phase 7: leakage scan` comment, add:
```bash
# --- phase 7b: image-tag single-source check -------------------------------
# CLAUDE.md non-negotiable: the tag lives in bin/g4run only. Static docs that
# DISPLAY it (README, Pages config) must match it; CHANGELOG/design history is
# point-in-time and intentionally NOT checked here.
log "tag-sync: README + docs/_config.yml must match g4run's pinned tag"
want_tag="$("${PLUGIN_ROOT}/bin/g4run" image-tag)"
grep -qF "${want_tag}" "${PLUGIN_ROOT}/README.md" \
  || fail "README.md does not display g4run's pinned image tag (${want_tag})"
grep -qF "${want_tag}" "${PLUGIN_ROOT}/docs/_config.yml" \
  || fail "docs/_config.yml image_tag != g4run's pinned tag (${want_tag})"
```

- [ ] **Step 5: Add an apostrophe-filename validate-gdml step (locks in F4) to phase 2**

In `tests/clean-smoke.sh`, find the existing example validate line `g4run validate-gdml geometries/example.gdml >/dev/null` (phase 2). Immediately after it add:
```bash
log "example: validate-gdml tolerates a quote in the filename (F4 regression)"
cp geometries/example.gdml "geometries/wei'rd.gdml"
g4run validate-gdml "geometries/wei'rd.gdml" >/dev/null \
  || fail "validate-gdml broke on an apostrophe in the filename"
rm -f "geometries/wei'rd.gdml"
```

- [ ] **Step 6: Derive `SIF_NAME` in `tests/clean-install-test.sh`**

Read `sed -n '98,104p' tests/clean-install-test.sh`. Replace:
```bash
SIF_NAME="g4install_11.4.0-almalinux-9.4.sif"
```
with (the script defines its repo root earlier; confirm the variable name by reading the top — it is the dir containing `bin/g4run`; use that variable, here shown as `${REPO_ROOT}` — substitute the script's actual name for its repo-root path):
```bash
SIF_NAME="$("$(cd "$(dirname "$0")/.." && pwd)/bin/g4run" sif-name)"
```
Verify: `grep -n 'g4install_11\.4\.0-almalinux-9\.4\.sif' tests/clean-install-test.sh` → no matches.

- [ ] **Step 7: Static verification**

Run:
```bash
bash -n tests/clean-smoke.sh && bash -n tests/clean-install-test.sh && bash -n bin/g4run && echo "SYNTAX-OK"
bash tests/g4run-unit-test.sh
```
Expected: `SYNTAX-OK` then `g4run-unit ok`.

- [ ] **Step 8: Commit**

```bash
git add bin/g4run tests/clean-smoke.sh tests/clean-install-test.sh
git commit -m "fix(g4run): add image-tag/sif-name accessors; de-hardcode tests; tag-sync check (F5, scoped)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: F1 — repair the fresh-install venv fallback

**Files:**
- Modify: `commands/geant4-analyze.md` (branch (c), ~line 63-74)
- Modify: `commands/geant4-validate.md` (branch (c), ~line 105-113)

Context: `hooks/install-deps.sh` creates the venv (`uv venv` / `python3 -m venv`) and installs all of `requirements.txt` (which includes `uproot`, `numpy`, `matplotlib`). Branch (c) currently assumes the venv already exists and just installs into it — broken when the SessionStart hook never ran. The fix: branch (c) runs the hook (idempotent; creates venv + seeds deps), then re-verifies, and errors clearly if still broken.

- [ ] **Step 1: Fix `commands/geant4-analyze.md` branch (c)**

Read `sed -n '55,80p' commands/geant4-analyze.md`. Replace the `else` branch:
```bash
   else
     PY="${CLAUDE_PLUGIN_DATA}/venv/bin/python"
     if command -v uv >/dev/null 2>&1; then
       uv pip install --python "${PY}" -q uproot numpy matplotlib
     else
       "${PY}" -m pip install -q uproot numpy matplotlib
     fi
   fi
```
with:
```bash
   else
     # The SessionStart hook normally seeds the venv. If it didn't run
     # (not approved / failed / fresh install), the venv may not exist —
     # so create+seed it via the hook itself (idempotent, single source
     # of venv-creation logic), then re-resolve.
     bash "${CLAUDE_PLUGIN_ROOT}/hooks/install-deps.sh" || true
     PY="${CLAUDE_PLUGIN_DATA}/venv/bin/python"
     if ! "${PY}" -c "import uproot, numpy, matplotlib" 2>/dev/null; then
       echo "analyze: could not provision uproot/numpy/matplotlib in the" \
            "plugin venv (${PY}). Check hooks/install-deps.sh output and" \
            "network; do not pip install --user." >&2
       exit 1
     fi
   fi
```

- [ ] **Step 2: Fix `commands/geant4-validate.md` branch (c)**

Read `sed -n '100,115p' commands/geant4-validate.md`. Replace the `else` branch:
```bash
   else
     PY="${CLAUDE_PLUGIN_DATA}/venv/bin/python"
     if command -v uv >/dev/null 2>&1; then
       uv pip install --python "${PY}" -q uproot numpy
     else
       "${PY}" -m pip install -q uproot numpy
     fi
   fi
```
with:
```bash
   else
     # SessionStart hook normally seeds the venv; if it didn't run the
     # venv may be absent. Create+seed via the hook (idempotent), then
     # re-resolve. Never pip install --user.
     bash "${CLAUDE_PLUGIN_ROOT}/hooks/install-deps.sh" || true
     PY="${CLAUDE_PLUGIN_DATA}/venv/bin/python"
     if ! "${PY}" -c "import uproot, numpy" 2>/dev/null; then
       echo "validate: could not provision uproot/numpy in the plugin" \
            "venv (${PY}). Check hooks/install-deps.sh output and network." >&2
       exit 2
     fi
   fi
```
(Exit code `2` matches `geant4-validate`'s documented "bad input / missing data" convention; `geant4-analyze` uses `1`.)

- [ ] **Step 3: Verify the edits**

Run:
```bash
grep -n "hooks/install-deps.sh" commands/geant4-analyze.md commands/geant4-validate.md
grep -n "could not provision" commands/geant4-analyze.md commands/geant4-validate.md
! grep -n "uv pip install --python .* -q uproot" commands/geant4-analyze.md commands/geant4-validate.md && echo "old blind-install branch gone"
```
Expected: both files reference the hook and the new error; the old `uv pip install --python … uproot` lines are gone.

- [ ] **Step 4: Functional check — hook provisions a missing venv**

Run (simulates a fresh install with no venv):
```bash
TMPD="$(mktemp -d)"; export CLAUDE_PLUGIN_DATA="${TMPD}"
export CLAUDE_PLUGIN_ROOT="$(git rev-parse --show-toplevel)"
bash "${CLAUDE_PLUGIN_ROOT}/hooks/install-deps.sh" || true
"${CLAUDE_PLUGIN_DATA}/venv/bin/python" -c "import uproot, numpy, matplotlib; print('venv provisioned from scratch OK')"
rm -rf "${TMPD}"; unset CLAUDE_PLUGIN_DATA CLAUDE_PLUGIN_ROOT
```
Expected: `venv provisioned from scratch OK` (proves the branch-(c) recovery path actually creates a working venv on a clean data dir). If the host lacks network and the install fails, note it: the *logic* is what's under test — the clear-error path is exercised instead; report which occurred.

- [ ] **Step 5: Commit**

```bash
git add commands/geant4-analyze.md commands/geant4-validate.md
git commit -m "fix(analyze,validate): repair venv via install-deps.sh on fresh install (F1)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Full regression + finish

- [ ] **Step 1: Pure-bash + syntax gates**

Run:
```bash
bash -n bin/g4run tests/clean-smoke.sh tests/clean-install-test.sh tests/g4run-unit-test.sh && echo SYNTAX-OK
bash tests/g4run-unit-test.sh
```
Expected: `SYNTAX-OK`, then `g4run-unit ok`.

- [ ] **Step 2: Full clean-smoke (container; several minutes)**

Run:
```bash
G4C_REUSE_SIF=/home/zwzhao/.geant4_claude/sif/g4install_11.4.0-almalinux-9.4.sif tests/clean-smoke.sh
```
Expected final line: `✓ all smoke checks passed`. Specifically confirm the new gates ran green: phase 0c (`g4run-unit`), the apostrophe-filename `validate-gdml` step in phase 2, phase 4b optical closure `RESULT: PASS`, phase 7b (`tag-sync`), phase 7 (`leakage`, tracked-only).

If phase 7b fails: `bin/g4run image-tag` and the literal in `README.md`/`docs/_config.yml` disagree — reconcile the docs to the g4run value (g4run is the source of truth; do not edit g4run to match docs).

- [ ] **Step 3: Confirm scope discipline (F5 not over-applied)**

Run: `git diff --stat main..HEAD -- CHANGELOG.md docs/DESIGN.md`
Expected: empty — this burndown must NOT have rewritten CHANGELOG or DESIGN history (F5 scoped decision).

- [ ] **Step 4: Hand off**

Invoke `superpowers:finishing-a-development-branch`. Do not push or open a PR without explicit user confirmation (red line).

---

## Self-review (plan author)

**Spec coverage:** F1→Task 6; F2→Task 2; F3→Task 3; F4→Task 4; F5 (scoped: accessors + de-hardcode tests + equality check, no history rewrite)→Task 5 (+Task 7 Step 3 guards the scope); F6→Task 1. All six mapped; F5's out-of-scope half explicitly fenced.

**Placeholder scan:** every code step shows exact text. The only intentional indirection is Task 5 Step 6's `tests/clean-install-test.sh` repo-root variable (the step says to read the file and use the script's actual repo-root expression, and gives a self-contained `$(cd "$(dirname "$0")/.." && pwd)` fallback that works regardless) — not a placeholder, a read-then-match instruction with a working default.

**Consistency:** `path_is_under`, `extra_binds_for`, `image_tag_value`, `sif_name_value`, the `image-tag`/`sif-name` subcommands, `SIF_NAME`, and the phase names (0c, 7b) are used identically across Tasks 3/5/7 and the unit test. Task 3's unit test references `image_tag_value`/`sif_name_value` which Task 3 Step 3 explicitly notes stay red until Task 5 — sequencing is called out, not contradictory. `bin/g4run` is touched by Tasks 3, 4, 5 in disjoint regions (dispatch guard / `extra_binds_for` / `cmd_validate_gdml` / pinned-constants block) executed sequentially, so no merge hazard.
