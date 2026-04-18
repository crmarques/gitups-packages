# service-mesh

Istio service-mesh package. Installed from the official Istio Helm repository
(`istio-release.storage.googleapis.com/charts`). Upstream Istio splits cluster
primitives (CRDs, ClusterRoles) from the discovery control plane, so this
package mirrors that split:

- `install/helm` pulls the `base` chart (CRDs + cluster-scoped primitives).
- `resources/istiod` pulls the `istiod` chart (the control plane itself) and
  depends on the base install.
- `resources/config` is an env-specific mesh ConfigMap for review.

## Install Methods

| Name | Renderer | Notes |
|------|----------|-------|
| `helm` | `helm` | Upstream Istio `base` chart pinned to `1.29.2`. |

## Resources

| Template | Renderer | Notes |
|----------|----------|-------|
| `istiod` | `helm` | Istio discovery/control plane, `istiod` chart pinned to `1.29.2`. |
| `config` | `raw` | Environment-specific mesh ConfigMap. |

## Inputs

| Name | Default | Notes |
|------|---------|-------|
| `namespace` | `istio-system` | install namespace |
| `chart.version` | `1.29.2` | Istio chart version used for render (shared across base and istiod) |
| `appVersion` | `1.29.2` | Istio app version |
| `replicaCount` (istiod) | `1` | pilot replica count |
| `meshID` (config) | `mesh-default` | env-specific mesh identity |

## Why Helm and not OLM?

Upstream Istio publishes official Helm charts but does not maintain an
OperatorHub/OLM bundle. The `sailoperator` / Red Hat OpenShift Service Mesh
catalogs are adjacent projects, not the Istio project itself, so Helm is the
correct trust-bounded choice here per AGENTS.md renderer priority.
