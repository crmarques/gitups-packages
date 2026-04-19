#!/usr/bin/env bash
# tools/generate-index.sh
# Generate index/index.json from the current state of packages/.
#
# Usage:
#   tools/generate-index.sh [--out PATH] [--registry HOST] [--owner ORG]
#                           [--publish-record PATH]
#
# The publish-record file (one line per published version:
# "<name> <version> <oci-ref>@<digest>") lets the release workflow feed back
# real publish digests into the index. When omitted, the index is generated
# from manifest data alone and omits digest fields.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/common.sh
source "${here}/common.sh"

out="${GP_INDEX_DIR}/index.json"
registry="${GHCR_REGISTRY:-ghcr.io}"
owner="${GHCR_OWNER:-<owner>}"
publish_record=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)      shift; out="${1:?}"; shift ;;
    --registry) shift; registry="${1:?}"; shift ;;
    --owner)    shift; owner="${1:?}"; shift ;;
    --publish-record) shift; publish_record="${1:?}"; shift ;;
    -h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) gp_die "unknown arg: $1" ;;
  esac
done

gp_require_cmd python3
mkdir -p "$(dirname "${out}")"

python3 - "${GP_PACKAGES_DIR}" "${registry}" "${owner}" "${publish_record}" "${out}" <<'PY'
import json, os, sys, yaml, glob

packages_dir, registry, owner, publish_record, out_path = sys.argv[1:6]

# Load prior digests from an optional publish record. Format: lines of
#   <name> <version> <oci-ref>@<digest>
digests = {}  # (name, version) -> (oci_ref, digest)
if publish_record and os.path.isfile(publish_record):
    with open(publish_record) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) != 3:
                continue
            name, version, full = parts
            if "@" in full:
                ref, digest = full.split("@", 1)
            else:
                ref, digest = full, ""
            digests[(name, version)] = (ref, digest)

packages = []
for pkg_path in sorted(glob.glob(os.path.join(packages_dir, "*"))):
    manifest = os.path.join(pkg_path, "package.yaml")
    if not os.path.isfile(manifest):
        continue
    with open(manifest) as f:
        doc = yaml.safe_load(f) or {}
    md = doc.get("metadata") or {}
    spec = doc.get("spec") or {}
    name = md.get("name")
    version = md.get("version")
    if not name or not version:
        continue

    oci_ref = f"{registry}/{owner}/gitups-packages/{name}:{version}"
    digest = ""
    recorded = digests.get((name, version))
    if recorded:
        oci_ref, digest = recorded

    entry = {
        "name": name,
        "version": version,
        "description": md.get("description", ""),
        "role": spec.get("role"),
        "category": spec.get("category"),
        "oci": oci_ref,
    }
    if digest:
        entry["digest"] = digest

    deps = spec.get("dependencies") or []
    if deps:
        entry["dependencies"] = deps

    compat = spec.get("compatibility") or {}
    if compat.get("gitupsMinVersion"):
        entry["gitupsMinVersion"] = compat["gitupsMinVersion"]

    if md.get("deprecated"):
        entry["deprecated"] = md["deprecated"]

    packages.append(entry)

# Latest view per package (picked by the single declared version in the repo).
latest = {p["name"]: {"version": p["version"], "oci": p["oci"]} for p in packages}

index = {
    "apiVersion": "gitups-packages.io/v1alpha1",
    "kind": "PackageIndex",
    "packages": packages,
    "latest": latest,
}

with open(out_path, "w") as f:
    json.dump(index, f, indent=2, sort_keys=True)
    f.write("\n")

print(f"wrote {out_path} ({len(packages)} packages)")
PY
