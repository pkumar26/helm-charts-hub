# Chart Catalog

All Helm charts available in this repository.

| Chart | Description | Workload Types | README |
|-------|-------------|---------------|--------|
| [common-lib](charts/common-lib/) | Shared library chart — reusable helpers for Deployments, Services, Ingress, HPA, labels, annotations, and security contexts | N/A (library) | [README](charts/common-lib/README.md) |
| [web-app](charts/web-app/) | General-purpose application chart for deploying services on Kubernetes | Deployment | [README](charts/web-app/README.md) |
| [traefik-controller](charts/traefik-controller/) | Traefik v3 edge controller — Kubernetes Ingress and Gateway API modes | Deployment | [README](charts/traefik-controller/README.md) |
| [nginx-controller](charts/nginx-controller/) | NGINX Ingress Controller — based on ingress-nginx for Kubernetes Ingress mode | Deployment | [README](charts/nginx-controller/README.md) |
| [envoy-gateway](charts/envoy-gateway/) | Envoy Gateway controller — Gateway API-native controller using Envoy Proxy as data plane | Deployment | [README](charts/envoy-gateway/README.md) |
