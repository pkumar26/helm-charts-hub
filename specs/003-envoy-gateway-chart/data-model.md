# Data Model: Envoy Gateway Controller Chart

**Feature Branch**: `003-envoy-gateway-chart`
**Date**: 2026-02-26

---

## 1. Kubernetes Resources (Entities)

### 1.1 Deployment — Envoy Gateway Controller

| Field | Source | Notes |
|-------|--------|-------|
| name | `common-lib.fullname` | Standard naming |
| replicas | `.Values.replicaCount` | Default: 1 |
| image | `.Values.image.repository:tag` | `docker.io/envoyproxy/gateway:v1.3.0` |
| container args | fixed | `["server", "--config-path=/config/envoy-gateway.yaml"]` |
| container ports | `.Values.service.containerPorts` | grpc:18000, ratelimit:18001, metrics:19001 |
| env: ENVOY_GATEWAY_NAMESPACE | downward API | `fieldRef: metadata.namespace` |
| env: KUBERNETES_CLUSTER_DOMAIN | `.Values.kubernetesClusterDomain` | Default: `cluster.local` |
| volume mounts | fixed | `/config` (ConfigMap, readOnly) |
| liveness probe | `.Values.livenessProbe` | HTTP GET `/healthz` port 8081 |
| readiness probe | `.Values.readinessProbe` | HTTP GET `/readyz` port 8081 |
| security context | `.Values.securityContext` | runAsNonRoot, drop ALL caps |
| pod security context | `.Values.podSecurityContext` | runAsNonRoot, runAsUser: 65532 |
| resources | `.Values.resources` | 100m/256Mi request, 500m/512Mi limit |
| service account | `.Values.serviceAccount.name` or fullname | automountServiceAccountToken: true |
| termination grace period | `.Values.terminationGracePeriodSeconds` | Default: 10 |

### 1.2 Service — Controller

| Field | Source | Notes |
|-------|--------|-------|
| name | `common-lib.fullname` | Standard naming |
| type | `.Values.service.type` | Default: ClusterIP |
| port: grpc | `.Values.service.ports.grpc` | 18000 → 18000 |
| port: ratelimit | `.Values.service.ports.ratelimit` | 18001 → 18001 (optional) |
| port: metrics | `.Values.service.ports.metrics` | 19001 → 19001 (conditional on metrics.enabled) |

### 1.3 ServiceAccount

| Field | Source | Notes |
|-------|--------|-------|
| name | `.Values.serviceAccount.name` or fullname | Via `common-lib.serviceaccount` |
| create | `.Values.serviceAccount.create` | Default: true |
| annotations | `.Values.serviceAccount.annotations` | Mergeable |

### 1.4 ClusterRole

| Field | Source | Notes |
|-------|--------|-------|
| name | `common-lib.fullname` | Standard naming |
| rules | fixed + conditional | See §2 below |
| create | `.Values.rbac.create` | Default: true |

### 1.5 ClusterRoleBinding

| Field | Source | Notes |
|-------|--------|-------|
| name | `common-lib.fullname` | Standard naming |
| roleRef | ClusterRole name | Same as ClusterRole |
| subject | ServiceAccount | name + namespace |
| create | `.Values.rbac.create` | Default: true |

### 1.6 ConfigMap — Envoy Gateway Config

| Field | Source | Notes |
|-------|--------|-------|
| name | `fullname`-config | Suffix: -config |
| data key | `envoy-gateway.yaml` | EnvoyGateway configuration object |
| content | `.Values.config` | Gateway controller settings |

### 1.7 GatewayClass

| Field | Source | Notes |
|-------|--------|-------|
| name | `.Values.gatewayClass.name` | Default: `envoy` |
| controllerName | `.Values.gatewayClass.controllerName` | `gateway.envoyproxy.io/gatewayclass-controller` |
| create | `.Values.gatewayClass.create` | Default: true |

### 1.8 Gateway (Optional)

| Field | Source | Notes |
|-------|--------|-------|
| name | `.Values.gateway.name` | Default: `envoy-gateway` |
| namespace | `.Values.gateway.namespace` or release namespace | Configurable |
| gatewayClassName | `.Values.gatewayClass.name` | References GatewayClass |
| listeners | `.Values.gateway.listeners` | HTTP (80), HTTPS (443) |
| create | `.Values.gateway.enabled` | Default: false |

---

## 2. RBAC Rules

### ClusterRole Rules (when `.Values.rbac.create`)

