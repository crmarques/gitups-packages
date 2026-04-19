#!/usr/bin/env bash
# Smoke test for another-example. Shipped inside the release tarball because
# package.yaml sets spec.package.includeTests: true.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pkg="$(cd "${here}/.." && pwd)"

python3 - "${pkg}/package.yaml" <<'PY'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1]))
pkg_spec = doc["spec"].get("package") or {}
assert pkg_spec.get("includeTests") is True, "expected includeTests=True"
assert any(pat.endswith("*.disabled") for pat in pkg_spec.get("exclude") or []), \
    "expected exclude pattern for *.disabled"
print("another-example: tests ok")
PY
