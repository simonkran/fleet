# Architecture Overview

This document describes the architecture and design decisions for the fleet management system.

## Three-Repository Architecture

The fleet management system uses a three-repository pattern:

```
┌─────────────────────────────────────────────────────────────┐
│                         fleet (this repo)                    │
│  - Cluster configurations (staging, production)              │
│  - Tenant definitions                                        │
│  - Fleet-level policies                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ References via GitRepository
                              │
           ┌──────────────────┴──────────────────┐
           │                                     │
           ▼                                     ▼
┌──────────────────────────┐      ┌──────────────────────────┐
│      fleet-infra         │      │       fleet-apps         │
│  - Infrastructure        │      │  - Application           │
│    components            │      │    deployments           │
│  - Platform services     │      │  - Services              │
│  - Security policies     │      │  - Configurations        │
└──────────────────────────┘      └──────────────────────────┘
```

## Repository Responsibilities

### fleet (Fleet Management Repository)

**Purpose**: Centralized cluster fleet management and configuration

**Responsibilities**:
- Define cluster configurations (staging, production, etc.)
- Configure Flux CD synchronization
- Manage multi-tenancy via ResourceSets
- Define tenant boundaries and permissions
- Bootstrap cluster with Flux Operator

**Who manages**: Platform/SRE team with cluster-admin access

**Structure**:
```
fleet/
├── clusters/              # Cluster-specific configs
│   ├── staging/
│   │   └── flux-system/   # FluxInstance, GitRepository, Kustomization
│   └── production/
│       └── flux-system/
├── tenants/               # Tenant definitions
│   ├── platform/          # Platform team tenant
│   └── apps/              # Application team tenant
├── infra/                 # Optional local infrastructure overlays
├── apps/                  # Optional local application overlays
└── docs/                  # Documentation
```

### fleet-infra (Infrastructure Repository)

**Purpose**: Shared infrastructure components and platform services

**Responsibilities**:
- Kubernetes operators (cert-manager, external-dns, etc.)
- Ingress controllers (nginx, traefik)
- Observability stack (prometheus, grafana, loki)
- Security policies (network policies, pod security)
- Storage classes and persistent volume configurations

**Who manages**: Platform/Infrastructure team

**Example Structure**:
```
fleet-infra/
├── clusters/
│   ├── staging/
│   │   └── kustomization.yaml    # References components
│   └── production/
│       └── kustomization.yaml
├── components/
│   ├── cert-manager/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── helmrelease.yaml
│   │   └── clusterissuer.yaml
│   ├── ingress-nginx/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   └── helmrelease.yaml
│   ├── monitoring/
│   │   ├── prometheus/
│   │   ├── grafana/
│   │   └── loki/
│   └── security/
│       ├── network-policies/
│       └── pod-security-policies/
└── base/                          # Shared base configurations
    └── namespaces/
```

### fleet-apps (Applications Repository)

**Purpose**: Application deployments and services

**Responsibilities**:
- Application deployments
- Application configurations
- Service definitions
- Application-specific resources

**Who manages**: Application/Development teams

**Example Structure**:
```
fleet-apps/
├── clusters/
│   ├── staging/
│   │   └── kustomization.yaml    # References apps
│   └── production/
│       └── kustomization.yaml
├── components/
│   ├── frontend/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   └── configmap.yaml
│   ├── backend/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── secret.yaml
│   └── database/
│       ├── kustomization.yaml
│       └── helmrelease.yaml
└── base/                          # Shared app configurations
    ├── common-labels/
    └── resource-quotas/
```

## Design Decisions

### Git-Based Delivery vs OCI Artifacts

**Decision**: Use Git-based delivery with GitRepository resources

**Rationale**:
- **Familiarity**: Teams already use Git workflows
- **Simplicity**: No need for OCI registry management
- **Auditability**: Git provides built-in history and audit trail
- **Tooling**: Existing Git tools (PRs, code review, CI/CD)
- **Transparency**: Easy to browse and review in GitHub UI

**Trade-offs**:
- OCI provides better immutability guarantees
- Git repositories can have larger size over time
- Git-based delivery requires proper branch/tag management

### Staging vs Production Strategy

**Staging**:
- **Ref**: `branch: main`
- **Interval**: 5-10 minutes
- **Purpose**: Rapid feedback, continuous testing
- **Risk tolerance**: High - failures are acceptable

**Production**:
- **Ref**: `semver: ">=1.0.0 <2.0.0"`
- **Interval**: 10-30 minutes
- **Purpose**: Stability, controlled releases
- **Risk tolerance**: Low - failures are not acceptable

**Workflow**:
```
Developer → Commit to main → Auto-deploy to staging → Validate → Tag release → Auto-deploy to production
```

