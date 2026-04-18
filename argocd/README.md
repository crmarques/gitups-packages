# argocd

Argo CD service package. Generic repositories install Argo CD with the default
OLM install method unless `installMethod: helm` is selected. Env repositories
derive the default `instance` and `applications` resources from the referenced
generic repo.

```yaml
repositories:
  - name: gitops-controllers
    type: k8s-gitops-generic
    packages:
      - template: local/argocd
  - name: gitops-controllers-{{.Env}}
    type: k8s-gitops-env
    repoRef:
      name: gitops-controllers
      commit: main
```

## Install Methods

| Name | Renderer | Notes |
|------|----------|-------|
| `olm` | `olm` | Argo CD operator Subscription, pinned to `argocd-operator.v0.17.0`. |
| `helm` | `helm` | Upstream Argo CD chart, pinned to chart version `9.5.2` (appVersion `v3.3.7`). |

## Resources

| Template | Renderer | Notes |
|----------|----------|-------|
| `instance` | `raw` | `ArgoCD` custom resource. |
| `applications` | `raw` | Root App-of-Apps pointing at the GitOps repo. |

## Inputs

| Name | Default | Notes |
|------|---------|-------|
| `namespace` | `argocd` | namespace the install lives in |
| `instance` | `argocd` | `ArgoCD` resource name |
| `olm.startingCSV` | `argocd-operator.v0.17.0` | OLM install CSV pin |
| `chart.version` | `9.5.2` | Helm chart version used for render |
| `appVersion` | `v3.3.7` | Helm install review value |
| `repoURL` | **placeholder** | base repo URL for the generated root App-of-Apps |
| `targetRevision` | `HEAD` | Git revision used by the root App-of-Apps |
| `server.ingress.enabled` | `false` | Helm install value |
