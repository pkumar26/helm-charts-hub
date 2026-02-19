# Implementation Plan: Helm Charts Hub — Foundational Specification

**Branch**: `001-foundational-spec` | **Date**: 2026-02-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-foundational-spec/spec.md`

## Summary

Build the foundational infrastructure for **helm-charts-hub**: a `common-lib` Helm library chart providing reusable helpers for Deployments, Services, Ingress, HPA, labels, annotations, and security contexts; one application chart (`web-app`) exercising the full pattern; GitHub Actions CI for linting, rendering, and OCI publishing to `ghcr.io`; and first-class documentation (root README, Getting Started guide, per-chart READMEs, chart catalog). Future phases extend the catalog with Traefik and NGINX controller charts supporting both Kubernetes Ingress and Gateway API.

## Technical Context

**Language/Version**: Helm 3.12+ (Go templates / Kubernetes YAML)
**Primary Dependencies**: Helm 3.12+, chart-testing (ct) 3.10+, helm-docs 1.14+, kind 0.20+
**Storage**: N/A
**Testing**: `helm lint`, `helm template`, `ct lint`, `ct install` (kind cluster), GitHub Actions
**Target Platform**: Kubernetes 1.26+
**Project Type**: Helm chart monorepo (library + application charts)
**Performance Goals**: Chart rendering (`helm template`) < 5 seconds per chart; < 15 resource objects per typical install
**Constraints**: OCI publishing to ghcr.io; offline rendering support (`helm template` without cluster); pod security defaults (`runAsNonRoot: true`, read-only root FS)
**Scale/Scope**: Initial release: 2 charts (`common-lib`, `web-app`). Future: Traefik controller, NGINX controller, additional app charts.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Constitution Section | Requirement | Status | Notes |
|---------------------|-------------|--------|-------|
| §2.1 Simplicity | Sensible defaults, no deep nesting | ✅ PASS | Defaults in values.yaml; helpers extract complexity |
| §2.2 Consistency | Identical naming, labeling, values conventions | ✅ PASS | Canonical values shape, common-lib enforces labels |
| §2.3 Modularity | Composable helpers, no copy-paste | ✅ PASS | common-lib library chart, `{{ include }}` pattern |
| §2.4 Flexibility | All behavior via values.yaml | ✅ PASS | Feature flags, layered values, configurable prefix |
| §2.5 Best Practices | Helm best practices, security contexts, probes | ✅ PASS | podsecurity helper, resource defaults, probe defaults |
| §3 Repo Structure | Standard folder layout | ✅ PASS | `charts/common-lib/`, `charts/web-app/`, docs/, etc. |
| §4 Library Design | type: library, prescribed helpers, dict signatures | ✅ PASS | See contracts/common-lib-helpers.md |
| §5 Configuration | Canonical values shape, backwards compat | ✅ PASS | See data-model.md §2.3 |
| §6 Labels/Annotations | 6 base labels, 2 base annotations, platform prefix | ✅ PASS | common-lib.labels, common-lib.annotations helpers |
| §7 Extensibility | Quality bar for new charts, library-first | ✅ PASS | README template, contribution checklist |
| §8 Testing/CI | helm lint, ct, optional kind install | ✅ PASS | See contracts/ci-workflows.md |
| §9 Documentation | README with 7 required sections | ✅ PASS | Per-chart README, root README, Getting Started |
| §10 Governance | PR review by maintainer, RFC for major changes | ✅ PASS | CONTRIBUTING.md, PR templates |
| §11 Versioning | SemVer, deprecation process, CHANGELOG | ✅ PASS | Independent versioning per chart |

**Post-Phase 1 re-check**: ✅ No violations found. Design aligns with all constitution sections.

## Project Structure

### Documentation (this feature)

```text
specs/001-foundational-spec/
├── plan.md              # This file
├── research.md          # Phase 0 output — technology research
├── data-model.md        # Phase 1 output — entity definitions, values schema
├── quickstart.md        # Phase 1 output — developer setup guide
├── contracts/           # Phase 1 output — interface contracts
│   ├── common-lib-helpers.md   # Helper template I/O contracts
│   ├── chart-schemas.md        # Chart.yaml schemas and versioning rules
│   └── ci-workflows.md         # CI pipeline contracts
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
helm-charts-hub/
├── charts/
│   ├── common-lib/                 # Helm library chart (type: library)
│   │   ├── Chart.yaml
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── _helpers.tpl        # fullname, chart name helpers
│   │       ├── _labels.tpl         # common-lib.labels, common-lib.selectorLabels
│   │       ├── _annotations.tpl    # common-lib.annotations
│   │       ├── _deployment.tpl     # common-lib.deployment
│   │       ├── _service.tpl        # common-lib.service
│   │       ├── _ingress.tpl        # common-lib.ingress
│   │       ├── _hpa.tpl            # common-lib.hpa
│   │       ├── _configmap.tpl      # common-lib.configmap
│   │       ├── _secrets.tpl        # common-lib.secrets
│   │       ├── _podsecurity.tpl    # common-lib.podsecurity
│   │       └── _serviceaccount.tpl # common-lib.serviceaccount
│   │
│   └── web-app/                    # Application chart
│       ├── Chart.yaml              # Declares dependency on common-lib
│       ├── README.md
│       ├── README.md.gotmpl        # helm-docs template
│       ├── CHANGELOG.md
│       ├── values.yaml
│       ├── templates/
│       │   ├── deployment.yaml     # {{ include "common-lib.deployment" ... }}
│       │   ├── service.yaml        # {{ include "common-lib.service" ... }}
│       │   ├── ingress.yaml        # {{ include "common-lib.ingress" ... }}
│       │   ├── hpa.yaml            # {{ include "common-lib.hpa" ... }}
│       │   ├── serviceaccount.yaml # {{ include "common-lib.serviceaccount" . }}
│       │   ├── _helpers.tpl        # Chart-specific overrides (if any)
│       │   └── NOTES.txt           # Post-install guidance
│       └── ci/                     # Test values for CI
│           ├── test-values.yaml    # Minimal values for ct install
│           └── test-ingress-values.yaml
│
├── docs/
│   ├── getting-started.md          # Getting Started guide (FR-030)
│   └── templates/
│       └── chart-readme.md         # README scaffold for new charts (FR-045)
│
├── examples/                       # Example values files
│   ├── web-app-minimal.yaml
│   └── web-app-production.yaml
│
├── .github/
│   ├── workflows/
│   │   ├── chart-lint-test.yaml    # PR gate: ct lint + optional ct install
│   │   └── chart-release.yaml      # Main push: package + OCI push
│   └── PULL_REQUEST_TEMPLATE.md
│
├── README.md                       # Root README (FR-025)
├── CHARTS.md                       # Chart catalog (FR-041)
├── CONTRIBUTING.md                 # Contribution guide
├── ct.yaml                         # chart-testing configuration
├── .helmignore                     # Global Helm ignore patterns
│
└── .specify/                       # Speckit configuration (existing)
    ├── memory/
    │   └── constitution.md
    ├── templates/
    └── scripts/
