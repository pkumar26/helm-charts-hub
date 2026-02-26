# Implementation Plan: Envoy Gateway Controller Chart

**Branch**: `003-envoy-gateway-chart` | **Date**: 2026-02-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-envoy-gateway-chart/spec.md`

## Summary

Add an Envoy Gateway controller Helm chart to the helm-charts-hub repository. Envoy Gateway is a Kubernetes Gateway API implementation that manages Envoy Proxy as its data plane. The chart follows the established controller chart pattern (like `traefik-controller`) — using `common-lib` for metadata helpers while providing custom templates for the controller Deployment, RBAC, Service, GatewayClass, and Gateway resources.

## Technical Context

**Language/Version**: Helm chart templates (Go templates), Kubernetes 1.28+  
**Primary Dependencies**: common-lib (library chart), Envoy Gateway v1.3.x, Gateway API CRDs v1.2+  
**Storage**: N/A  
**Testing**: `helm lint`, `helm template`, `ct lint`, CI test values  
**Target Platform**: Kubernetes 1.28+  
**Project Type**: Helm chart (follows existing controller chart pattern)  
**Performance Goals**: N/A (infrastructure chart — performance determined by Envoy Gateway itself)  
**Constraints**: Gateway API CRDs must be pre-installed; controller manages Envoy Proxy data-plane instances automatically  
**Scale/Scope**: Single chart with ~10 template files, values.yaml, CI values, environment overlays, README

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Constitution Section | Status | Notes |
|------|---------------------|--------|-------|
| Uses common-lib helpers | §3.2, §4, §7.2 | ✅ PASS | Labels, annotations, naming, serviceaccount via common-lib |
| Follows canonical values shape | §5.2 | ✅ PASS | image, replicaCount, resources, service, serviceAccount, etc. |
| Feature flags for optional components | §5.5 | ✅ PASS | gateway.enabled, rbac.create, serviceAccount.create |
| Standard labels and annotations | §6 | ✅ PASS | Uses common-lib.labels and common-lib.annotations |
| Chart README with required sections | §9 | ✅ PASS | Will include all §9.2 sections |
| Follows naming conventions | §3.3 | ✅ PASS | lowercase-hyphenated dir, camelCase values |
| values.yaml with sensible defaults | §5.1 | ✅ PASS | Working deployment without overrides |
| Passes helm lint | §8.1 | ✅ PASS | CI test values included |
| SemVer versioning | §11.1 | ✅ PASS | Starting at 0.1.0 |
| Custom templates justified | §3.2 | ✅ PASS | Controller needs multi-port, custom args, RBAC — same rationale as traefik/nginx |

**Gate Result**: PASS — No violations.

## Project Structure

### Documentation (this feature)

```text
specs/003-envoy-gateway-chart/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── chart-resources.md
└── tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
charts/envoy-gateway/
├── Chart.yaml
├── README.md
├── values.yaml
├── ci/
│   ├── test-values.yaml
│   └── test-gateway-values.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   ├── clusterrole.yaml
│   ├── clusterrolebinding.yaml
│   ├── configmap.yaml
│   ├── gateway-class.yaml
│   ├── gateway.yaml
│   └── NOTES.txt

environments/
├── dev/
│   └── envoy-gateway.values.yaml
├── staging/
│   └── envoy-gateway.values.yaml
└── production/
    └── envoy-gateway.values.yaml

examples/
└── envoy-gateway-production.yaml
```

**Structure Decision**: Follows the established controller chart pattern identical to `traefik-controller`. Custom templates for Deployment, Service, RBAC, and Gateway API resources; common-lib for metadata. No IngressClass since Envoy Gateway is Gateway API-native (not an Ingress controller).

## Complexity Tracking

> No violations — no entries needed.

## Constitution Re-Check (Post Phase 1 Design)

*All gates re-evaluated after data model, contracts, and quickstart were produced.*

| Gate | Constitution Section | Status | Notes |
|------|---------------------|--------|-------|
| Uses common-lib helpers | §3.2, §4, §7.2 | ✅ PASS | Labels, annotations, naming, serviceaccount via common-lib. Custom templates justified for controller-specific needs. |
| Follows canonical values shape | §5.2 | ✅ PASS | All canonical keys present: image, replicaCount, resources, service, serviceAccount, podSecurityContext, etc. |
| Feature flags for optional components | §5.5 | ✅ PASS | gateway.enabled, gatewayClass.create, rbac.create, serviceAccount.create, metrics.enabled, autoscaling.enabled |
| Standard labels and annotations | §6 | ✅ PASS | 6 base labels + 2 base annotations on all resources via common-lib |
| Chart README with required sections | §9 | ✅ PASS | All §9.2 sections planned |
| Follows naming conventions | §3.3 | ✅ PASS | Dir: envoy-gateway, values: camelCase, helpers: common-lib.* |
| values.yaml with sensible defaults | §5.1 | ✅ PASS | Working deployment without overrides |
| Passes helm lint | §8.1 | ✅ PASS | CI test values for both basic and gateway modes |
| SemVer versioning | §11.1 | ✅ PASS | 0.1.0 |
| Custom templates justified | §3.2 | ✅ PASS | Same controller-chart rationale as traefik/nginx |

**Gate Result**: ✅ PASS — No violations detected post-design.
