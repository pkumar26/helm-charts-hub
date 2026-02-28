# Research: kgateway Controller Chart

**Feature Branch**: `004-kgateway-chart`
**Date**: 2026-02-26

---

## 1. kgateway Version & Image

- **Decision**: Use kgateway v2.2.1 (latest stable) with `cr.kgateway.dev/kgateway-dev/kgateway:v2.2.1`
- **Rationale**: v2.2.1 is the latest stable release. kgateway (formerly Gloo, by Solo.io) is a CNCF sandbox project with 5.4k GitHub stars.
- **Image registry**: `cr.kgateway.dev/kgateway-dev`
- **Image repository**: `kgateway`
- **Image tag convention**: Tags are prefixed with `v` (e.g., `v2.2.1`). The upstream `_helpers.tpl` has a `kgateway.imageTag` helper that prepends `v` to semver-style Chart.AppVersion. Our chart replicates this logic.
- **Full image**: `cr.kgateway.dev/kgateway-dev/kgateway:v2.2.1`

## 2. GatewayClass Controller Name

- **Decision**: `kgateway.dev/kgateway`
- **Rationale**: This is the canonical controller name for kgateway. It differs from Envoy Gateway (`gateway.envoyproxy.io/gatewayclass-controller`).
- **Note**: kgateway auto-creates a GatewayClass named `kgateway` at runtime. Our chart provides an optional Helm-managed GatewayClass for explicitness and auditability, gated by `gatewayApi.createGatewayClass`.

## 3. Configuration Mechanism

- **Decision**: Environment variables (NOT ConfigMap)
- **Rationale**: kgateway is configured entirely via `KGW_*` environment variables. There is no ConfigMap-based configuration, which is a key difference from Envoy Gateway.
- **Key environment variables**:
  | Env Var | Purpose | Default |
  |---------|---------|---------|
  | `POD_NAMESPACE` | Pod namespace (downward API fieldRef) | fieldRef: metadata.namespace |
  | `KGW_LOG_LEVEL` | Log level | info |
  | `KGW_XDS_SERVICE_NAME` | xDS service name | derived from fullname |
  | `KGW_XDS_SERVICE_PORT` | xDS service port | 9977 |
  | `KGW_DEFAULT_IMAGE_REGISTRY` | Default image registry for proxies | cr.kgateway.dev/kgateway-dev |
  | `KGW_DEFAULT_IMAGE_TAG` | Default image tag for proxies | v2.2.1 |
  | `KGW_DEFAULT_IMAGE_PULL_POLICY` | Default pull policy for proxies | IfNotPresent |
  | `KGW_ENABLE_ENVOY` | Enable Envoy data plane | true |
  | `KGW_VALIDATION_MODE` | Validation mode | standard |
  | `KGW_DISCOVERY_NAMESPACE_SELECTORS` | Namespace selectors (JSON) | [] |
  | `KGW_POLICY_MERGE` | Policy merge settings | {} |
  | `GOMEMLIMIT` | Go memory limit (from resource limits) | — |
  | `GOMAXPROCS` | Go max procs | — |

## 4. Controller Ports

- **Decision**: Three control-plane ports:
  | Port | Name | Purpose |
  |------|------|---------|
  | 9977 | grpc-xds | xDS gRPC server for Envoy proxy fleet |
  | 9093 | health | Health/readiness endpoint |
  | 9092 | metrics | Prometheus metrics |
- **Service ports**: All three ports exposed on the ClusterIP Service (upstream exposes all).
- **Key difference from Envoy Gateway**: Envoy Gateway uses 18000/18001/8081/19001; kgateway uses 9977/9093/9092.

## 5. Health Probes

- **Decision**: Readiness + startup probes only (NO liveness probe), matching upstream pattern:
  - Readiness: HTTP GET `/readyz` port 9093, initialDelay: 1s, period: 10s
  - Startup: HTTP GET `/readyz` port 9093, failureThreshold: 120, period: 1s
- **Rationale**: The upstream chart uses readiness + startup probes with no liveness probe. The startup probe gives the controller up to 120 seconds to initialize. This avoids unnecessary restarts during initialization.
- **Key difference from Envoy Gateway**: Envoy Gateway uses liveness + readiness; kgateway uses readiness + startup.

