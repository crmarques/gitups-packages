# gitea

Gitea source-control package. Installs Gitea via the upstream Gitea Helm chart
(`dl.gitea.com/charts`). The chart defaults here turn off persistence and the
chart-bundled Postgres/Redis dependencies so the package is apply-safe on
disposable kind clusters; flip `persistence.enabled` / `postgresql.enabled`
for production-shaped installs.

## Install Methods

| Name | Renderer | Notes |
|------|----------|-------|
| `helm` | `helm` | Upstream Gitea chart pinned to `12.5.3` (appVersion `1.25.5`). |

## Resources

| Template | Renderer | Notes |
|----------|----------|-------|
| `config` | `raw` | Environment-specific review ConfigMap. |

## Inputs

| Name | Default | Notes |
|------|---------|-------|
| `namespace` | `gitea` | install namespace |
| `chart.version` | `12.5.3` | Gitea Helm chart version |
| `appVersion` | `1.25.5` | Gitea application version shipped by the chart |
| `rootURL` | `http://gitea.gitea.svc.cluster.local:3000/` | advertised internal URL |
| `persistence.enabled` | `false` | chart PVC toggle; enable for non-ephemeral installs |
| `postgresql.enabled` | `false` | bundled single-node Postgres toggle |
| `postgresql-ha.enabled` | `false` | bundled HA Postgres toggle |
| `redis-cluster.enabled` | `false` | bundled Redis cluster toggle |
