#!/usr/bin/env bash
set -euo pipefail

CUA_BIN="${CUA_BIN:-$HOME/.local/bin/cua}"
DEFAULT_BROWSER="${CUA_BROWSER:-Google Chrome}"
QUIET="${CUA_LOCAL_QUIET:-0}"
ACTION_DELAY="${CUA_LOCAL_DELAY:-0.15}"
LAST_SCREENSHOT_FILE="${CUA_LOCAL_LAST_SCREENSHOT_FILE:-$HOME/.openclaw/tmp/cua-local-last-screenshot.txt}"

if [[ ! -x "$CUA_BIN" ]]; then
  echo "Cua binary not found at $CUA_BIN" >&2
  exit 1
fi

mkdir -p "$(dirname "$LAST_SCREENSHOT_FILE")"

run_cua() {
  local out rc
  out=$("$CUA_BIN" do "$@" 2>&1) || rc=$?
  rc=${rc:-0}
  if [[ "$QUIET" != "1" ]]; then
    printf '%s\n' "$out"
  fi
  return "$rc"
}

run_cua_capture() {
  "$CUA_BIN" do "$@" 2>&1
}

capture_screenshot_path() {
  local out path
  out=$("$CUA_BIN" do screenshot 2>&1)
  if [[ "$QUIET" != "1" ]]; then
    printf '%s\n' "$out"
  fi
  path=$(printf '%s\n' "$out" | sed -n 's/^✅ screenshot saved to //p' | tail -1)
  if [[ -n "$path" ]]; then
    printf '%s\n' "$path" > "$LAST_SCREENSHOT_FILE"
  fi
}

activate_app() {
  osascript -e 'on run argv' -e 'tell application (item 1 of argv) to activate' -e 'end run' "$1"
}

frontmost_app() {
  osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true'
}

ensure_frontmost() {
  local app tries current
  app="$1"
  tries="${2:-10}"
  activate_app "$app"
  for _ in $(seq 1 "$tries"); do
    current=$(frontmost_app 2>/dev/null || true)
    if [[ "$current" == "$app" ]]; then
      return 0
    fi
    sleep 0.2
  done
  echo "App not frontmost: expected '$app', got '${current:-unknown}'" >&2
  return 1
}

wait_for_window() {
  local app tries json title
  app="$1"
  tries="${2:-15}"
  for _ in $(seq 1 "$tries"); do
    json=$(peekaboo list windows --app "$app" --json 2>/dev/null || true)
    title=$(printf '%s' "$json" | jq -r '.data.windows[]? | select(.isMainWindow==true and (.title|length>=0)) | .title' | head -1)
    if [[ -n "$title" || "$json" == *'"windows":['* ]]; then
      return 0
    fi
    sleep 0.3
  done
  echo "Window not ready for app: $app" >&2
  return 1
}

browser_title() {
  peekaboo list windows --app "$DEFAULT_BROWSER" --json | jq -r '.data.windows[] | select(.isMainWindow==true and (.title|length>0)) | .title' | head -1
}

with_failure_snapshot() {
  local rc snapshot_path
  "$@" || rc=$?
  rc=${rc:-0}
  if [[ "$rc" -ne 0 ]]; then
    snapshot_path=$(capture_screenshot_path 2>/dev/null || true)
    echo "failure_screenshot=${snapshot_path:-unknown}" >&2
    return "$rc"
  fi
}

cmd="${1:-}"
if [[ -z "$cmd" ]]; then
  echo "Usage: cua-local.sh <status|screenshot|screenshot-path|last-screenshot|browser-title|frontmost-app|wait|pause-ms|retry|open-app|activate-app|ensure-frontmost|wait-for-window|move|click|right-click|double-click|drag|scroll|type|key|hotkey|submit|new-tab|close-tab|address-bar|back|forward|open-url|browser-open|navigate|goto-url|tab|press|paste|fill-form|safe-step|raw> [...]" >&2
  exit 2
fi
shift || true

case "$cmd" in
  status)
    exec "$CUA_BIN" do status
    ;;
  screenshot)
    capture_screenshot_path
    ;;
  screenshot-path)
    capture_screenshot_path >/dev/null
    cat "$LAST_SCREENSHOT_FILE"
    ;;
  last-screenshot)
    cat "$LAST_SCREENSHOT_FILE"
    ;;
  browser-title)
    browser_title
    ;;
  wait)
    secs="${1:-1}"
    sleep "$secs"
    ;;
  pause-ms)
    ms="${1:-100}"
    python3 - <<PY