### Multi-Tenancy Model

**Decision**: Use ResourceSets for tenant isolation

**Rationale**:
- Logical separation of resources
- RBAC integration for team-based access
- Namespace isolation
- Network policy enforcement

**Tenants**:
1. **Platform**: Infrastructure and platform services
2. **Apps**: Application deployments
3. (Additional tenants as needed)

### Component Organization

**Decision**: Use kustomize with base/components/clusters pattern

**Structure**:
```
base/               # Shared, environment-agnostic configs
components/         # Reusable components (cert-manager, apps)
clusters/           # Environment-specific overlays (staging, production)
  staging/
  production/
```

**Benefits**:
- DRY principle - shared configs in base
- Environment-specific customization via overlays
- Clear separation of concerns
- Easy to understand and navigate

## Data Flow

### Configuration Update Flow

```
1. Developer commits change to fleet-infra or fleet-apps
   ↓
2. Git repository updated (main branch or tag created)
   ↓
3. Flux source-controller detects change
   ↓
4. GitRepository resource updated with new revision
   ↓
5. Kustomization resource detects source change
   ↓
6. kustomize-controller fetches and builds manifests
   ↓
7. kustomize-controller applies resources to cluster
   ↓
8. Kubernetes reconciles to desired state
```

### Bootstrap Flow

```
1. Install Flux Operator on cluster
   ↓
2. Create Git credentials secret
   ↓
3. Apply FluxInstance resource
   ↓
4. Flux Operator installs Flux components
   ↓
5. FluxInstance syncs from fleet repository
   ↓
6. GitRepository resources created for fleet-infra and fleet-apps
   ↓
7. Kustomization resources apply infra and apps
   ↓
8. Cluster reaches desired state
```

## Security Model

### Access Control

**Fleet Repository**:
- Platform team: Write access
- App teams: Read access (for reference)

**Fleet-Infra Repository**:
- Platform team: Write access
- App teams: Read access

**Fleet-Apps Repository**:
- App teams: Write access
- Platform team: Admin access (for emergencies)

### Secret Management

**Git Credentials**:
- Stored as Kubernetes secrets
- Separate secret per cluster
- Rotated regularly (90 days)

**Application Secrets**:
- Use external secret management (Sealed Secrets, External Secrets Operator)
- Never commit secrets to Git
- Reference secrets created out-of-band

### Network Isolation

- Network policies enabled via FluxInstance
- Tenant namespace isolation
- Ingress controls per application
- Service mesh (optional) for mTLS

## Scalability Considerations

### Cluster Scaling

- Add new clusters by creating `clusters/<name>/flux-system/` directory
- Minimal configuration required per cluster
- Shared components via fleet-infra and fleet-apps

### Repository Scaling

- Keep component definitions small and focused
- Use Kustomize components for reusability
- Split large applications into multiple components
- Use Git submodules for very large codebases (if needed)

### Reconciliation Performance

- Adjust intervals based on environment (staging: fast, production: slower)
- Use `dependsOn` to ensure proper ordering
- Set appropriate `timeout` values
- Use `--concurrent` flags for parallel reconciliation

## Disaster Recovery

### Cluster Loss

1. Provision new cluster
2. Install Flux Operator
3. Bootstrap using fleet repository
4. Flux restores all resources automatically

**Recovery Time**: Minutes to hours (depending on cluster size)

### Repository Loss

**Prevention**:
- Regular Git backups
- Mirror repositories to secondary location
- Export cluster state periodically

**Recovery**:
- Restore from Git backup
- Rebuild from cluster state if needed: `flux export source git --all`

## Monitoring and Observability

### Flux Monitoring

- Flux exports Prometheus metrics
- Monitor reconciliation failures
- Alert on sync errors

**Key Metrics**:
- `gotk_reconcile_condition` - Reconciliation status
- `gotk_reconcile_duration_seconds` - Reconciliation time
- `controller_runtime_reconcile_total` - Reconciliation count

### Application Monitoring

- Deployed via fleet-infra (Prometheus, Grafana, Loki)
- Application-specific dashboards in fleet-apps
- Centralized logging and metrics

## Future Enhancements

Potential improvements:
- Add image automation for automatic app updates
- Implement progressive delivery with Flagger
- Add policy enforcement with Kyverno or OPA
- Integrate with external secret management
- Add drift detection and remediation
- Implement cluster-api for cluster lifecycle management

## References

- [Flux CD Documentation](https://fluxcd.io/flux/)
- [Kustomize Documentation](https://kustomize.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Multi-tenancy Best Practices](https://fluxcd.io/flux/use-cases/multi-tenancy/)