```

**Structure Decision**: Helm chart monorepo with `charts/` as the chart root directory. No `src/` or `tests/` directories — Helm charts are their own source and test structure. CI workflows live in `.github/workflows/`. Documentation is split between `docs/` (guides, templates) and co-located `README.md` files per chart.

## Complexity Tracking

No constitution violations. Table omitted.

---

## 1. Architecture and Repository Layout

### 1.1 Overall Architecture

The repository follows a **monorepo** pattern with all Helm charts under `charts/`. The architecture has two tiers:

1. **Library tier** — `charts/common-lib/` is a Helm library chart (`type: library`) that provides reusable helper templates. It cannot be installed on its own.
2. **Application tier** — `charts/web-app/` (and future charts) are installable application charts that declare a dependency on `common-lib` and delegate standard resource rendering to its helpers.

### 1.2 Dependency Declaration

Application charts declare their dependency on `common-lib` in `Chart.yaml`:

```yaml
# charts/web-app/Chart.yaml
dependencies:
  - name: common-lib
    version: ">=0.1.0 <1.0.0"
    repository: "file://../common-lib"
```

- **Local development**: `file://../common-lib` resolves the sibling directory. `helm dependency build charts/web-app` packages it into `charts/web-app/charts/common-lib-0.1.0.tgz`.
- **CI publishing**: `helm package charts/web-app` embeds the resolved dependency — the published `.tgz` is self-contained regardless of repository scheme.
- **Calling helpers**: Templates use `{{ include "common-lib.<helper>" <args> }}`.

### 1.3 Environment-Specific Values

Environment overlays are applied at deploy time, not stored in the chart package:

```text
environments/                       # OPTIONAL — example overlays
├── dev/
│   └── web-app.values.yaml         # replicaCount: 1, resources: minimal
├── staging/
│   └── web-app.values.yaml         # replicaCount: 2, ingress: staging host
└── production/
    └── web-app.values.yaml         # replicaCount: 3, ingress: prod host, HPA enabled
```

Usage: `helm install my-app oci://ghcr.io/<org>/charts/web-app --version 0.1.0 -f environments/production/web-app.values.yaml`

The `environments/` directory is provided as **examples** in the repo. Real environments may be managed externally (ArgoCD, FluxCD, or CI pipelines).

### 1.4 Additional Top-Level Directories

