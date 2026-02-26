# Contracts: Envoy Gateway Chart Resources

**Feature Branch**: `003-envoy-gateway-chart`
**Date**: 2026-02-26

---

## 1. Chart.yaml

```yaml
apiVersion: v2
name: envoy-gateway
description: Envoy Gateway controller chart for helm-charts-hub — Gateway API-native controller using Envoy Proxy as data plane
type: application
version: 0.1.0
appVersion: "1.3.0"
dependencies:
  - name: common-lib
    version: ">=0.1.0 <1.0.0"
    repository: "file://../common-lib"
```

## 2. Template Files

### 2.1 deployment.yaml

Renders a `Deployment` with:
- Container: `envoy-gateway` using `image.repository:image.tag`
- Args: `["server", "--config-path=/config/envoy-gateway.yaml"]`
- Ports: grpc (18000), ratelimit (18001), metrics (19001)
- Health probe port: 8081 (liveness: `/healthz`, readiness: `/readyz`)
- Volume mount: `/config` from ConfigMap (readOnly)
- Env: `ENVOY_GATEWAY_NAMESPACE` (downward API), `KUBERNETES_CLUSTER_DOMAIN`
- Labels via `common-lib.labels`, selector via `common-lib.selectorLabels`
- Naming via `common-lib.fullname`
- Optional: extraArgs, extraEnv, extraVolumes, extraVolumeMounts

### 2.2 service.yaml

Renders a `Service` with:
- Type: ClusterIP (default)
- Port: grpc (18000)
- Conditional port: metrics (19001) when `metrics.enabled`
- Labels via `common-lib.labels`
- Annotations via `common-lib.annotations`

### 2.3 serviceaccount.yaml

Renders via `common-lib.serviceaccount` helper.
- Gated: `serviceAccount.create`

### 2.4 clusterrole.yaml

Renders a `ClusterRole` with:
- Core, Gateway API, Apps, Autoscaling, Coordination permissions
- Gated: `rbac.create`
- Labels via `common-lib.labels`

### 2.5 clusterrolebinding.yaml

Renders a `ClusterRoleBinding` with:
- References ClusterRole by `common-lib.fullname`
- Subject: ServiceAccount in release namespace
- Gated: `rbac.create`
- Labels via `common-lib.labels`

### 2.6 configmap.yaml

Renders a `ConfigMap` with:
- Name: `fullname`-config
- Data key: `envoy-gateway.yaml`
- Content: EnvoyGateway config object (apiVersion, kind, gateway, provider, logging)
- Labels via `common-lib.labels`

### 2.7 gateway-class.yaml

Renders a `GatewayClass` with:
- Name: `.Values.gatewayClass.name` (default: `envoy`)
- Controller: `.Values.gatewayClass.controllerName`
- Gated: `gatewayClass.create`
- Labels via `common-lib.labels`

### 2.8 gateway.yaml

Renders a `Gateway` with:
- Name: `.Values.gateway.name` (default: `envoy-gateway`)
- GatewayClassName: references GatewayClass name
- Listeners: configurable list with name, port, protocol, hostname
- AllowedRoutes: namespaces from All
- Gated: `gateway.enabled`
- Labels via `common-lib.labels`

### 2.9 _helpers.tpl

Local chart helpers:
- `envoy-gateway.name` — chart name with nameOverride support
- `envoy-gateway.fullname` — full resource name with fullnameOverride support

### 2.10 NOTES.txt

Post-install instructions showing:
- GatewayClass name and usage
- Gateway details (if enabled)
- How to create HTTPRoute resources
- Prerequisite: Gateway API CRDs
- Controller service info

## 3. CI Test Values

### 3.1 test-values.yaml

Minimal CI values — no Gateway, GatewayClass only:
```yaml
image:
  repository: docker.io/envoyproxy/gateway
  tag: "v1.3.0"
replicaCount: 1
service:
  type: ClusterIP
gatewayClass:
  create: true
  name: envoy
gateway:
  enabled: false
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

### 3.2 test-gateway-values.yaml

CI values with Gateway enabled:
```yaml
image:
  repository: docker.io/envoyproxy/gateway
  tag: "v1.3.0"
replicaCount: 1
service:
  type: ClusterIP
gatewayClass:
  create: true
  name: envoy
gateway:
  enabled: true
  name: envoy-gateway
  listeners:
    - name: http
      port: 80
      protocol: HTTP
    - name: https
      port: 443
      protocol: HTTPS
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

## 4. Environment Overlays

### dev

```yaml
replicaCount: 1
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
gateway:
  enabled: true
  name: envoy-gateway
  listeners:
    - name: http
      port: 80
      protocol: HTTP
config:
  logging:
    level:
      default: debug
```

### staging

```yaml
replicaCount: 1
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
gateway:
  enabled: true
  name: envoy-gateway
  listeners:
    - name: http
      port: 80
      protocol: HTTP
    - name: https
      port: 443
      protocol: HTTPS
```

### production

```yaml
replicaCount: 2
resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 75
gateway:
  enabled: true
  name: envoy-gateway
  listeners:
    - name: http
      port: 80
      protocol: HTTP
    - name: https
      port: 443
      protocol: HTTPS
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - envoy-gateway
          topologyKey: kubernetes.io/hostname
```
