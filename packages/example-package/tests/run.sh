#!/usr/bin/env bash
# Smoke test for example-package.
# Confirms every reference surface exists and package.yaml parses.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pkg="$(cd "${here}/.." && pwd)"

for f in \
  package.yaml \
  README.md \
  values.schema.json \
  install/raw/descriptor.yaml \
  install/raw/raw/configmap.yaml.tmpl \
  resources/config/descriptor.yaml \
  resources/config/overlays/config.yaml.tmpl
do
  [[ -f "${pkg}/${f}" ]] || { echo "missing: ${f}" >&2; exit 1; }
done

python3 - "${pkg}/package.yaml" <<'PY'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
assert doc["metadata"]["name"] == "example-package"
assert doc["metadata"]["version"]
assert doc["spec"]["role"] == "workload"
print("example-package: tests ok")
PY