| Directory | Purpose |
|-----------|---------|
| `docs/` | Getting Started guide, README templates, architecture docs |
| `.specify/` | Speckit configuration (constitution, specs, templates, scripts) |
| `.github/` | GitHub Actions workflows, PR templates |
| `examples/` | Example values files referenced by chart READMEs |

---

## 2. Technology Choices

### 2.1 Core Tooling

| Technology | Version | Purpose |
|------------|---------|---------|
| **Helm** | ≥ 3.12 | Chart packaging, templating, OCI publishing |
| **Kubernetes** | ≥ 1.26 | Target platform |
| **Go templates** | (built into Helm) | Template language for chart resources |
| **GitHub Actions** | — | CI/CD platform |
| **chart-testing (ct)** | ≥ 3.10 | Monorepo chart linting and install testing |
| **kind** | ≥ 0.20 | Disposable Kubernetes clusters for CI install tests |
| **helm-docs** | ≥ 1.14 | README configuration table generation |
| **yamllint** | ≥ 1.35 | YAML linting (used by ct) |

### 2.2 Kubernetes APIs

| API | Version | Usage | Status |
|-----|---------|-------|--------|
| `apps/v1` | Deployment | Core workload | Stable, GA |
| `batch/v1` | CronJob | Scheduled workloads | Stable, GA |
| `v1` | Service, ConfigMap, Secret, ServiceAccount | Core resources | Stable, GA |
| `networking.k8s.io/v1` | Ingress | Traffic routing (current baseline) | Stable, GA |
| `autoscaling/v2` | HPA | Horizontal scaling | Stable, GA |
| `gateway.networking.k8s.io/v1` | HTTPRoute, Gateway, GatewayClass | Traffic routing (future) | GA since Gateway API v1.0 |

### 2.3 Ingress vs Gateway API Strategy

- **Phase 1–4 (initial release)**: Ingress only. The `common-lib.ingress` helper renders `networking.k8s.io/v1` Ingress resources.
- **Phase 5+**: Add `common-lib.httproute` helper for Gateway API `HTTPRoute` resources. `Gateway` and `GatewayClass` are cluster-scoped infrastructure managed by platform teams — they are NOT templated in `common-lib`.
- **Controller charts** (Traefik, NGINX): future phases. The Getting Started guide uses upstream controller charts (e.g., `traefik/traefik`, `ingress-nginx/ingress-nginx`) until custom controller charts are built.

### 2.4 Chart Distribution

| Aspect | Decision |
|--------|----------|
| Registry | GitHub Container Registry (`ghcr.io`) |
| Format | OCI artifacts |
| Install command | `helm install <release> oci://ghcr.io/<org>/charts/<name> --version <ver>` |
| Pull command | `helm pull oci://ghcr.io/<org>/charts/<name> --version <ver>` |
| Authentication | `GITHUB_TOKEN` with `packages: write` in GitHub Actions |
| Visibility | Public (must be set manually in GitHub Package Settings after first push) |

### 2.5 Constraints

| Constraint | Detail |
|------------|--------|
| Kubernetes ≥ 1.26 | Requires `networking.k8s.io/v1` Ingress, `autoscaling/v2` HPA |
| Helm ≥ 3.12 | OCI support stable; `helm push` available |
| Offline rendering | `helm template` must work without cluster access |
| No hard-coded secrets | Secrets via values or external secret managers |
| Non-`latest` image tags | `image.tag` is validated as non-empty |
| Gateway API CRDs | Not assumed to be installed; only used when controller charts enable it |

---

## 3. Common-Lib Chart Design

### 3.1 Chart Declaration

```yaml
# charts/common-lib/Chart.yaml
apiVersion: v2
name: common-lib
description: Reusable Helm library chart — standard helpers for Deployments, Services, Ingress, HPA, labels, annotations, and security contexts.
type: library
version: 0.1.0
```

### 3.2 Helper Template Catalog

See [contracts/common-lib-helpers.md](contracts/common-lib-helpers.md) for full I/O contracts.

| Helper | File | Output | guard |
|--------|------|--------|-------|
| `common-lib.fullname` | `_helpers.tpl` | Resource name string | — |
| `common-lib.chart` | `_helpers.tpl` | Chart label string | — |
| `common-lib.labels` | `_labels.tpl` | 6 base labels + extras | — |
| `common-lib.selectorLabels` | `_labels.tpl` | 2 immutable selector labels | — |
| `common-lib.annotations` | `_annotations.tpl` | 2 base annotations + extras | — |
| `common-lib.deployment` | `_deployment.tpl` | Full Deployment YAML | `workloadType == "deployment"` |
| `common-lib.service` | `_service.tpl` | Full Service YAML | `workloadType == "deployment"` |
| `common-lib.ingress` | `_ingress.tpl` | Full Ingress YAML | `ingress.enabled` |
| `common-lib.hpa` | `_hpa.tpl` | Full HPA YAML | `autoscaling.enabled` |
| `common-lib.configmap` | `_configmap.tpl` | Full ConfigMap YAML | data dict non-empty |
| `common-lib.secrets` | `_secrets.tpl` | Full Secret YAML | data dict non-empty |
| `common-lib.podsecurity` | `_podsecurity.tpl` | Security context YAML fragment | — |
| `common-lib.serviceaccount` | `_serviceaccount.tpl` | Full ServiceAccount YAML | `serviceAccount.create` |

