# Data Model: kgateway Controller Chart

**Feature Branch**: `004-kgateway-chart`

---

## 1. Overview

The kgateway-controller chart produces up to 10 Kubernetes resource types. All resources share a common set of labels via common-lib and namespace from Release.Namespace.

---

## 2. Resource Inventory

| # | Kind | API Version | Template | Gated By | Notes |
|---|------|-------------|----------|----------|-------|
| 1 | Deployment | apps/v1 | deployment.yaml | Always | Controller pod with env-var config |
| 2 | Service | v1 | service.yaml | Always | ClusterIP: xDS, health, metrics |
| 3 | ServiceAccount | v1 | serviceaccount.yaml | `serviceAccount.create` | Supports annotations for IRSA/workload identity |
| 4 | ClusterRole | rbac.authorization.k8s.io/v1 | clusterrole.yaml | Always | Extensive permissions for Gateway API + kgateway CRDs |
| 5 | ClusterRoleBinding | rbac.authorization.k8s.io/v1 | clusterrolebinding.yaml | Always | Binds ClusterRole to ServiceAccount |
| 6 | GatewayClass | gateway.networking.k8s.io/v1 | gateway-class.yaml | `gatewayApi.createGatewayClass` | Controller name: kgateway.dev/kgateway |
| 7 | HPA | autoscaling/v2 | hpa.yaml | `autoscaling.enabled` | common-lib based |
| 8 | PDB | policy/v1 | pdb.yaml | `podDisruptionBudget.enabled` | Chart-specific template |
| 9 | VPA | autoscaling.k8s.io/v1 | vpa.yaml | `verticalPodAutoscaler.enabled` | Chart-specific template |
| 10 | IngressClass | — | — | — | NOT applicable (Gateway API only) |

---

## 3. Deployment Spec

### Container: kgateway

```yaml
image: "{{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ tag }}"
# tag logic: .Values.image.tag || "v" + .Chart.AppVersion
ports:
  - name: grpc-xds
    containerPort: 9977
    protocol: TCP
  - name: health
    containerPort: 9093
    protocol: TCP
  - name: metrics
    containerPort: 9092
    protocol: TCP
```

### Environment Variables

| Env Var | Source | Value Template |
|---------|--------|---------------|
| `POD_NAMESPACE` | Downward API | `fieldRef: metadata.namespace` |
| `KGW_LOG_LEVEL` | values | `{{ .Values.controller.logLevel }}` |
| `KGW_XDS_SERVICE_NAME` | derived | `{{ include "kgateway-controller.fullname" . }}` |
| `KGW_XDS_SERVICE_PORT` | values | `{{ .Values.service.ports.grpcXds }}` |
| `KGW_DEFAULT_IMAGE_REGISTRY` | values | `{{ .Values.controller.proxy.image.registry }}` |
| `KGW_DEFAULT_IMAGE_TAG` | values/chart | `{{ .Values.controller.proxy.image.tag \| default (printf "v%s" .Chart.AppVersion) }}` |
| `KGW_DEFAULT_IMAGE_PULL_POLICY` | values | `{{ .Values.controller.proxy.image.pullPolicy }}` |
| `KGW_ENABLE_ENVOY` | values | `{{ .Values.controller.enableEnvoy }}` |
| `KGW_VALIDATION_MODE` | values | `{{ .Values.controller.validationMode }}` |
| `KGW_DISCOVERY_NAMESPACE_SELECTORS` | values | `{{ .Values.controller.discoveryNamespaceSelectors \| toJson }}` (omitted when empty `[]`) |
| `KGW_POLICY_MERGE` | values | `{{ .Values.controller.policyMerge \| toJson }}` (omitted when empty `{}`) |
| `GOMEMLIMIT` | values | `{{ .Values.controller.goMemLimit }}` (if set) |
| `GOMAXPROCS` | values | `{{ .Values.controller.goMaxProcs }}` (if set) |

### Probes

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: health    # 9093
  initialDelaySeconds: 1
  periodSeconds: 10
startupProbe:
  httpGet:
    path: /readyz
    port: health    # 9093
  failureThreshold: 120
  periodSeconds: 1
```

Note: No liveness probe (matches upstream).

### Security Context

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10101
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]
```

---

## 4. Service Spec

