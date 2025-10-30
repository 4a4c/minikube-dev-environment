#!/usr/bin/env bash
# Bridge minikube node SSH port from host to devcontainer localhost
# so minikube CLI inside the devcontainer can reach the node's SSH.
#
# How it works:
# - The minikube docker driver publishes the node container's 22/tcp to a host port (e.g., 127.0.0.1:32823).
# - From inside the devcontainer, 127.0.0.1 refers to the devcontainer, not the host.
# - We run a tiny socat forwarder that listens on devcontainer's 0.0.0.0:$PORT and forwards to host.docker.internal:$PORT.
# - This makes the minikube CLI's attempts to ssh to 127.0.0.1:$PORT work transparently.
#
# Usage:
#   ./minikube-ssh-forwarder.sh run   # start a background watcher
#   ./minikube-ssh-forwarder.sh once  # perform one attempt to forward current port
#   ./minikube-ssh-forwarder.sh stop  # stop any forwarders and watcher

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
PID_DIR="/tmp"
WATCHER_PID_FILE="$PID_DIR/minikube-ssh-forwarder.watcher.pid"
SOCAT_PID_PREFIX="$PID_DIR/minikube-socat"

log() { echo "[$SCRIPT_NAME] $*"; }

minikube_host_port() {
  docker container inspect -f '{{(index (index .NetworkSettings.Ports "22/tcp") 0).HostPort}}' minikube 2>/dev/null || true
}

is_forwarder_running() {
  local port="$1"
  local pid_file="$SOCAT_PID_PREFIX.$port.pid"
  if [ -f "$pid_file" ]; then
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    # stale pid file
    rm -f "$pid_file" || true
  fi
  return 1
}

start_forward_for_port() {
  local port="$1"
  if [ -z "$port" ]; then
    return 1
  fi
  if is_forwarder_running "$port"; then
    return 0
  fi
  log "Starting socat forwarder for port $port -> host.docker.internal:$port"
  nohup socat TCP-LISTEN:"$port",fork,reuseaddr TCP:host.docker.internal:"$port" >"$PID_DIR/socat.$port.log" 2>&1 &
  echo $! >"$SOCAT_PID_PREFIX.$port.pid"
}

stop_all_forwarders() {
  for f in "$SOCAT_PID_PREFIX".*.pid; do
    [ -e "$f" ] || continue
    pid="$(cat "$f" || true)"
    if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
      log "Stopping socat pid $pid from $f"
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$f" || true
  done
}

run_once() {
  local port
  port="$(minikube_host_port)"
  if [ -z "$port" ]; then
    log "minikube host SSH port not found yet; nothing to forward"
    return 0
  fi
  start_forward_for_port "$port" || true
}

run_watcher() {
  echo $$ >"$WATCHER_PID_FILE"
  log "Watcher started (pid $$)"
  while true; do
    run_once || true
    sleep 2
  done
}

stop_watcher() {
  if [ -f "$WATCHER_PID_FILE" ]; then
    local pid
    pid="$(cat "$WATCHER_PID_FILE" || true)"
    if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
      log "Stopping watcher pid $pid"
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$WATCHER_PID_FILE" || true
  fi
}

case "${1:-run}" in
  run)
    # If a watcher is already running, exit silently
    if [ -f "$WATCHER_PID_FILE" ]; then
      existing="$(cat "$WATCHER_PID_FILE" || true)"
      if [ -n "${existing:-}" ] && kill -0 "$existing" 2>/dev/null; then
        log "Watcher already running (pid $existing)"
        exit 0
      fi
    fi
    run_watcher &
    disown || true
    ;;
  once)
    run_once
    ;;
  stop)
    stop_watcher
    stop_all_forwarders
    ;;
  *)
    echo "Usage: $0 [run|once|stop]" 1>&2
    exit 2
    ;;

esac
