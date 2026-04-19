# declarest

Service-resource-controller (SRC) package for
[DeclaREST](https://github.com/crmarques/declarest). Declarest
reconciles arbitrary REST-API-backed systems from Git using four
generic CRDs (`ResourceRepository`, `ManagedService`, `SecretStore`,
`SyncPolicy`) driven by **metadata bundles**. This package installs
the operator and ships one gitups resource template per CRD so
Provisions can compose a scoped sync policy in any env repo.

See [gitups/agents/references/declarest.md](../../../gitups/agents/references/declarest.md)
for the gitups-level integration contract.

## Install Methods

| Name | Renderer | Notes |
|------|----------|-------|
| `raw` | `raw` | In-tree deployment pinned to `ghcr.io/crmarques/declarest:v0.3.8`. Default. |
| `olm` | `olm` | `declarest-operator` via OperatorHubio catalog, pinned to `declarest-operator.v0.4.0`. |

## Resource Templates

Each template renders exactly one declarest CR, intended to be
composed per-scope in a consumer env repo.

| Template              | Renders                              | Use |
|-----------------------|--------------------------------------|-----|
| `resource-repository` | `declarest.io/v1alpha1/ResourceRepository` | One per env output repo (where desired-state files live). |
| `managed-service`     | `declarest.io/v1alpha1/ManagedService`     | One per target REST service instance + bundle pairing. |
| `secret-store`        | `declarest.io/v1alpha1/SecretStore`        | One per secret backend (vault or encrypted file). |
| `sync-policy`         | `declarest.io/v1alpha1/SyncPolicy`         | One per logical sync scope (`source.path`). |

`sync-policy` references the other three by `metadata.name`, so
`managedServiceRef.name` / `secretStoreRef.name` /
`resourceRepositoryRef.name` in a Provision must match the `name:` of
the selected `managed-service` / `secret-store` / `resource-repository`
resource entry.

Declarest itself owns no per-product CR (no `HttpProxyBackend`, no
`KeycloakRealm`). Bundles map logical paths to the target API's real
endpoints; payloads are plain JSON/YAML files committed to the
`ResourceRepository`.

## Typical Provision wiring

```yaml
- template: local/declarest
  installMethod: olm
  resources:
    - template: resource-repository
      name: env-repo
      values:
        git.url: https://example.com/gitops/services-keycloak-dev.git
    - template: managed-service
      name: keycloak
      values:
        http.baseURL: https://keycloak.keycloak.svc.cluster.local:8443
        http.auth.valueRef.name: keycloak-admin-token
        metadata.bundle: keycloak-bundle:1.0.0
    - template: secret-store
      name: vault
      values:
        kind: vault
        vault.address: http://vault.vault.svc:8200
        vault.auth.token.secretRef.name: vault-root-token
    - template: sync-policy
      name: keycloak-master-realm
      values:
        resourceRepositoryRef.name: env-repo
        managedServiceRef.name: keycloak
        secretStoreRef.name: vault
        source.path: /realms/master
```

## Intent hook

Declarest's SRC domain carries:

- `service-resource-controller/managed-resource/descriptor.yaml` —
  the intent gitups uses when it hands a rendered manifest directory
  off to declarest's CLI during bootstrap apply.
- `service-resource-controller/managed-script/descriptor.yaml` —
  wraps script-style resource descriptors in a deterministic Job.

## Credentials

Declarest itself doesn't ship a git-credentials Secret template.
Pair this package with `gitea` (or any `git-provider` capability
provider) in the env repo to produce a `repository-credentials`
Secret that `resource-repository` references via
`git.auth.tokenRef`.
