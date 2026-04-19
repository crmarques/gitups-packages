# example-package

Minimal package used to exercise the monorepo tooling. It declares one `raw`
install method (a single ConfigMap) and one `config` resource template. It
has no runtime behaviour and is not meant for cluster use.

## Layout

```
packages/example-package/
├── package.yaml
├── README.md
├── values.schema.json
├── install/
│   └── raw/
│       ├── descriptor.yaml
│       └── raw/
│           └── configmap.yaml.tmpl
├── resources/
│   └── config/
│       ├── descriptor.yaml
│       └── overlays/
│           └── config.yaml.tmpl
└── tests/
    └── run.sh
```

## Inputs

| Name        | Default             | Description                     |
| ----------- | ------------------- | ------------------------------- |
| `message`   | `Hello, gitups!`    | Free-form message stored in the ConfigMap. |
| `namespace` | `example`           | Namespace for the ConfigMap.    |

## Use

```yaml
# in a Provision
sources:
  - name: local
    type: filesystem
    path: ../../../gitups-packages/packages
repositories:
  - name: demo
    packages:
      - name: example-package
```