### 3.3 Helper Signature Pattern

All resource-generating helpers use the **dict pattern**:

```yaml
# Application chart template (e.g., charts/web-app/templates/deployment.yaml)
{{- include "common-lib.deployment" (dict "root" .) }}
```

Metadata-only helpers accept root context directly:

```yaml
# Inside a custom template
metadata:
  labels:
    {{- include "common-lib.labels" (dict "root" .) | nindent 4 }}
```

The dict pattern allows future extension (e.g., passing `"component"` for multi-component charts) without breaking existing callers.

### 3.4 How Controller Charts Will Reuse common-lib

When Traefik/NGINX controller charts are added (Phases 5–7), they will:

1. Declare `common-lib` as a dependency (same as `web-app`)
2. Use `common-lib.deployment`, `common-lib.service`, `common-lib.labels`, `common-lib.annotations` for their core resources
3. Define **additional templates** for controller-specific resources:
   - Traefik: `IngressRoute` (Traefik CRD), `GatewayClass`, `Gateway` (Gateway API)
   - NGINX: controller-specific ConfigMap, `IngressClass`, `GatewayClass` (Gateway API via nginx-gateway-fabric)
4. These controller-specific templates still call `common-lib.labels` and `common-lib.annotations` to ensure consistent metadata

### 3.5 Versioning and Compatibility

| Rule | Policy |
|------|--------|
| Breaking helper signature change | Major version bump, migration docs in CHANGELOG |
| New helper added | Minor version bump |
| Bug fix in existing helper | Patch version bump |
| Application chart pins | `>=0.1.0 <1.0.0` (all 0.x releases accepted) |
| Independent release | common-lib version NOT bumped by web-app changes |

---

## 4. Initial Chart: web-app

### 4.1 Purpose

`web-app` is the initial application chart demonstrating the full `common-lib` integration pattern. It deploys a generic HTTP service (Deployment + Service) with optional Ingress, HPA, and ConfigMap support.

### 4.2 Values Schema

See [data-model.md](data-model.md) §2.3 for the complete canonical values shape.

Key values groups:
- **Core**: `image.*`, `replicaCount`, `workloadType`, `resources`
- **Networking**: `service.*`, `ingress.*`
- **Scaling**: `autoscaling.*`
- **Security**: `podSecurityContext`, `securityContext`
- **Scheduling**: `nodeSelector`, `tolerations`, `affinity`
- **Extensions**: `extraEnv`, `extraVolumes`, `extraVolumeMounts`
- **Metadata**: `labels`, `podLabels`, `annotations`, `podAnnotations`, `global.annotationPrefix`
- **Identity**: `serviceAccount.*`

### 4.3 Template Structure

Each template file is a thin wrapper around a `common-lib` helper:

```yaml
# charts/web-app/templates/deployment.yaml
{{- include "common-lib.deployment" (dict "root" .) }}

# charts/web-app/templates/service.yaml
{{- include "common-lib.service" (dict "root" .) }}

# charts/web-app/templates/ingress.yaml
{{- include "common-lib.ingress" (dict "root" .) }}

# charts/web-app/templates/hpa.yaml
{{- include "common-lib.hpa" (dict "root" .) }}

# charts/web-app/templates/serviceaccount.yaml
{{- include "common-lib.serviceaccount" . }}
```

### 4.4 Acceptance Criteria

| Criteria | Verification |
|----------|-------------|
| `helm lint charts/web-app` passes with zero errors | CI gate |
| `helm template` renders Deployment + Service with defaults | CI gate |
| All resources carry 6 base labels + 2 base annotations | Automated grep in CI |
| `ingress.enabled: false` → no Ingress resource | Template diff test |
| `ingress.enabled: true` → valid Ingress resource | Template rendering |
| `autoscaling.enabled: true` → HPA resource | Template rendering |
| Missing `image.repository` → clear error | `helm template` failure test |
| Invalid `workloadType` → clear error | `helm template` failure test |
| Install on kind cluster with nginx image → healthy pods | ct install (advisory) |

---

## 5. Future Charts: Traefik Controller (Phases 6–7)

> **Note**: This section documents the planned design for the Traefik controller chart, to be implemented after the initial release (Phases 1–5).