```yaml
apiVersion: v1
kind: Service
spec:
  type: ClusterIP
  ports:
    - name: grpc-xds
      port: 9977
      targetPort: grpc-xds
      protocol: TCP
    - name: health
      port: 9093
      targetPort: health
      protocol: TCP
    - name: metrics
      port: 9092
      targetPort: metrics
      protocol: TCP
```

---

## 5. RBAC Rules

### ClusterRole Rules

```yaml
rules:
  # Gateway API resources
  - apiGroups: ["gateway.networking.k8s.io"]
    resources:
      - gatewayclasses
      - gateways
      - httproutes
      - grpcroutes
      - tcproutes
      - tlsroutes
      - referencegrants
      - backendtlspolicies
    verbs: ["get", "list", "watch", "patch"]
  
  # Gateway API status updates
  - apiGroups: ["gateway.networking.k8s.io"]
    resources:
      - gatewayclasses/status
      - gateways/status
      - httproutes/status
      - grpcroutes/status
      - tcproutes/status
      - tlsroutes/status
      - backendtlspolicies/status
    verbs: ["get", "update", "patch"]

  # Experimental Gateway API
  - apiGroups: ["gateway.networking.x-k8s.io"]
    resources:
      - xlistenersets
    verbs: ["get", "list", "watch", "patch"]
  - apiGroups: ["gateway.networking.x-k8s.io"]
    resources:
      - xlistenersets/status
    verbs: ["get", "update", "patch"]

  # kgateway CRDs
  - apiGroups: ["gateway.kgateway.dev"]
    resources:
      - trafficpolicies
      - listenerpolicies
      - httplistenerpolicies
      - backends
      - directresponses
      - gatewayextensions
      - gatewayparameters
      - backendconfigpolicies
    verbs: ["get", "list", "watch", "patch"]
  
  # kgateway CRD status updates
  - apiGroups: ["gateway.kgateway.dev"]
    resources:
      - trafficpolicies/status
      - listenerpolicies/status
      - httplistenerpolicies/status
      - backends/status
      - directresponses/status
      - gatewayextensions/status
      - gatewayparameters/status
      - backendconfigpolicies/status
    verbs: ["get", "update", "patch"]

  # Core resources
  - apiGroups: [""]
    resources:
      - services
      - endpoints
      - secrets
      - namespaces
      - nodes
      - pods
      - configmaps
      - events
      - serviceaccounts
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

  # Deployments (data-plane proxy management)
  - apiGroups: ["apps"]
    resources:
      - deployments
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

  # Autoscaling (proxy HPA management)
  - apiGroups: ["autoscaling"]
    resources:
      - horizontalpodautoscalers
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

  # VPA (proxy VPA management)
  - apiGroups: ["autoscaling.k8s.io"]
    resources:
      - verticalpodautoscalers
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

  # PDB (proxy PDB management)
  - apiGroups: ["policy"]
    resources:
      - poddisruptionbudgets
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

  # Discovery
  - apiGroups: ["discovery.k8s.io"]
    resources:
      - endpointslices
    verbs: ["get", "list", "watch"]

  # CRD management
  - apiGroups: ["apiextensions.k8s.io"]
    resources:
      - customresourcedefinitions
    verbs: ["get", "list", "watch"]

  # Authentication (for gateway API admission)
  - apiGroups: ["authentication.k8s.io"]
    resources:
      - tokenreviews
    verbs: ["create"]

  # Leader election
  - apiGroups: ["coordination.k8s.io"]
    resources:
      - leases
    verbs: ["create", "get", "update"]
```

---

## 6. GatewayClass Spec

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: {{ .Values.gatewayApi.gatewayClassName | default "kgateway" }}
spec:
  controllerName: kgateway.dev/kgateway
```

---

## 7. PDB Spec

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "kgateway-controller.fullname" . }}
spec:
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  # OR maxUnavailable: {{ .Values.podDisruptionBudget.maxUnavailable }}
  selector:
    matchLabels:
      {{- include "kgateway-controller.selectorLabels" . | nindent 6 }}
```

---

## 8. VPA Spec

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: {{ include "kgateway-controller.fullname" . }}
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "kgateway-controller.fullname" . }}
  updatePolicy:
    updateMode: {{ .Values.verticalPodAutoscaler.updateMode | default "Off" }}
  resourcePolicy:
    containerPolicies:
      - containerName: kgateway
        minAllowed:
          cpu: {{ .Values.verticalPodAutoscaler.minAllowed.cpu }}
          memory: {{ .Values.verticalPodAutoscaler.minAllowed.memory }}
        maxAllowed:
          cpu: {{ .Values.verticalPodAutoscaler.maxAllowed.cpu }}
          memory: {{ .Values.verticalPodAutoscaler.maxAllowed.memory }}
