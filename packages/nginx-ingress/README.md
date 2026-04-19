# nginx-ingress

ingress-nginx installed from the upstream community Helm chart. It orders
after the MetalLB operator when that package is selected; the env-specific
MetalLB address pools can be applied later and the `LoadBalancer` Service will
settle once the pool exists.

**Why `renderer: helm` and not `renderer: olm`?** The kubernetes-community
`ingress-nginx` project does not publish an OLM catalog entry. NGINX Inc's
`nginx-ingress-operator` on OperatorHub is for their NGINX Plus stack and
carries a different CR shape and licensing. Helm is the right fallback here
per AGENTS.md §1.1 (OLM → Kustomize → Helm).

## Chart

- Repo: `https://kubernetes.github.io/ingress-nginx`
- Chart: `ingress-nginx`
- Default pinned version: `4.15.1` (appVersion `1.15.1`)

## Inputs

| Name | Default | Notes |
|------|---------|-------|
| `namespace` | `ingress-nginx` | |
| `chart.version` | `4.15.1` | Helm chart version used for render |
| `appVersion` | `1.15.1` | ingress-nginx controller app version bundled by the chart |
| `controller.service.type` | `LoadBalancer` | one of `ClusterIP`, `LoadBalancer`, `NodePort` |
| `controller.ingressClassResource.name` | `nginx` | |
| `controller.ingressClassResource.default` | `true` | install as the cluster's default ingress class |

## Output

Rendered into `<outputPath>/<env>/packages/nginx-ingress/`:

- `namespace.yaml` — overlay.
- `values.yaml` — merged helm values used for this render.
- `install.yaml` — the frozen `helm template` output of the chart.

## Resources

| Template | Renderer | Notes |
|----------|----------|-------|
| `lb-binding` | `raw` | Synthesized consumer-side unit for the `lb-ip-pool` capability. Emits a documentation `ConfigMap` recording the bound pool/CIDRs and carries the controller Deployment readiness marker. |

## Capabilities

Requires `lb-ip-pool`: one binding per ingress instance names the pool and
CIDR list for the MetalLB-backed LoadBalancer Service. Because the ingress
controller Service is the only LoadBalancer consumer in the simple bootstrap,
the bound pool is effectively this Service's external-IP source; narrow
`cidrs` to a single `/32` entry when an exact VIP is needed.

Example binding (env repo):

```yaml
- template: local/nginx-ingress
  bindings:
    - name: nginx-ingress-lb
      capability: lb-ip-pool
      provider: {repo: basic-infra, instance: metallb}
      values:
        poolName: ingress-pool
        cidrs: [172.18.255.200-172.18.255.210]   # or [172.18.255.200/32] for exact pin
```
