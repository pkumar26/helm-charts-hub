# Feature Specification: Envoy Gateway Controller Chart

**Feature Branch**: `003-envoy-gateway-chart`
**Created**: 2026-02-26
**Status**: Draft
**Input**: Add a new Helm chart to deploy Envoy Gateway which uses the Gateway API of Kubernetes.

---

## 1. Overview

Add an **envoy-gateway** controller chart to the helm-charts-hub catalog. Envoy Gateway is an implementation of the Kubernetes Gateway API that manages Envoy Proxy as a data plane. Unlike Traefik or NGINX Ingress controllers that use proprietary controller binaries, Envoy Gateway is purpose-built for the Gateway API specification and uses Envoy Proxy as its underlying data plane.

The chart deploys:
- **Envoy Gateway controller** — the control plane that watches Gateway API resources and configures Envoy Proxy instances
- **GatewayClass** — registers Envoy Gateway as a Gateway API implementation
- **Gateway** (optional) — a default Gateway resource with configurable listeners
- **Supporting resources** — RBAC, ServiceAccount, ConfigMap, Service

The chart follows the same `common-lib` integration pattern established by `traefik-controller` and `nginx-controller`.

## 2. Goals

- Deploy Envoy Gateway as a Gateway API controller on Kubernetes
- Provide GatewayClass, Gateway, and supporting RBAC resources
- Reuse common-lib helpers for labels, annotations, naming, and service accounts
- Provide production-ready defaults (security context, RBAC, resource limits)
- Support configurable listeners (HTTP, HTTPS, TCP, UDP, TLS)
- Include CI test values, README, and environment overlays for dev/staging/production
- Follow all repository conventions from the constitution

## 3. Non-Goals

- Envoy Proxy data-plane deployment — Envoy Gateway controller provisions data-plane Envoy instances automatically via the Gateway API
- EnvoyProxy custom resource (advanced Envoy configuration) — may be added as a follow-on
- EnvoyPatchPolicy or BackendTrafficPolicy CRDs — Envoy Gateway extension policies are out of scope for initial chart
- Automatic TLS certificate management (cert-manager integration)
- Rate limiting, authentication, or other extension filters

## 4. Acceptance Criteria

| Criteria | Details |
|----------|---------|
| `helm lint` passes with zero errors | Chart passes linting |
| `helm template` renders Deployment, Service, ServiceAccount, ClusterRole, ClusterRoleBinding, GatewayClass | All core resources rendered |
| All resources carry 6 base labels + 2 base annotations | Uses common-lib helpers |
| GatewayClass references correct controller name | `gateway.envoyproxy.io/gatewayclass-controller` |
| Gateway only rendered when `gateway.enabled: true` | Feature-flagged |
| RBAC grants minimum required permissions for Gateway API resources | Least-privilege |
| Service type ClusterIP by default for controller (not data-plane) | Controller is internal |
| ConfigMap renders Envoy Gateway configuration | Provider config |
| CI test values pass `helm template` | test-values.yaml and test-gateway-values.yaml |
| Environment overlays exist for dev, staging, production | Consistent with existing charts |
| README includes all required sections per constitution §9 | Complete documentation |

## 5. Functional Requirements

### FR-1: Controller Deployment
Deploy the Envoy Gateway controller as a Kubernetes Deployment with configurable replicas, resource limits, security context, and health probes.

### FR-2: GatewayClass Resource
Create a GatewayClass resource that registers Envoy Gateway as a Gateway API implementation with the controller name `gateway.envoyproxy.io/gatewayclass-controller`.

### FR-3: Gateway Resource (Optional)
Optionally create a default Gateway resource with configurable listeners for HTTP and HTTPS traffic, gated behind `gateway.enabled`.

### FR-4: RBAC
Create ClusterRole and ClusterRoleBinding with minimum required permissions for managing Gateway API resources (GatewayClasses, Gateways, HTTPRoutes, GRPCRoutes, TLSRoutes, TCPRoutes, ReferenceGrants, etc.), as well as core resources (Services, Endpoints, Secrets, Namespaces, ConfigMaps).

### FR-5: Service
Expose the controller via a ClusterIP Service on its gRPC xDS port (default: 18000). Optionally expose the metrics port (19001) when metrics collection is enabled. Health probes use port 8081 internally and are not exposed on the Service.

### FR-6: ConfigMap
Provide an Envoy Gateway configuration via ConfigMap, including gateway controller settings, provider configuration, and logging levels.

### FR-7: ServiceAccount
Create a ServiceAccount using the `common-lib.serviceaccount` helper.

## 6. Technical Constraints

- Must use `common-lib` as a dependency (same pattern as traefik-controller)
- Must follow the canonical values shape from constitution §5.2
- Must gate optional resources behind boolean feature flags
- Envoy Gateway v1.3.x is the target version (latest stable)
- Requires Kubernetes 1.28+ for Gateway API v1 support
- Requires Gateway API CRDs to be pre-installed on the cluster

## 7. Dependencies

- `common-lib` library chart (>=0.1.0 <1.0.0)
- Gateway API CRDs (v1.2+) must be installed separately
- Kubernetes 1.28+
- Helm 3.x
