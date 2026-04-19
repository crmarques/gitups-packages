# ADR 0001 — Monorepo with independent package lifecycle

## Status

Accepted.

## Context

`gitups-packages` is the catalog consumed by the gitups CLI. It started as a
flat repo where every top-level directory was a package and a single
CI workflow published every changed package with the composite OCI tag
`<name>-<version>`. As the catalog grew past ~10 packages we hit three
consistent frictions:

1. **No per-package release history.** All packages shared the same
   `gitups-packages` OCI repository; listing releases of a single package
   required filtering by tag prefix. Retention, pruning, and access control
   were also repo-wide.
2. **Release coupling by convention only.** Publishing was driven by a
   version bump in `package.yaml` on a push to `main`. It was easy to
   accidentally land a mixed-version bump across multiple packages. There was
   no way to ship a fix for one package without implicitly endorsing the
   state of every other package on that commit.
3. **No pinnable release contract.** There were no git tags per release, no
   SBOM, no provenance attestation, no digest recorded anywhere downstream
   could look it up. Consumers had no way to say *exactly this*.

We considered three alternatives:

1. **One repo per package.** Cleanest per-package lifecycle, worst
   contributor experience (N clones, N PRs for cross-cutting refactors),
   most duplicated tooling.
2. **Monorepo with repo-wide versioning** (e.g. `lerna`, synced bumps). Solves
   the per-PR consistency problem, but forces every unrelated package to
   accept a version bump for every release. Rejected — it is the exact
   opposite of independent lifecycle.
3. **Monorepo with per-package tags + per-package OCI paths.** Keeps the
   clone/PR simplicity of a monorepo but makes each package independently
   releasable, traceable, and extractable.

## Decision

We adopt option 3. Specifically:

- Packages live under `packages/<name>/`.
- Each package carries its own `metadata.version`.
- A release is identified by a git tag `pkg/<name>/v<version>`.
- Each package publishes to its own OCI path:
  `ghcr.io/<owner>/gitups-packages/<name>:<version>`.
- The release workflow is triggered by the tag push, not by main-branch
  merges.
- PRs validate only the changed packages (plus all packages if shared infra
  changes).
- The repo has no repo-wide version. There is no root `VERSION`, no root
  `CHANGELOG`.

## Consequences

**Positive**

- A fix in one package does not require touching, re-validating, or bumping
  any other.
- Consumers can pin a package by `<oci>:<X.Y.Z>` or by digest, independent
  of every other package's state.
- Per-package release history, retention, and access control on GHCR.
- Extracting a package into its own repo later is a file move + tag-prefix
  drop, with no downstream rewiring beyond the OCI path.
- Shared tooling (schema, scripts, workflows) lives in one place.

**Negative**

- More tags in the repo (one per release per package). Manageable; `git tag
  -l 'pkg/<name>/v*'` scopes them.
- Maintainers must remember to cut a tag — merging to main no longer
  publishes. We consider this a feature, not a bug: explicit is better than
  implicit for a release step.
- Consumers of the old `ghcr.io/<owner>/gitups-packages:<name>-<version>`
  path must re-pin to the new per-package path. This is a one-time
  cost.

**Neutral**

- CI cost is roughly the same: old workflow validated all packages on every
  push; new workflow validates only changed ones on PR, then publishes one on
  tag.
