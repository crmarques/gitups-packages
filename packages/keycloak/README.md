# keycloak

Keycloak identity package. Installs the upstream Keycloak Operator via OLM; the
operator reconciles `Keycloak` / `KeycloakRealmImport` custom resources. The
actual Keycloak server instance is not shipped here - provide one through a
follow-up resource descriptor or an env repository that references `config`.

## Install Methods

| Name | Renderer | Notes |
|------|----------|-------|
| `olm` | `olm` | Upstream keycloak-operator Subscription pinned to `keycloak-operator.v26.5.0`. |
| `helm` | `helm` | Bitnami `keycloak` chart `24.4.3` (Keycloak `26.0.7`). Ships a full Keycloak server (not the operator); toggle `ingress.enabled` to publish through an IngressClass. |

## Resources

| Template | Renderer | Notes |
|----------|----------|-------|
| `config` | `raw` | Environment-specific review ConfigMap. |

## Inputs

### `olm`

| Name | Default | Notes |
|------|---------|-------|
| `namespace` | `keycloak` | install namespace |
| `olm.startingCSV` | `keycloak-operator.v26.5.0` | OLM install CSV pin |

### `helm`

| Name | Default | Notes |
|------|---------|-------|
| `namespace` | `keycloak` | install namespace |
| `chart.version` | `24.4.3` | pinned bitnami chart version |
| `appVersion` | `26.0.7` | Keycloak server image tag |
| `service.type` | `ClusterIP` | set `LoadBalancer` to expose directly |
| `ingress.enabled` | `false` | when `true`, renders a bitnami-managed Ingress |
| `ingress.ingressClassName` | `nginx` | IngressClass name consumed by the controller |
| `ingress.hostname` | placeholder | public host; must be filled before `generate` if `ingress.enabled=true` |
| `ingress.tls` | `false` | request a TLS secret via the chart's built-in handling |
| `auth.adminUser` | `admin` | initial admin username |
| `auth.adminPassword` | placeholder (sensitive) | initial admin password |
| `production` | `false` | chart's production flag; toggles TLS/persistence defaults |
| `proxy` | `edge` | Keycloak reverse-proxy mode (`none`, `edge`, `reencrypt`, `passthrough`) |
