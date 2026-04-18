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
