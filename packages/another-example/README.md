# another-example

Example package showing how to use the `spec.package` block in `package.yaml`
to control what ends up in the release tarball.

- `spec.package.includeTests: true` keeps the `tests/` directory in the
  published artifact so downstreams can run the same smoke tests against the
  pinned tarball. The default is `false`.
- `spec.package.exclude` is a list of globs (relative to the package root)
  that are dropped from the tarball even when they sit inside an included
  directory. This example excludes `*.disabled` overlays under
  `install/raw/raw/` — `debug.yaml.disabled` lives in the repo but **not**
  in the release tarball.

Build locally and inspect:

```bash
tools/package-build.sh another-example
tar -tzf dist/another-example-0.1.0.tgz
```

Expected contents:

```
another-example/
├── package.yaml
├── README.md
├── values.schema.json
├── install/raw/descriptor.yaml
├── install/raw/raw/deployment.yaml   ← kept
│                                     ← debug.yaml.disabled filtered out
└── tests/run.sh                      ← kept by includeTests: true
```

See [../../docs/package-format.md#packaging-overrides](../../docs/package-format.md#packaging-overrides)
for the full override contract.
