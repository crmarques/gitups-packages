#!/usr/bin/env bash
# tools/package-build.sh
# Build a deterministic tarball for a single package.
#
# Usage:
#   tools/package-build.sh <package-name> [--out-dir DIR]
#
# Output:
#   <out-dir>/<name>-<version>.tgz
#   <out-dir>/<name>-<version>.tgz.sha256
#
# The tarball uses GNU tar flags to produce byte-for-byte reproducible archives
# for the same source tree:
#   --sort=name   --mtime=@0   --owner=0  --group=0  --numeric-owner
# and is gzipped with `gzip -n` to drop the mtime/name from the gzip header.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/common.sh
source "${here}/common.sh"

pkg_name=""
out_dir="${GP_REPO_ROOT}/dist"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      shift; out_dir="${1:?}"; shift ;;
    -h|--help)
      sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)
      gp_die "unknown flag: $1" ;;
    *)
      [[ -z "${pkg_name}" ]] || gp_die "multiple package names"; pkg_name="$1"; shift ;;
  esac
done

[[ -n "${pkg_name}" ]] || gp_die "usage: package-build.sh <package-name>"

pkg_dir="$(gp_package_dir "${pkg_name}")"
manifest="$(gp_package_manifest "${pkg_name}")"
[[ -d "${pkg_dir}" ]] || gp_die "package directory not found: packages/${pkg_name}/"
[[ -f "${manifest}" ]] || gp_die "manifest missing: packages/${pkg_name}/package.yaml"

gp_require_cmd python3
gp_require_cmd tar
gp_require_cmd gzip

version="$(gp_manifest_field "${manifest}" metadata.version)"
[[ -n "${version}" ]] || gp_die "metadata.version missing in ${manifest}"

# Default include list — every known package surface. Tooling works even if
# some are absent; the filter below drops missing paths.
default_includes=(
  "package.yaml"
  "README.md"
  "values.schema.json"
  "install"
  "resources"
  "templates"
  "manifests"
  "kubernetes-resource-controller"
  "service-resource-controller"
)

# package.yaml may override/extend the include list and add excludes.
mapfile -t include_list < <(python3 - "${manifest}" "${default_includes[@]}" <<'PY'
import sys, yaml
manifest, *defaults = sys.argv[1:]
with open(manifest) as f:
    doc = yaml.safe_load(f) or {}
pkg = ((doc.get("spec") or {}).get("package") or {})
inc = pkg.get("include") or []
if inc:
    for x in inc: print(x)
else:
    for x in defaults: print(x)
    if pkg.get("includeTests"):
        print("tests")
PY
)

mapfile -t exclude_list < <(python3 - "${manifest}" <<'PY'
import sys, yaml
manifest = sys.argv[1]
with open(manifest) as f:
    doc = yaml.safe_load(f) or {}
pkg = ((doc.get("spec") or {}).get("package") or {})
for x in pkg.get("exclude") or []:
    print(x)
PY
)

mkdir -p "${out_dir}"
out_dir="$(cd "${out_dir}" && pwd)"

stage="$(mktemp -d "${TMPDIR:-/tmp}/gp-build-${pkg_name}.XXXXXX")"
trap 'rm -rf "${stage}"' EXIT

dest="${stage}/${pkg_name}"
mkdir -p "${dest}"

# Copy each include path if present. Use cp -a to preserve structure but we'll
# normalise timestamps and ownership at tar time.
for entry in "${include_list[@]}"; do
  src="${pkg_dir}/${entry}"
  if [[ -e "${src}" ]]; then
    cp -a "${src}" "${dest}/${entry}"
  fi
done

# Apply excludes (relative to package root).
for pat in "${exclude_list[@]}"; do
  # shellcheck disable=SC2086
  find "${dest}" -path "${dest}/${pat}" -prune -exec rm -rf {} + 2>/dev/null || true
done

# Sanity: must contain a package.yaml after filtering.
[[ -f "${dest}/package.yaml" ]] || gp_die "refusing to build: package.yaml filtered out for ${pkg_name}"

archive="${out_dir}/${pkg_name}-${version}.tgz"

# Build with GNU-tar reproducibility flags, pipe through gzip -n.
# `find | sort` provides stable ordering regardless of filesystem listing.
(
  cd "${stage}"
  find "${pkg_name}" -print0 |
    LC_ALL=C sort -z |
    tar --no-recursion --null -T - \
        --owner=0 --group=0 --numeric-owner --mtime='@0' \
        --format=ustar -cf - |
    gzip -n -9 > "${archive}"
)

( cd "${out_dir}" && sha256sum "${pkg_name}-${version}.tgz" > "${pkg_name}-${version}.tgz.sha256" )

gp_log "built ${archive}"
gp_log "sha256:"
cat "${archive}.sha256" >&2

printf '%s\n' "${archive}"
