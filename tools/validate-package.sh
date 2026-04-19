#!/usr/bin/env bash
# tools/validate-package.sh
# Validate a single package: schema, tag/dir/manifest consistency, structure.
#
# Usage:
#   tools/validate-package.sh <package-name>
#   tools/validate-package.sh --tag pkg/<name>/v<version>
#
# Exits 0 on success. Prints a human-readable error and exits non-zero on failure.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/common.sh
source "${here}/common.sh"

expected_version=""
pkg_name=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      shift
      [[ $# -gt 0 ]] || gp_die "--tag requires a value"
      read -r pkg_name expected_version < <(gp_parse_tag "$1")
      shift
      ;;
    -h|--help)
      sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      gp_die "unknown flag: $1"
      ;;
    *)
      [[ -z "${pkg_name}" ]] || gp_die "multiple package names given"
      pkg_name="$1"
      shift
      ;;
  esac
done

[[ -n "${pkg_name}" ]] || gp_die "usage: validate-package.sh <package-name> | --tag pkg/<name>/v<version>"

pkg_dir="$(gp_package_dir "${pkg_name}")"
manifest="$(gp_package_manifest "${pkg_name}")"

[[ -d "${pkg_dir}" ]] || gp_die "package directory not found: packages/${pkg_name}/"
[[ -f "${manifest}" ]] || gp_die "package.yaml not found: packages/${pkg_name}/package.yaml"

gp_require_cmd python3

python3 - "${manifest}" "${GP_SCHEMAS_DIR}/package.schema.json" "${pkg_name}" "${expected_version}" <<'PY'
import json, sys, yaml, re

manifest_path, schema_path, dir_name, expected_version = sys.argv[1:5]

with open(manifest_path) as f:
    doc = yaml.safe_load(f)
with open(schema_path) as f:
    schema = json.load(f)

errors = []

# Try jsonschema if present — falls back to structural checks otherwise.
try:
    import jsonschema
    validator = jsonschema.Draft202012Validator(schema)
    for e in sorted(validator.iter_errors(doc), key=lambda e: list(e.path)):
        loc = "/".join(str(p) for p in e.path) or "<root>"
        errors.append(f"schema[{loc}]: {e.message}")
except ImportError:
    # Minimal manual validation when jsonschema isn't installed.
    def need(cond, msg):
        if not cond:
            errors.append(msg)
    need(doc.get("apiVersion") == "gitups/v1alpha1",
         f"apiVersion must be gitups/v1alpha1, got {doc.get('apiVersion')!r}")
    need(doc.get("kind") == "PackageDefinition",
         f"kind must be PackageDefinition, got {doc.get('kind')!r}")
    md = doc.get("metadata") or {}
    need(isinstance(md.get("name"), str), "metadata.name must be a string")
    need(isinstance(md.get("version"), str), "metadata.version must be a string")
    spec = doc.get("spec") or {}
    need(spec.get("role") in (
        "workload", "kubernetes-resource-controller", "service-resource-controller"),
         f"spec.role invalid: {spec.get('role')!r}")

md = doc.get("metadata") or {}
name = md.get("name")
version = md.get("version")

if name != dir_name:
    errors.append(f"metadata.name ({name!r}) must equal package directory name ({dir_name!r})")

if isinstance(version, str):
    if not re.match(r'^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$', version):
        errors.append(f"metadata.version {version!r} is not a valid semver (X.Y.Z[-prerelease])")
    if version.startswith("v"):
        errors.append("metadata.version must not have a leading 'v'")

if expected_version and version != expected_version:
    errors.append(
        f"tag version ({expected_version!r}) does not match metadata.version ({version!r})"
    )

if errors:
    for err in errors:
        print(f"packages/{dir_name}/package.yaml: {err}", file=sys.stderr)
    sys.exit(1)

print(f"packages/{dir_name}: ok (version {version})")
PY