## 6. RBAC Permissions

- **Decision**: Extensive ClusterRole covering:
  - Core: services, endpoints, secrets, namespaces, nodes, pods, configmaps, events, serviceaccounts
  - Apps: deployments (full CRUD for managing data-plane proxy pods)
  - Gateway API (gateway.networking.k8s.io): gatewayclasses, gateways, httproutes, grpcroutes, tcproutes, tlsroutes, referencegrants, backendtlspolicies (+ status update)
  - kgateway custom resources (gateway.kgateway.dev): trafficpolicies, listenerpolicies, httplistenerpolicies, backends, directresponses, gatewayextensions, gatewayparameters, backendconfigpolicies (+ status update)
  - Experimental (gateway.networking.x-k8s.io): xlistenersets
  - Discovery: endpointslices
  - API extensions: customresourcedefinitions (get/list/watch)
  - Authentication: tokenreviews (create)
  - Coordination: leases (create/get/update for leader election)
  - Autoscaling: horizontalpodautoscalers, verticalpodautoscalers (full CRUD)
  - Policy: poddisruptionbudgets (full CRUD)
- **Rationale**: kgateway manages the data plane (creating Deployments, Services, HPAs, VPAs, PDBs for Envoy proxy pods). The RBAC is more extensive than Envoy Gateway's because kgateway also manages its own CRDs and supports more autoscaling resources.

## 7. CRD Requirements

- **Decision**: Two sets of CRDs required, both pre-installed. NOT bundled in chart.
  1. **Gateway API CRDs** (v1.5.0):
     ```bash
     kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
     ```
  2. **kgateway CRDs** (v2.2.1):
     ```bash
     helm upgrade -i kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds --version v2.2.1
     ```
- **Rationale**: Same pattern as traefik-controller. CRDs are cluster-scoped and have independent lifecycle.

## 8. No Gateway Template

- **Decision**: No Gateway resource template in this chart.
- **Rationale**: Unlike Envoy Gateway where the chart optionally creates a Gateway resource, kgateway's data plane is fully dynamic. When users create Gateway resources, the kgateway controller automatically provisions Envoy proxy Deployments+Services. The control plane chart should not create data-plane resources.
- **Key difference from traefik-controller and envoy-gateway**: Both of those charts have optional Gateway templates. kgateway does not.

## 9. No ConfigMap Template

- **Decision**: No ConfigMap template.
- **Rationale**: kgateway uses environment variables for all configuration. There is no file-based config mechanism.

## 10. Extended Resources

- **Decision**: Include PDB and VPA as chart-specific templates (not in common-lib).
  - PDB: `policy/v1` PodDisruptionBudget, gated by `podDisruptionBudget.enabled`
  - VPA: `autoscaling.k8s.io/v1` VerticalPodAutoscaler, gated by `verticalPodAutoscaler.enabled`
- **Rationale**: Upstream kgateway chart supports both. PDB is essential for production HA. VPA helps right-size controller resources.

## 11. Image Tag Helper

- **Decision**: Include a `kgateway-controller.imageTag` helper that prepends `v` to the AppVersion if the tag is not explicitly set.
- **Rationale**: The upstream chart prepends `v` to semver tags. E.g., AppVersion `2.2.1` → image tag `v2.2.1`. This matches upstream behavior.

## 12. Prometheus Annotations

- **Decision**: Add Prometheus scrape annotations to pod template when `metrics.enabled: true`:
  ```yaml
  prometheus.io/scrape: "true"
  prometheus.io/path: "/metrics"
  prometheus.io/port: "9092"
  ```
- **Rationale**: Upstream defaults to these annotations. Follows standard Prometheus discovery pattern.

## 13. Kubernetes / Gateway API Compatibility

| kgateway | Kubernetes | Gateway API | Envoy Proxy | Helm |
|----------|-----------|-------------|-------------|------|
| 2.2.x | 1.31–1.35 | 1.4.x | 1.35 | ≥ 3.12 |
| 2.1.x | 1.31–1.34 | 1.4.x | 1.35 | ≥ 3.12 |
| 2.0.x | 1.27–1.31 | 1.2.x | 1.33 | ≥ 3.12 |
