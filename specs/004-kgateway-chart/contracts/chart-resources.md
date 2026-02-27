# Chart Resource Contracts: kgateway-controller

**Feature Branch**: `004-kgateway-chart`

---

## 1. Chart.yaml

```yaml
apiVersion: v2
name: kgateway-controller
description: A Helm chart for deploying kgateway (CNCF Gateway API implementation) controller
type: application
version: 0.1.0
appVersion: "2.2.1"
kubeVersion: ">=1.31.0-0"
home: https://kgateway.dev
sources:
  - https://github.com/kgateway-dev/kgateway
keywords:
  - kgateway
  - gateway-api
  - envoy
  - ingress
  - kubernetes
maintainers:
  - name: helm-charts-hub
dependencies:
  - name: common-lib
    version: ">=0.1.0 <1.0.0"
    repository: "file://../common-lib"
```

---

## 2. Template Behaviors

### deployment.yaml
- **Always created**: Yes
- **Uses common-lib**: `common-lib.labels`, `common-lib.annotations`; selector labels via chart-specific `kgateway-controller.selectorLabels` (shared with PDB/VPA); security context applied inline from `.Values.securityContext` (not `common-lib.podSecurity`), matching controller-chart precedent
- **Container**: Single container named `kgateway`
- **Image**: `{{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ include "kgateway-controller.imageTag" . }}`
- **Ports**: grpc-xds (9977), health (9093), metrics (9092)
- **Config**: All via environment variables (see data-model.md §3)
- **Probes**: readinessProbe + startupProbe (NO liveness)
- **SecurityContext**: runAsNonRoot, runAsUser 10101, readOnlyRootFilesystem, drop ALL capabilities
- **Pod annotations**: Prometheus scrape annotations when `metrics.enabled`

### service.yaml
- **Always created**: Yes
- **Uses common-lib**: `common-lib.labels`, `common-lib.annotations`
- **Ports**: grpc-xds (9977), health (9093), metrics (9092)
- **Type**: `{{ .Values.service.type }}` (default: ClusterIP)

### serviceaccount.yaml
- **Gated**: `{{ .Values.serviceAccount.create }}`
- **Uses common-lib**: `common-lib.labels`, `common-lib.annotations`
- **Annotations**: Merged from `serviceAccount.annotations`
- **automountServiceAccountToken**: true

### clusterrole.yaml
- **Always created**: Yes
- **Uses common-lib**: `common-lib.labels`
- **Rules**: Full RBAC rules from data-model.md §5

### clusterrolebinding.yaml
- **Always created**: Yes
- **Uses common-lib**: `common-lib.labels`
- **RoleRef**: Binds to the clusterrole
- **Subject**: ServiceAccount in Release.Namespace

### gateway-class.yaml
- **Gated**: `{{ .Values.gatewayApi.createGatewayClass }}`
- **Name**: `{{ .Values.gatewayApi.gatewayClassName }}` (default: kgateway)
- **ControllerName**: `kgateway.dev/kgateway`

### hpa.yaml
- **Gated**: `{{ .Values.autoscaling.enabled }}`
- **Uses common-lib**: `common-lib.hpa` helper
- **Target**: Deployment

### pdb.yaml
- **Gated**: `{{ .Values.podDisruptionBudget.enabled }}`
- **Uses common-lib**: `common-lib.labels`
- **Spec**: minAvailable or maxUnavailable (mutually exclusive)

### vpa.yaml
- **Gated**: `{{ .Values.verticalPodAutoscaler.enabled }}`
- **Uses common-lib**: `common-lib.labels`
- **Spec**: targetRef → Deployment, updatePolicy, resourcePolicy

### NOTES.txt
- Installation summary with connection instructions
- Prints xDS endpoint, health endpoint, and metrics endpoint
- Lists enabled optional features (GatewayClass, HPA, PDB, VPA)

---

## 3. CI Test Values

### ci/test-values.yaml (minimal)
```yaml
replicaCount: 1
image:
  registry: cr.kgateway.dev/kgateway-dev
  repository: kgateway
  pullPolicy: IfNotPresent
controller:
  logLevel: info
  enableEnvoy: true
```

### ci/test-full-values.yaml (comprehensive)
```yaml
replicaCount: 2
image:
  registry: cr.kgateway.dev/kgateway-dev
  repository: kgateway
  pullPolicy: Always
controller:
  logLevel: debug
  enableEnvoy: true
  validationMode: strict
  discoveryNamespaceSelectors:
    - matchLabels:
        kgateway-discovery: "true"
  proxy:
    image:
      registry: cr.kgateway.dev/kgateway-dev
      repository: kgateway
      pullPolicy: IfNotPresent
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/kgateway
gatewayApi:
  createGatewayClass: true
  gatewayClassName: kgateway
metrics:
  enabled: true
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 75
podDisruptionBudget:
  enabled: true
  minAvailable: 1
verticalPodAutoscaler:
  enabled: true
  updateMode: "Off"
  minAllowed:
    cpu: 100m
    memory: 128Mi
  maxAllowed:
    cpu: 2
    memory: 2Gi
resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi
podAnnotations:
  custom-annotation: "test"
nodeSelector:
  kubernetes.io/os: linux
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "kgateway"
    effect: "NoSchedule"
```

---

## 4. Environment Overlays

### environments/dev/kgateway-controller.values.yaml
```yaml
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

### environments/staging/kgateway-controller.values.yaml
```yaml
replicaCount: 2
controller:
  logLevel: info
  enableEnvoy: true
gatewayApi:
  createGatewayClass: true
metrics:
  enabled: true
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
podDisruptionBudget:
  enabled: true
  minAvailable: 1
resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi
```

### environments/production/kgateway-controller.values.yaml
```yaml
replicaCount: 3
controller:
  logLevel: warn
  enableEnvoy: true
  validationMode: strict
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
    cpu: 4
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
```
