# Helm Charts Hub

A Helm chart monorepo providing reusable, production-ready Kubernetes charts with consistent patterns, security defaults, and comprehensive documentation.

## Project Overview

**helm-charts-hub** follows a two-tier architecture:

1. **Library tier** — `common-lib` is a Helm library chart providing reusable helpers for Deployments, Services, Ingress/Gateway resources, HPA, labels, annotations, and security contexts.
2. **Application tier** — Application and controller charts (e.g., `web-app`, `traefik-controller`, `nginx-controller`) declare `common-lib` as a dependency and delegate standard resource rendering to library helpers.

```text
common-lib (library)
    │
    ├── web-app (application)
    ├── traefik-controller (edge controller)
    └── nginx-controller (edge controller)
```

All resources carry standard Kubernetes app labels plus project-specific labels, and two base annotations. Security defaults include runAsNonRoot: true, read-only root filesystem, and no privilege escalation.

**Ingress and Gateway API**

Kubernetes is moving toward the Gateway API as the long-term standard for traffic management, while Ingress remains widely used and supported.

This repository:

- Supports Ingress today for broad compatibility (via Traefik and NGINX controllers).

- Is designed so controllers (starting with Traefik) can also be configured via Gateway API resources in future versions.

## Prerequisites

| Tool               | Version | Notes                                  |
| ------------------ | ------- | -------------------------------------- |
| [Helm](https://helm.sh/docs/intro/install/)               | ≥ 3.12  | Helm 3.x required                      |
| [kubectl](https://kubernetes.io/docs/tasks/tools/)            | ≥ 1.26  | Matching cluster version               |
| [Kubernetes cluster](https://kubernetes.io/docs/setup/) | ≥ 1.26  | kind, minikube, or any managed cluster |

> **Note**: Ingress features require an Ingress controller (Traefik or NGINX). Gateway API support will be introduced gradually, starting with Traefik controller.

## Quick Start

See the [Getting Started guide](docs/getting-started.md) for a step-by-step walkthrough — from creating a local cluster to deploying a sample application in under 5 minutes.

## Add the Helm Repository
Charts are published from this GitHub repository via GitHub Pages.

### Add the helm-charts-hub repo (GitHub Pages)

```bash
helm repo add helm-charts-hub https://pkumar26.github.io/helm-charts-hub/
helm repo update
```
## Install a Chart
### Install web-app from the Helm repository

```bash
helm install my-app helm-charts-hub/web-app \
  --set image.repository=nginx \
  --set image.tag=1.27-alpine
```

### Or install from source
```bash
helm dependency build charts/web-app
helm install my-app charts/web-app \
  --set image.repository=nginx \
  --set image.tag=1.27-alpine
```

### With custom values
```bash
helm install my-app helm-charts-hub/web-app \
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
| [traefik-controller](charts/traefik-controller/) | Traefik-based edge controller (Ingress today, Gateway-ready roadmap) | Controller  |
| [nginx-controller](charts/nginx-controller/) | NGINX-based edge controller (Ingress-first, Gateway roadmap)         | Controller  |

## Troubleshooting

### Helm Repo Issues

```
Error: failed to fetch https://pkumar26.github.io/helm-charts-hub/index.yaml
```
- Verify the URL is correct and GitHub Pages is enabled for the repository.
- Run helm repo update and try again.
- Check that charts have been packaged and the index.yaml has been generated and committed.

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

The project constitution and specifications (in .specify/) describe the high-level design principles, chart conventions, and roadmap, including the transition path from Ingress to Gateway API.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
