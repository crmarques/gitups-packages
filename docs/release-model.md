# Release model

This document is the contract for how a package goes from source in
`packages/<name>/` to a pinnable, verifiable artifact in GHCR.

## Tag format

Every release is driven by a git tag of the form:

```
pkg/<package-name>/v<major>.<minor>.<patch>[-<prerelease>]
```

Examples:

- `pkg/keycloak/v1.0.0`
- `pkg/metallb/v0.14.2`
- `pkg/declarest/v0.1.0-rc.1`

Constraints:

- `<package-name>` must match the directory name under `packages/`.
- `<package-name>` must match `metadata.name` in that directory's
  `package.yaml`.
- The version after `v` must match `metadata.version` in that
  `package.yaml` **exactly**.
- `<package-name>` is DNS-1123 safe (`[a-z0-9-]+`).
- Version is SemVer 2.0 without build metadata (`+` is not allowed because
  it's not OCI-tag-safe).

If any of these constraints fail, the release workflow aborts before
publishing.

## Lifecycle

```
┌─────────────────┐
│  PR with edits  │
└────────┬────────┘
         │ pr-validate-packages.yml
         ▼  (schema + structure + test + dry build of changed packages)
┌─────────────────┐
│  Merge to main  │
└────────┬────────┘
         │ maintainer pushes pkg/<name>/v<version>
         ▼
┌─────────────────────┐
│ release-package.yml │
└────────┬────────────┘
         │  parse tag
         │  validate (tag ↔ dir ↔ manifest consistency)
         │  run tests
         │  build deterministic <name>-<version>.tgz
         │  generate SHA256
         │  generate SBOM
         │  oras push to GHCR with per-package OCI path
         │  tag :major, :major.minor, :stable, :latest (non-prerelease only)
         │  create provenance attestation
         │  refresh index/index.json
         │  create GitHub Release with assets
         ▼
┌─────────────────┐
│ Pinnable artifact │
└───────────────────┘
```

Merging to main **does not** publish. Only a `pkg/*/v*` tag publishes.

## OCI naming

```
<registry>/<owner>/gitups-packages/<package-name>:<tag>
```

With the default `ghcr.io`:

```
ghcr.io/<owner>/gitups-packages/<package-name>:<tag>
```

Each package gets its **own** OCI path, not a shared `gitups-packages` with
`<name>-<version>` composite tags. This keeps per-package tag history,
per-package retention, and per-package access control clean.

### Tags published per release

For a SemVer `X.Y.Z` release:

| Tag              | Moving? | When                                 |
| ---------------- | ------- | ------------------------------------ |
| `:X.Y.Z`         | No      | Always                               |
| `:X.Y`           | Yes     | Non-prerelease                       |
| `:X`             | Yes     | Non-prerelease                       |
| `:stable`        | Yes     | Non-prerelease                       |
| `:latest`        | Yes     | Non-prerelease                       |

For prereleases (`X.Y.Z-rc.1` etc.), only the exact `:X.Y.Z-...` tag is
published. Moving tags are never assigned to prereleases.

### Consumer guidance

For **production** use, pin by digest:

```
ghcr.io/<owner>/gitups-packages/keycloak@sha256:<hex>
```

The exact digest is recorded in `index/index.json` after each release.

For **development**, the version tag is fine:

```
ghcr.io/<owner>/gitups-packages/keycloak:1.2.3
```

The moving tags (`:stable`, `:latest`, `:1`, `:1.2`) are **convenience
pointers** and may change under you. Do not use them in reproducible flows.

## Media types

We use custom OCI media types so that a generic OCI client can tell our
artifacts apart from container images:

| Role            | Media type                                         |
| --------------- | -------------------------------------------------- |
| Artifact type   | `application/vnd.gitups.package.v1+tar`            |
| Layer           | `application/vnd.gitups.package.layer.v1.tar+gzip` |

The artifact is a single layer: the deterministic `<name>-<version>.tgz`
tarball (see [package-format.md](package-format.md)).

## Artifact manifest annotations

Each pushed manifest carries:

- `org.opencontainers.image.title` = `<package-name>`
- `org.opencontainers.image.version` = `<version>`
- `org.opencontainers.image.source` = repo URL
- `org.opencontainers.image.revision` = git SHA
- `io.gitups.package.name` = `<package-name>`
- `io.gitups.package.version` = `<version>`

## Metadata artifacts

Alongside the main OCI push, every release produces:

| File                                        | Purpose                                   |
| ------------------------------------------- | ----------------------------------------- |
| `<name>-<version>.tgz`                      | Deterministic source archive (primary)    |
| `<name>-<version>.tgz.sha256`               | SHA256 of the archive                     |
| `<name>-<version>.sbom.spdx.json`           | SPDX SBOM (best-effort, via `syft`)       |
| Provenance attestation (GitHub OIDC)        | `actions/attest-build-provenance`         |

All of these are attached as GitHub Release assets. The SHA256 and SBOM are
also uploadable to OCI as referrers in a future revision of the workflow.

## Determinism

The tarball is **reproducible**: same source tree → same bytes → same digest.
We enforce this via GNU tar flags in [tools/package-build.sh](../tools/package-build.sh):

- `--sort=name` — stable file order
- `--owner=0 --group=0 --numeric-owner` — no UID/GID leakage
- `--mtime=@0` — zero timestamps
- `--format=ustar` — stable format
- `gzip -n -9` — drop the gzip header's mtime/name field

If you change packaging logic, validate determinism by building twice and
diffing the sha256.

## Never republish

Re-pushing `pkg/<name>/v<X>` to a version that has already been published is a
policy violation. The publish workflow checks GHCR for existing manifests and
aborts if one exists. To ship a fix, bump the version and cut a new tag.

## Immutability guarantee

We guarantee that a given `<package-name>:<X.Y.Z>` tag (the exact, non-moving
one) resolves to a stable digest for the lifetime of the artifact in GHCR.
The moving tags (`:latest`, `:stable`, `:X.Y`, `:X`) are explicitly
**not** immutable.
