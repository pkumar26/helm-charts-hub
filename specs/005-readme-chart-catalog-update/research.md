# Research: README Chart Catalog Update

**Feature**: 005-readme-chart-catalog-update  
**Date**: 2026-03-01

## Gap Analysis

### Current State of README.md

The root README.md has 4 sections with incomplete chart references:

| Section | Current State | Gap |
|---------|--------------|-----|
| Project Overview text block | Lists `web-app`, `traefik-controller`, `nginx-controller` | Missing `envoy-controller` and `kgateway-controller` |
| Architecture text block | Shows 3 children of common-lib | Missing `envoy-controller` and `kgateway-controller` |
| "Ingress and Gateway API" subsection | Only mentions Traefik for Gateway API | Missing envoy-controller and kgateway-controller as Gateway API-native controllers |
| Prerequisites note | Only mentions Traefik for Gateway API CRDs | Missing envoy-controller and kgateway-controller |
| Chart Catalog table | 4 rows | Missing `envoy-controller` and `kgateway-controller` rows |

### Current State of CHARTS.md (Authoritative Source)

CHARTS.md already lists all 6 charts correctly:

| Chart | Description | Type |
|-------|-------------|------|
| common-lib | Shared library chart | Library |
| web-app | General-purpose application chart | Application |
| traefik-controller | Traefik v3 edge controller — Ingress + Gateway API | Controller |
| nginx-controller | NGINX Ingress Controller — Ingress mode | Controller |
| envoy-controller | Envoy Gateway — Gateway API-native, Envoy Proxy data plane | Controller |
| kgateway-controller | kgateway — CNCF Gateway API implementation, Envoy proxy | Controller |

## Decisions

### Decision 1: Chart Catalog Table Entries

- **Decision**: Add envoy-controller and kgateway-controller to the README Chart Catalog table, using descriptions from CHARTS.md/Chart.yaml.
- **Rationale**: CHARTS.md is the authoritative source and already has both entries. README should mirror it.
- **Alternatives considered**: Only link to CHARTS.md from README — rejected because users expect to see the catalog inline without clicking through.

### Decision 2: Project Overview Updates

- **Decision**: Update the architecture text block to show all 4 controller charts as children of common-lib. Update the "Ingress and Gateway API" section to distinguish between Ingress-mode controllers (Traefik, NGINX) and Gateway API-native controllers (Envoy Gateway, kgateway) and dual-mode (Traefik).
- **Rationale**: The overview should give an accurate picture of the project's full scope. Gateway API is a key differentiator for envoy-controller and kgateway-controller.
- **Alternatives considered**: Keeping the overview minimal and just updating the table — rejected because the overview text and diagram are what give context before the table.

### Decision 3: Prerequisites Note

- **Decision**: Update the note to mention all 3 controllers that support Gateway API: Traefik (opt-in), Envoy Gateway (native), kgateway (native).
- **Rationale**: Users installing any of these controllers need to know about Gateway API CRDs.
- **Alternatives considered**: Leave the note as-is — rejected because it would be misleading for envoy/kgateway users.

## All NEEDS CLARIFICATION: Resolved

No unresolved clarifications — all information is available from existing Chart.yaml files, CHARTS.md, and chart READMEs.
