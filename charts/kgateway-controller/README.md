# kgateway-controller

A Helm chart for deploying kgateway — a CNCF Sandbox project that provides a Kubernetes-native Gateway API implementation powered by Envoy proxy.

## Overview

This chart deploys the **kgateway controller**, which watches Kubernetes Gateway API resources (GatewayClass, Gateway, HTTPRoute, etc.) and dynamically provisions and configures Envoy proxy instances as the data plane.

Key capabilities:
- Full Gateway API v1.2+ support (GatewayClass, Gateway, HTTPRoute, GRPCRoute, TCPRoute, TLSRoute)
- Automatic Envoy proxy provisioning and lifecycle management
- kgateway-specific CRDs for traffic policies, listener policies, and backend configuration
- Prometheus metrics exposure
- Optional HPA, PDB, and VPA for production resilience

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Kubernetes | ≥ 1.31 |
| Helm | ≥ 3.12 |
| Gateway API CRDs | v1.4.0+ |
| kgateway CRDs | Matching chart appVersion |

**Install Gateway API CRDs** (if not already present):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
```

## Installation

### Add the repository

```bash
helm repo add helm-charts-hub <your-repo-url>
helm repo update
```

### Install with default values

```bash
helm install kgateway charts/kgateway-controller -n kgateway-system --create-namespace
```

### Install with custom values

```bash
helm install kgateway charts/kgateway-controller \
  -n kgateway-system --create-namespace \
  -f my-values.yaml
```

### Install with GatewayClass

```bash
helm install kgateway charts/kgateway-controller \
  -n kgateway-system --create-namespace \
  --set gatewayApi.createGatewayClass=true
```

### Upgrade

```bash
helm upgrade kgateway charts/kgateway-controller -n kgateway-system -f my-values.yaml
```

### Uninstall

```bash
helm uninstall kgateway -n kgateway-system
```

## Configuration

### Image

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image.registry` | string | `cr.kgateway.dev/kgateway-dev` | Container image registry |
| `image.repository` | string | `kgateway` | Container image repository |
| `image.tag` | string | `""` | Image tag (defaults to `v` + Chart.AppVersion) |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `imagePullSecrets` | list | `[]` | Image pull secrets |

### Controller

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `replicaCount` | int | `1` | Number of controller replicas |
| `controller.logLevel` | string | `info` | Log level (`KGW_LOG_LEVEL`) |
| `controller.enableEnvoy` | bool | `true` | Enable Envoy data plane (`KGW_ENABLE_ENVOY`) |
| `controller.validationMode` | string | `standard` | Validation mode: `standard` or `strict` |
| `controller.discoveryNamespaceSelectors` | list | `[]` | Namespace selectors for discovery |
| `controller.policyMerge` | object | `{}` | Policy merge configuration |
| `controller.goMemLimit` | string | `""` | Go memory limit (`GOMEMLIMIT`) |
| `controller.goMaxProcs` | string | `""` | Go max procs (`GOMAXPROCS`) |

### Proxy Image

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `controller.proxy.image.registry` | string | `cr.kgateway.dev/kgateway-dev` | Proxy image registry |
| `controller.proxy.image.repository` | string | `kgateway` | Proxy image repository |
| `controller.proxy.image.tag` | string | `""` | Proxy image tag (defaults to `v` + Chart.AppVersion) |
| `controller.proxy.image.pullPolicy` | string | `IfNotPresent` | Proxy image pull policy |

### Service

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `service.type` | string | `ClusterIP` | Service type |
| `service.ports.grpcXds` | int | `9977` | xDS gRPC port |
| `service.ports.health` | int | `9093` | Health check port |
| `service.ports.metrics` | int | `9092` | Prometheus metrics port |
| `service.annotations` | object | `{}` | Extra service annotations |

### ServiceAccount

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serviceAccount.create` | bool | `true` | Create a ServiceAccount |
| `serviceAccount.name` | string | `""` | ServiceAccount name (defaults to fullname) |
| `serviceAccount.annotations` | object | `{}` | Annotations (e.g., IRSA or workload identity) |

### Gateway API

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `gatewayApi.createGatewayClass` | bool | `false` | Create a GatewayClass resource |
| `gatewayApi.gatewayClassName` | string | `kgateway` | GatewayClass name |

### Metrics

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `metrics.enabled` | bool | `true` | Enable Prometheus scrape annotations |

### Autoscaling (HPA)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `autoscaling.enabled` | bool | `false` | Enable HPA |
| `autoscaling.minReplicas` | int | `1` | Minimum replicas |
| `autoscaling.maxReplicas` | int | `5` | Maximum replicas |
| `autoscaling.targetCPUUtilizationPercentage` | int | `80` | Target CPU utilization |

### PodDisruptionBudget

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podDisruptionBudget.enabled` | bool | `false` | Enable PDB |
| `podDisruptionBudget.minAvailable` | int/string | `1` | Min available (mutually exclusive with maxUnavailable) |
| `podDisruptionBudget.maxUnavailable` | string | `""` | Max unavailable (mutually exclusive with minAvailable) |

