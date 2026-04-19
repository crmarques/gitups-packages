# keycloak

Keycloak identity package. Installs the upstream Keycloak Operator via OLM; the
operator reconciles `Keycloak` / `KeycloakRealmImport` custom resources. The
actual Keycloak server instance is not shipped here - provide one through a
follow-up resource descriptor or an env repository that references `config`.

## Install Methods

| Name | Renderer | Notes |
|------|----------|-------|
| `olm` | `olm` | Upstream keycloak-operator Subscription pinned to `keycloak-operator.v26.5.0`. |

## Resources

| Template | Renderer | Notes |
|----------|----------|-------|
| `config` | `raw` | Environment-specific review ConfigMap. |

## Inputs

| Name | Default | Notes |
|------|---------|-------|
| `namespace` | `keycloak` | install namespace |
| `olm.startingCSV` | `keycloak-operator.v26.5.0` | OLM install CSV pin |