### 5.1 Goals

Deploy Traefik as a cluster-level edge controller supporting:
- **Ingress mode**: Kubernetes Ingress resources (`networking.k8s.io/v1`)
- **Gateway API mode**: Traefik's `kubernetesGateway` provider (`GatewayClass`, `Gateway`, `HTTPRoute`)

### 5.2 Planned Values Schema

```yaml
# Core (from common-lib canonical shape)
image:
  repository: traefik
  tag: "v3.x"
replicaCount: 1
service:
  type: LoadBalancer
  ports:
    web: 80
    websecure: 443
resources: { ... }

# Traefik-specific
providers:
  kubernetesIngress:
    enabled: true       # Ingress controller mode
  kubernetesGateway:
    enabled: false      # Gateway API mode (Phase 5)

dashboard:
  enabled: false
  ingress:
    enabled: false

metrics:
  prometheus:
    enabled: false

tls:
  enabled: false
  certResolver: ""

# Feature flags
ingressController:
  enabled: true         # Manage classic Ingress resources
gatewayApi:
  enabled: false        # Enable Gateway provider, GatewayClass, Gateway
  gatewayClass:
    name: traefik
  gateway:
    name: traefik-gateway
    listeners:
      - name: http
        port: 80
        protocol: HTTP
```

### 5.3 common-lib Usage

- `common-lib.deployment` for the Traefik Deployment
- `common-lib.service` for the LoadBalancer Service
- `common-lib.labels` / `common-lib.annotations` for all resources
- **Chart-specific templates**: `GatewayClass`, `Gateway`, `IngressClass`, Traefik middleware CRDs

### 5.4 Acceptance Criteria

| Criteria | Mode |
|----------|------|
| Ingress mode: Routes HTTP(S) traffic to a sample Service via Ingress resource | Ingress |
| Gateway mode: Routes traffic via Gateway + HTTPRoute pair | Gateway API |
| Both modes can be enabled simultaneously | Dual |
| `gatewayApi.enabled: false` → no Gateway API resources rendered | Feature flag |
| Traefik pods become Ready within 60 seconds | Both |

---

## 6. Future Charts: NGINX Controller (Phases 8–9)

> **Note**: This section documents the planned design for the NGINX controller chart, to be implemented after the Traefik controller (Phase 7+).

### 6.1 Goals

Deploy an NGINX-based edge controller initially as a Kubernetes Ingress controller, with a clear path to Gateway API support.

### 6.2 Key Design Decision

Two separate projects exist in the NGINX ecosystem:
- **`ingress-nginx`** — Ingress-only controller (no Gateway API plans)
- **`nginx-gateway-fabric`** — Purpose-built Gateway API implementation

**Decision**: Start with `ingress-nginx` as the Ingress controller. For Gateway API, recommend `nginx-gateway-fabric` as a separate chart or chart mode, rather than bolting Gateway API onto `ingress-nginx`.

### 6.3 Planned Values Schema

```yaml
# Core (from common-lib canonical shape)
image:
  repository: registry.k8s.io/ingress-nginx/controller
  tag: "v1.x"
replicaCount: 1
service:
  type: LoadBalancer
resources: { ... }

# NGINX-specific
ingressController:
  enabled: true
  ingressClassName: nginx
  config: {}            # NGINX ConfigMap overrides

# Future
gatewayApi:
  enabled: false        # Reserved for future nginx-gateway-fabric integration
```

### 6.4 Acceptance Criteria

| Criteria | Mode |
|----------|------|
| Exposes sample HTTP service via NGINX Ingress | Ingress |
| Configurable host and TLS | Ingress |
| Placeholder values for Gateway API documented | Roadmap |

---

## 7. Environment Configuration Strategy

### 7.1 Values Layering

Helm merges values files left-to-right. The project supports three layers:

```
[chart defaults]  ←  [environment overlay]  ←  [runtime --set flags]
   values.yaml        environments/<env>/        CI/CD pipeline
```

### 7.2 Example Environment Files

```yaml
# environments/dev/web-app.values.yaml
replicaCount: 1
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
ingress:
  enabled: false

# environments/production/web-app.values.yaml
replicaCount: 3
resources:
  requests:
    cpu: 500m
    memory: 256Mi
  limits:
    cpu: "1"
    memory: 512Mi
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: app-tls
      hosts:
        - app.example.com
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
```

### 7.3 Secrets Management

- Charts MUST NOT contain hard-coded secrets (Constitution §2.5, Spec §6.3)
- Secrets are provided via:
  - `--set` flags from CI/CD with secret values from vault/environment
  - External Secrets Operator (ESO) syncing from a secrets manager to Kubernetes Secrets
  - Sealed Secrets (encrypted Secrets committed to Git)
