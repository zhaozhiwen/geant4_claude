#!/usr/bin/env bash
# Verifies the sentinel-file exit-capture pattern used by geant4-run
# survives a piped command without depending on PIPESTATUS/pipefail.
set -euo pipefail

run_capture() {
  # $1 = exit code the "executable" should return
  local want="$1" EXIT_FILE STATUS
  EXIT_FILE="$(mktemp)"
  ( sh -c "exit ${want}"; echo $? > "${EXIT_FILE}" ) 2>&1 | tee /dev/null >/dev/null
  STATUS="$(cat "${EXIT_FILE}" 2>/dev/null || echo 1)"
  rm -f "${EXIT_FILE}"
  echo "${STATUS}"
}

[ "$(run_capture 0)" = "0" ]  || { echo "FAIL: success not captured"; exit 1; }
[ "$(run_capture 2)" = "2" ]  || { echo "FAIL: failure not captured"; exit 1; }
echo "exit-capture ok"
