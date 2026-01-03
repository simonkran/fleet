.PHONY: help validate-staging validate-production diff-staging diff-production reconcile-staging reconcile-production status-staging status-production install-flux-operator bootstrap-staging bootstrap-production

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-30s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

validate-staging: ## Validate staging cluster configuration
	@echo "Validating staging cluster configuration..."
	kubectl apply --dry-run=client -k clusters/staging/flux-system

validate-production: ## Validate production cluster configuration
	@echo "Validating production cluster configuration..."
	kubectl apply --dry-run=client -k clusters/production/flux-system

diff-staging: ## Show diff for staging cluster
	@echo "Diff for staging cluster:"
	kubectl diff -k clusters/staging/flux-system || true

diff-production: ## Show diff for production cluster
	@echo "Diff for production cluster:"
	kubectl diff -k clusters/production/flux-system || true

reconcile-staging: ## Force reconciliation for staging cluster
	@echo "Forcing reconciliation for staging cluster..."
	flux reconcile source git flux-system
	flux reconcile source git infra
	flux reconcile source git apps
	flux reconcile kustomization infra
	flux reconcile kustomization apps

reconcile-production: ## Force reconciliation for production cluster
	@echo "Forcing reconciliation for production cluster..."
	flux reconcile source git flux-system
	flux reconcile source git infra
	flux reconcile source git apps
	flux reconcile kustomization infra
	flux reconcile kustomization apps

status-staging: ## Check status of staging cluster resources
	@echo "=== FluxInstance Status ==="
	kubectl get fluxinstance -n flux-system
	@echo ""
	@echo "=== GitRepository Status ==="
	kubectl get gitrepository -n flux-system
	@echo ""
	@echo "=== Kustomization Status ==="
	kubectl get kustomization -n flux-system

status-production: ## Check status of production cluster resources
	@echo "=== FluxInstance Status ==="
	kubectl get fluxinstance -n flux-system
	@echo ""
	@echo "=== GitRepository Status ==="
	kubectl get gitrepository -n flux-system
	@echo ""
	@echo "=== Kustomization Status ==="
	kubectl get kustomization -n flux-system

install-flux-operator: ## Install Flux Operator
	@echo "Installing Flux Operator..."
	kubectl apply -f https://github.com/controlplaneio/flux-operator/releases/latest/download/install.yaml
	@echo "Waiting for Flux Operator to be ready..."
	kubectl wait --for=condition=available --timeout=300s deployment/flux-operator -n flux-operator-system

bootstrap-staging: ## Bootstrap staging cluster
	@echo "Bootstrapping staging cluster..."
	@if [ -z "$$GITHUB_TOKEN" ]; then \
		echo "Error: GITHUB_TOKEN environment variable is not set"; \
		exit 1; \
	fi
	@kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic flux-system \
		--namespace flux-system \
		--from-literal=username=git \
		--from-literal=password=$$GITHUB_TOKEN \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -k clusters/staging/flux-system
	@echo "Staging cluster bootstrapped successfully"

bootstrap-production: ## Bootstrap production cluster
	@echo "Bootstrapping production cluster..."
	@if [ -z "$$GITHUB_TOKEN" ]; then \
		echo "Error: GITHUB_TOKEN environment variable is not set"; \
		exit 1; \
	fi
	@kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic flux-system \
		--namespace flux-system \
		--from-literal=username=git \
		--from-literal=password=$$GITHUB_TOKEN \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -k clusters/production/flux-system
	@echo "Production cluster bootstrapped successfully"
