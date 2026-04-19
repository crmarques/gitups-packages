# haproxy

HAProxy Kubernetes Ingress Controller, installed via the upstream
`haproxytech/kubernetes-ingress` Helm chart. Exposes a Data Plane API
that declarest can reconcile through the `haproxy-dataplane-bundle`
metadata bundle.

## Install

Helm only. There is no trustworthy community OLM operator for HAProxy
at the pinned chart version, so per the renderer priority (OLM →
Kustomize → Helm → raw) this package defaults to Helm.

The chart's `controller.defaultTLSSecret.enabled: false` is pinned in
the values template because leaving it on generates a fresh
self-signed cert on every render, violating gitups's determinism
invariant.

## Declarest integration

```yaml
spec:
  declarestBundle:
    name: haproxy-dataplane-bundle
    version: 0.1.0
    ref: ghcr.io/crmarques/declarest-bundles/haproxy-dataplane-bundle:0.1.0
```

The bundle declares how logical paths (e.g. `/backends/keycloak`,
`/frontends/http`) map to the HAProxy Data Plane API. Gitups never
fetches the bundle; declarest resolves it at runtime when a
`ManagedService` references `haproxy-dataplane-bundle:0.1.0` via
`spec.metadata.bundle`.

Typical wiring in a consumer env repo:

```yaml
- template: local/declarest
  installMethod: olm
  resources:
    - template: managed-service
      name: haproxy
      values:
        http.baseURL: http://haproxy-kubernetes-ingress.haproxy.svc:5555
        http.auth.valueRef.name: haproxy-dataplane-token
        metadata.bundle: haproxy-dataplane-bundle:0.1.0
    - template: sync-policy
      name: haproxy-backends
      values:
        resourceRepositoryRef.name: env-repo
        managedServiceRef.name: haproxy
        secretStoreRef.name: vault
        source.path: /backends
```

Resource payloads (backend/frontend JSON) are authored (or generated
by a bundle author tool) under the env repo at `/backends/<name>/resource.json`.

See [gitups/agents/references/declarest.md](../../../gitups/agents/references/declarest.md)
for the full declarest integration model.

## Compatibility

Declared `kubernetes: [">=1.28"]`. Gitups's apply-time compatibility
probe compares this against the target cluster's server version and
warns (non-blocking) when the cluster is outside the declared range.
