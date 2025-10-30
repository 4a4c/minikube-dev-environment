#!/usr/bin/env bash
# Aggressively ensure the SSH bridge is established during minikube start/create
# Usage: minikube-ensure-ssh-bridge.sh [duration_seconds]
#
# Tunables (env):
#   ENSURE_BRIDGE_SECS            Total duration to keep enforcing (default 35)
#   ENSURE_BRIDGE_INTERVAL_SECS   Interval between attempts (default 0.25)
set -euo pipefail

# Prefer env override, then positional arg, then default
DURATION="${ENSURE_BRIDGE_SECS:-${1:-35}}"
INTERVAL="${ENSURE_BRIDGE_INTERVAL_SECS:-0.25}"

END=$(( $(date +%s) + DURATION ))
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FORWARDER="$SCRIPT_DIR/minikube-ssh-forwarder.sh"

# Ensure watcher is running
bash "$FORWARDER" run || true

# Tight loop to catch the moment the host port appears and immediately forward it
while [ "$(date +%s)" -lt "$END" ]; do
  bash "$FORWARDER" once || true
  # small sleep for responsiveness (supports fractional seconds)
  sleep "$INTERVAL" 2>/dev/null || {
    # fallback for shells without fractional sleep
    usleep 250000 2>/dev/null || sleep 1
  }
done