```

---

## 9. values.yaml Schema (Key Fields)

| Path | Type | Default | Description |
|------|------|---------|-------------|
| `replicaCount` | int | 1 | Controller replicas |
| `image.registry` | string | `cr.kgateway.dev/kgateway-dev` | Image registry |
| `image.repository` | string | `kgateway` | Image repository |
| `image.tag` | string | `""` | Overrides Chart.AppVersion (auto-prepends v) |
| `image.pullPolicy` | string | `IfNotPresent` | Pull policy |
| `controller.logLevel` | string | `info` | KGW_LOG_LEVEL |
| `controller.enableEnvoy` | bool | `true` | KGW_ENABLE_ENVOY |
| `controller.validationMode` | string | `standard` | KGW_VALIDATION_MODE |
| `controller.discoveryNamespaceSelectors` | list | `[]` | Namespace selectors |
| `controller.policyMerge` | object | `{}` | Policy merge config |
| `controller.goMemLimit` | string | `""` | GOMEMLIMIT |
| `controller.goMaxProcs` | string | `""` | GOMAXPROCS |
| `controller.proxy.image.registry` | string | `cr.kgateway.dev/kgateway-dev` | Proxy image registry |
| `controller.proxy.image.repository` | string | `kgateway` | Proxy image repository |
| `controller.proxy.image.tag` | string | `""` | Proxy image tag |
| `controller.proxy.image.pullPolicy` | string | `IfNotPresent` | Proxy pull policy |
| `service.type` | string | `ClusterIP` | Service type |
| `service.ports.grpcXds` | int | `9977` | xDS port |
| `service.ports.health` | int | `9093` | Health port |
| `service.ports.metrics` | int | `9092` | Metrics port |
| `serviceAccount.create` | bool | `true` | Create SA |
| `serviceAccount.name` | string | `""` | SA name override |
| `serviceAccount.annotations` | object | `{}` | SA annotations |
| `gatewayApi.createGatewayClass` | bool | `false` | Create GatewayClass resource |
| `gatewayApi.gatewayClassName` | string | `kgateway` | GatewayClass name |
| `metrics.enabled` | bool | `true` | Enable Prometheus annotations |
| `autoscaling.enabled` | bool | `false` | Enable HPA |
| `autoscaling.minReplicas` | int | `1` | HPA min replicas |
| `autoscaling.maxReplicas` | int | `5` | HPA max replicas |
| `autoscaling.targetCPUUtilizationPercentage` | int | `80` | CPU target |
| `podDisruptionBudget.enabled` | bool | `false` | Enable PDB |
| `podDisruptionBudget.minAvailable` | int/string | `1` | Min available pods |
| `podDisruptionBudget.maxUnavailable` | string | `""` | Max unavailable (mutually exclusive with minAvailable) |
| `verticalPodAutoscaler.enabled` | bool | `false` | Enable VPA |
| `verticalPodAutoscaler.updateMode` | string | `Off` | VPA update mode |
| `verticalPodAutoscaler.minAllowed.cpu` | string | `100m` | VPA min CPU |
| `verticalPodAutoscaler.minAllowed.memory` | string | `128Mi` | VPA min memory |
| `verticalPodAutoscaler.maxAllowed.cpu` | string | `2` | VPA max CPU |
| `verticalPodAutoscaler.maxAllowed.memory` | string | `2Gi` | VPA max memory |
| `resources.requests.cpu` | string | `100m` | CPU request |
| `resources.requests.memory` | string | `256Mi` | Memory request |
| `resources.limits.cpu` | string | `500m` | CPU limit |
| `resources.limits.memory` | string | `512Mi` | Memory limit |

> **Schema `required` fields**: `values.schema.json` marks `image.registry` and `image.repository` as required. All other fields have defaults and are optional. `replicaCount` has a `minimum: 1` constraint.

| `nodeSelector` | object | `{}` | Node selector |
| `tolerations` | list | `[]` | Tolerations |
| `affinity` | object | `{}` | Affinity |
| `podAnnotations` | object | `{}` | Pod annotations |
| `podLabels` | object | `{}` | Pod labels |
| `podSecurityContext` | object | `{}` | Pod-level security context |
| `securityContext` | object | see §3 above | Container security context |
