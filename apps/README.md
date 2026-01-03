# Application Overlays

This directory contains optional local application overlays that can be used to customize application deployments per cluster without modifying the main fleet-apps repository.

## Usage

Create environment-specific overlays:

```
apps/
├── staging/
│   ├── kustomization.yaml
│   └── patches/
└── production/
    ├── kustomization.yaml
    └── patches/
```

## Example: Customize Application Replicas

```yaml
# apps/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../components/frontend
  - ../../components/backend
patches:
  - path: patches/frontend-replicas.yaml
```

```yaml
# apps/staging/patches/frontend-replicas.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: apps
spec:
  replicas: 3
```

This approach keeps the main fleet-apps repository clean while allowing cluster-specific customizations.
