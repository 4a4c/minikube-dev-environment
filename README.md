# k8s-supervised-learning-demo

Developer environment configured with a Dev Container that includes kubectl, Helm, and Minikube, and connects to your host Docker (OrbStack or Docker Desktop).

## Quick start

1. **Open in VS Code and build the Dev Container**:
   - Command Palette → "Dev Containers: Reopen in Container"
   - Wait for the build to complete (installs kubectl, helm, minikube, zsh, Oh My Zsh)

2. **Start a local Kubernetes cluster**:
   ```bash
   make minikube-start
   ```
   - This creates a single-node cluster using the Docker driver
   - kubectl is auto-reconciled to match the cluster version (v1.34.0)
   - Takes ~30-60s on first run

3. **Verify everything works**:
   ```bash
   make minikube-status      # Check cluster health
   kubectl get nodes         # Should show 1 Ready node
   kubectl get pods -A       # List all system pods
   ```

4. **Optional: Open the Kubernetes Dashboard**:
   - Via task: Command Palette → "Tasks: Run Task" → "Minikube: Dashboard (Open)"
   - Or: `make minikube-dashboard`
   - Or: Press `Ctrl+Alt+D` (opens in your host browser)

5. **Stop/delete when done**:
   ```bash
   make minikube-stop        # Pause the cluster (keeps state)
   make minikube-delete      # Fully remove the cluster
   ```

## Host integrations

- Kubeconfig: `~/.kube` → `/home/vscode/.kube` (shared with host)
- Helm config: `~/.config/helm` → `/home/vscode/.config/helm` (shared with host)
- Minikube state: stored in Docker volume `minikube-data` (container-local, persists across rebuilds)
- Docker socket:
  - OrbStack (default): `${HOME}/.orbstack/run/docker.sock` → `/var/run/docker.sock`
  - Docker Desktop or native Linux: toggle the commented alternative in `.devcontainer/devcontainer.json` under "Docker backend: choose ONE" to use `/var/run/docker.sock`.

**Note**: Minikube state is kept inside the container (not synced to host) to avoid path conflicts. Your kubeconfig in `~/.kube` will still reference the minikube cluster correctly.

## Working with the environment

You can use Makefile targets, VS Code tasks, or direct commands.

### Common workflows

**Starting fresh**:
```bash
make minikube-start          # Create and start cluster
make minikube-status         # Verify it's running
kubectl get pods -A          # Check system pods
```

**Daily usage**:
```bash
kubectl get nodes            # List cluster nodes
kubectl get pods -A          # List all pods
make cluster-info            # Show endpoints
make minikube-dashboard      # Open dashboard in browser
```

**Version-matched kubectl**:
```bash
make k CMD='get pods -A'     # Use minikube's embedded kubectl (always matched)
make kubectl-reconcile       # Install kubectl binary matching cluster version
```

**Cleanup**:
```bash
make minikube-stop           # Pause cluster (state preserved)
make minikube-delete         # Remove cluster completely
```

### All Makefile targets

Run `make help` or `make` to see all available targets:

**Cluster management**:
- `minikube-start` — Start cluster (auto-reconciles kubectl)
- `minikube-start-verbose` — Start with debug logging
- `minikube-stop` — Stop cluster
- `minikube-delete` — Delete cluster
- `minikube-status` — Show cluster status
- `minikube-logs` — Print recent minikube logs
- `minikube-docker-logs` — Print Docker container logs

**Dashboard**:
- `minikube-dashboard` — Open dashboard (non-blocking)
- `minikube-dashboard-url` — Print dashboard URL
- `minikube-dashboard-stop` — Stop dashboard proxy

**Kubernetes**:
- `k8s-nodes` — Show nodes
- `k8s-contexts` — List kubeconfig contexts
- `cluster-info` — Show cluster endpoints
- `k` / `kubectl-mk` — Version-matched kubectl (pass `CMD='...'`)
- `kubectl-reconcile` — Install kubectl matching server version

**Helm**:
- `helm-version` — Show Helm version

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

### VS Code integration

**Tasks**: Command Palette → "Tasks: Run Task" and pick one of:
- Minikube: Start / Stop / Delete / Status
- Kubernetes: Nodes / Contexts / Cluster Info
- Helm: Version
- Dashboard: Open / URL / Stop

**Status bar buttons** (requires extension install prompt on first use):
- 🎯 Minikube — Open dashboard
- 🔗 Dashboard URL — Print URL
- ⏹️ Stop Dashboard — Stop proxy

**Keyboard shortcuts**:
- `Ctrl+Alt+D` — Open dashboard
- `Ctrl+Alt+U` — Print dashboard URL
- `Ctrl+Alt+X` — Stop dashboard

## Shell & prompt

- Default shell: `zsh`
- Oh My Zsh is installed automatically (or mounted from host if present)

## Troubleshooting

**"Connection refused" when running `minikube status` directly**:
- The SSH forwarder auto-starts on every new terminal
- If you see this after a rebuild, open a new terminal or run: `make minikube-status` (self-healing)

**Permission denied on Docker socket**:
- Open a new terminal after container starts (auto-aligns docker group GID and ACLs)

**kubectl version skew warning**:
- Run `make kubectl-reconcile` to install a kubectl matching your cluster
- Or use the matched client: `make k CMD='get pods -A'`

**Switching Docker backends** (OrbStack ↔ Docker Desktop):
- Edit `.devcontainer/devcontainer.json` and flip the commented mount under "Docker backend: choose ONE"
- Rebuild the container

**After `minikube delete`, start fails with SSH errors**:
- This should be fixed automatically by the aggressive SSH bridge during start
- If you still see issues, try: `make ENSURE_BRIDGE_SECS=60 minikube-start-verbose`
