# metallb

MetalLB service package. Generic repositories install MetalLB with the default
OLM install method unless `installMethod: helm` is selected. Env repositories
derive the default `config` resource from the referenced generic repo.

```yaml
repositories:
  - name: basic-infra
    type: k8s-gitops-generic
    packages:
      - template: local/metallb
        installMethod: helm
  - name: basic-infra-{{.Env}}
    type: k8s-gitops-env
    repoRef:
      name: basic-infra
      commit: main
```

## Install Methods

| Name | Renderer | Notes |
|------|----------|-------|
| `olm` | `olm` | MetalLB operator Subscription, pinned to `metallb-operator.v0.14.0`. |
| `helm` | `helm` | Upstream MetalLB chart, pinned to chart version `0.15.3` (appVersion `v0.15.3`). |

## Resources

| Template | Renderer | Notes |
|----------|----------|-------|
| `config` | `raw` | `MetalLB`, `IPAddressPool`, and `L2Advertisement` resources. |
| `pool`   | `raw` | Single `IPAddressPool` + `L2Advertisement` synthesized from an `lb-ip-pool` binding. |

## Capabilities

Provides `lb-ip-pool`: consumers (ingress controllers, HAProxy, etc.) bind a pool name and CIDR list; expand synthesizes a dedicated `IPAddressPool` + `L2Advertisement` via the `pool` resource template. An exact-IP pin is expressed by narrowing `cidrs` to a single `/32` entry.

## Inputs

| Name | Default | Notes |
|------|---------|-------|
| `namespace` | `metallb-system` | namespace the install lives in |
| `olm.startingCSV` | `metallb-operator.v0.14.0` | OLM install CSV pin |
| `chart.version` | `0.15.3` | Helm chart version used for render |
| `appVersion` | `v0.15.3` | Helm install review value |
| `addressPools` | pool named `default` with a single placeholder CIDR | the CIDR entries are site-specific; must be filled before render |

The e2e fixture selects `installMethod: helm` because the OperatorHub
`metallb-operator.v0.14.0` CSV available from the bundled OLM catalog
references `quay.io/metallb/controller:main` for its webhook deployment. That
violates Gitups' pinning rule and currently fails on kind.
