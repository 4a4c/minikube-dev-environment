#!/bin/bash
# Install kubectl, helm, minikube, and ACL utilities for the devcontainer

set -e

# Use sudo if available; otherwise run as root
if command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

echo "Installing system packages..."
$SUDO apt-get update
$SUDO apt-get install -y \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https \
    git \
    zsh \
    docker.io \
  acl \
  socat

echo "Setting up Kubernetes repository..."
$SUDO mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
    $SUDO gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
KUBE_LIST_FILE=/etc/apt/sources.list.d/kubernetes.list
if [ -n "$SUDO" ]; then
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | $SUDO tee "$KUBE_LIST_FILE" >/dev/null
else
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" > "$KUBE_LIST_FILE"
fi

echo "Installing kubectl..."
$SUDO apt-get update
$SUDO apt-get install -y kubectl

echo "Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "Installing minikube..."
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    MINIKUBE_ARCH=arm64
else
    MINIKUBE_ARCH=amd64
fi
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-$MINIKUBE_ARCH
$SUDO install minikube /usr/local/bin/
rm minikube

echo "Configuring user permissions..."
# Add both possible users; ignore if not present
($SUDO usermod -aG docker vscode || true)
($SUDO usermod -aG docker root || true)

echo "Installing Oh My Zsh for vscode (idempotent)..."
# If host mount provides ~/.oh-my-zsh, this will detect and skip
if [ ! -d "/home/vscode/.oh-my-zsh" ]; then
  $SUDO -u vscode bash -lc 'export RUNZSH=no CHSH=no KEEP_ZSHRC=yes; curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash' || true
fi

echo "Ensuring zsh is listed in /etc/shells and set as default for vscode..."
ZSHELL_PATH=$(command -v zsh || echo "/usr/bin/zsh")
if ! grep -qxF "$ZSHELL_PATH" /etc/shells; then
  echo "$ZSHELL_PATH" | $SUDO tee -a /etc/shells >/dev/null
fi
($SUDO chsh -s "$ZSHELL_PATH" vscode || true)

echo "Making devcontainer helper scripts executable..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

echo "Setup complete!"
