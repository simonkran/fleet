# Infrastructure Overlays

This directory contains optional local infrastructure overlays that can be used to customize infrastructure deployments per cluster without modifying the main fleet-infra repository.

## Usage

Create environment-specific overlays:

```
infra/
├── staging/
│   ├── kustomization.yaml
│   └── patches/
└── production/
    ├── kustomization.yaml
    └── patches/
```

## Example: Customize Ingress Controller

```yaml
# infra/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../components/ingress-nginx
patches:
  - path: patches/ingress-replicas.yaml
```

```yaml
# infra/staging/patches/ingress-replicas.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  replicas: 2
```

This approach keeps the main fleet-infra repository clean while allowing cluster-specific customizations.
