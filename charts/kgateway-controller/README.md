# kgateway-controller

kgateway controller chart for helm-charts-hub — CNCF Gateway API implementation powered by Envoy proxy.

## Overview

This chart deploys [kgateway](https://kgateway.dev/) as a Kubernetes Gateway API controller. kgateway is a CNCF Sandbox project that watches Gateway API resources (GatewayClass, Gateway, HTTPRoute, etc.) and dynamically provisions Envoy proxy instances as the data plane.

## Prerequisites

- Kubernetes ≥ 1.31
- Helm ≥ 3.12
- Gateway API CRDs v1.5.0+ installed (experimental channel required for TLSRoute v1alpha2)
- kgateway CRDs chart (`kgateway-crds`) installed
- agentgateway CRDs chart (`agentgateway-crds`) installed (required by kgateway v2.2.1)

## Installation

```bash
# Install Gateway API CRDs — experimental channel (required for TLSRoute v1alpha2)
kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/experimental-install.yaml

# Install kgateway CRDs
helm upgrade -i kgateway-crds oci://ghcr.io/kgateway-dev/charts/kgateway-crds --version v2.2.1

# Install agentgateway CRDs (required by kgateway v2.2.1)
helm upgrade -i agentgateway-crds oci://ghcr.io/agentgateway/charts/agentgateway-crds --version v1.0.0-alpha.2

# From the Helm repository
helm repo add helm-charts-hub https://pkumar26.github.io/helm-charts-hub/
helm install kgateway-controller helm-charts-hub/kgateway-controller

# Or install from local source
helm install kgateway-controller ./charts/kgateway-controller

# Or use a values file
helm install kgateway-controller helm-charts-hub/kgateway-controller \
  -f values-production.yaml
```

> **Note**: The controller auto-creates a GatewayClass at runtime. To create a Helm-managed GatewayClass instead (for auditability), set `gatewayApi.createGatewayClass=true`.

## Configuration

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `image.registry` | string | `cr.kgateway.dev/kgateway-dev` | Container image registry |
| `image.repository` | string | `kgateway` | Container image repository |
| `image.tag` | string | `""` | Image tag (defaults to `v` + Chart.AppVersion) |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `imagePullSecrets` | list | `[]` | Image pull secrets |
| `replicaCount` | int | `1` | Number of controller replicas |
| `controller.logLevel` | string | `info` | Log level (`KGW_LOG_LEVEL`) |
| `controller.enableEnvoy` | bool | `true` | Enable Envoy data plane (`KGW_ENABLE_ENVOY`) |
| `controller.validationMode` | string | `standard` | Validation mode: `standard` or `strict` |
| `controller.discoveryNamespaceSelectors` | list | `[]` | Namespace selectors for discovery |
| `controller.policyMerge` | object | `{}` | Policy merge configuration |
| `controller.goMemLimit` | string | `""` | Go memory limit (`GOMEMLIMIT`) |
| `controller.goMaxProcs` | string | `""` | Go max procs (`GOMAXPROCS`) |
| `controller.proxy.image.registry` | string | `cr.kgateway.dev/kgateway-dev` | Proxy image registry |
| `controller.proxy.image.repository` | string | `kgateway` | Proxy image repository |
| `controller.proxy.image.tag` | string | `""` | Proxy image tag (defaults to `v` + Chart.AppVersion) |
| `controller.proxy.image.pullPolicy` | string | `IfNotPresent` | Proxy image pull policy |
| `service.type` | string | `ClusterIP` | Service type |
| `service.ports.grpcXds` | int | `9977` | xDS gRPC port |
| `service.ports.health` | int | `9093` | Health check port |
| `service.ports.metrics` | int | `9092` | Prometheus metrics port |
| `service.annotations` | object | `{}` | Extra service annotations |
| `podSecurityContext` | object | `{}` | Pod-level security context |
| `securityContext` | object | `{runAsNonRoot:true,...}` | Container-level security context |
| `serviceAccount.create` | bool | `true` | Create a ServiceAccount |
| `serviceAccount.name` | string | `""` | ServiceAccount name (defaults to fullname) |
| `serviceAccount.annotations` | object | `{}` | Annotations (e.g., IRSA or workload identity) |
| `gatewayApi.createGatewayClass` | bool | `false` | Create a GatewayClass resource |
| `gatewayApi.gatewayClassName` | string | `kgateway` | GatewayClass name |
| `metrics.enabled` | bool | `true` | Enable Prometheus scrape annotations |
| `autoscaling.enabled` | bool | `false` | Enable HPA |
| `autoscaling.minReplicas` | int | `1` | Minimum replicas |
| `autoscaling.maxReplicas` | int | `5` | Maximum replicas |
| `autoscaling.targetCPUUtilizationPercentage` | int | `80` | Target CPU utilization |
| `podDisruptionBudget.enabled` | bool | `false` | Enable PDB |
| `podDisruptionBudget.minAvailable` | int/string | `1` | Min available (mutually exclusive with maxUnavailable) |
| `podDisruptionBudget.maxUnavailable` | string | `""` | Max unavailable (mutually exclusive with minAvailable) |
| `verticalPodAutoscaler.enabled` | bool | `false` | Enable VPA |
| `verticalPodAutoscaler.updateMode` | string | `Off` | Update mode: Off, Initial, Recreate, Auto |
| `resources.requests.cpu` | string | `100m` | CPU request |
| `resources.requests.memory` | string | `256Mi` | Memory request |
| `resources.limits.cpu` | string | `500m` | CPU limit |
| `resources.limits.memory` | string | `512Mi` | Memory limit |
| `nodeSelector` | object | `{}` | Node selector |
| `tolerations` | list | `[]` | Tolerations |
| `affinity` | object | `{}` | Affinity rules |
| `podAnnotations` | object | `{}` | Extra pod annotations |
| `podLabels` | object | `{}` | Extra pod labels |

## Examples

### Minimal installation

```yaml
# values-minimal.yaml
image:
  registry: cr.kgateway.dev/kgateway-dev
  repository: kgateway
```

### Production with GatewayClass

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

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: "2"
    memory: 2Gi
```

## Upgrade Notes

### 0.1.0

Initial release with Gateway API support.

## Troubleshooting

### Controller pod is not starting

Check that the ServiceAccount has the correct RBAC permissions:

```bash
kubectl describe clusterrole <release-name>-kgateway-controller
kubectl describe clusterrolebinding <release-name>-kgateway-controller
```

### Gateway API CRDs not found

Ensure all required CRDs are installed on the cluster before installing the chart:

```bash
# Gateway API CRDs (experimental channel)
kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/experimental-install.yaml

# kgateway CRDs
helm upgrade -i kgateway-crds oci://ghcr.io/kgateway-dev/charts/kgateway-crds --version v2.2.1

# agentgateway CRDs (required by kgateway v2.2.1)
helm upgrade -i agentgateway-crds oci://ghcr.io/agentgateway/charts/agentgateway-crds --version v1.0.0-alpha.2
```

### GatewayClass not created

By default, `gatewayApi.createGatewayClass` is `false`. The kgateway controller auto-creates a GatewayClass at runtime, but you can also create one explicitly:

```bash
helm upgrade kgateway charts/kgateway-controller --set gatewayApi.createGatewayClass=true
```

### Metrics not scraped by Prometheus

Ensure `metrics.enabled` is `true` (default). Verify Prometheus annotations are on the pod:

```bash
kubectl get pods -l app.kubernetes.io/name=kgateway-controller -o jsonpath='{.items[0].metadata.annotations}'
```
