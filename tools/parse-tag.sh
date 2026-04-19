#!/usr/bin/env bash
# tools/parse-tag.sh
# Parse a release tag of the form pkg/<name>/v<semver>.
#
# Usage:
#   tools/parse-tag.sh <tag>
#   # or, for CI friendliness:
#   tools/parse-tag.sh --tag <tag> --output github
#
# Outputs (default):
#   name=<name>
#   version=<version>
#
# With --output github, emits GitHub Actions outputs (name=..., version=...)
# to ${GITHUB_OUTPUT} and stdout.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/common.sh
source "${here}/common.sh"

tag=""
output="kv"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)    shift; tag="${1:?}"; shift ;;
    --output) shift; output="${1:?}"; shift ;;
    -h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) gp_die "unknown flag: $1" ;;
    *)  [[ -z "${tag}" ]] || gp_die "multiple tags"; tag="$1"; shift ;;
  esac
done

[[ -n "${tag}" ]] || gp_die "usage: parse-tag.sh <tag>"

read -r name version < <(gp_parse_tag "${tag}")

case "${output}" in
  kv)
    printf 'name=%s\n' "${name}"
    printf 'version=%s\n' "${version}"
    ;;
  github)
    printf 'name=%s\n' "${name}"
    printf 'version=%s\n' "${version}"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
      {
        printf 'name=%s\n' "${name}"
        printf 'version=%s\n' "${version}"
      } >> "${GITHUB_OUTPUT}"
    fi
    ;;
  *)
    gp_die "unknown --output: ${output}"
    ;;
esac
