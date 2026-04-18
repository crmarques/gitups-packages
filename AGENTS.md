# AGENTS.md - Gitups Packages

Read before changing this repository. This repo is the package catalog consumed
by Gitups.

## Repo Contract

- Each top-level directory is one package. The directory name must match
  `metadata.name` in that package's `package.yaml`.
- Each package must declare an exact `metadata.version`. Keep versions stable
  unless maintainers explicitly request package release versioning.
- Versions must be OCI-tag safe: use letters, numbers, dots, underscores, and
  dashes only. Do not use `latest`, floating ranges, or build metadata that
  requires `+`.
- Published artifacts use this reference shape:
  `ghcr.io/<owner>/gitups-packages:<metadata.name>-<metadata.version>`.
- Package definitions use `apiVersion: gitups/v1alpha1` and
  `kind: PackageDefinition`. Keep schema changes additive and compatible with
  the Gitups CLI.
- Pin all upstream inputs: chart versions, `startingCSV`, catalog sources,
  image tags, and upstream URLs must be exact.

## Package Authoring

- Prefer renderers in this order: OLM, Kustomize, Helm, raw. Use raw only for
  bootstrap assets or escape hatches.
- Put user-tunable settings in install/resource descriptor `spec.inputs[]`. Use
  `__GITUPS_PLACEHOLDER__` only through placeholder inputs, not as hidden
  template logic.
- For explicit image references, expose the image repository and tag or digest
  as separate inputs and compose the final reference in the template. Do not
  default an image tag to `latest`; if upstream ships a mutable latest tag,
  resolve it to an immutable digest before committing the package.
- Keep templates thin. Prefer explicit package defaults over optional template
  branches.
- Model one service/application per top-level package. Put install choices
  under `install/<renderer>/descriptor.yaml` and custom resources under
  `resources/<resourceTemplate>/descriptor.yaml`. Split top-level packages only
  for independently selectable services, platform primitives, or deliberate
  variants.
- Package README files should describe non-obvious inputs, placeholders,
  renderer choice, and any reason for not using a preferred renderer.

## Layout

```text
<package>/
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
```

## Publishing

- GitHub Actions publishes only packages whose package directory changed and
  whose `package.yaml` version changed in the same commit range.
- If package files change without a version bump, the workflow validates them
  but skips publishing.
- Do not republish an existing `<name>-<version>` tag; bump the package
  version for every new artifact.
- Package tarballs must be deterministic: no generated timestamps, random
  identifiers, or environment-specific bytes.

## Workflow

- Keep changes scoped to the package being edited unless a shared convention is
  intentionally changing.
- Do not store task notes or scratch state in package directories.
- When changing package behavior, run the focused Gitups validation that covers
  the affected package before handing off.