- The chart's `common-lib.secrets` helper templates a Kubernetes Secret from values, but the actual secret data is injected at deploy time

### 7.4 Environment Patterns

| Aspect | Dev | Staging | Production |
|--------|-----|---------|------------|
| Replicas | 1 | 2 | 3+ (HPA) |
| Resources | Minimal | Moderate | Full |
| Ingress | Disabled | Enabled (staging host) | Enabled (prod host + TLS) |
| HPA | Disabled | Disabled | Enabled |
| Metrics | Disabled | Enabled | Enabled |
| Debug | Enabled | Disabled | Disabled |

---

## 8. CI/CD and Quality Gates

### 8.1 Pipeline Overview

See [contracts/ci-workflows.md](contracts/ci-workflows.md) for full pipeline contracts.

```
PR opened → chart-lint-test.yaml
  ├── ct lint (BLOCKING)
  ├── helm template rendering (BLOCKING)
  └── ct install on kind (ADVISORY)

Merge to main → chart-release.yaml
  ├── helm package common-lib → helm push to ghcr.io
  └── helm package web-app → helm push to ghcr.io
```

### 8.2 Lint and Test Workflow (PR Gate)

```yaml
# .github/workflows/chart-lint-test.yaml
name: Lint and Test Charts
on:
  pull_request:
    paths: ['charts/**']

jobs:
  lint-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: azure/setup-helm@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.x' }
      - uses: helm/chart-testing-action@v2
      - name: List changed charts
        id: list
        run: |
          changed=$(ct list-changed --target-branch ${{ github.event.repository.default_branch }})
          [[ -n "$changed" ]] && echo "changed=true" >> "$GITHUB_OUTPUT"
      - name: Lint
        if: steps.list.outputs.changed == 'true'
        run: ct lint --target-branch ${{ github.event.repository.default_branch }}
      - name: Create kind cluster
        if: steps.list.outputs.changed == 'true'
        uses: helm/kind-action@v1
      - name: Install test
        if: steps.list.outputs.changed == 'true'
        continue-on-error: true   # advisory-only (FR-023)
        run: ct install --target-branch ${{ github.event.repository.default_branch }}
```

### 8.3 Release Workflow (OCI Publish)

```yaml
# .github/workflows/chart-release.yaml
name: Release Charts
on:
  push:
    branches: [main]
    paths: ['charts/**']
permissions:
  contents: read
  packages: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v4
      - name: Login to GHCR
        run: echo "${{ secrets.GITHUB_TOKEN }}" | helm registry login ghcr.io -u "${{ github.actor }}" --password-stdin
      - name: Package and push common-lib
        run: |
          helm package charts/common-lib
          helm push common-lib-*.tgz oci://ghcr.io/${{ github.repository_owner }}/charts
      - name: Package and push web-app
        run: |
          helm dependency build charts/web-app
          helm package charts/web-app
          helm push web-app-*.tgz oci://ghcr.io/${{ github.repository_owner }}/charts
```

### 8.4 Versioning and Release Flow

| Rule | Implementation |
|------|---------------|
| SemVer per chart | `version:` in each `Chart.yaml` |
| common-lib independent | Push only when `charts/common-lib/` changes |
| Version check | `ct lint` with `check-version-increment: true` |
| CHANGELOG required | Each chart maintains `CHANGELOG.md` |
| Tag convention | OCI tag = chart version (e.g., `ghcr.io/<org>/charts/web-app:0.1.0`) |

### 8.5 Documentation CI (Advisory)

- Run `helm-docs --chart-search-root charts --dry-run` and diff against committed READMEs
- Check every `charts/*/` has a `README.md`
- Check `CHARTS.md` lists every chart directory
- Check required sections present in each README

---

## 9. Documentation and Setup Experience

### 9.1 Root README (`README.md`)

**Sections** (per FR-026):
1. **Project Overview** — What helm-charts-hub is, architecture diagram (common-lib → app charts), Ingress vs Gateway API roadmap
2. **Prerequisites** — Helm ≥ 3.12, Kubernetes ≥ 1.26, kubectl, note on Ingress vs Gateway API
3. **Quick Start** — Link to `docs/getting-started.md`
4. **Install a Chart** — OCI install command: `helm install my-app oci://ghcr.io/<org>/charts/web-app --version 0.1.0 --set image.repository=<image> --set image.tag=<tag>`
5. **Uninstall a Chart** — `helm uninstall my-app`
6. **Chart Catalog** — Link to `CHARTS.md`
7. **Troubleshooting** — OCI pull failures, image pull errors, values validation errors, namespace not found
8. **Contributing** — Link to `CONTRIBUTING.md`

### 9.2 Getting Started Guide (`docs/getting-started.md`)

