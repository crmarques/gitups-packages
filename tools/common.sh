#!/usr/bin/env bash
# tools/common.sh
# Shared helpers for gitups-packages automation. Source, don't execute.
#
# Usage:
#   # shellcheck source=tools/common.sh
#   source "${repo_root}/tools/common.sh"

set -euo pipefail

# --- repo paths -------------------------------------------------------------

# Resolve the repo root (containing packages/, tools/, schemas/, ...).
gp_repo_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  (cd "${here}/.." && pwd)
}

GP_REPO_ROOT="${GP_REPO_ROOT:-$(gp_repo_root)}"
GP_PACKAGES_DIR="${GP_REPO_ROOT}/packages"
GP_SCHEMAS_DIR="${GP_REPO_ROOT}/schemas"
GP_TOOLS_DIR="${GP_REPO_ROOT}/tools"
GP_INDEX_DIR="${GP_REPO_ROOT}/index"

export GP_REPO_ROOT GP_PACKAGES_DIR GP_SCHEMAS_DIR GP_TOOLS_DIR GP_INDEX_DIR

# --- logging ---------------------------------------------------------------

gp_log()  { printf 'gitups-packages: %s\n' "$*" >&2; }
gp_err()  { printf 'gitups-packages: error: %s\n' "$*" >&2; }
gp_die()  { gp_err "$*"; exit 1; }

# --- tag parsing -----------------------------------------------------------
#
# Tag format: pkg/<package-name>/v<semver>
#
# gp_parse_tag TAG   -> prints "<name> <version>" on stdout
#                       (version is the semver WITHOUT the leading 'v')

gp_parse_tag() {
  local tag="${1:-}"
  [[ -n "${tag}" ]] || gp_die "gp_parse_tag: empty tag"

  # strip optional refs/tags/ prefix
  tag="${tag#refs/tags/}"

  local re='^pkg/([a-z0-9][a-z0-9-]*[a-z0-9])/v([0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?)$'
  if [[ ! "${tag}" =~ ${re} ]]; then
    gp_die "invalid release tag: '${tag}' (expected pkg/<name>/v<major>.<minor>.<patch>[-prerelease])"
  fi
  printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
}

# --- package metadata ------------------------------------------------------

gp_package_dir() {
  local name="${1:?gp_package_dir: name required}"
  printf '%s/%s\n' "${GP_PACKAGES_DIR}" "${name}"
}

gp_package_manifest() {
  local name="${1:?gp_package_manifest: name required}"
  printf '%s/%s/package.yaml\n' "${GP_PACKAGES_DIR}" "${name}"
}

# gp_manifest_field MANIFEST JQ_PATH
#   Reads a scalar from a package.yaml. Uses python yaml if available,
#   falling back to yq when present.
gp_manifest_field() {
  local manifest="${1:?}" path="${2:?}"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "${manifest}" "${path}" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    doc = yaml.safe_load(f) or {}
cur = doc
for key in sys.argv[2].split('.'):
    if key == '':
        continue
    if not isinstance(cur, dict) or key not in cur:
        sys.exit(0)
    cur = cur[key]
if cur is None:
    sys.exit(0)
if isinstance(cur, (dict, list)):
    import json
    print(json.dumps(cur))
else:
    print(cur)
PY
  elif command -v yq >/dev/null 2>&1; then
    yq -r ".${path} // \"\"" "${manifest}"
  else
    gp_die "need python3 or yq to read manifest fields"
  fi
}

# --- package listing -------------------------------------------------------

gp_list_packages() {
  [[ -d "${GP_PACKAGES_DIR}" ]] || return 0
  find "${GP_PACKAGES_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

# --- utility ---------------------------------------------------------------

gp_require_cmd() {
  local cmd="${1:?}"
  command -v "${cmd}" >/dev/null 2>&1 || gp_die "required command not found in PATH: ${cmd}"
}
