# AGENTS.md - Gitups Packages

Read before changing this repository. This repo is the monorepo catalog
consumed by Gitups. Every package lives under `packages/<name>/` and is
released independently.

## Repo Contract

- Each directory under `packages/` is one package. The directory name must
  match `metadata.name` in that package's `package.yaml`.
- Each package declares its own `metadata.version`. No repo-wide version, no
  synchronised bumps. Independent lifecycle is non-negotiable — see
  [docs/adr/0001-monorepo-independent-package-lifecycle.md](docs/adr/0001-monorepo-independent-package-lifecycle.md).
- Versions are SemVer `X.Y.Z[-prerelease]`, no leading `v`, no `+` build
  metadata (must remain OCI-tag safe).
- Packages validate against [`schemas/package.schema.json`](schemas/package.schema.json).
  `apiVersion` is `gitups/v1alpha1`, `kind` is `PackageDefinition`. Schema
  changes are additive while the API is `v1alpha1`.
- Pin all upstream inputs: chart versions, `startingCSV`, catalog sources,
  image tags, and upstream URLs must be exact. Never `latest` or floating
  ranges.

## Release Contract

- A release is triggered by a git tag of the form `pkg/<name>/v<version>`.
  Nothing else publishes. Pushing to `main` only validates.
- The tag's `<name>` must match the package directory name, and the tag's
  `<version>` (without leading `v`) must equal `metadata.version` in that
  package's `package.yaml`. The release workflow aborts on any mismatch.
- Every release publishes to its own per-package OCI path:
  `ghcr.io/<owner>/gitups-packages/<name>:<version>`. The old composite
  convention (`gitups-packages:<name>-<version>`) is retired.
- Moving tags (`:latest`, `:stable`, `:<major>`, `:<major>.<minor>`) are
  published for non-prerelease versions only. Consumers pin by exact
  version tag or by digest; moving tags are explicitly not immutable.
- Release tarballs are deterministic: sorted files, zero timestamps, zero
  ownership, gzip `-n`. See [docs/release-model.md](docs/release-model.md).

## Package Authoring

- Prefer renderers in this order: OLM, Kustomize, Helm, raw. Use raw only
  for bootstrap assets or escape hatches.
- Put user-tunable settings in install/resource `spec.inputs[]`. Use
  `__GITUPS_PLACEHOLDER__` only through placeholder inputs, not as hidden
  template logic.
- For image references, expose the image repository and tag or digest as
  separate inputs and compose the final reference in the template. Do not
  default an image tag to `latest`; if upstream ships a mutable latest tag,
  resolve it to an immutable digest before committing the package.
- Keep templates thin. Prefer explicit package defaults over optional
  template branches.
- Model one service/application per package. Put install choices under
  `install/<renderer>/descriptor.yaml` and custom resources under
  `resources/<resourceTemplate>/descriptor.yaml`. Controllers carry an
  additional `kubernetes-resource-controller/` or
  `service-resource-controller/` domain directory.
- Package README files describe non-obvious inputs, placeholders, renderer
  choice, and any reason for not using a preferred renderer.

### Optional packaging overrides

If a package does not follow the default install/resources shape (e.g. a
vendored chart with a custom manifests/templates layout), use
`spec.package.include` / `spec.package.exclude` / `spec.package.includeTests`
in `package.yaml` to control what goes into the release tarball. See
[docs/package-format.md#packaging-overrides](docs/package-format.md#packaging-overrides).

## Layout

```text
packages/<name>/
  package.yaml
  README.md
  install/
    <renderer>/
      descriptor.yaml
      raw/ | overlays/ | scripts/
  resources/
    <resourceTemplate>/
      descriptor.yaml
      raw/ | overlays/ | scripts/
  kubernetes-resource-controller/    # KRC only
    <intent>/descriptor.yaml
  service-resource-controller/       # SRC only
    <intent>/descriptor.yaml
  tests/                             # optional, excluded from tarball by default
  values.schema.json                 # optional
```

## Workflows

Pull requests (`pr-validate-packages.yml`):

- `tools/detect-changed-packages.sh` computes the set of changed packages
  relative to the PR base. If any shared-infra file changes
  (`schemas/`, `tools/`, `.github/workflows/`), all packages are validated.
- For each changed package: schema validation, manifest/dir/version
  consistency check, `tests/run.sh` (if present), and a dry tarball build.
- No artifacts are pushed from PRs.

Releases (`release-package.yml`):

- Triggered by pushes of tags matching `pkg/*/v*`.
- Parses the tag, validates the single referenced package, runs its tests,
  builds a deterministic tarball, computes SHA256, generates an SBOM, pushes
  the artifact to GHCR via ORAS, generates a provenance attestation,
  regenerates `index/index.json`, and creates a GitHub Release.

## Local Tooling

- `make validate PKG=<name>` — schema + structure
- `make build PKG=<name>` — deterministic tarball into `dist/`
- `make publish PKG=<name> OWNER=<org>` — push to GHCR (requires oras login)
- `make index` — regenerate `index/index.json` from manifest state
- `make validate-all` / `make build-all` — catalog-wide loops

See [README.md](README.md) for the full quickstart, and
[tools/](tools/) for the underlying shell scripts.

## Workflow

- Keep changes scoped to the package being edited unless a shared convention
  is intentionally changing.
- Do not store task notes or scratch state in package directories.
- When changing package behavior, run the focused Gitups validation that
  covers the affected package before handing off.
- When a package reaches end of life, set `metadata.deprecated` with a
  `reason` and (optionally) `replacedBy` / `since`. The index will surface
  deprecation automatically.