**Flow** (per FR-030–FR-033):
1. Prerequisites check (Helm, kubectl, kind/minikube)
2. Create a local kind cluster
3. Install an ingress controller (commands for both Traefik and NGINX using upstream charts)
4. Install the `web-app` chart with a sample nginx image
5. Verify: `kubectl get pods`, `kubectl get svc`, `curl` test
6. (Optional) Enable ingress and verify HTTP routing
7. Clean up: `helm uninstall`, `kind delete cluster`

Target: 5 minutes from start to running sample app (SC-009).

### 9.3 Per-Chart README

Each chart has a `README.md` with **7 required sections** (Constitution §9.2):
1. Overview
2. Prerequisites
3. Installation (with OCI commands)
4. Configuration (parameters table — generated by `helm-docs`)
5. Examples (minimal + production snippets)
6. Upgrade Notes (migration steps per major version, or "Initial release — no prior versions")
7. Troubleshooting

**`common-lib` README** additionally documents each helper definition, inputs, and usage examples (Constitution §4.4).

### 9.4 Chart Catalog (`CHARTS.md`)

```markdown
# Chart Catalog

| Chart | Description | Workload Types | README |
|-------|-------------|---------------|--------|
| [common-lib](charts/common-lib/) | Shared library chart — reusable helpers | N/A (library) | [README](charts/common-lib/README.md) |
| [web-app](charts/web-app/) | General-purpose application chart | Deployment, CronJob | [README](charts/web-app/README.md) |
```

Updated with every PR that adds, deprecates, or removes a chart (FR-043).

### 9.5 Documentation Tooling

| Tool | Purpose | Integration |
|------|---------|-------------|
| `helm-docs` | Generate configuration tables from `values.yaml` | `make docs`, CI check |
| `README.md.gotmpl` | Per-chart README template for helm-docs | Each chart directory |
| `docs/templates/chart-readme.md` | Scaffold for new chart authors | Manual copy |
| `NOTES.txt` | Post-install Helm output | Each application chart |

---

## 10. Phased Implementation Plan

### Phase 1: Repository Bootstrap and common-lib (Week 1)

**Deliverables**:
- Repository scaffold: `charts/common-lib/`, `docs/`, `.github/workflows/`, `ct.yaml`
- `common-lib` Chart.yaml (`type: library`, v0.1.0)
- Metadata helpers: `_helpers.tpl` (fullname, chart), `_labels.tpl` (6 base labels, selector labels), `_annotations.tpl` (2 base annotations)
- Core resource helpers: `_deployment.tpl`, `_service.tpl`, `_podsecurity.tpl`, `_serviceaccount.tpl`
- `common-lib` values.yaml with canonical defaults
- `common-lib` README documenting all helpers
- `common-lib` CHANGELOG.md (initial release)
- Minimal root README (project overview, prerequisites, basic structure)
- `CONTRIBUTING.md` (contribution workflow, library-first approach)

**Risks**: None — foundational work with no external dependencies.

**Dependencies**: None.

### Phase 2: web-app Chart (Week 2)

**Deliverables**:
- `charts/web-app/` with Chart.yaml declaring `common-lib` dependency
- Templates: `deployment.yaml`, `service.yaml`, `serviceaccount.yaml` delegating to common-lib
- `values.yaml` with full canonical shape (image, replicas, resources, service, security, scheduling, etc.)
- Template-level validation: `image.repository` required, `image.tag` non-empty, `workloadType` valid
- `NOTES.txt` with post-install guidance
- `web-app` README with all 7 required sections
- `web-app` CHANGELOG.md (initial release)
- `README.md.gotmpl` for helm-docs
- `helm lint` and `helm template` pass

**Risks**: Low — standard Helm chart, building on proven common-lib helpers.

**Dependencies**: Phase 1 (common-lib must exist).

### Phase 3: Optional Features — Ingress, HPA, ConfigMap (Week 2–3)

**Deliverables**:
- `common-lib` additions: `_ingress.tpl`, `_hpa.tpl`, `_configmap.tpl`, `_secrets.tpl`
- `web-app` additions: `ingress.yaml`, `hpa.yaml` template wrappers
- Feature flags: `ingress.enabled`, `autoscaling.enabled`, `serviceAccount.create`
- Values additions: `ingress.*`, `autoscaling.*`, `extraEnv`, `extraVolumes`, `extraVolumeMounts`
- Example values files: `examples/web-app-minimal.yaml`, `examples/web-app-production.yaml`
- CI test values: `charts/web-app/ci/test-values.yaml`, `test-ingress-values.yaml`
- Bump common-lib to v0.2.0 (new helpers = minor bump)
- Update web-app values.yaml, README configuration table, examples

**Risks**: `ingress.enabled: false` must produce zero diff vs Phase 2 output (SC-005). Need template diff test.

**Dependencies**: Phase 2 (web-app must exist to consume new helpers).

