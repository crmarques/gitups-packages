# declarest

Declarest controller package for the e2e bootstrap flow. It renders a minimal
controller-shaped Deployment plus env-specific bootstrap configuration.

## Components

| Name | Renderer | Target repo | Notes |
|------|----------|-------------|-------|
| `install` | `raw` | `gitops-controllers` | Namespace, ServiceAccount, and Deployment. |
| `config` | `raw` | `gitops-controllers-{{.Env}}` | Environment-specific bootstrap ConfigMap. |

## Inputs

| Name | Default | Notes |
|------|---------|-------|
| `namespace` | `declarest-system` | install namespace |
| `image.repository` | `ghcr.io/crmarques/declarest` | controller image repository |
| `image.tag` | `v0.3.8` | controller image tag |
| `replicas` | `1` | Deployment replica count |
| `repoURL` | **placeholder** | GitOps repository URL Declarest will watch |
| `targetRevision` | `HEAD` | Git revision used by the bootstrap config |
