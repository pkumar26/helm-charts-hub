# Feature Specification: kgateway Controller Chart

**Feature Branch**: `004-kgateway-chart`
**Created**: 2026-02-26
**Status**: Draft
**Input**: Add a new Helm chart to deploy kgateway which uses the Gateway API of Kubernetes.

---

## 1. Overview

Add a **kgateway-controller** chart to the helm-charts-hub catalog. kgateway (formerly Gloo, by Solo.io) is a CNCF sandbox Envoy-based API gateway that implements the Kubernetes Gateway API. The control plane watches Gateway API resources, translates them into Envoy xDS configuration, and dynamically provisions Envoy proxy data-plane pods when users create Gateway resources.

The chart deploys:
- **kgateway controller** — the control plane that watches Gateway API resources and serves xDS to Envoy proxy instances
- **GatewayClass** (optional, gated) — registers kgateway as a Gateway API implementation with controller name `kgateway.dev/kgateway`
- **Supporting resources** — RBAC (ClusterRole/ClusterRoleBinding), ServiceAccount, Service
- **Extended resources** — HorizontalPodAutoscaler, PodDisruptionBudget, VerticalPodAutoscaler (all gated)

The chart follows the same `common-lib` integration pattern established by `traefik-controller` and `nginx-controller`.

**Key differences from envoy-gateway chart:**
- kgateway is a separate CNCF project (not Envoy Gateway)
- Configuration via environment variables (not ConfigMap)
- GatewayClass auto-created by controller at runtime (Helm template provided as optional explicit override)
- No Gateway template — data plane Gateways are user-created; the controller dynamically provisions proxy pods
- Three control-plane ports: xDS gRPC (9977), health (9093), metrics (9092)
- Readiness + startup probes only (no liveness probe), matching upstream pattern

## 2. Goals

- Deploy kgateway v2.2.1 as a Gateway API controller on Kubernetes
- Provide GatewayClass and supporting RBAC resources
- Reuse common-lib helpers for labels, annotations, naming, and service accounts
- Provide production-ready defaults: `runAsNonRoot`/`readOnlyRootFilesystem` security context, least-privilege RBAC, CPU/memory requests and limits, startup+readiness probes
- Include extended resources: HPA, PDB, VPA (all gated behind feature flags)
- Include CI test values, README, and environment overlays for dev/staging/production
- Follow all repository conventions from the constitution

## 3. Non-Goals

- Envoy proxy data-plane deployment — kgateway controller provisions data-plane Envoy instances automatically when users create Gateway resources
- kgateway CRDs (TrafficPolicy, ListenerPolicy, etc.) — installed via separate `kgateway-crds` Helm chart
- Gateway API CRDs — must be pre-installed on the cluster
- Istio waypoint integration — optional feature, deferred
- TLS for xDS communication — deferred to follow-on
- Rate limiting, authentication, or other extension filters

## 4. Acceptance Criteria

| Criteria | Details |
|----------|---------|
| `helm lint` passes with zero errors | Chart passes linting with default and CI values |
| `helm template` renders Deployment, Service, ServiceAccount, ClusterRole, ClusterRoleBinding | All core resources rendered |
| GatewayClass only rendered when `gatewayApi.createGatewayClass: true` | Feature-flagged |
| All resources carry 6 base labels + 2 base annotations | Uses common-lib helpers |
| GatewayClass references correct controller name | `kgateway.dev/kgateway` |
| RBAC grants minimum required permissions | Gateway API, core, apps, autoscaling, coordination, discovery, apiextensions, authentication |
| Service type ClusterIP by default | Controller is internal control plane |
| HPA only rendered when `autoscaling.enabled: true` | Feature-flagged |
| PDB only rendered when `podDisruptionBudget.enabled: true` | Feature-flagged |
| VPA only rendered when `verticalPodAutoscaler.enabled: true` | Feature-flagged |
| CI test values pass `helm lint` and `helm template` | test-values.yaml and test-full-values.yaml |
| Environment overlays exist for dev, staging, production | Consistent with existing charts |
| README includes all required sections per constitution §9 | Complete documentation |

