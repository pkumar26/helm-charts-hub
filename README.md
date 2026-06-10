# Helm Charts Hub

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/pkumar26/helm-charts-hub/blob/master/LICENSE)
[![Lint and Test Charts](https://img.shields.io/github/actions/workflow/status/pkumar26/helm-charts-hub/chart-lint-test.yaml)](https://github.com/pkumar26/helm-charts-hub/actions/workflows/chart-lint-test.yaml)
[![Last Commit](https://img.shields.io/github/last-commit/pkumar26/helm-charts-hub)](https://github.com/pkumar26/helm-charts-hub/commits)
[![Contributors](https://img.shields.io/github/contributors/pkumar26/helm-charts-hub)](https://github.com/pkumar26/helm-charts-hub/graphs/contributors)

A Helm chart monorepo providing reusable, production-ready Kubernetes charts with consistent patterns, security defaults, and comprehensive documentation.

## Project Overview

**helm-charts-hub** follows a two-tier architecture:

1. **Library tier** — `common-lib` is a Helm library chart providing reusable helpers for Deployments, Services, Ingress/Gateway resources, HPA, labels, annotations, and security contexts.
2. **Application tier** — Application and controller charts (e.g., `web-app`, `traefik-controller`, `nginx-controller`, `envoy-controller`, `kgateway-controller`) declare `common-lib` as a dependency and delegate standard resource rendering to library helpers.

```text
common-lib (library)
    │
    ├── web-app (application)
    ├── traefik-controller (edge controller — Ingress + Gateway API)
    ├── nginx-controller (edge controller — Ingress)
    ├── envoy-controller (edge controller — Gateway API-native)
    └── kgateway-controller (edge controller — Gateway API-native)
```

All resources carry standard Kubernetes app labels plus project-specific labels, and two base annotations. Security defaults include runAsNonRoot: true, read-only root filesystem, and no privilege escalation.

**Ingress and Gateway API**

Kubernetes is moving toward the Gateway API as the long-term standard for traffic management, while Ingress remains widely used and supported.

This repository:

- Supports **Ingress** for broad compatibility (via Traefik and NGINX controllers).

- Supports **Gateway API** natively with the Envoy Gateway (`envoy-controller`) and kgateway (`kgateway-controller`) charts.

- Supports **Gateway API opt-in** with the Traefik controller chart (via `gatewayApi.enabled: true`).

## Prerequisites

| Tool               | Version | Notes                                  |
| ------------------ | ------- | -------------------------------------- |
| [Helm](https://helm.sh/docs/intro/install/)               | ≥ 3.12  | Helm 3.x required                      |
| [kubectl](https://kubernetes.io/docs/tasks/tools/)            | ≥ 1.26  | Matching cluster version               |
| [Kubernetes cluster](https://kubernetes.io/docs/setup/) | ≥ 1.26  | kind, minikube, or any managed cluster |

> **Note**: Ingress features require an Ingress controller (Traefik or NGINX). Gateway API is supported by Envoy Gateway (`envoy-controller`), kgateway (`kgateway-controller`), and Traefik (`traefik-controller`, opt-in) — install [Gateway API CRDs](https://gateway-api.sigs.k8s.io/) first.

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
| [traefik-controller](charts/traefik-controller/) | Traefik-based edge controller (Ingress + Gateway API) | Controller  |
| [nginx-controller](charts/nginx-controller/) | NGINX-based edge controller (Ingress)                 | Controller  |
| [envoy-controller](charts/envoy-controller/) | Envoy Gateway controller — Gateway API-native (Envoy Proxy data plane) | Controller |
| [kgateway-controller](charts/kgateway-controller/) | kgateway controller — CNCF Gateway API implementation (Envoy proxy) | Controller |
| [istio/base](charts/istio/base/) | Istio base — CRDs and cluster-wide resources (install first) | Service Mesh |
| [istio/istiod](charts/istio/istiod/) | Istio control plane — FIPS 140-2 compliant service mesh | Service Mesh |
| [istio/gateway](charts/istio/gateway/) | Istio gateway — FIPS-compliant ingress with security baseline | Service Mesh |
| [istio/kiali](charts/istio/kiali/) | Kiali dashboard — optional mesh observability | Service Mesh |

### Istio Service Mesh on AKS

The repository includes production-ready Istio charts for Azure Kubernetes Service (AKS) with **FIPS 140-2 compliance** support:

**Installation Order** (critical):
1. **istio/base** — Install CRDs first
2. **istio/istiod** — Control plane (requires FIPS-enabled node pool for production)
3. **istio/gateway** — Ingress gateway with STRICT mTLS and security baseline
4. **istio/kiali** — Optional mesh visualization (can skip for air-gapped/minimal environments)

**Quick Start**:
```bash
# Development deployment (minimal resources, PERMISSIVE mTLS)
./examples/deploy-istio-dev.sh --with-kiali

# Production deployment (FIPS, STRICT mTLS, full security)
# Prerequisites: AKS cluster with FIPS-enabled node pool
./examples/deploy-istio-production.sh --with-kiali

# Validate deployment
./examples/validate-istio-deployment.sh --environment production
```

**FIPS Requirements** (production):
- AKS cluster with FIPS-enabled node pool: `az aks nodepool add --enable-fips-image --labels fips=enabled`
- Kubernetes 1.26+
- Distroless images with BoringSSL (Certificate #4407)
- See [Istio AKS Deployment Guide](docs/istio-aks-deployment.md) for complete setup

**Features**:
- ✅ FIPS 140-2 compliance for production workloads
- ✅ Progressive security (dev → staging → production)
- ✅ STRICT mTLS enforcement with AuthorizationPolicy and NetworkPolicy
- ✅ High availability with HPA (3-5 replicas)
- ✅ Canary upgrades for zero-downtime version updates
- ✅ Automated deployment and validation scripts

**Documentation**:
- [Deployment Guide](docs/istio-aks-deployment.md) — Complete guide with upgrade procedures
- [Examples README](examples/README.md) — Deployment scripts and troubleshooting
- [Base Chart](charts/istio/base/README.md) — CRDs and installation order
- [Istiod Chart](charts/istio/istiod/README.md) — Control plane with canary upgrade guide
- [Gateway Chart](charts/istio/gateway/README.md) — Ingress with security baseline
- [Kiali Chart](charts/istio/kiali/README.md) — Optional observability dashboard

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
