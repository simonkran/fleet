# Fleet - GitOps Multi-Cluster Management

This repository implements a GitOps-based fleet management system for Kubernetes clusters using Flux CD with Git-based delivery. It is inspired by the [d2-fleet](https://github.com/controlplaneio-fluxcd/d2-fleet) architecture but uses Git repositories instead of OCI artifacts for component delivery.

## Architecture

This fleet repository follows a three-repository architecture:

- **fleet** (this repo): Cluster fleet management and configuration
- **fleet-infra**: Infrastructure components (operators, controllers, security policies)
- **fleet-apps**: Application deployments and services

## Directory Structure

```
fleet/
├── clusters/           # Per-cluster configurations
│   ├── staging/       # Staging environment
│   │   └── flux-system/
│   └── production/    # Production environment
│       └── flux-system/
├── tenants/           # Multi-tenant ResourceSet definitions
│   ├── platform/      # Platform team resources
│   └── apps/          # Application team resources
├── infra/             # Local infrastructure overlays (optional)
├── apps/              # Local application overlays (optional)
└── Makefile           # Common automation tasks
```

## Key Differences from d2-fleet

### Git-Based Delivery vs OCI Artifacts

- **d2-fleet**: Uses `OCIRepository` resources pointing to OCI artifacts in container registries
- **This fleet**: Uses `GitRepository` resources pointing to Git repositories with branches/tags

### Deployment Strategy

**Staging Environment:**
- Syncs from `main` branch for continuous updates
- Fast reconciliation intervals (5-10 minutes)
- Tracks latest changes automatically

**Production Environment:**
- Uses semver tags (`>=1.0.0 <2.0.0`) for stability
- Slower reconciliation intervals (10-30 minutes)
- Controlled releases via Git tags

## Components

### FluxInstance

Each cluster has a `FluxInstance` resource that:
- Configures Flux CD components (source, kustomize, helm, notification controllers)
- Enables multi-tenancy with network policies
- Syncs cluster state from this Git repository

### GitRepository Resources

- `infra`: References the fleet-infra repository for infrastructure components
- `apps`: References the fleet-apps repository for application deployments

### Kustomization Resources

- `kustomization-infra.yaml`: Applies infrastructure configurations
- `kustomization-apps.yaml`: Applies application configurations (depends on infra)

### Tenants (ResourceSets)

Multi-tenant organization using ResourceSet resources:
- `platform`: Platform team infrastructure and tooling
- `apps`: Application team deployments

### Runtime Configuration (runtime-info.yaml)

Each cluster includes a `runtime-info` ConfigMap that stores environment-specific variables:
- **Environment metadata**: `ENVIRONMENT`, `CLUSTER_NAME`, `CLUSTER_DOMAIN`
- **Git references**: `INFRA_REF`, `APPS_REF` (branches for staging, semver for production)
- **Reconciliation settings**: `RECONCILE_INTERVAL`, `RECONCILE_TIMEOUT`
- **Feature flags**: `ENABLE_MULTITENANCY`, `ENABLE_NETWORK_POLICY`

These variables are automatically substituted into GitRepository and Kustomization resources using Flux's `postBuild.substituteFrom` feature, enabling:
- Single source of truth for environment configuration
- Easy environment-specific customization
- Simplified cluster configuration management

### Declarative Flux Operator Installation

The Flux Operator itself is managed declaratively using a HelmRelease resource (`flux-operator.yaml`):
- Pulls the operator from OCI Helm registry
- Configures multitenancy and reporting settings
- Enables automatic operator updates
- Provides GitOps-based operator lifecycle management

## Prerequisites

- Kubernetes cluster(s) with cluster-admin access
- [Flux Operator](https://github.com/controlplaneio/flux-operator) installed
- Git repository access (GitHub, GitLab, etc.)
- GitHub personal access token or deploy key

## Bootstrap Process

### 1. Install Flux Operator

**Option A: Quick Install (recommended for initial bootstrap)**

```bash
kubectl apply -f https://github.com/controlplaneio/flux-operator/releases/latest/download/install.yaml
```

**Option B: Declarative Install (GitOps-managed operator)**

For GitOps-managed Flux Operator lifecycle:

```bash
kubectl apply -f clusters/staging/flux-system/flux-operator.yaml
```

This installs the operator using a HelmRelease, enabling automatic updates and declarative management. Once bootstrapped, the operator will be managed by Flux itself.

### 2. Create Git Credentials Secret

Create a secret with your Git credentials:

```bash
export GITHUB_TOKEN=<your-token>

kubectl create namespace flux-system

kubectl create secret generic flux-system \
  --namespace flux-system \
  --from-literal=username=git \
  --from-literal=password=${GITHUB_TOKEN}
```

### 3. Update Repository URLs

Replace `${GITHUB_ORG}` placeholders in cluster configs:

```bash
# For staging
export GITHUB_ORG=your-github-org
find clusters/staging -type f -name "*.yaml" -exec sed -i "s/\${GITHUB_ORG}/${GITHUB_ORG}/g" {} +

# For production
find clusters/production -type f -name "*.yaml" -exec sed -i "s/\${GITHUB_ORG}/${GITHUB_ORG}/g" {} +
```

### 4. Bootstrap Staging Cluster

```bash
kubectl apply -k clusters/staging/flux-system
```

### 5. Bootstrap Production Cluster

```bash
kubectl apply -k clusters/production/flux-system
```

### 6. Verify Installation

```bash
# Check FluxInstance status
kubectl get fluxinstance -n flux-system

# Check GitRepository resources
kubectl get gitrepository -n flux-system

# Check Kustomization resources
kubectl get kustomization -n flux-system

# Watch reconciliation
flux logs --all-namespaces --follow
```

## Deployment Workflow

### Staging Deployments

1. Make changes to fleet-infra or fleet-apps repositories
2. Commit and push to `main` branch
3. Flux automatically reconciles changes to staging clusters within 5-10 minutes
4. Monitor with `flux get sources git` and `flux get kustomizations`

### Production Deployments

1. Test changes thoroughly in staging
2. Tag the fleet-infra or fleet-apps repository with a semver tag:
   ```bash
   git tag -a v1.0.1 -m "Release v1.0.1"
   git push origin v1.0.1
   ```
3. Flux automatically reconciles to production clusters using the latest matching semver tag
4. Monitor with `flux get sources git` and `flux get kustomizations`

### Updating Fleet Configuration

1. Make changes to this fleet repository (cluster configs, tenants, etc.)
2. Commit and push to `main` branch
3. Flux reconciles cluster configurations automatically

### Customizing Runtime Configuration

To modify environment-specific settings, edit the `runtime-info.yaml` ConfigMap for each cluster:

**Example: Change reconciliation interval for staging**
```yaml
# clusters/staging/flux-system/runtime-info.yaml
data:
  RECONCILE_INTERVAL: 3m  # Changed from 5m to 3m
```

**Example: Update cluster domain**
```yaml
# clusters/production/flux-system/runtime-info.yaml
data:
  CLUSTER_DOMAIN: prod.example.com
```

After committing changes, Flux automatically applies the new configuration and reconciles affected resources. The `postBuild.substituteFrom` feature ensures all GitRepository and Kustomization resources use the updated values.

## Multi-Tenancy

This setup supports multi-tenancy through:

- **Namespace isolation**: Separate namespaces per tenant
- **ResourceSets**: Group and manage tenant resources
- **Network policies**: Enabled in FluxInstance for network isolation
- **Service accounts**: Dedicated service accounts per tenant

## Repository Organization

### fleet-infra Repository Structure

```
fleet-infra/
├── clusters/
│   ├── staging/
│   │   ├── infrastructure.yaml    # Infrastructure Kustomizations
│   │   └── ...
│   └── production/
│       ├── infrastructure.yaml
│       └── ...
└── components/                    # Shared infrastructure components
    ├── cert-manager/
    ├── ingress-nginx/
    └── ...
```

### fleet-apps Repository Structure

```
fleet-apps/
├── clusters/
│   ├── staging/
│   │   ├── applications.yaml      # Application Kustomizations
│   │   └── ...
│   └── production/
│       ├── applications.yaml
│       └── ...
└── components/                    # Shared application components
    ├── frontend/
    ├── backend/
    └── ...
```

## Makefile Commands

```bash
# Validate cluster configurations
make validate-staging
make validate-production

# Show diff before applying
make diff-staging
make diff-production

# Force reconciliation
make reconcile-staging
make reconcile-production

# Check status
make status-staging
make status-production
```

## Troubleshooting

### Check GitRepository Status

```bash
kubectl get gitrepository -n flux-system
kubectl describe gitrepository infra -n flux-system
```

### Check Kustomization Status

```bash
kubectl get kustomization -n flux-system
kubectl describe kustomization infra -n flux-system
```

### Force Reconciliation

```bash
flux reconcile source git infra
flux reconcile kustomization infra
```

### View Logs

```bash
flux logs --all-namespaces --follow
kubectl logs -n flux-system -l app=source-controller
kubectl logs -n flux-system -l app=kustomize-controller
```

## Security Considerations

1. **Git Credentials**: Store as Kubernetes secrets, rotate regularly
2. **RBAC**: Limit cluster-admin access to platform team
3. **Network Policies**: Enabled by default in FluxInstance
4. **Multi-tenancy**: Isolate tenant workloads using namespaces and service accounts
5. **Git Signing**: Consider GPG-signed commits for production

## Migration from OCI to Git

If migrating from d2-fleet's OCI approach:

1. Package your OCI artifacts as Git repositories (fleet-infra, fleet-apps)
2. Replace `OCIRepository` resources with `GitRepository` resources
3. Update `sourceRef.kind` in Kustomizations from `OCIRepository` to `GitRepository`
4. Use branches for staging, semver tags for production
5. Remove Cosign verification patches (unless using Git commit signing)

## References

- [Flux CD Documentation](https://fluxcd.io/flux/)
- [Flux Operator](https://github.com/controlplaneio/flux-operator)
- [d2-fleet Reference Architecture](https://github.com/controlplaneio-fluxcd/d2-fleet)
- [GitOps Principles](https://opengitops.dev/)
