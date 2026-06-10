# Chart Catalog

All Helm charts available in this repository.

| Chart | Description | Workload Types | README |
|-------|-------------|---------------|--------|
| [common-lib](charts/common-lib/) | Shared library chart — reusable helpers for Deployments, Services, Ingress, HPA, labels, annotations, and security contexts | N/A (library) | [README](charts/common-lib/README.md) |
| [web-app](charts/web-app/) | General-purpose application chart for deploying services on Kubernetes | Deployment | [README](charts/web-app/README.md) |
| [traefik-controller](charts/traefik-controller/) | Traefik v3 edge controller — Kubernetes Ingress and Gateway API modes | Deployment | [README](charts/traefik-controller/README.md) |
| [nginx-controller](charts/nginx-controller/) | NGINX Ingress Controller — based on ingress-nginx for Kubernetes Ingress mode | Deployment | [README](charts/nginx-controller/README.md) |
| [envoy-controller](charts/envoy-controller/) | Envoy Gateway controller — Gateway API-native controller using Envoy Proxy as data plane | Deployment | [README](charts/envoy-controller/README.md) |
| [kgateway-controller](charts/kgateway-controller/) | kgateway controller — CNCF Gateway API implementation powered by Envoy proxy | Deployment | [README](charts/kgateway-controller/README.md) |
| [istio/base](charts/istio/base/) | Istio base chart — CRDs and cluster-wide resources for Istio service mesh (install first) | N/A (CRDs) | [README](charts/istio/base/README.md) |
| [istio/istiod](charts/istio/istiod/) | Istio control plane (istiod) — service mesh control plane with FIPS 140-2 support for AKS | Deployment | [README](charts/istio/istiod/README.md) |
| [istio/gateway](charts/istio/gateway/) | Istio ingress gateway — FIPS-compliant gateway with full security baseline (STRICT mTLS, AuthorizationPolicy, NetworkPolicy) | Deployment | [README](charts/istio/gateway/README.md) |
| [istio/gateway-api](charts/istio/gateway-api/) | **NEW** Kubernetes Gateway API for Istio Ambient Mode — multi-tenant Gateway with Azure AKS optimizations (externalTrafficPolicy auto-patch) | Gateway API | [README](charts/istio/gateway-api/README.md) |
| [istio/kiali](charts/istio/kiali/) | Kiali dashboard — mesh observability with Prometheus integration and mTLS status display (updated for Azure AKS) | Deployment | [README](charts/istio/kiali/README.md) |