### Phase 4: CI/CD Pipelines and Documentation (Week 3–4)

**Deliverables**:
- `.github/workflows/chart-lint-test.yaml` — PR gate (ct lint, helm template, advisory ct install)
- `.github/workflows/chart-release.yaml` — main push (OCI publish to ghcr.io)
- `ct.yaml` configuration
- `docs/getting-started.md` — full Getting Started guide (kind cluster, upstream ingress controller, web-app install, verify, clean up)
- Root `README.md` — complete with all sections (FR-026)
- `CHARTS.md` — chart catalog with both charts
- `docs/templates/chart-readme.md` — README scaffold for new charts
- `.github/PULL_REQUEST_TEMPLATE.md` — PR checklist
- `helm-docs` integration (README.md.gotmpl, make target, CI advisory check)

**Risks**:
- GHCR package visibility must be set to public after first push
- `ct install` may fail on first run if kind cluster setup is slow — mitigated by advisory-only policy

**Dependencies**: Phases 1–3 (charts must exist for CI to lint/test).

### Phase 5: Environment Examples and Hardening (Week 4)

**Deliverables**:
- `environments/dev/web-app.values.yaml`
- `environments/staging/web-app.values.yaml`
- `environments/production/web-app.values.yaml`
- Optional: `values.schema.json` for web-app (SHOULD, not MUST per FR-024)
- Documentation CI advisory checks (README presence, CHARTS.md sync, helm-docs freshness)
- End-to-end validation: fresh kind cluster, install web-app, verify labels/annotations, test ingress

**Risks**: Low — refinement phase.

**Dependencies**: Phase 4 (CI and docs must be in place).

### Phase 6: Traefik Controller Chart — Ingress Mode (Future)

**Deliverables**:
- `charts/traefik-controller/` — application chart using common-lib
- Traefik Deployment, Service (LoadBalancer), IngressClass
- Values schema: `providers.kubernetesIngress.enabled`, `dashboard`, `metrics`, `tls`
- Feature flag: `ingressController.enabled: true`
- Per-chart README, CHANGELOG, NOTES.txt
- CI lint/test for Traefik in Ingress mode
- Update `CHARTS.md` and root README

**Risks**:
- Traefik CRDs (middlewares, IngressRoute) if used alongside standard Ingress
- Upstream Traefik Helm chart overlap — decide whether to wrap upstream or build from scratch

**Dependencies**: Phase 5 complete (stable common-lib and CI).

### Phase 7: Traefik Gateway API Support (Future)

**Deliverables**:
- `gatewayApi.enabled` path in `traefik-controller`
- Configure `kubernetesGateway` provider
- Optional `GatewayClass` and default `Gateway` resources
- Example `HTTPRoute` manifests in `examples/`
- `common-lib` v0.3.0: add `_httproute.tpl` helper (optional, for app charts)
- Update Getting Started guide with Gateway examples
- CI: render Traefik in both Ingress and Gateway mode

**Risks**:
- Gateway API CRDs must be installed on cluster (not always present)
- Dual Ingress + Gateway mode requires careful RBAC
- `common-lib.httproute` must be controller-agnostic (HTTPRoute is standardized, but edge cases exist)

**Dependencies**: Phase 6 (Traefik Ingress mode must work first). Gateway API CRDs available on test clusters.

### Phase 8: NGINX Controller Chart — Ingress Mode (Future)

**Deliverables**:
- `charts/nginx-controller/` — application chart using common-lib
- NGINX Ingress Controller Deployment, Service. IngressClass
- Values schema aligned with Traefik where practical
- `ingressController.enabled: true`
- Per-chart README, CHANGELOG, NOTES.txt
- CI coverage for NGINX in Ingress mode
- Update `CHARTS.md`

**Risks**:
- `ingress-nginx` has no Gateway API support — Gateway API requires `nginx-gateway-fabric` (separate project)
- Deciding between wrapping upstream chart vs building custom

**Dependencies**: Phase 5 (stable common-lib and CI); can be parallel with Phase 6.

### Phase 9: NGINX Gateway Roadmap and Documentation Hardening (Future)

**Deliverables**:
- Decision: extend `nginx-controller` with Gateway mode OR create `nginx-gateway` chart
- Placeholder values and documentation for Gateway migration
- Architecture Decision Record (ADR) documenting the choice
- Finalize all READMEs, migration guides
- Comprehensive CI: lint, render, install for all charts in all modes
- Central catalog fully up to date

**Risks**:
- `nginx-gateway-fabric` is a fundamentally different deployment from `ingress-nginx`
- May require a separate chart rather than a mode toggle

**Dependencies**: Phase 8 (NGINX Ingress must be stable). Phase 7 (Gateway API patterns established with Traefik).
