# olm

Operator Lifecycle Manager (OLM) service package. It installs the pinned
upstream CRD and runtime bundles through one raw install descriptor.

## Why raw?

OLM does not publish a maintained community Helm chart. Upstream distributes
two YAML bundles per release (`crds.yaml`, `olm.yaml`) and installation is a
two-step `kubectl apply`. Gitups ships the CRD bundle verbatim and renders the
runtime bundle from `install/raw/raw/olm.yaml.tmpl` so image and release pins
are reviewable package inputs.

## Install Methods

| Name | Renderer | Target repo | Notes |
|------|----------|-------------|-------|
| `raw` | `raw` | selected generic repo | CRDs plus control plane bundle from the pinned OLM release. |

## Inputs

| Name | Default | Notes |
|------|---------|-------|
| `namespace` | `olm` | namespace where the OLM control plane runs |
| `release` | `v0.42.0` | mirrors the upstream tag the checked-in bundles were pulled from |
| `podSecurity.version` | `v1.35` | Kubernetes Pod Security Standards policy version for OLM namespaces |
| `images.olm.repository` | `quay.io/operator-framework/olm` | OLM runtime image repository |
| `images.olm.digest` | `36563571fdddf266ab871efcec0fbd98d3b74bff14506718aa79f9853712d640` | OLM runtime image digest |
| `images.configmapOperatorRegistry.repository` | `quay.io/operator-framework/configmap-operator-registry` | configmap registry image repository |
| `images.configmapOperatorRegistry.digest` | `3e259e1e339ad9d388cb611745312ae1c0390c9338bfd6d9965811e1978d9d1c` | configmap registry image digest |
| `images.opm.repository` | `quay.io/operator-framework/opm` | opm image repository |
| `images.opm.digest` | `f778630c62ee19b0aeda9969c2488de88ce84d5b1d040c97a33f9f38832bab14` | opm image digest |
| `catalog.image.repository` | `quay.io/operatorhubio/catalog` | OperatorHub catalog image repository |
| `catalog.image.digest` | `9fbfd70da2cedae8754fb8ed1b4d9c55733b5a7e06685d34aa415063cd964743` | OperatorHub catalog image digest |

## Upgrading the pin

1. Bump `inputs[name: release].default` in `install/raw/descriptor.yaml`.
2. Replace `install/raw/raw/crds.yaml` and refresh
   `install/raw/raw/olm.yaml.tmpl` from the upstream release while preserving
   the image and release template inputs.
3. Resolve any upstream mutable latest image tags to immutable digests before
   committing the package.
4. Sanity-check `kubectl apply --dry-run=server` on a kind cluster.
