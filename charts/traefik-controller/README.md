# traefik-controller

Traefik v3 edge controller chart for helm-charts-hub — supports Kubernetes Ingress and Gateway API modes.

## Overview

This chart deploys [Traefik](https://traefik.io/) as a Kubernetes edge controller. Traefik is a modern HTTP reverse proxy and load balancer that supports both Kubernetes Ingress resources and the Gateway API.

### Modes

- **Ingress mode** (default): Processes standard `networking.k8s.io/v1` Ingress resources
- **Gateway API mode** (opt-in): Processes `GatewayClass`, `Gateway`, and `HTTPRoute` resources

## Prerequisites

- Kubernetes ≥ 1.26
- Helm ≥ 3.12
- For Gateway API mode: Gateway API CRDs installed on the cluster

## Installation

```bash
# Add the chart repository
helm install traefik oci://ghcr.io/pkumar26/charts/traefik-controller --version 0.1.0

# Or install from local source
helm install traefik ./charts/traefik-controller
```

### With Gateway API enabled

```bash
# Install Gateway API CRDs first
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml

# Install Traefik with Gateway API
helm install traefik ./charts/traefik-controller \
  --set gatewayApi.enabled=true \
  --set providers.kubernetesGateway.enabled=true
```

## Configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `image.repository` | string | `traefik` | Traefik container image repository |
| `image.tag` | string | `v3.3.3` | Traefik container image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `replicaCount` | int | `1` | Number of replicas |
| `service.type` | string | `LoadBalancer` | Service type |
| `service.ports.web` | int | `80` | HTTP entrypoint port |
| `service.ports.websecure` | int | `443` | HTTPS entrypoint port |
| `service.annotations` | object | `{}` | Extra service annotations |
| `providers.kubernetesIngress.enabled` | bool | `true` | Enable Kubernetes Ingress provider |
| `providers.kubernetesGateway.enabled` | bool | `false` | Enable Kubernetes Gateway API provider |
| `ingressController.enabled` | bool | `true` | Create IngressClass resource |
| `ingressController.ingressClassName` | string | `traefik` | IngressClass name |
| `gatewayApi.enabled` | bool | `false` | Enable Gateway API resources (GatewayClass, Gateway) |
| `gatewayApi.gatewayClass.name` | string | `traefik` | GatewayClass name |
| `gatewayApi.gateway.name` | string | `traefik-gateway` | Gateway name |
| `gatewayApi.gateway.listeners` | list | `[{http:80},{https:443}]` | Gateway listeners |
| `dashboard.enabled` | bool | `false` | Enable Traefik dashboard |
| `metrics.prometheus.enabled` | bool | `false` | Enable Prometheus metrics |
| `metrics.prometheus.port` | int | `9100` | Metrics entrypoint port |
| `tls.enabled` | bool | `false` | Enable TLS on websecure entrypoint |
| `rbac.create` | bool | `true` | Create RBAC resources |
| `serviceAccount.create` | bool | `true` | Create ServiceAccount |
| `autoscaling.enabled` | bool | `false` | Enable HPA |
| `resources.requests.cpu` | string | `100m` | CPU request |
| `resources.requests.memory` | string | `128Mi` | Memory request |
| `resources.limits.cpu` | string | `500m` | CPU limit |
| `resources.limits.memory` | string | `256Mi` | Memory limit |
| `extraArgs` | list | `[]` | Extra container args |
| `extraEnv` | list | `[]` | Extra environment variables |

## Examples

### Minimal Ingress mode

```yaml
# values-minimal.yaml
image:
  repository: traefik
  tag: "v3.3.3"
```

### Production with Gateway API

```yaml
# values-production.yaml
replicaCount: 3
gatewayApi:
  enabled: true
  gateway:
    listeners:
      - name: http
        port: 80
        protocol: HTTP
      - name: https
        port: 443
        protocol: HTTPS
providers:
  kubernetesGateway:
    enabled: true
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
metrics:
  prometheus:
    enabled: true
```

## Upgrade Notes

### 0.1.0

Initial release with Ingress and Gateway API support.

## Troubleshooting

### Traefik pods not starting

Check that the ServiceAccount has the correct RBAC permissions:

```bash
kubectl describe clusterrole <release-name>-traefik-controller
kubectl describe clusterrolebinding <release-name>-traefik-controller
```

### Gateway API resources not rendered

Ensure both `gatewayApi.enabled: true` and `providers.kubernetesGateway.enabled: true` are set. Gateway API CRDs must be installed on the cluster before installing the chart.

### IngressClass not created

Verify `ingressController.enabled: true` (default). The IngressClass name defaults to `traefik`.
