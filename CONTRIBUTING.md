# Contributing Guide

This guide explains how to contribute changes to the fleet management system.

## Making Changes

### Modifying Fleet Configuration

Changes to cluster configurations, tenants, or fleet-level settings:

1. Create a feature branch:
   ```bash
   git checkout -b feature/my-change
   ```

2. Make your changes to files in:
   - `clusters/`: Cluster-specific configurations
   - `tenants/`: Tenant ResourceSet definitions

3. Validate your changes:
   ```bash
   make validate-staging
   make validate-production
   ```

4. Commit and push:
   ```bash
   git add .
   git commit -m "Description of changes"
   git push origin feature/my-change
   ```

5. Create a pull request and get review

6. Merge to `main` - Flux will automatically reconcile changes to clusters

### Modifying Infrastructure Components

Changes to infrastructure components (cert-manager, ingress, etc.):

1. Work in the `fleet-infra` repository
2. Create a feature branch
3. Make changes to components
4. Test in staging:
   ```bash
   git push origin feature/my-change
   # Update staging GitRepository to use feature branch temporarily
   kubectl patch gitrepository infra -n flux-system -p '{"spec":{"ref":{"branch":"feature/my-change"}}}'
   flux reconcile source git infra
   flux reconcile kustomization infra
   ```
5. After validation, merge to `main` for staging
6. Tag with semver for production release:
   ```bash
   git tag -a v1.1.0 -m "Add new feature"
   git push origin v1.1.0
   ```

### Modifying Applications

Changes to application deployments:

1. Work in the `fleet-apps` repository
2. Follow the same process as infrastructure changes
3. Test thoroughly in staging before tagging for production

## Deployment Strategy

### Staging Environment

- **Source**: `main` branch of fleet-infra and fleet-apps
- **Update Frequency**: Automatic, every 5-10 minutes
- **Purpose**: Continuous testing and validation
- **Risk**: Higher - receives all changes immediately

**Workflow:**
```
Commit to main → Auto-sync to staging → Validate → Promote to production
```

### Production Environment

- **Source**: Semver tags of fleet-infra and fleet-apps
- **Update Frequency**: Controlled via tagging
- **Purpose**: Stable, tested releases
- **Risk**: Lower - only tagged, validated changes

**Workflow:**
```
Test in staging → Tag release → Auto-sync to production → Monitor
```

## Tagging and Versioning

Use semantic versioning (semver) for production releases:

- **Major version** (v2.0.0): Breaking changes, significant updates
- **Minor version** (v1.1.0): New features, backwards-compatible
- **Patch version** (v1.0.1): Bug fixes, minor updates

### Creating a Release

```bash
# For fleet-infra
cd fleet-infra
git tag -a v1.1.0 -m "Add monitoring stack"
git push origin v1.1.0

# For fleet-apps
cd fleet-apps
git tag -a v2.0.0 -m "Deploy new frontend version"
git push origin v2.0.0
```

Production clusters will automatically reconcile to the latest matching semver tag within the configured range.

## Testing Changes

### Local Validation

```bash
# Validate Kubernetes manifests
kubectl apply --dry-run=client -k clusters/staging/flux-system
kubectl apply --dry-run=server -k clusters/staging/flux-system

# Check for kustomize build errors
kustomize build clusters/staging
kustomize build clusters/production

# Lint YAML
yamllint clusters/
```

### Staging Validation

Before promoting to production, verify in staging:

```bash
# Check reconciliation status
flux get sources git
flux get kustomizations

# Check resource health
kubectl get all -n <namespace>

# Check logs for errors
flux logs --all-namespaces

# Run smoke tests
# (Add your application-specific tests here)
```

## Pull Request Guidelines

### PR Title Format

Use conventional commits format:
- `feat: Add new feature`
- `fix: Fix bug in configuration`
- `chore: Update documentation`
- `refactor: Reorganize cluster configs`

### PR Description

Include:
1. **What**: Description of changes
2. **Why**: Reason for changes
3. **Testing**: How changes were tested
4. **Impact**: Which clusters/components are affected
5. **Rollback**: How to rollback if needed

### Example PR Description

```markdown
## What
Add cert-manager to infrastructure components

## Why
Enable automated TLS certificate management across all applications

## Testing
- Validated in staging cluster
- Verified certificate issuance
- Tested with sample application

## Impact
- Affects: All clusters
- New component: cert-manager namespace and resources
- Dependencies: None

## Rollback
Remove cert-manager kustomization from fleet-infra/clusters/*/kustomization.yaml
```

## Review Process

1. **Self-review**: Check your changes before requesting review
2. **Peer review**: Get approval from at least one team member
3. **Validation**: Ensure CI checks pass
4. **Staging test**: Verify in staging environment
5. **Documentation**: Update docs if needed
6. **Merge**: Squash and merge to main

## Emergency Changes

For critical production fixes:

1. Create hotfix branch from main
2. Make minimal changes to fix the issue
3. Tag immediately: `v1.0.1-hotfix`
4. Fast-track review and merge
5. Follow up with proper fix in next release

```bash
git checkout -b hotfix/critical-security-fix
# Make changes
git commit -m "fix: Critical security patch"
git tag -a v1.0.1 -m "Hotfix: Security patch"
git push origin hotfix/critical-security-fix v1.0.1
```

## Rollback Procedure

### Rollback Fleet Configuration

```bash
# Revert commit
git revert <commit-hash>
git push origin main

# Flux auto-reconciles to reverted state
```

### Rollback Infrastructure/Apps

```bash
# In fleet-infra or fleet-apps repo
# For staging: revert commit on main
git revert <commit-hash>
git push origin main

# For production: tag previous version
git tag -a v1.0.1 -m "Rollback to previous version"
git push origin v1.0.1
```

### Force Immediate Rollback

If Flux is not reconciling quickly enough:

```bash
# Manually apply previous state
kubectl apply -k clusters/production/flux-system

# Or suspend and manually fix
flux suspend kustomization <name>
# Fix manually
flux resume kustomization <name>
```

## Best Practices

1. **Small changes**: Keep PRs focused and small
2. **Test in staging**: Always validate in staging first
3. **Descriptive commits**: Write clear commit messages
4. **Documentation**: Update docs with code changes
5. **Backward compatibility**: Avoid breaking changes when possible
6. **Gradual rollout**: Stage → Production, never skip staging
7. **Monitor after deploy**: Watch reconciliation and application health
8. **Tag regularly**: Create semver tags for production releases

## Getting Help

- Check existing issues and PRs
- Review documentation in this repository
- Consult Flux documentation: https://fluxcd.io
- Ask in team chat or create an issue
