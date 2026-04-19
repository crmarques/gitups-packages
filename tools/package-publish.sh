#!/usr/bin/env bash
# tools/package-publish.sh
# Publish a built package tarball to GHCR as an OCI artifact using ORAS.
#
# Usage:
#   tools/package-publish.sh <package-name> [--archive PATH] [--registry HOST]
#                           [--owner ORG] [--extra-tag TAG ...]
#
# Reference shape:
#   <registry>/<owner>/gitups-packages/<name>:<version>
#
# Also publishes moving tags when appropriate (:major, :major.minor, :stable,
# :latest). See docs/release-model.md for the immutability story.
#
# Requires: oras (https://oras.land), either in PATH or at $ORAS_BIN.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/common.sh
source "${here}/common.sh"

pkg_name=""
archive=""
registry="${GHCR_REGISTRY:-ghcr.io}"
owner="${GHCR_OWNER:-}"
extra_tags=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --archive)  shift; archive="${1:?}"; shift ;;
    --registry) shift; registry="${1:?}"; shift ;;
    --owner)    shift; owner="${1:?}"; shift ;;
    --extra-tag) shift; extra_tags+=("${1:?}"); shift ;;
    -h|--help)
      sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)
      gp_die "unknown flag: $1" ;;
    *)
      [[ -z "${pkg_name}" ]] || gp_die "multiple package names"; pkg_name="$1"; shift ;;
  esac
done

[[ -n "${pkg_name}" ]] || gp_die "usage: package-publish.sh <package-name>"
[[ -n "${owner}" ]] || gp_die "--owner (or env GHCR_OWNER) required"

manifest="$(gp_package_manifest "${pkg_name}")"
[[ -f "${manifest}" ]] || gp_die "manifest missing: ${manifest}"

version="$(gp_manifest_field "${manifest}" metadata.version)"
[[ -n "${version}" ]] || gp_die "metadata.version missing in ${manifest}"

if [[ -z "${archive}" ]]; then
  archive="${GP_REPO_ROOT}/dist/${pkg_name}-${version}.tgz"
fi
[[ -f "${archive}" ]] || gp_die "archive not found: ${archive} (run package-build.sh first)"

ORAS_BIN="${ORAS_BIN:-oras}"
command -v "${ORAS_BIN}" >/dev/null 2>&1 || gp_die "oras not found (install from https://oras.land)"

# Derive moving tags. Prereleases do NOT receive :latest/:stable/:major.
derive_moving_tags() {
  local v="$1"
  local core="${v%%-*}"  # strip prerelease
  local prerelease=""
  [[ "${v}" == *-* ]] && prerelease="${v#*-}"

  if [[ -n "${prerelease}" ]]; then
    return 0
  fi
  IFS='.' read -r major minor _patch <<< "${core}"
  printf '%s\n' "${major}"
  printf '%s\n' "${major}.${minor}"
  printf '%s\n' "stable"
  printf '%s\n' "latest"
}

base_ref="${registry}/${owner}/gitups-packages/${pkg_name}"
primary_ref="${base_ref}:${version}"

gp_log "pushing ${archive} -> ${primary_ref}"

# Media types documented in docs/release-model.md.
artifact_type="application/vnd.gitups.package.v1+tar"
layer_media_type="application/vnd.gitups.package.layer.v1.tar+gzip"

annotations_tmp="$(mktemp)"
trap 'rm -f "${annotations_tmp}"' EXIT
cat > "${annotations_tmp}" <<JSON
{
  "\$manifest": {
    "org.opencontainers.image.title": "${pkg_name}",
    "org.opencontainers.image.version": "${version}",
    "org.opencontainers.image.source": "https://github.com/${owner}/gitups-packages",
    "io.gitups.package.name": "${pkg_name}",
    "io.gitups.package.version": "${version}"
  }
}
JSON

# Push against a local working dir so the layer path inside the manifest is
# just the basename (cleaner artifact listing).
pushd "$(dirname "${archive}")" >/dev/null
"${ORAS_BIN}" push \
  --artifact-type "${artifact_type}" \
  --annotation-file "${annotations_tmp}" \
  "${primary_ref}" \
  "$(basename "${archive}"):${layer_media_type}"
popd >/dev/null

# Moving tags: 'oras tag' aliases primary_ref digest to additional tags.
mapfile -t moving < <(derive_moving_tags "${version}")
for t in "${moving[@]}" "${extra_tags[@]}"; do
  [[ -n "${t}" ]] || continue
  gp_log "tagging ${base_ref}:${t}"
  "${ORAS_BIN}" tag "${primary_ref}" "${base_ref}:${t}"
done

# Resolve digest for index/metadata consumers.
digest="$("${ORAS_BIN}" resolve "${primary_ref}")"
gp_log "published ${primary_ref} @ ${digest}"
printf '%s@%s\n' "${primary_ref}" "${digest}"
