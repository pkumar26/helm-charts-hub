# Feature Specification: Controller Charts — Traefik & NGINX

**Feature Branch**: `002-controller-charts`
**Created**: 2026-02-19
**Status**: Draft
**Input**: Implement Traefik and NGINX ingress controller charts as described in 001-foundational-spec plan.md phases 6–9.

---

## 1. Overview

Add two ingress controller charts to the helm-charts-hub catalog:

- **traefik-controller** — Traefik v3 edge controller supporting Kubernetes Ingress and Gateway API modes
- **nginx-controller** — NGINX Ingress Controller (`ingress-nginx`) supporting Kubernetes Ingress mode

Both charts reuse `common-lib` for consistent metadata (labels, annotations, naming) while providing controller-specific templates for RBAC, IngressClass, multi-port services, and CRDs.

## 2. Goals

- Deploy Traefik as a cluster edge controller with Ingress and Gateway API support
- Deploy NGINX (`ingress-nginx`) as a cluster edge controller with Ingress support
- Reuse common-lib helpers for labels, annotations, naming, and service accounts
- Provide production-ready defaults (security context, RBAC, resource limits)
- Include CI test values, READMEs, environment overlays

## 3. Non-Goals

- Running `nginx-gateway-fabric` (Gateway API for NGINX) — documented as roadmap
- Traefik middleware CRDs (IngressRoute, etc.) — Traefik-specific CRDs beyond Gateway API
- Automatic TLS certificate management (cert-manager integration)

## 4. Acceptance Criteria

| Criteria | Chart |
|----------|-------|
| `helm lint` passes with zero errors | Both |
| `helm template` renders Deployment, Service, ServiceAccount, ClusterRole, ClusterRoleBinding, IngressClass | Both |
| All resources carry 6 base labels + 2 base annotations | Both |
| Traefik Gateway API resources only rendered when `gatewayApi.enabled: true` | Traefik |
| NGINX controller ConfigMap merges custom config | NGINX |
| RBAC grants minimum required permissions | Both |
| Service type LoadBalancer with correct ports | Both |
