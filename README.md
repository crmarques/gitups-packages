# gitups-packages

Monorepo of **independently versioned** packages consumed by the
[gitups](https://github.com/crmarques/gitups) CLI.

- One package per directory under `packages/<name>/`.
- Each package ships its own `package.yaml`, its own version, its own OCI
  artifact. Nothing in this repo is versioned at the repo level.
- Releases are driven by per-package git tags: `pkg/<name>/v<version>`.
- Artifacts are published to GHCR as OCI bundles:
  `ghcr.io/<owner>/gitups-packages/<name>:<version>`.

## Quickstart

### Validate a package

```bash
# Uses the JSON schema + checks directory/manifest name/version consistency.
tools/validate-package.sh keycloak
# or, against a prospective release tag:
tools/validate-package.sh --tag pkg/keycloak/v0.0.1
```

### Build a package tarball locally

```bash
tools/package-build.sh keycloak
# writes dist/keycloak-0.0.1.tgz and dist/keycloak-0.0.1.tgz.sha256
```

The tarball is deterministic — same source tree produces identical bytes and
SHA256.

### Simulate a release locally

```bash
# 1. validate
tools/validate-package.sh keycloak

# 2. build
tools/package-build.sh keycloak

# 3. push to your own GHCR namespace (requires oras + docker login)
tools/package-publish.sh keycloak \
  --owner your-user \
  --archive dist/keycloak-0.0.1.tgz
```

### Cut a real release

```bash
# 1. bump metadata.version in packages/<name>/package.yaml on main
# 2. tag and push
git tag pkg/keycloak/v0.0.2
git push origin pkg/keycloak/v0.0.2
# The release-package workflow runs: validate → build → sbom → oras push
# → provenance attestation → update index.json → GitHub Release.
```

## Repo layout

```
.
├── README.md                         # this file
├── AGENTS.md                         # authoring contract for agents
├── docs/
│   ├── architecture.md               # why monorepo + independent lifecycle
│   ├── package-format.md             # manifest + directory layout
│   ├── release-model.md              # tag / publish / pin contract
│   └── adr/
│       └── 0001-monorepo-independent-package-lifecycle.md
├── schemas/
│   └── package.schema.json           # JSON schema for package.yaml
├── tools/
│   ├── common.sh                     # shared helpers (sourced, not run)
│   ├── parse-tag.sh                  # pkg/<name>/v<version> → (name, version)
│   ├── detect-changed-packages.sh    # git diff → changed package list
│   ├── validate-package.sh           # schema + consistency + structure
│   ├── package-build.sh              # deterministic tarball
│   ├── package-publish.sh            # oras push to GHCR
│   └── generate-index.sh             # rebuild index/index.json
├── .github/
│   └── workflows/
│       ├── pr-validate-packages.yml  # PR: validate changed packages
│       └── release-package.yml       # tag push: build + publish one package
├── packages/
│   ├── example-package/              # minimal end-to-end example
│   ├── another-example/              # alternate layout example
│   ├── argocd/
│   ├── declarest/
│   ├── gitea/
│   ├── haproxy/
│   ├── keycloak/
│   ├── metallb/
│   ├── nginx-ingress/
│   ├── olm/
│   ├── service-mesh/
│   └── vault/
└── index/
    └── index.json                    # machine-readable catalog view
```

## Release flow at a glance

1. Work on a package in a branch.
2. Open a PR. CI validates only the packages you touched (or all, if shared
   infra changed).
3. Merge to `main`. Nothing is published yet.
4. Bump `metadata.version` if you haven't already and push a tag
   `pkg/<name>/v<version>`.
5. The release workflow validates tag/dir/manifest consistency, builds a
   deterministic tarball, computes SHA256, generates an SBOM, pushes to GHCR
   with per-package OCI path, generates a provenance attestation, refreshes
   the index, and creates a GitHub Release.

Read [docs/release-model.md](docs/release-model.md) for the full contract
(tag format, OCI naming, moving tags, digest pinning, determinism).

## Consuming a package

In gitups, reference the catalog as a filesystem source. Paths are resolved
relative to the provision file:

```yaml
spec:
  sources:
    - name: local-catalog
      type: filesystem
      path: ../../../gitups-packages/packages
```

For pinnable remote consumption, pull the OCI artifact by **digest**:

```bash
oras pull ghcr.io/your-user/gitups-packages/keycloak@sha256:<hex>
```

See [docs/release-model.md#consumer-guidance](docs/release-model.md) for
pin-by-digest vs pin-by-tag guidance.

## Contributing

- Read [AGENTS.md](AGENTS.md) and [docs/package-format.md](docs/package-format.md).
- One package per PR when possible. Keep shared-infra changes in separate PRs.
- Use `make` targets (see `Makefile`) for local loops.
