# Data Model: README Chart Catalog Update

**Feature**: 005-readme-chart-catalog-update  
**Date**: 2026-03-01

## Document Structure Mapping

This feature modifies a single file (README.md). The "data model" is the mapping between the authoritative chart registry (CHARTS.md + Chart.yaml files) and the README sections that reference them.

### Entity: Chart Entry

Each chart in the repository has the following attributes relevant to README documentation:

| Field | Source | Example (envoy-controller) |
|-------|--------|---------------------------|
| name | Chart.yaml `name` | envoy-controller |
| description | Chart.yaml `description` | Envoy Gateway controller — Gateway API-native, Envoy Proxy data plane |
| type | Chart.yaml `type` | application → "Controller" in README |
| directory | charts/{name}/ | charts/envoy-controller/ |
| supportsIngress | values.yaml `ingressController.enabled` | false |
| supportsGatewayApi | values.yaml `gatewayApi.enabled` or `gatewayClass.create` | true (native) |
| gatewayApiMode | Derived from defaults | native / opt-in / roadmap |

### Chart Registry (6 charts)

| Chart | Type | Ingress | Gateway API | README Link |
|-------|------|---------|-------------|-------------|
| common-lib | Library | N/A | N/A | charts/common-lib/ |
| web-app | Application | N/A | N/A | charts/web-app/ |
| traefik-controller | Controller | Yes (default) | Opt-in | charts/traefik-controller/ |
| nginx-controller | Controller | Yes (default) | Roadmap | charts/nginx-controller/ |
| envoy-controller | Controller | No | Native | charts/envoy-controller/ |
| kgateway-controller | Controller | No | Native | charts/kgateway-controller/ |

### README Sections to Update

| Section | Line Range (approx) | Change Type |
|---------|---------------------|-------------|
| Project Overview text block (§Overview) | Lines 8-20 | Add envoy-controller, kgateway-controller to tree |
| Ingress and Gateway API (§Overview) | Lines 24-30 | Expand Gateway API description |
| Prerequisites note | Line 43 | Add envoy-controller, kgateway-controller |
| Chart Catalog table | Lines 86-92 | Add 2 new rows |

### Validation Rules

- README Chart Catalog MUST have exactly as many chart rows as CHARTS.md
- Every chart directory under `charts/` MUST appear in both CHARTS.md and README Chart Catalog
- Gateway API references MUST list all controllers where `gatewayApiMode` is "native" or "opt-in"
