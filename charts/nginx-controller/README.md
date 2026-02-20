# nginx-controller

NGINX Ingress Controller chart for helm-charts-hub — based on ingress-nginx for Kubernetes Ingress mode.

## Overview

This chart deploys the [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/) (`ingress-nginx`) as a Kubernetes Ingress controller. It processes standard `networking.k8s.io/v1` Ingress resources and routes traffic to backend services.

### Gateway API

Gateway API support for NGINX requires the separate [nginx-gateway-fabric](https://github.com/nginx/nginx-gateway-fabric) project. This chart includes placeholder values for Gateway API (`gatewayApi.enabled`) as a roadmap item.

## Prerequisites

- Kubernetes ≥ 1.26
- Helm ≥ 3.12

## Installation

```bash
# From the Helm repository
helm repo add helm-charts-hub https://pkumar26.github.io/helm-charts-hub/
helm install nginx helm-charts-hub/nginx-controller

# Or install from local source
helm install nginx ./charts/nginx-controller
```

## Configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `image.repository` | string | `registry.k8s.io/ingress-nginx/controller` | Controller image repository |
| `image.tag` | string | `v1.12.1` | Controller image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `replicaCount` | int | `1` | Number of replicas |
| `service.type` | string | `LoadBalancer` | Service type |
| `service.ports.http` | int | `80` | HTTP port |
| `service.ports.https` | int | `443` | HTTPS port |
| `service.annotations` | object | `{}` | Extra service annotations |
| `ingressController.enabled` | bool | `true` | Create IngressClass resource |
| `ingressController.ingressClassName` | string | `nginx` | IngressClass name |
| `ingressController.config` | object | `{}` | NGINX ConfigMap overrides |
| `ingressController.electionId` | string | `ingress-nginx-leader` | Leader election ID |
| `gatewayApi.enabled` | bool | `false` | Reserved for future Gateway API support |
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

### Minimal

```yaml
# values-minimal.yaml
image:
  repository: registry.k8s.io/ingress-nginx/controller
  tag: "v1.12.1"
```

### Production with custom NGINX config

```yaml
# values-production.yaml
replicaCount: 3
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
ingressController:
  config:
    use-forwarded-headers: "true"
    proxy-body-size: "100m"
    use-gzip: "true"
    enable-brotli: "true"
resources:
  requests:
    cpu: 500m
    memory: 256Mi
  limits:
    cpu: "1"
    memory: 512Mi
```

## Upgrade Notes

### 0.1.0

Initial release with Ingress support.

## Troubleshooting

### Controller pods not starting

Check that the ServiceAccount has the correct RBAC permissions:

```bash
kubectl describe clusterrole <release-name>-nginx-controller
kubectl describe clusterrolebinding <release-name>-nginx-controller
```

### NGINX configuration not applied

Verify the ConfigMap contains your configuration overrides:

```bash
kubectl get configmap <release-name>-nginx-controller -o yaml
```

Configuration keys must be strings. Example: `use-forwarded-headers: "true"` (not `true`).

### IngressClass not created

Verify `ingressController.enabled: true` (default). The IngressClass name defaults to `nginx`.
