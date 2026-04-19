#!/usr/bin/env bash
# tools/detect-changed-packages.sh
# Print the names of packages changed between two git refs, one per line.
#
# Usage:
#   tools/detect-changed-packages.sh [BASE_REF] [HEAD_REF]
#
# Defaults: BASE_REF=origin/main, HEAD_REF=HEAD
#
# Behaviour:
#   - Lists every packages/<name>/ directory that has any changed file.
#   - If any shared infrastructure changes (schemas/, tools/, .github/workflows/,
#     or this script itself), prints ALL packages — a shared-infra change must
#     re-validate the whole catalog.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/common.sh
source "${here}/common.sh"

base_ref="${1:-origin/main}"
head_ref="${2:-HEAD}"

gp_require_cmd git

cd "${GP_REPO_ROOT}"

# Fall back to empty-tree baseline if base_ref doesn't resolve (e.g. shallow clone).
if ! git rev-parse --verify --quiet "${base_ref}" >/dev/null; then
  gp_log "base ref '${base_ref}' not found; falling back to empty-tree diff"
  base_ref="$(git hash-object -t tree /dev/null)"
fi

mapfile -t changed_files < <(git diff --name-only "${base_ref}" "${head_ref}" -- .)

shared_infra_touched=false
declare -A changed_pkgs=()

for f in "${changed_files[@]}"; do
  case "${f}" in
    schemas/*|tools/*|.github/workflows/*)
      shared_infra_touched=true
      ;;
    packages/*)
      # packages/<name>/...
      name="${f#packages/}"
      name="${name%%/*}"
      [[ -n "${name}" ]] && changed_pkgs["${name}"]=1
      ;;
  esac
done

if [[ "${shared_infra_touched}" == true ]]; then
  gp_log "shared infra changed — validating all packages"
  gp_list_packages
  exit 0
fi

if [[ ${#changed_pkgs[@]} -eq 0 ]]; then
  exit 0
fi

printf '%s\n' "${!changed_pkgs[@]}" | sort