### VerticalPodAutoscaler

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `verticalPodAutoscaler.enabled` | bool | `false` | Enable VPA |
| `verticalPodAutoscaler.updateMode` | string | `Off` | Update mode: Off, Initial, Recreate, Auto |
| `verticalPodAutoscaler.minAllowed.cpu` | string | `100m` | Minimum CPU |
| `verticalPodAutoscaler.minAllowed.memory` | string | `128Mi` | Minimum memory |
| `verticalPodAutoscaler.maxAllowed.cpu` | string | `2` | Maximum CPU |
| `verticalPodAutoscaler.maxAllowed.memory` | string | `2Gi` | Maximum memory |

### Resources & Scheduling

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `resources.requests.cpu` | string | `100m` | CPU request |
| `resources.requests.memory` | string | `256Mi` | Memory request |
| `resources.limits.cpu` | string | `500m` | CPU limit |
| `resources.limits.memory` | string | `512Mi` | Memory limit |
| `nodeSelector` | object | `{}` | Node selector |
| `tolerations` | list | `[]` | Tolerations |
| `affinity` | object | `{}` | Affinity rules |
| `podAnnotations` | object | `{}` | Extra pod annotations |
| `podLabels` | object | `{}` | Extra pod labels |

### Security

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `podSecurityContext` | object | `{}` | Pod-level security context |
| `securityContext.runAsNonRoot` | bool | `true` | Run as non-root |
| `securityContext.runAsUser` | int | `10101` | User ID |
| `securityContext.readOnlyRootFilesystem` | bool | `true` | Read-only root filesystem |
| `securityContext.allowPrivilegeEscalation` | bool | `false` | Prevent privilege escalation |
| `securityContext.capabilities.drop` | list | `[ALL]` | Drop all capabilities |

## Examples

### Minimal installation

```yaml
# values-minimal.yaml
replicaCount: 1
controller:
  logLevel: info
  enableEnvoy: true
```

### Production deployment

```yaml
# values-production.yaml
replicaCount: 3

controller:
  logLevel: warn
  enableEnvoy: true
  validationMode: strict
  goMemLimit: "512MiB"

gatewayApi:
  createGatewayClass: true

metrics:
  enabled: true

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 75

podDisruptionBudget:
  enabled: true
  minAvailable: 2

verticalPodAutoscaler:
  enabled: true
  updateMode: "Off"
  minAllowed:
    cpu: 200m
    memory: 512Mi
  maxAllowed:
    cpu: "4"
    memory: 4Gi

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: "2"
    memory: 2Gi

nodeSelector:
  kubernetes.io/os: linux

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: kgateway-controller
          topologyKey: kubernetes.io/hostname
```

### Development with debug logging

```yaml
# values-dev.yaml
replicaCount: 1
controller:
  logLevel: debug
  enableEnvoy: true
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### With namespace-scoped discovery

```yaml
# values-scoped.yaml
controller:
  logLevel: info
  enableEnvoy: true
  discoveryNamespaceSelectors:
    - matchLabels:
        kgateway-discovery: "true"
```

## Upgrade Notes

### 0.1.0

Initial release — no upgrade considerations.

## Troubleshooting

### Controller pod is not starting

Check the pod status and logs:

```bash
kubectl get pods -n kgateway-system -l app.kubernetes.io/name=kgateway-controller
kubectl logs -n kgateway-system -l app.kubernetes.io/name=kgateway-controller
```

### Gateway API CRDs not found

Ensure Gateway API CRDs are installed:

```bash
kubectl get crd gatewayclasses.gateway.networking.k8s.io
```

If missing, install them:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml
```

### GatewayClass not created

By default, `gatewayApi.createGatewayClass` is `false`. Enable it explicitly:

```bash
helm upgrade kgateway charts/kgateway-controller --set gatewayApi.createGatewayClass=true
```

### Metrics not scraped by Prometheus

Verify Prometheus annotations are on the pod:

```bash
kubectl get pods -n kgateway-system -l app.kubernetes.io/name=kgateway-controller -o jsonpath='{.items[0].metadata.annotations}'
```

Ensure `metrics.enabled` is `true` (default).

### RBAC errors

Check ClusterRole and ClusterRoleBinding:

```bash
kubectl get clusterrole -l app.kubernetes.io/name=kgateway-controller
kubectl get clusterrolebinding -l app.kubernetes.io/name=kgateway-controller
```

### Health check failing

The controller uses `/readyz` on port 9093. Verify the health endpoint:

```bash
kubectl port-forward -n kgateway-system svc/kgateway 9093:9093
curl http://localhost:9093/readyz
```
