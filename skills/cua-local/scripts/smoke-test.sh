#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
WRAP="$DIR/cua-local.sh"

run() {
  echo ">>> $*"
  "$@"
  echo
}

run "$WRAP" status
run env CUA_LOCAL_QUIET=1 "$WRAP" screenshot-path
run "$WRAP" launch-app "Google Chrome"
sleep 1
run "$WRAP" activate-app "Google Chrome"
run env CUA_LOCAL_QUIET=1 "$WRAP" browser-open "https://example.com"
sleep 2
run "$WRAP" browser-title
run env CUA_LOCAL_QUIET=1 "$WRAP" navigate "https://example.org"
sleep 2
run "$WRAP" browser-title
run "$WRAP" tab 2
run "$WRAP" press tab tab enter
run "$WRAP" move 400 300
run "$WRAP" click 400 300
run "$WRAP" right-click 400 300
run "$WRAP" double-click 400 300
run "$WRAP" scroll down 2
run "$WRAP" drag 400 300 420 320
run "$WRAP" type "smoke test"
run "$WRAP" key enter
run "$WRAP" new-tab
run "$WRAP" address-bar
run env CUA_LOCAL_QUIET=1 "$WRAP" safe-step 1 navigate "https://example.com"
run "$WRAP" last-screenshot

echo "smoke-test-ok"
