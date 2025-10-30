.PHONY: help minikube-start minikube-start-verbose minikube-logs minikube-docker-logs minikube-stop minikube-delete minikube-status minikube-dashboard minikube-dashboard-open minikube-dashboard-stop minikube-dashboard-url k8s-nodes k8s-contexts cluster-info helm-version k kubectl-mk mkubectl kubectl-reconcile

# Tunables for SSH bridge enforcement during start
# Override at invocation time, e.g.:
#   make ENSURE_BRIDGE_SECS=60 ENSURE_BRIDGE_INTERVAL_SECS=0.2 minikube-start-verbose
ENSURE_BRIDGE_SECS ?= 35
ENSURE_BRIDGE_INTERVAL_SECS ?= 0.25
export ENSURE_BRIDGE_SECS
export ENSURE_BRIDGE_INTERVAL_SECS

help:
	@echo "Available targets:"
	@echo "  minikube-start      Start a minikube cluster using Docker driver"
	@echo "  minikube-start-verbose  Start with verbose logging and longer timeout (pass extra ARGS=...)"
	@echo "  minikube-stop       Stop the minikube cluster"
	@echo "  minikube-delete     Delete the minikube cluster"
	@echo "  minikube-status     Show minikube status"
	@echo "  minikube-dashboard  Open the Kubernetes dashboard (non-blocking, uses host browser if available)"
	@echo "  minikube-dashboard-open  Start dashboard proxy in background and open in host browser"
	@echo "  minikube-dashboard-url   Print dashboard URL (starts proxy if needed)"
	@echo "  minikube-dashboard-stop  Stop dashboard proxy"
	@echo "  minikube-logs       Print recent minikube logs"
	@echo "  minikube-docker-logs  Print docker logs of the minikube node"
	@echo "  k8s-nodes           Show Kubernetes nodes"
	@echo "  k8s-contexts        List kubeconfig contexts"
	@echo "  cluster-info        Show cluster info"
	@echo "  helm-version        Show Helm client/server version"
	@echo "  k / kubectl-mk      Use version-matched kubectl via 'minikube kubectl --' (pass CMD=...)"
	@echo "  kubectl-reconcile   Install kubectl matching the cluster server version"

minikube-start:
	# Ensure SSH bridge watcher is running and aggressively establish port forward during startup
	( bash .devcontainer/minikube-ssh-forwarder.sh run >/dev/null 2>&1 || true )
	( nohup bash .devcontainer/minikube-ensure-ssh-bridge.sh >/dev/null 2>&1 & )
	minikube start --driver=docker --native-ssh=false
	# Reconcile kubectl to the server version (non-fatal on failure)
	( bash .devcontainer/reconcile-kubectl.sh >/dev/null 2>&1 || true )

minikube-start-verbose:
	# Ensure SSH bridge watcher is running and aggressively establish port forward during startup
	( bash .devcontainer/minikube-ssh-forwarder.sh run >/dev/null 2>&1 || true )
	( nohup bash .devcontainer/minikube-ensure-ssh-bridge.sh >/dev/null 2>&1 & )
	minikube start --driver=docker --native-ssh=false --alsologtostderr -v=7 --wait-timeout=10m $(ARGS)
	# Reconcile kubectl to the server version (non-fatal on failure)
	( bash .devcontainer/reconcile-kubectl.sh >/dev/null 2>&1 || true )

minikube-stop:
	minikube stop

minikube-delete:
	minikube delete

minikube-status:
	minikube status

minikube-dashboard:
	bash .devcontainer/minikube-dashboard.sh open

minikube-dashboard-open:
	bash .devcontainer/minikube-dashboard.sh open

minikube-dashboard-url:
	bash .devcontainer/minikube-dashboard.sh url

minikube-dashboard-stop:
	bash .devcontainer/minikube-dashboard.sh stop

k8s-nodes:
	kubectl get nodes -o wide

k8s-contexts:
	kubectl config get-contexts

cluster-info:
	kubectl cluster-info

helm-version:
	helm version

# Version-matched kubectl via minikube (pass CMD='get pods -A', etc.)
k kubectl-mk mkubectl:
	@minikube kubectl -- $(CMD)

kubectl-reconcile:
	bash .devcontainer/reconcile-kubectl.sh

minikube-logs:
	minikube logs --file=- | tail -n 200 || true

minikube-docker-logs:
	docker logs minikube --tail=200 || true
