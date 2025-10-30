# k8s-supervised-learning-demo

Developer environment is configured with a Dev Container that includes kubectl, Helm, and Minikube, and connects to your host Docker (OrbStack or Docker Desktop).

## Quick start

1. Open in VS Code and Rebuild the Dev Container:
   - Command Palette → "Dev Containers: Rebuild Container"
2. Verify tools:
   - `kubectl version --client`
   - `helm version`
   - `docker ps`

## Host integrations

- Kubeconfig: `~/.kube` → `/home/vscode/.kube` (shared with host)
- Helm config: `~/.config/helm` → `/home/vscode/.config/helm` (shared with host)
- Minikube state: stored in Docker volume `minikube-data` (container-local, persists across rebuilds)
- Docker socket:
  - OrbStack (default): `${HOME}/.orbstack/run/docker.sock` → `/var/run/docker.sock`
  - Docker Desktop or native Linux: toggle the commented alternative in `.devcontainer/devcontainer.json` under "Docker backend: choose ONE" to use `/var/run/docker.sock`.

**Note**: Minikube state is kept inside the container (not synced to host) to avoid path conflicts. Your kubeconfig in `~/.kube` will still reference the minikube cluster correctly.

## Using Minikube

You can use Makefile targets or VS Code tasks.

### Makefile targets

- Start cluster: `make minikube-start`
- Stop cluster: `make minikube-stop`
- Delete cluster: `make minikube-delete`
- Status: `make minikube-status`
- Dashboard: `make minikube-dashboard`
- Nodes: `make k8s-nodes`
- Contexts: `make k8s-contexts`
- Cluster info: `make cluster-info`
- Helm version: `make helm-version`
- Version-matched kubectl: `make k CMD='get pods -A'`
- Reconcile kubectl to cluster version: `make kubectl-reconcile`

### SSH forwarding inside Dev Container

When using the Docker driver, Minikube exposes the node's SSH on a host loopback port (e.g., 127.0.0.1:32823). Inside this devcontainer, 127.0.0.1 refers to the container, not the host, so the CLI couldn't reach the node by default.

To fix this seamlessly, the devcontainer starts a tiny background forwarder that bridges the exposed host port back to the container via host.docker.internal. It's idempotent and auto-starts on container boot.

Manual control if needed:
- Ensure running: `.devcontainer/minikube-ssh-forwarder.sh run`
- One-shot setup: `.devcontainer/minikube-ssh-forwarder.sh once`
- Stop it: `.devcontainer/minikube-ssh-forwarder.sh stop`

You can tune how aggressively we enforce the SSH bridge during `minikube start` with environment variables passed to Make:

- `ENSURE_BRIDGE_SECS` (default 35): total seconds to keep probing/forwarding during start
- `ENSURE_BRIDGE_INTERVAL_SECS` (default 0.25): seconds between attempts

Example:

```
make ENSURE_BRIDGE_SECS=60 ENSURE_BRIDGE_INTERVAL_SECS=0.2 minikube-start-verbose
```

### kubectl compatibility tip

If you see a kubectl version skew warning, prefer using the version-matched kubectl embedded in Minikube:

- Ad-hoc: `minikube kubectl -- get pods -A`
- Via Makefile: `make k CMD='get pods -A'`

This devcontainer also auto-reconciles `/usr/local/bin/kubectl` to match the running cluster version immediately after `minikube start`. If the download fails (e.g., offline), it will be skipped without blocking; you can:

- Re-run: `make kubectl-reconcile`
- Or use the embedded client: `make k CMD='...'`

### VS Code tasks

Command Palette → "Tasks: Run Task" and pick one of:

- Minikube: Start / Stop / Delete / Status
- Kubernetes: Nodes / Contexts / Cluster Info
- Helm: Version
 - Dashboard: Open / URL / Stop

## Shell & prompt

- Default shell: `zsh`
- Oh My Zsh is installed automatically (or mounted from host if present)

## Troubleshooting

- Permission denied on Docker socket:
  - Open a new terminal or reload the window after container starts
  - The container auto-aligns the docker group GID and sets ACLs
- `newgrp` starts the wrong shell:
  - The container sets zsh as the login shell; open a new terminal
- OrbStack vs Docker Desktop:
  - Update the docker socket mount path in `.devcontainer/devcontainer.json` accordingly