## 5. Functional Requirements

### FR-1: Controller Deployment
Deploy the kgateway controller as a Kubernetes Deployment with configurable replicas, resource limits, security context, readiness probe (HTTP GET `/readyz` port 9093), and startup probe (HTTP GET `/readyz` port 9093). Configuration is provided via environment variables (KGW_LOG_LEVEL, KGW_XDS_SERVICE_NAME, KGW_XDS_SERVICE_PORT, KGW_DEFAULT_IMAGE_REGISTRY, KGW_DEFAULT_IMAGE_TAG, KGW_ENABLE_ENVOY, etc.).

### FR-2: GatewayClass Resource (Optional)
Optionally create a GatewayClass resource that registers kgateway as a Gateway API implementation with controller name `kgateway.dev/kgateway`. Gated behind `gatewayApi.createGatewayClass`. Note: the kgateway controller also auto-creates a GatewayClass at runtime.

### FR-3: RBAC
Create ClusterRole and ClusterRoleBinding with permissions for Gateway API resources (gatewayclasses, gateways, httproutes, grpcroutes, tcproutes, tlsroutes, referencegrants, backendtlspolicies), kgateway custom resources (gateway.kgateway.dev group), core resources (services, endpoints, secrets, namespaces, nodes, pods, configmaps, events, serviceaccounts), apps (deployments), autoscaling (HPAs, VPAs), policy (PDBs), coordination (leases), discovery (endpointslices), apiextensions (CRDs), and authentication (tokenreviews).

### FR-4: Service
Expose the controller via a ClusterIP Service with three ports: grpc-xds (9977), health (9093), and metrics (9092).

### FR-5: ServiceAccount
Create a ServiceAccount using the `common-lib.serviceaccount` helper.

### FR-6: HorizontalPodAutoscaler
Optionally create an HPA gated behind `autoscaling.enabled`, using common-lib.hpa helper.

### FR-7: PodDisruptionBudget
Optionally create a PDB with configurable minAvailable/maxUnavailable, gated behind `podDisruptionBudget.enabled`.

### FR-8: VerticalPodAutoscaler
Optionally create a VPA with configurable updateMode, gated behind `verticalPodAutoscaler.enabled`.

## 6. Technical Constraints

- Must use `common-lib` as a dependency (same pattern as traefik-controller)
- Must follow the canonical values shape from constitution §5.2
- Must gate optional resources behind boolean feature flags

### Constitution Deviations

| Principle | Deviation | Justification |
|-----------|-----------|---------------|
| §2.5 "liveness/readiness probes" MUST | No liveness probe — uses readiness + startup probes only | Matches upstream kgateway chart. Startup probe (failureThreshold 120, period 1s) provides equivalent health gating during initialization. Liveness probe is intentionally omitted upstream to avoid unnecessary restarts of a leader-elected controller. |
| §3.2 Templates MUST primarily delegate to common-lib | Deployment and Service use custom templates | Follows established controller-chart precedent (traefik-controller, nginx-controller). Custom templates are required for controller-specific needs (env-var config, multi-port, RBAC). Common-lib is used for labels, annotations, naming, ServiceAccount, and HPA. |
- kgateway v2.2.1 is the target version (latest stable)
- Requires Kubernetes 1.31+ for Gateway API v1.4 support
- Requires Gateway API CRDs v1.4.0 and kgateway-crds chart pre-installed
- Image registry: `cr.kgateway.dev/kgateway-dev`
- Image tag must be prefixed with `v` (e.g., `v2.2.1`)

## 7. Dependencies

- `common-lib` library chart (>=0.1.0 <1.0.0)
- Gateway API CRDs (v1.4.0) must be installed separately
- kgateway CRDs chart (`kgateway-crds`) must be installed separately
- Kubernetes 1.31+
- Helm ≥ 3.12
