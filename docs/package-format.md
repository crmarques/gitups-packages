# Package format

This document defines the layout and manifest schema for a package under
`packages/<name>/`. Every package is validated against
[`schemas/package.schema.json`](../schemas/package.schema.json) in CI.

## Directory layout

```text
packages/<name>/
  package.yaml              # REQUIRED — manifest
  README.md                 # strongly recommended
  install/
    <renderer>/             # one of: helm, kustomize, olm, raw
      descriptor.yaml
      raw/ | overlays/ | scripts/ | values.yaml.tmpl | ...
  resources/
    <resourceTemplate>/
      descriptor.yaml
      raw/ | overlays/ | scripts/ | ...
  kubernetes-resource-controller/   # only for role: kubernetes-resource-controller
    <intent>/descriptor.yaml
  service-resource-controller/      # only for role: service-resource-controller
    <intent>/descriptor.yaml
  tests/                    # optional — run from tests/run.sh
    run.sh
  values.schema.json        # optional — JSON schema for package inputs
```

None of the sub-directories are required at the filesystem level; the schema
only requires `package.yaml`. The package's role and install method determine
which sub-directories are meaningful at render time.

## `package.yaml`

Minimal example:

```yaml
apiVersion: gitups/v1alpha1
kind: PackageDefinition
metadata:
  name: example-package
  version: 0.1.0
  description: Example package that does nothing useful.
spec:
  role: workload
  category: example
  defaultInstall: raw
```

Full field reference is in [`schemas/package.schema.json`](../schemas/package.schema.json).
Key fields:

| Field                         | Required | Meaning                                                    |
| ----------------------------- | -------- | ---------------------------------------------------------- |
| `apiVersion`                  | yes      | Must be `gitups/v1alpha1`                                  |
| `kind`                        | yes      | Must be `PackageDefinition`                                |
| `metadata.name`               | yes      | Equals directory name. DNS-1123 safe.                      |
| `metadata.version`            | yes      | SemVer `X.Y.Z[-prerelease]`. No leading `v`.               |
| `metadata.description`        | no       | Shown in the index and GHCR listings.                      |
| `metadata.deprecated`         | no       | `{reason, replacedBy?, since?}` when the package is EOL.   |
| `spec.role`                   | yes      | `workload` \| `kubernetes-resource-controller` \| `service-resource-controller` |
| `spec.category`               | no       | Free-form grouping (`identity`, `ingress`, `mesh`, …)      |
| `spec.defaultInstall`         | no       | Default renderer (`helm`, `olm`, `kustomize`, `raw`)       |
| `spec.defaultResources`       | no       | Resources auto-selected when this package is picked        |
| `spec.readiness`              | no       | Readiness probes gitups core waits on at `apply` time      |
| `spec.provides` / `requires`  | no       | Capability bindings (free-form names)                      |
| `spec.implements` / `bundles` | no       | Service-config interfaces (free-form names)                |
| `spec.cli`                    | no       | SRC CLI contract                                           |
| `spec.compatibility`          | no       | Kubernetes version constraints, `gitupsMinVersion`         |
| `spec.dependencies`           | no       | Other packages this one depends on (`[{name, version}]`)   |
| `spec.package.include/exclude/includeTests` | no | Packaging overrides (see below)                       |

### Packaging overrides

By default, [tools/package-build.sh](../tools/package-build.sh) includes
these paths from a package directory if they exist:

```
package.yaml
README.md
values.schema.json
install/
resources/
templates/
manifests/
kubernetes-resource-controller/
service-resource-controller/
```

`tests/` is **not** included by default. To include it, set:

```yaml
spec:
  package:
    includeTests: true
```

To replace the include list entirely (for packages with a non-standard
layout):

```yaml
spec:
  package:
    include:
      - package.yaml
      - README.md
      - my-custom-dir
    exclude:
      - "my-custom-dir/*.secret"
```

`include` is matched by path prefix. `exclude` is matched as a path glob
relative to the package root and applied after include.

## Determinism rules

The release tarball is reproducible. This means the package source must also
be deterministic:

- No generated timestamps, random IDs, or environment-dependent bytes in
  committed files.
- Pin every upstream input: chart versions, `startingCSV`, catalog sources,
  image tags, upstream URLs. Never use `latest` or floating ranges.
- Don't write files in `tests/run.sh` that get picked up by the tarball;
  write to a temp directory.

## Validation

Local:

```bash
make validate PKG=<name>
# or
tools/validate-package.sh <name>
```

CI runs the same script on every changed package for every PR, and again on
the tagged package for every release.

## Authoring tips

- **One service per package.** Don't bundle two unrelated things.
- **Thin templates, rich defaults.** Prefer exposing a small set of
  `descriptor.yaml` `spec.inputs[]` over branching template logic.
- **README first.** Non-obvious inputs, placeholders, renderer choice, and
  reasons for not using a preferred renderer belong in `README.md`.
- **Free-form capability names.** If you coin a new capability
  (`provides[]` / `requires[]`) or a new interface (`implements[]` /
  `bundles[]`), document it in your README so downstream authors know it
  exists.

## Migrating an existing package

If you're extracting a package from a downstream repo:

1. Create `packages/<name>/`, copy files.
2. Write `package.yaml` with the minimal required fields.
3. `tools/validate-package.sh <name>`
4. `tools/package-build.sh <name>` — inspect `dist/<name>-<version>.tgz`.
5. Open a PR. The `pr-validate-packages.yml` workflow will do schema +
   structure + test + dry-build on CI.
6. Cut a release: `git tag pkg/<name>/v<version> && git push --tags`.
