# Architecture

`gitups-packages` is a **monorepo** of **independently versioned** packages.
Each package under `packages/<name>/` has its own version, its own release
cadence, and its own published artifact. The repo shares tooling, CI, schema,
and docs, but no package version is ever coupled to any other.

## Why a monorepo

We picked a monorepo over one-repo-per-package for operational simplicity:

- One clone, one PR surface, one set of review conventions.
- One schema, one set of tools, one set of workflows — consistent across
  packages without copy-pasting.
- Cross-package refactors (capability names, shared conventions, test
  scaffolding) happen in a single PR rather than N coordinated PRs.
- Contributors who author or review more than one package don't juggle N
  working trees.

We keep the monorepo **decoupled**, so a package can move out later (see
[Future-proofing](#future-proofing) below).

## Why independent versions

Each package is a product in its own right. It has its own upstream, its own
stability guarantees, its own consumers, and its own release cadence. A bug fix
in `keycloak` should not force a version bump on `vault`. A breaking change
in `metallb` should not drag the rest of the catalog behind it.

This means:

- There is **no repo-wide version** — no root `VERSION` file, no root
  `CHANGELOG`, no `lerna`-style synchronised bump.
- A release is identified by a **per-package tag**:
  `pkg/<name>/v<major>.<minor>.<patch>[-prerelease]`.
- The CI release workflow parses the tag, validates that exactly that
  package/version is consistent, and publishes only that package.

## Release flow (high-level)

```
  developer pushes pkg/keycloak/v1.2.3
        │
        ▼
  .github/workflows/release-package.yml
        │
        ├── tools/parse-tag.sh          → name=keycloak  version=1.2.3
        ├── tools/validate-package.sh   → schema + dir/name/version consistency
        ├── tools/package-build.sh      → deterministic keycloak-1.2.3.tgz
        ├── tools/package-publish.sh    → oras push to GHCR
        ├── sbom + provenance attestation
        └── tools/generate-index.sh     → index/index.json refreshed
```

Pull requests go through `pr-validate-packages.yml`, which **only validates
the packages that changed** (plus every package if shared infra changes).

See [release-model.md](release-model.md) for the full contract.

## Boundary between gitups core and gitups-packages

`gitups-packages` is consumed by the gitups CLI as a *package source*. The CLI
walks `packages/<name>/package.yaml` at resolve time and the packages flow
through `Provision → FullProvision → render`. Nothing in gitups core
hard-codes package names; nothing in a package hard-codes consumer repos.

This means:

- New packages can be added without changing gitups core.
- gitups core features (capability bindings, SRC projection, KRC
  reconciliation) are driven by **free-form name strings** in package
  manifests (`provides[]`, `requires[]`, `implements[]`, `bundles[]`), not by
  a closed registry baked into the core. Adding a new capability is a
  package-level operation.

## Future-proofing: moving a package to its own repo

The per-package OCI path (`ghcr.io/<owner>/gitups-packages/<name>`) and the
per-package tag (`pkg/<name>/v<version>`) are both **already independent of
the monorepo**. To extract a package:

1. Copy `packages/<name>/` into a new repo as the root.
2. Copy `schemas/`, `tools/`, `.github/workflows/release-package.yml`, and
   `docs/` as needed (or vendor them).
3. Tags become `v<version>` (the `pkg/<name>/` prefix is dropped, since there
   is only one package in the new repo).
4. Publish under the new repo's OCI path, or keep publishing under the old
   path if downstreams depend on it.
5. Delete the package from the monorepo.

No consumer needs to rewire anything except the OCI path (if it changes),
because the per-package release contract is already stable.

## Non-goals

- `gitups-packages` is **not** a Helm repo, an OLM catalog, or a Kustomize
  base. It is a source-of-truth catalog for gitups PackageDefinitions; each
  package *may* use Helm/Kustomize/OLM/raw under `install/<renderer>/`, but
  the packaging contract here is gitups-native.
- It is **not** a runtime — no controllers, no reconcilers, no cluster access.
- It is **not** a secret store — placeholders are resolved by gitups core at
  render/expand time, not here.
