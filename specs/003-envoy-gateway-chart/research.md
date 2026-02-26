# Research: Envoy Gateway Controller Chart

**Feature Branch**: `003-envoy-gateway-chart`
**Date**: 2026-02-26

---

## 1. Envoy Gateway Version & Image

- **Decision**: Use Envoy Gateway v1.3.x (conservative stable) with `docker.io/envoyproxy/gateway:v1.3.0`
- **Rationale**: v1.3.x is the target specified in the feature spec. While v1.7.0 is the latest, using a well-established stable version reduces risk. The `appVersion` in Chart.yaml can be updated as needed.
- **Alternatives considered**: v1.7.0 (latest), v1.6.4 (previous LTS). Both are viable upgrade targets later.
- **Image**: `docker.io/envoyproxy/gateway`
- **Note**: The chart's `appVersion` and default `image.tag` will use `v1.3.0`. Users can override via values.

## 2. GatewayClass Controller Name

- **Decision**: `gateway.envoyproxy.io/gatewayclass-controller`
- **Rationale**: This is the canonical controller name used by Envoy Gateway across all versions. It is hardcoded in the Envoy Gateway binary and must match exactly in the GatewayClass resource.
- **Alternatives considered**: None — this is a fixed value.

## 3. RBAC Permissions

- **Decision**: Implement a simplified but sufficient ClusterRole covering:
  - Core resources: namespaces, services, secrets, configmaps, endpointslices, events, nodes
  - Gateway API resources: gatewayclasses, gateways, httproutes, grpcroutes, tcproutes, tlsroutes, udproutes, referencegrants, backendtlspolicies (with status update)
  - Apps resources: deployments (for managing Envoy Proxy data plane)
  - Autoscaling: horizontalpodautoscalers (for Envoy Proxy HPA)
  - Coordination: leases (for leader election)
  - Discovery: endpointslices
- **Rationale**: Envoy Gateway needs to watch Gateway API resources and manage the Envoy Proxy data plane (creating Deployments, Services, ServiceAccounts). Leader election requires lease access. We simplify by using a single ClusterRole rather than splitting into multiple Roles.
- **Alternatives considered**: Separate namespaced Role for infra management — adds complexity without clear benefit for a simple chart.

## 4. Controller Ports

- **Decision**: Expose the following ports:
  | Port | Name | Purpose |
  |------|------|---------|
  | 18000 | grpc | xDS server (gRPC) for Envoy Proxy fleet |
  | 18001 | ratelimit | xDS Ratelimit server |
  | 19001 | metrics | Prometheus metrics |
  | 8081 | health | Health check (liveness + readiness) — only used internally |
- **Rationale**: Port 18000 is the primary xDS gRPC port that data-plane Envoy instances connect to. Port 19001 provides Prometheus metrics. Port 8081 is for health probes (not exposed on Service since it binds to 127.0.0.1).
- **Service ports**: Only 18000 (grpc) needs to be exposed on the ClusterIP Service for data-plane connectivity. Metrics port 19001 optionally exposed.

## 5. Health Probes

- **Decision**: Use HTTP GET probes on port 8081:
  - Liveness: `/healthz` — initialDelaySeconds: 15, periodSeconds: 20
  - Readiness: `/readyz` — initialDelaySeconds: 5, periodSeconds: 10
- **Rationale**: These are the standard Envoy Gateway health endpoints, matching upstream defaults.
- **Alternatives considered**: TCP socket checks — less precise, HTTP GET is preferred.

## 6. Configuration Mechanism

- **Decision**: Use a ConfigMap with key `envoy-gateway.yaml` containing the `EnvoyGateway` configuration object:
  ```yaml
  apiVersion: gateway.envoyproxy.io/v1alpha1
  kind: EnvoyGateway
  gateway:
    controllerName: gateway.envoyproxy.io/gatewayclass-controller
  provider:
    type: Kubernetes
  logging:
    level:
      default: info
  ```
- **Rationale**: This is the standard configuration mechanism. The ConfigMap is mounted at `/config` in the container.
- **Alternatives considered**: EnvoyGateway CRD — requires the CRDs to be installed first and adds a chicken-and-egg problem.

## 7. Container Args

- **Decision**: Use `args: ["server", "--config-path=/config/envoy-gateway.yaml"]`
- **Rationale**: This is the standard startup command. No explicit `command` override — uses the image's default entrypoint.
- **Environment variables**:
  - `ENVOY_GATEWAY_NAMESPACE` — from downward API `fieldRef: metadata.namespace`
  - `KUBERNETES_CLUSTER_DOMAIN` — defaults to `cluster.local`

## 8. Gateway API CRD Requirements

- **Decision**: Assume Gateway API CRDs are pre-installed. Do NOT bundle CRDs in the chart.
- **Rationale**: Follows the same pattern as `traefik-controller`. CRDs are cluster-scoped resources with lifecycle independent of any single chart. Bundling CRDs causes upgrade conflicts. The README will document the prerequisite.
- **Required CRD versions**: Gateway API v1.0+ (GatewayClass, Gateway, HTTPRoute, GRPCRoute, etc.)
- **Installation**: `kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml`

## 9. Namespace

- **Decision**: No namespace restriction. Use `{{ .Release.Namespace }}` throughout.
- **Rationale**: While the convention is `envoy-gateway-system`, the chart should work in any namespace. The controller discovers its namespace via the `ENVOY_GATEWAY_NAMESPACE` env var.
- **README recommendation**: Use `envoy-gateway-system` namespace.

## 10. Data Plane Management

- **Decision**: Chart only deploys the control plane (Envoy Gateway controller). Data plane (Envoy Proxy) is automatically managed by the controller.
- **Rationale**: When a `Gateway` resource is created, Envoy Gateway automatically provisions Envoy Proxy Deployments, Services, ServiceAccounts, and ConfigMaps. This is core to Envoy Gateway's architecture.
- **Implication**: The RBAC ClusterRole must include permissions to create/delete/patch Deployments, Services, ServiceAccounts, ConfigMaps, and HPAs — these are for the auto-provisioned data plane.

## 11. Chart Pattern Decision

- **Decision**: Follow the identical pattern to `traefik-controller` — custom templates for Deployment, Service, RBAC; common-lib for metadata helpers.
- **Rationale**: Controller charts have unique requirements (multi-port, custom args, RBAC) that don't map to `common-lib.deployment`. All existing controller charts use this pattern.
- **Key difference from traefik-controller**: No IngressClass resource (Envoy Gateway is Gateway API-native, not an Ingress controller).
