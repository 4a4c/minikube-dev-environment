#!/usr/bin/env bash
# Reconcile /usr/local/bin/kubectl to match the Kubernetes server version used by minikube
# Strategy: detect server version via `minikube kubectl -- version`, download exact kubectl from dl.k8s.io,
# verify sha256, and atomically install to /usr/local/bin/kubectl.

set -euo pipefail

SCRIPT_NAME="kubectl-reconcile"
log() { echo "[$SCRIPT_NAME] $*" >&2; }

# Sudo helper
if command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log "Missing required command: $1"; exit 1; }
}

require_cmd curl
require_cmd sha256sum

# Ensure minikube is available
if ! command -v minikube >/dev/null 2>&1; then
  log "minikube is not installed or not in PATH"
  exit 1
fi

# Detect server version from the running cluster using minikube's kubectl
detect_server_version() {
  local v json line
  # Try JSON first
  if json=$(minikube kubectl -- version -o json 2>/dev/null); then
    v=$(printf '%s' "$json" | sed -n 's/.*"gitVersion"[[:space:]]*:[[:space:]]*"\(v[0-9]\+\.[0-9]\+\.[0-9]\+\)".*/\1/p' | head -n1 || true)
    if [ -n "${v:-}" ]; then
      echo "$v"
      return 0
    fi
  fi
  # Fallback: short text output
  if line=$(minikube kubectl -- version --short 2>/dev/null | grep -i 'Server Version' || true); then
    v=$(printf '%s' "$line" | sed -n 's/.*Server Version:[[:space:]]*\(v[0-9][0-9.]*\).*/\1/p' || true)
    if [ -n "${v:-}" ]; then
      echo "$v"
      return 0
    fi
  fi
  return 1
}

SERVER_VER="$(detect_server_version || true)"
if [ -z "${SERVER_VER:-}" ]; then
  log "Could not detect Kubernetes server version. Is the cluster up?"
  exit 1
fi

# Map architecture
UNAME_M="$(uname -m)"
case "$UNAME_M" in
  aarch64|arm64)
    ARCH="arm64" ;;
  x86_64|amd64)
    ARCH="amd64" ;;
  *)
    log "Unsupported architecture: $UNAME_M"; exit 1 ;;
esac

BASE_URL="https://dl.k8s.io/release/${SERVER_VER}/bin/linux/${ARCH}"
TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR" >/dev/null 2>&1 || true; }
trap cleanup EXIT

log "Target kubectl version: ${SERVER_VER} (linux/${ARCH})"
log "Downloading kubectl and checksum from ${BASE_URL} ..."

curl -fsSL -o "$TMPDIR/kubectl" "${BASE_URL}/kubectl"
curl -fsSL -o "$TMPDIR/kubectl.sha256" "${BASE_URL}/kubectl.sha256"

pushd "$TMPDIR" >/dev/null
if ! echo "$(cat kubectl.sha256)  kubectl" | sha256sum -c - >/dev/null 2>&1; then
  log "Checksum verification failed for kubectl ${SERVER_VER}"; exit 1
fi
popd >/dev/null

chmod +x "$TMPDIR/kubectl"

DEST="/usr/local/bin/kubectl"
log "Installing kubectl to ${DEST} ..."
$SUDO install -m 0755 "$TMPDIR/kubectl" "$DEST"

# Verify the installed client version
INSTALLED_VER="$($DEST version --client -o json 2>/dev/null | sed -n 's/.*"gitVersion"[[:space:]]*:[[:space:]]*"\(v[0-9]\+\.[0-9]\+\.[0-9]\+\)".*/\1/p' | head -n1 || true)"
if [ -n "$INSTALLED_VER" ]; then
  log "Installed kubectl client: ${INSTALLED_VER}"
else
  log "Installed kubectl, but could not parse client version (non-fatal)"
fi

log "kubectl reconcile complete."