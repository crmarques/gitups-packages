# haproxy

HAProxy Kubernetes Ingress Controller, installed via the upstream
`haproxytech/kubernetes-ingress` Helm chart, plus an `http-proxy`
service-config interface consumers can bind to.

## Install

Helm only. There is no trustworthy community OLM operator for HAProxy
at the pinned chart version, so per the renderer priority (OLM →
Kustomize → Helm → raw) this package defaults to Helm.

The chart's `controller.defaultTLSSecret.enabled: false` is pinned in
the values template because leaving it on generates a fresh self-signed
cert on every render, violating gitups's determinism invariant.

## Service config: http-proxy/v1alpha1

haproxy declares `spec.implements`:

```yaml
implements:
  - interface: http-proxy
    version: v1alpha1
    resourceTemplate: backend
```

This tells gitups: any Provision.spec.repositories[].interfaceResources[]
entry pointing at `http-proxy/v1alpha1` and targeting this haproxy
instance should be rendered using `resources/backend/`. Gitups core
synthesises one ResolvedPackage per entry in the matching
service-resources repo, tagged with the selected SRC (Declarest) as
its controller, and Declarest reconciles the CRs into live haproxy
configuration at runtime.

### Using it

Declare a service-resources repo targeting this haproxy instance:

```yaml
- name: services-haproxy-{{.Env}}
  type: service-resources
  serviceRef:
    repo: support-services
    instance: haproxy
  interfaceResources:
    - name: gitea
      interface: http-proxy
      version: v1alpha1
      consumer:
        repo: support-services
        instance: gitea
      values:
        serviceName: gitea-http
        serviceNamespace: gitea
        servicePort: 3000
        host: gitea.dsv.local
    - name: keycloak
      interface: http-proxy
      version: v1alpha1
      consumer:
        repo: support-services
        instance: keycloak
      values:
        serviceName: keycloak-service
        serviceNamespace: keycloak
        servicePort: 8080
        host: keycloak.dsv.local
```

`gitups expand` emits two `HttpProxyBackend` CRs (one per entry) into
the `services-haproxy-dsv` repo. At apply time the SRC routes them
through `declarest apply`, which converts them into HAProxy backend
definitions and reloads the data-plane.

## Compatibility

Declared `kubernetes: [">=1.28"]`. Gitups's apply-time compatibility
probe compares this against the target cluster's server version and
warns (non-blocking) when the cluster is outside the declared range.

## Inputs (backend template)

| Input               | Type  | Default | Notes                                      |
|---------------------|-------|---------|--------------------------------------------|
| `serviceName`       | str   | —       | Target Service name                        |
| `serviceNamespace`  | str   | —       | Target Service namespace                   |
| `servicePort`       | int   | —       | Target Service port (integer)              |
| `host`              | str   | —       | HTTP Host header to match on the frontend  |
| `path`              | str   | `/`     | Path prefix                                |
| `tls.enabled`       | bool  | `false` | Terminate TLS on the frontend              |
| `tls.secretName`    | str   | `""`    | K8s Secret name with cert/key (TLS only)   |
