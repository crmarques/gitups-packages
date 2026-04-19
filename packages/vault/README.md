# vault

HashiCorp Vault package. Installed from the official HashiCorp Vault Helm
chart (`helm.releases.hashicorp.com`). The chart ships in dev mode by default
so the package is apply-safe on disposable kind clusters; flip
`server.dev.enabled` off and toggle `server.ha` or `server.standalone` for
non-ephemeral installs.

## Install Methods

| Name | Renderer | Notes |
|------|----------|-------|
| `helm` | `helm` | Upstream HashiCorp Vault chart pinned to `0.32.0` (appVersion `1.21.2`). |

## Resources

| Template | Renderer | Notes |
|----------|----------|-------|
| `config` | `raw` | Environment-specific review ConfigMap. |

## Inputs

| Name | Default | Notes |
|------|---------|-------|
| `namespace` | `vault` | install namespace |
| `chart.version` | `0.32.0` | Vault Helm chart version |
| `appVersion` | `1.21.2` | Vault application version shipped by the chart |
| `server.dev.enabled` | `true` | chart dev-mode toggle; leave on for bootstrap, off for prod |
| `server.dev.devRootToken` | **placeholder** | sensitive dev-mode root token |
| `ui.enabled` | `true` | enable Vault UI Service |
| `server.ha.enabled` | `false` | HA (Raft) mode |
| `server.standalone.enabled` | `false` | file-backed standalone mode |
| `injector.enabled` | `false` | sidecar injector webhook |

## Why Helm and not OLM?

HashiCorp does not maintain an OperatorHub/OLM bundle for Vault. The official
install path is Helm, which is the correct trust-bounded choice per AGENTS.md
renderer priority.
