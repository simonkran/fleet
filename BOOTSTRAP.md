# Bootstrap Guide

This guide walks through bootstrapping your clusters with the fleet management system.

## Prerequisites

Before bootstrapping, ensure you have:

1. **Kubernetes Clusters**: Access to one or more Kubernetes clusters
2. **kubectl**: Configured to access your clusters
3. **flux CLI**: Install from https://fluxcd.io/flux/cmd/
4. **Git Access**: GitHub token or deploy key with repository access
5. **Cluster Admin**: cluster-admin RBAC permissions on target clusters

## Preparation

### 1. Set Up Repository References

This fleet repository references two additional repositories:
- `fleet-infra`: Infrastructure components
- `fleet-apps`: Application deployments

Update the repository URLs in cluster configurations:

```bash
export GITHUB_ORG="your-github-organization"

# Update staging cluster configs
find clusters/staging/flux-system -type f -name "*.yaml" -exec sed -i "s/\${GITHUB_ORG}/${GITHUB_ORG}/g" {} +

# Update production cluster configs
find clusters/production/flux-system -type f -name "*.yaml" -exec sed -i "s/\${GITHUB_ORG}/${GITHUB_ORG}/g" {} +

# Commit the changes
git add clusters/
git commit -m "Configure repository URLs for ${GITHUB_ORG}"
git push origin main
```

### 2. Create Supporting Repositories

Create the fleet-infra and fleet-apps repositories in your GitHub organization:

```bash
# Create fleet-infra repository
gh repo create ${GITHUB_ORG}/fleet-infra --public --description "Infrastructure components"

# Create fleet-apps repository
gh repo create ${GITHUB_ORG}/fleet-apps --public --description "Application deployments"
```

Initialize these repositories with basic structure:

**fleet-infra repository structure:**
```
fleet-infra/
├── clusters/
│   ├── staging/
│   │   └── kustomization.yaml
│   └── production/
│       └── kustomization.yaml
└── components/
    └── README.md
```

**fleet-apps repository structure:**
```
fleet-apps/
├── clusters/
│   ├── staging/
│   │   └── kustomization.yaml
│   └── production/
│       └── kustomization.yaml
└── components/
    └── README.md
```

### 3. Prepare Git Credentials

Create a GitHub personal access token with `repo` scope:

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scope: `repo` (Full control of private repositories)
4. Generate and save the token

```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

## Bootstrap Staging Cluster

### Step 1: Install Flux Operator

```bash
# Switch to staging cluster context
kubectl config use-context staging-cluster

# Install Flux Operator
make install-flux-operator

# Or manually:
kubectl apply -f https://github.com/controlplaneio/flux-operator/releases/latest/download/install.yaml

# Wait for operator to be ready
kubectl wait --for=condition=available --timeout=300s deployment/flux-operator -n flux-operator-system
```

### Step 2: Create Git Secret

```bash
# Create flux-system namespace
kubectl create namespace flux-system

# Create secret with GitHub token
kubectl create secret generic flux-system \
  --namespace flux-system \
  --from-literal=username=git \
  --from-literal=password=${GITHUB_TOKEN}
```

### Step 3: Apply FluxInstance

```bash
# Bootstrap staging cluster
make bootstrap-staging

# Or manually:
kubectl apply -k clusters/staging/flux-system
```

### Step 4: Verify Installation

```bash
# Check FluxInstance status
kubectl get fluxinstance -n flux-system

# Wait for FluxInstance to be ready
kubectl wait --for=condition=ready --timeout=5m fluxinstance/flux -n flux-system

# Check all Flux components are running
kubectl get pods -n flux-system

# Check GitRepository resources
kubectl get gitrepository -n flux-system

# Check Kustomization resources
kubectl get kustomization -n flux-system

# Check detailed status
make status-staging
```

### Step 5: Monitor Reconciliation

```bash
# Watch Flux logs
flux logs --all-namespaces --follow

# Check for any errors
kubectl get gitrepository -n flux-system -o wide
kubectl get kustomization -n flux-system -o wide
```

## Bootstrap Production Cluster

### Step 1: Tag Infrastructure and Apps

Before bootstrapping production, tag your fleet-infra and fleet-apps repositories:

```bash
# Tag fleet-infra
cd ../fleet-infra
git tag -a v1.0.0 -m "Initial production release"
git push origin v1.0.0

