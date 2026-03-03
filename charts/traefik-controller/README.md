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
# From the Helm repository
helm repo add helm-charts-hub https://pkumar26.github.io/helm-charts-hub/
helm install traefik-controller helm-charts-hub/traefik-controller

# Or install from local source
helm install traefik-controller ./charts/traefik-controller
```

### With Gateway API enabled

```bash
# Install Gateway API CRDs first
kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml

# Install Traefik with Gateway API
helm install traefik-controller helm-charts-hub/traefik-controller \
  --set gatewayApi.enabled=true \
  --set providers.kubernetesGateway.enabled=true

# Or install from local source
helm install traefik-controller ./charts/traefik-controller \
  --set gatewayApi.enabled=true \
  --set providers.kubernetesGateway.enabled=true

# Or use a values file
helm install traefik-controller helm-charts-hub/traefik-controller \
  -f values-production.yaml
```

## Next Steps

After the controller pod is running, deploy a sample app and route traffic. Traefik supports two modes — choose the one matching your installation.

### Ingress mode (default)

```bash
# 1. Deploy a sample application
kubectl create deployment httpbin --image=kennethreitz/httpbin --port=80
kubectl expose deployment httpbin --port=80

# 2. Create an Ingress resource to route traffic to the app
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: httpbin-ingress
spec:
  ingressClassName: traefik
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: httpbin
                port:
                  number: 80
EOF

# 3. Verify the Ingress is created and has an address
kubectl get ingress httpbin-ingress

# 4. Test the route
TRAEFIK_IP=$(kubectl get svc traefik-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s http://$TRAEFIK_IP/get | head -20
```

### Gateway API mode

```bash
# 1. Create a Gateway (if not already created by the chart)
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: traefik-gateway
spec:
  gatewayClassName: traefik
  listeners:
    - name: web
      protocol: HTTP
      port: 8080
EOF

# 2. Deploy a sample application
kubectl create deployment httpbin --image=kennethreitz/httpbin --port=80
kubectl expose deployment httpbin --port=80

# 3. Create an HTTPRoute to send traffic to the app
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-route
spec:
  parentRefs:
    - name: traefik-gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: httpbin
          port: 80
EOF

# 4. Verify the Gateway is programmed
kubectl get gateway traefik-gateway
kubectl get httproute httpbin-route

# 5. Test the route
TRAEFIK_IP=$(kubectl get svc traefik-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s http://$TRAEFIK_IP/get | head -20
```

> **Note**: In Gateway API mode, Gateway listener ports must match the container entrypoint ports (`service.containerPorts`), not the external Service ports. The Service maps external 80/443 to internal 8080/8443.

## Configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `image.repository` | string | `traefik` | Traefik container image repository |
| `image.tag` | string | `v3.3.3` | Traefik container image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `replicaCount` | int | `1` | Number of replicas |
| `service.type` | string | `LoadBalancer` | Service type |
| `service.ports.web` | int | `80` | HTTP service port (external) |
| `service.ports.websecure` | int | `443` | HTTPS service port (external) |
| `service.containerPorts.web` | int | `8080` | HTTP container/entrypoint port (must match Gateway listener port) |
| `service.containerPorts.websecure` | int | `8443` | HTTPS container/entrypoint port (must match Gateway listener port) |
| `service.annotations` | object | `{}` | Extra service annotations |
| `service.internal` | bool | `false` | Use an internal (private) load balancer. Auto-sets AWS, GCP, and Azure annotations |
| `service.loadBalancerIP` | string | `""` | Static IP address for the LoadBalancer |
| `service.loadBalancerSourceRanges` | list | `[]` | Restrict source ranges allowed to access the LoadBalancer |
| `podSecurityContext` | object | `{runAsNonRoot:true,...}` | Pod-level security context |
| `securityContext` | object | `{readOnlyRootFilesystem:true,...}` | Container-level security context |
| `providers.kubernetesIngress.enabled` | bool | `true` | Enable Kubernetes Ingress provider |
| `providers.kubernetesGateway.enabled` | bool | `false` | Enable Kubernetes Gateway API provider |
| `ingressController.enabled` | bool | `true` | Create IngressClass resource |
| `ingressController.ingressClassName` | string | `traefik` | IngressClass name |
| `gatewayApi.enabled` | bool | `false` | Enable Gateway API resources (GatewayClass, Gateway) |
| `gatewayApi.gatewayClass.name` | string | `traefik` | GatewayClass name |
| `gatewayApi.gateway.name` | string | `traefik-gateway` | Gateway name |
| `gatewayApi.gateway.listeners` | list | `[{web:8080,HTTP}]` | Gateway listeners (ports must match `service.containerPorts`) |
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
      - name: web
        port: 8080           # Must match service.containerPorts.web
        protocol: HTTP
      # Uncomment for HTTPS (requires TLS secret):
      # - name: websecure
      #   port: 8443         # Must match service.containerPorts.websecure
      #   protocol: HTTPS
      #   tls:
      #     certificateRefs:
      #       - name: my-tls-secret
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

> **Note**: Gateway listener ports must match the container entrypoint ports (`service.containerPorts`), not the Service ports. The Service maps external 80/443 to internal 8080/8443.

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

### Gateway API CRD conflicts on apply

If you see errors like:

```
Apply failed with 3 conflicts: conflicts with "helm" using apiextensions.k8s.io/v1
```

This happens when the CRDs were previously managed by another field manager (e.g., Helm or a prior `kubectl apply`). Fix with:

```bash
kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
```

`--force-conflicts` tells the server-side apply to take ownership of the conflicting fields.

### IngressClass not created

Verify `ingressController.enabled: true` (default). The IngressClass name defaults to `traefik`.