import time
time.sleep(${ms}/1000)
PY
    ;;
  retry)
    if [[ $# -lt 2 ]]; then
      echo "Usage: cua-local.sh retry <count> <subcommand...>" >&2
      exit 2
    fi
    count="$1"
    shift
    for attempt in $(seq 1 "$count"); do
      if "$0" "$@"; then
        exit 0
      fi
      sleep 0.4
    done
    exit 1
    ;;
  frontmost-app)
    frontmost_app
    ;;
  open-app)
    if [[ $# -lt 1 ]]; then
      echo "Usage: cua-local.sh open-app <app name>" >&2
      exit 2
    fi
    exec open -a "$*"
    ;;
  launch-app)
    if [[ $# -lt 1 ]]; then
      echo "Usage: cua-local.sh launch-app <app name>" >&2
      exit 2
    fi
    exec open -a "$*"
    ;;
  activate-app)
    if [[ $# -lt 1 ]]; then
      echo "Usage: cua-local.sh activate-app <app name>" >&2
      exit 2
    fi
    exec osascript -e 'on run argv' -e 'tell application (item 1 of argv) to activate' -e 'end run' "$*"
    ;;
  focus-app)
    if [[ $# -lt 1 ]]; then
      echo "Usage: cua-local.sh focus-app <app name>" >&2
      exit 2
    fi
    exec osascript -e 'on run argv' -e 'tell application (item 1 of argv) to activate' -e 'end run' "$*"
    ;;
  ensure-frontmost)
    if [[ $# -lt 1 ]]; then
      echo "Usage: cua-local.sh ensure-frontmost <app name> [tries]" >&2
      exit 2
    fi
    with_failure_snapshot ensure_frontmost "$@"
    ;;
  wait-for-window)
    if [[ $# -lt 1 ]]; then
      echo "Usage: cua-local.sh wait-for-window <app name> [tries]" >&2
      exit 2
    fi
    with_failure_snapshot wait_for_window "$@"
    ;;
  move)
    if [[ $# -ne 2 ]]; then
      echo "Usage: cua-local.sh move <x> <y>" >&2
      exit 2
    fi
    exec "$CUA_BIN" do move "$1" "$2"
    ;;
  click)
    if [[ $# -eq 0 ]]; then
      exec "$CUA_BIN" do click
    elif [[ $# -eq 2 ]]; then
      exec "$CUA_BIN" do click "$1" "$2"
    else
      echo "Usage: cua-local.sh click [x y]" >&2
      exit 2
    fi
    ;;
  right-click)
    if [[ $# -ne 2 ]]; then
      echo "Usage: cua-local.sh right-click <x> <y>" >&2
      exit 2
    fi
    exec "$CUA_BIN" do click "$1" "$2" right
    ;;
  double-click)
    if [[ $# -eq 0 ]]; then
      run_cua click
      sleep "$ACTION_DELAY"
      exec "$CUA_BIN" do click
    elif [[ $# -eq 2 ]]; then
      run_cua click "$1" "$2"
      sleep "$ACTION_DELAY"
      exec "$CUA_BIN" do click "$1" "$2"
    else
      echo "Usage: cua-local.sh double-click [x y]" >&2
      exit 2
    fi
    ;;
  drag)
    if [[ $# -ne 4 ]]; then
      echo "Usage: cua-local.sh drag <x1> <y1> <x2> <y2>" >&2
      exit 2
    fi
    exec "$CUA_BIN" do drag "$1" "$2" "$3" "$4"
    ;;
  scroll)
    if [[ $# -lt 1 || $# -gt 2 ]]; then
      echo "Usage: cua-local.sh scroll <up|down> [amount]" >&2
      exit 2
    fi
    exec "$CUA_BIN" do scroll "$1" "${2:-3}"
    ;;
  type)
    if [[ $# -lt 1 ]]; then
      echo "Usage: cua-local.sh type <text>" >&2
      exit 2
    fi
    exec "$CUA_BIN" do type "$*"
    ;;
  paste)
    if [[ $# -lt 1 ]]; then
      echo "Usage: cua-local.sh paste <text>" >&2
      exit 2
    fi
    printf '%s' "$*" | pbcopy
    exec "$CUA_BIN" do hotkey cmd+v
    ;;
  key)
    if [[ $# -ne 1 ]]; then
      echo "Usage: cua-local.sh key <key>" >&2
      exit 2
    fi
    exec "$CUA_BIN" do key "$1"
    ;;
  hotkey)
    if [[ $# -ne 1 ]]; then
      echo "Usage: cua-local.sh hotkey <combo>" >&2
      exit 2
    fi
    exec "$CUA_BIN" do hotkey "$1"
    ;;
  open-url)
    if [[ $# -ne 1 ]]; then
      echo "Usage: cua-local.sh open-url <url>" >&2
      exit 2
    fi
    exec open "$1"
    ;;
  browser-open)
    if [[ $# -ne 1 ]]; then
      echo "Usage: cua-local.sh browser-open <url>" >&2
      exit 2
    fi
    open -a "$DEFAULT_BROWSER" "$1"
    sleep 1
    ensure_frontmost "$DEFAULT_BROWSER" 10
    wait_for_window "$DEFAULT_BROWSER" 10
    ;;
  navigate|goto-url|browser-goto)
    if [[ $# -ne 1 ]]; then
      echo "Usage: cua-local.sh navigate <url>" >&2
      exit 2
    fi
    with_failure_snapshot ensure_frontmost "$DEFAULT_BROWSER" 10
    sleep 0.2
    run_cua hotkey cmd+l
    sleep 0.2
    run_cua type "$1"
    sleep 0.2
    exec "$CUA_BIN" do key enter
    ;;
  address-bar)
    exec "$CUA_BIN" do hotkey cmd+l
    ;;
  new-tab)
    exec "$CUA_BIN" do hotkey cmd+t
    ;;
  close-tab)
    exec "$CUA_BIN" do hotkey cmd+w
    ;;
  back)
    exec "$CUA_BIN" do hotkey cmd+[
    ;;
  forward)
    exec "$CUA_BIN" do hotkey cmd+]
    ;;
  tab|tab-n)
    if [[ $# -ne 1 ]]; then
      echo "Usage: cua-local.sh tab-n <count>" >&2
      exit 2
    fi
    count="$1"
    for _ in $(seq 1 "$count"); do
      run_cua key tab
      sleep "$ACTION_DELAY"
    done
    ;;
  press|press-seq)
    if [[ $# -lt 1 ]]; then
      echo "Usage: cua-local.sh press <key1> [key2 ...]" >&2
      exit 2
    fi
    for k in "$@"; do
      run_cua key "$k"
      sleep "$ACTION_DELAY"
    done
    ;;
  submit)
    exec "$CUA_BIN" do key enter
    ;;
  fill-form|form-fill)
    if [[ $# -lt 2 ]]; then
      echo "Usage: cua-local.sh form-fill <tab_count_before_field1> <value1> [tab_count_before_field2 value2 ...]" >&2
      exit 2
    fi
    if (( $# % 2 != 0 )); then
      echo "form-fill requires pairs: <tab_count> <value> ..." >&2
      exit 2
    fi
    while [[ $# -gt 0 ]]; do
      tabs="$1"
      value="$2"
      shift 2
      for _ in $(seq 1 "$tabs"); do
        run_cua key tab
        sleep "$ACTION_DELAY"
      done
      run_cua type "$value"
      sleep 0.2
    done
    ;;
  safe-step)
    if [[ $# -lt 2 ]]; then
      echo "Usage: cua-local.sh safe-step <wait_seconds> <subcommand...>" >&2
      exit 2
    fi
    before=$("$0" screenshot-path)
    "$0" "${@:2}"
    sleep "$1"
    after=$("$0" screenshot-path)
    printf 'before=%s\nafter=%s\n' "$before" "$after"
    ;;
  refresh)
    exec "$CUA_BIN" do hotkey cmd+r
    ;;
  raw|shell)
    if [[ $# -lt 1 ]]; then
      echo "Usage: cua-local.sh raw <cua do subcommand...>" >&2
      exit 2
    fi
    exec "$CUA_BIN" do "$@"
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    exit 2
    ;;
esac
