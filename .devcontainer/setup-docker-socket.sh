#!/bin/bash
# Configure Docker socket permissions for the vscode user

# Use sudo if available; otherwise run as root
if command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

if [ ! -S /var/run/docker.sock ]; then
    echo "Docker socket not found, skipping permission setup"
    exit 0
fi

if [ ! -S /var/run/docker.sock ]; then
    echo "Docker socket not found, skipping permission setup (will still start SSH forwarder)"
else
    echo "Configuring Docker socket permissions..."

    # Get the group ID of the Docker socket
    DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)

    # Create or update the docker group to match the socket's GID
    if getent group docker >/dev/null; then
        $SUDO groupmod -o -g "$DOCKER_GID" docker || true
    else
        $SUDO groupadd -g "$DOCKER_GID" docker || true
    fi

    # Add vscode and root users to the docker group (ignore if user doesn't exist)
    ($SUDO usermod -aG docker vscode || true)
    ($SUDO usermod -aG docker root || true)

    # Ensure the socket has group read/write permissions
    $SUDO chmod g+rw /var/run/docker.sock || true

    # Set ACL to grant vscode user direct access (fallback for root:root owned sockets)
    if command -v setfacl >/dev/null 2>&1; then
        $SUDO setfacl -m u:vscode:rw /var/run/docker.sock || true
    fi

    echo "Docker socket permissions configured successfully"
fi

# Create or update the docker group to match the socket's GID
if getent group docker >/dev/null; then
    $SUDO groupmod -o -g "$DOCKER_GID" docker || true
else
    $SUDO groupadd -g "$DOCKER_GID" docker || true
fi

# Add vscode and root users to the docker group (ignore if user doesn't exist)
($SUDO usermod -aG docker vscode || true)
($SUDO usermod -aG docker root || true)

# Ensure the socket has group read/write permissions
$SUDO chmod g+rw /var/run/docker.sock || true

# Set ACL to grant vscode user direct access (fallback for root:root owned sockets)
if command -v setfacl >/dev/null 2>&1; then
    $SUDO setfacl -m u:vscode:rw /var/run/docker.sock || true
fi

echo "Docker socket permissions configured successfully"

echo "Ensuring minikube data directory ownership..."
MINIKUBE_DIR="/home/vscode/.minikube"
$SUDO mkdir -p "$MINIKUBE_DIR" || true
$SUDO chown -R vscode:vscode "$MINIKUBE_DIR" || true
$SUDO chmod -R u+wrx,g+rx "$MINIKUBE_DIR" || true
echo "Minikube directory permissions set for user vscode"

# Start a background watcher to bridge the minikube SSH port from host to container localhost
# Use relative path from script location to avoid workspace mount timing issues
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORWARDER="$SCRIPT_DIR/minikube-ssh-forwarder.sh"
if [ -f "$FORWARDER" ]; then
  echo "Starting minikube SSH forwarder watcher (idempotent)..."
  bash "$FORWARDER" run || true
else
  echo "Forwarder script not found: $FORWARDER"
fi