# Tag fleet-apps
cd ../fleet-apps
git tag -a v1.0.0 -m "Initial production release"
git push origin v1.0.0
```

### Step 2: Install Flux Operator

```bash
# Switch to production cluster context
kubectl config use-context production-cluster

# Install Flux Operator
make install-flux-operator
```

### Step 3: Create Git Secret

```bash
kubectl create namespace flux-system

kubectl create secret generic flux-system \
  --namespace flux-system \
  --from-literal=username=git \
  --from-literal=password=${GITHUB_TOKEN}
```

### Step 4: Apply FluxInstance

```bash
# Bootstrap production cluster
make bootstrap-production

# Or manually:
kubectl apply -k clusters/production/flux-system
```

### Step 5: Verify Installation

```bash
# Check status
make status-production

# Verify production is using semver tags
kubectl get gitrepository infra -n flux-system -o jsonpath='{.spec.ref.semver}'
kubectl get gitrepository apps -n flux-system -o jsonpath='{.spec.ref.semver}'
```

## Post-Bootstrap Configuration

### Deploy Tenants (Optional)

If using multi-tenancy with ResourceSets:

```bash
# Apply tenant configurations
kubectl apply -k tenants/platform
kubectl apply -k tenants/apps
```

### Verify Complete Setup

```bash
# Check all namespaces
kubectl get namespaces

# Check all GitRepository sources
flux get sources git --all-namespaces

# Check all Kustomizations
flux get kustomizations --all-namespaces

# Check for any failures
flux get all --all-namespaces | grep -i false
```

## Troubleshooting

### GitRepository Authentication Fails

```bash
# Check secret exists
kubectl get secret flux-system -n flux-system

# Recreate secret if needed
kubectl delete secret flux-system -n flux-system
kubectl create secret generic flux-system \
  --namespace flux-system \
  --from-literal=username=git \
  --from-literal=password=${GITHUB_TOKEN}

# Force reconciliation
flux reconcile source git infra
```

### Kustomization Fails

```bash
# Check detailed error
kubectl describe kustomization infra -n flux-system

# Check if source is ready
kubectl get gitrepository infra -n flux-system

# Validate kustomization locally
kustomize build clusters/staging
```

### FluxInstance Not Ready

```bash
# Check FluxInstance status
kubectl describe fluxinstance flux -n flux-system

# Check operator logs
kubectl logs -n flux-operator-system -l app.kubernetes.io/name=flux-operator

# Check events
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

### Network/Timeout Issues

```bash
# Check if pods can reach GitHub
kubectl run -n flux-system test-curl --rm -it --image=curlimages/curl -- curl -I https://github.com

# Check source controller logs
kubectl logs -n flux-system -l app=source-controller --tail=100

# Increase timeout in GitRepository
kubectl edit gitrepository infra -n flux-system
# Add: spec.timeout: 5m
```

## Next Steps

After successful bootstrap:

1. **Configure Infrastructure**: Add components to fleet-infra repository
2. **Deploy Applications**: Add applications to fleet-apps repository
3. **Set Up CI/CD**: Configure automated testing and releases
4. **Monitor**: Set up alerts for Flux reconciliation failures
5. **Document**: Add team-specific documentation

## Ongoing Maintenance

### Updating Flux Components

Flux Operator manages Flux component updates automatically. To update:

1. Update `distribution.version` in FluxInstance
2. Commit and push changes
3. Flux Operator reconciles and updates components

### Rotating Git Credentials

```bash
# Generate new token
export NEW_GITHUB_TOKEN="ghp_new_token"

# Update secret
kubectl create secret generic flux-system \
  --namespace flux-system \
  --from-literal=username=git \
  --from-literal=password=${NEW_GITHUB_TOKEN} \
  --dry-run=client -o yaml | kubectl apply -f -

# Force reconciliation
flux reconcile source git flux-system
flux reconcile source git infra
flux reconcile source git apps
```

### Disaster Recovery

To recover a cluster from scratch:

1. Ensure this fleet repository has all desired state
2. Re-run bootstrap process
3. Flux will restore all resources to desired state
4. No manual intervention needed (GitOps!)