```yaml
rules:
  # Core resources — cluster-scoped
  - apiGroups: [""]
    resources: [namespaces, nodes]
    verbs: [get, list, watch]

  # Core resources — namespaced
  - apiGroups: [""]
    resources: [services, secrets, configmaps]
    verbs: [get, list, watch]

  # Core resources — events
  - apiGroups: [""]
    resources: [events]
    verbs: [create, patch]

  # Core resources — for data plane management
  - apiGroups: [""]
    resources: [serviceaccounts, services, configmaps]
    verbs: [create, get, list, delete, patch]

  # Discovery
  - apiGroups: [discovery.k8s.io]
    resources: [endpointslices]
    verbs: [get, list, watch]

  # Apps — for data plane deployment management
  - apiGroups: [apps]
    resources: [deployments]
    verbs: [create, get, list, delete, patch, watch]

  # Autoscaling — for data plane HPA
  - apiGroups: [autoscaling]
    resources: [horizontalpodautoscalers]
    verbs: [create, get, list, delete, patch]

  # Gateway API — read
  - apiGroups: [gateway.networking.k8s.io]
    resources: [gatewayclasses, gateways, httproutes, grpcroutes,
                tcproutes, tlsroutes, udproutes, referencegrants,
                backendtlspolicies]
    verbs: [get, list, watch]

  # Gateway API — status updates
  - apiGroups: [gateway.networking.k8s.io]
    resources: [gatewayclasses/status, gateways/status,
                httproutes/status, grpcroutes/status,
                tcproutes/status, tlsroutes/status, udproutes/status,
                backendtlspolicies/status]
    verbs: [update]

  # Gateway API — class updates
  - apiGroups: [gateway.networking.k8s.io]
    resources: [gatewayclasses]
    verbs: [patch, update]

  # Leader election
  - apiGroups: [coordination.k8s.io]
    resources: [leases]
    verbs: [get, list, watch, create, update, patch, delete]
```

---

## 3. Values Schema (Top-Level Keys)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `image.repository` | string | `docker.io/envoyproxy/gateway` | Container image repo |
| `image.tag` | string | `v1.3.0` | Container image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `replicaCount` | int | `1` | Number of controller replicas |
| `resources` | object | {requests: 100m/256Mi, limits: 500m/512Mi} | Resource limits |
| `service.type` | string | `ClusterIP` | Service type |
| `service.ports.grpc` | int | `18000` | xDS gRPC port |
| `service.ports.ratelimit` | int | `18001` | Ratelimit port |
| `service.containerPorts.grpc` | int | `18000` | Container xDS gRPC port |
| `service.containerPorts.ratelimit` | int | `18001` | Container ratelimit port |
| `service.annotations` | object | `{}` | Extra service annotations |
| `serviceAccount.create` | bool | `true` | Create ServiceAccount |
| `serviceAccount.name` | string | `""` | SA name override |
| `serviceAccount.annotations` | object | `{}` | SA annotations |
| `rbac.create` | bool | `true` | Create RBAC resources |
| `gatewayClass.create` | bool | `true` | Create GatewayClass |
| `gatewayClass.name` | string | `envoy` | GatewayClass name |
| `gatewayClass.controllerName` | string | `gateway.envoyproxy.io/gatewayclass-controller` | Controller name |
| `gateway.enabled` | bool | `false` | Create default Gateway |
| `gateway.name` | string | `envoy-gateway` | Gateway name |
| `gateway.namespace` | string | `""` | Gateway namespace |
| `gateway.listeners` | list | [{http:80}, {https:443}] | Gateway listeners |
| `config.logging.level.default` | string | `info` | Logging level |
| `kubernetesClusterDomain` | string | `cluster.local` | K8s cluster domain |
| `metrics.enabled` | bool | `false` | Expose metrics port on service |
| `metrics.port` | int | `19001` | Prometheus metrics port |
| `podSecurityContext` | object | {runAsNonRoot, runAsUser: 65532} | Pod security context |
| `securityContext` | object | {runAsNonRoot, drop ALL} | Container security context |
| `nodeSelector` | object | `{}` | Node selector |
| `tolerations` | list | `[]` | Tolerations |
| `affinity` | object | `{}` | Affinity rules |
| `podAnnotations` | object | `{}` | Extra pod annotations |
| `podLabels` | object | `{}` | Extra pod labels |
| `labels` | object | `{}` | Extra resource labels |
| `annotations` | object | `{}` | Extra resource annotations |
| `extraEnv` | list | `[]` | Extra environment variables |
| `extraVolumes` | list | `[]` | Extra volumes |
| `extraVolumeMounts` | list | `[]` | Extra volume mounts |
| `extraArgs` | list | `[]` | Extra container args |
| `terminationGracePeriodSeconds` | int | `10` | Termination grace period |
| `autoscaling.enabled` | bool | `false` | Enable HPA |
| `autoscaling.minReplicas` | int | `1` | HPA min replicas |
| `autoscaling.maxReplicas` | int | `5` | HPA max replicas |
| `autoscaling.targetCPUUtilizationPercentage` | int | `80` | HPA CPU target |
| `nameOverride` | string | `""` | Chart name override |
| `fullnameOverride` | string | `""` | Fullname override |

---

## 4. State Transitions

The Envoy Gateway controller has no explicit state machine. The relevant state transitions are:

1. **Controller startup**: Pod starts → reads ConfigMap → connects to K8s API → begins watching Gateway API resources
2. **GatewayClass accepted**: Controller detects GatewayClass → sets status to Accepted
3. **Gateway provisioned**: Controller detects Gateway referencing its GatewayClass → provisions Envoy Proxy data plane
4. **Route attached**: Controller detects HTTPRoute/GRPCRoute → configures Envoy Proxy via xDS

These transitions are internal to Envoy Gateway and not controlled by the chart.
