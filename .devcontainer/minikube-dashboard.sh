#!/usr/bin/env bash
# Manage Kubernetes dashboard via minikube without blocking the terminal
# Usage:
#   minikube-dashboard.sh start   # start proxy in background, print URL
#   minikube-dashboard.sh open    # start (if needed), open URL on host via $BROWSER, print URL
#   minikube-dashboard.sh url     # print URL if known (tries to start if not running)
#   minikube-dashboard.sh stop    # stop background proxy
#   minikube-dashboard.sh status  # show status and URL if available

set -euo pipefail
LOG_FILE="/tmp/minikube-dashboard.out"
PID_FILE="/tmp/minikube-dashboard.pid"
SCRIPT_NAME="$(basename "$0")"

log() { >&2 echo "[$SCRIPT_NAME] $*"; }

is_running() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

extract_url() {
  # Grep the first valid http URL printed by minikube
  if [[ -f "$LOG_FILE" ]]; then
    grep -Eo 'http://127\.0\.0\.1:[0-9]+/[^ ]*' "$LOG_FILE" | tail -n1 || true
  fi
}

start_bg() {
  if is_running; then
    log "dashboard already running (pid $(cat "$PID_FILE"))"
    return 0
  fi
  : > "$LOG_FILE"
  # Start dashboard proxy in background; --url prints the URL once and then continues serving
  nohup minikube dashboard --url >>"$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  log "started dashboard in background (pid $(cat "$PID_FILE"))"
}

wait_for_url() {
  local tries=100
  local sleep_s=0.2
  local url=""
  for ((i=0; i<tries; i++)); do
    url="$(extract_url)"
    if [[ -n "$url" ]]; then
      echo "$url"
      return 0
    fi
    sleep "$sleep_s"
  done
  # Fallback: try to query URL directly once (may briefly start a foreground proxy). Use timeout to avoid blocking.
  if command -v timeout >/dev/null 2>&1; then
    url="$(timeout 3s minikube dashboard --url 2>/dev/null | head -n1 || true)"
    if [[ -n "$url" ]]; then
      echo "$url"
      return 0
    fi
  fi
  return 1
}

cmd_start() {
  start_bg
  if ! url="$(wait_for_url)"; then
    log "URL not detected yet; check logs at $LOG_FILE"
    exit 1
  fi
  echo "$url"
}

cmd_open() {
  url="$(cmd_start)"
  if [[ -n "${BROWSER:-}" ]]; then
    "$BROWSER" "$url" >/dev/null 2>&1 & disown || true
    log "opened in host browser: $url"
  else
    log "BROWSER not set; open manually: $url"
  fi
  echo "$url"
}

cmd_url() {
  if ! is_running; then
    cmd_start
    return
  fi
  url="$(extract_url)"
  if [[ -z "$url" ]]; then
    if ! url="$(wait_for_url)"; then
      log "URL not detected; check logs at $LOG_FILE"
      exit 1
    fi
  fi
  echo "$url"
}

cmd_stop() {
  if is_running; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
  fi
  rm -f "$PID_FILE" "$LOG_FILE" 2>/dev/null || true
  log "dashboard stopped"
}

cmd_status() {
  if is_running; then
    echo "running (pid $(cat "$PID_FILE"))"
    extract_url || true
  else
    echo "stopped"
  fi
}

case "${1:-status}" in
  start) cmd_start ;;
  open) cmd_open ;;
  url) cmd_url ;;
  stop) cmd_stop ;;
  status) cmd_status ;;
  *) echo "Usage: $0 [start|open|url|stop|status]" 1>&2; exit 2 ;;
 esac
