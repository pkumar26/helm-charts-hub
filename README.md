# Helm Charts Hub

A Helm chart monorepo providing reusable, production-ready Kubernetes charts with consistent patterns, security defaults, and comprehensive documentation.

## Project Overview

**helm-charts-hub** follows a two-tier architecture:

1. **Library tier** — `common-lib` is a Helm library chart providing reusable helpers for Deployments, Services, Ingress, HPA, labels, annotations, and security contexts.
2. **Application tier** — Application charts (e.g., `web-app`) declare `common-lib` as a dependency and delegate standard resource rendering to library helpers.

```
common-lib (library)
    │
    ├── web-app (application)
    ├── [future: traefik-controller]
    └── [future: nginx-controller]
```

All resources carry 6 standard labels and 2 base annotations. Security defaults include `runAsNonRoot: true`, read-only root filesystem, and no privilege escalation.

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| [Helm](https://helm.sh/docs/intro/install/) | ≥ 3.12 | OCI support required |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | ≥ 1.26 | Matching cluster version |
| Kubernetes cluster | ≥ 1.26 | kind, minikube, or any managed cluster |

> **Note**: Ingress features require an Ingress controller (e.g., NGINX, Traefik). Gateway API support is planned for a future release.

## Quick Start

See the [Getting Started guide](docs/getting-started.md) for a step-by-step walkthrough — from creating a local cluster to deploying a sample application in under 5 minutes.

## Install a Chart

```bash
# Install web-app from OCI registry
helm install my-app oci://ghcr.io/<org>/charts/web-app --version 0.1.0 \
  --set image.repository=nginx \
  --set image.tag=1.27-alpine

# Or install from source
helm dependency build charts/web-app
helm install my-app charts/web-app \
  --set image.repository=nginx \
  --set image.tag=1.27-alpine
```

### With custom values

```bash
helm install my-app oci://ghcr.io/<org>/charts/web-app --version 0.1.0 \
  -f environments/production/web-app.values.yaml
```

## Uninstall a Chart

```bash
helm uninstall my-app
```

## Chart Catalog

See [CHARTS.md](CHARTS.md) for the complete list of available charts with descriptions and links.

| Chart | Description | Type |
|-------|-------------|------|
| [common-lib](charts/common-lib/) | Shared library chart — reusable helpers | Library |
| [web-app](charts/web-app/) | General-purpose application chart | Application |

## Troubleshooting

### OCI Pull Failures

```
Error: failed to fetch oci://ghcr.io/...
```

- Verify `helm version` is ≥ 3.12
- Check the package is public or authenticate: `helm registry login ghcr.io`
- Verify the chart name and version exist in the registry

### Image Pull Errors

```
ErrImagePull / ImagePullBackOff
```

- Verify `image.repository` and `image.tag` are correct
- If using a private registry, configure image pull secrets

### Values Validation Errors

```
image.repository is required
image.tag must not be empty
workloadType must be one of: deployment
```

- These are intentional validation errors. Provide the required values via `--set` or a values file.

### Namespace Not Found

```
Error: create: failed to create: namespaces "..." not found
```

- Create the namespace first: `kubectl create namespace <name>`
- Or use `--create-namespace` flag: `helm install my-app ... --create-namespace -n <name>`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the contribution guide, library-first workflow, and PR process.
