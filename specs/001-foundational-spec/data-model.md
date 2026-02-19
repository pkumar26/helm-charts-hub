# Data Model: Helm Charts Hub

**Date**: 2026-02-19
**Spec**: [spec.md](spec.md)

---

## 1. Entity Relationship Overview

```
┌─────────────────────┐
│   Library Chart      │
│   (common-lib)       │
│ type: library        │
│ version: SemVer      │
├─────────────────────┤
│ Helper Templates:    │
│  _deployment.tpl     │
│  _service.tpl        │
│  _ingress.tpl        │
│  _hpa.tpl            │
│  _configmap.tpl      │
│  _secrets.tpl        │
│  _labels.tpl         │
│  _annotations.tpl    │
│  _podsecurity.tpl    │
│  _helpers.tpl        │
└────────┬────────────┘
         │ depended on by
         ▼
┌─────────────────────┐       ┌───────────────────────────┐
│  Application Chart   │◄──────│   Values File             │
│  (e.g., web-app)     │       │   (values.yaml, overlays) │
│ type: application    │       └───────────────────────────┘
│ depends: common-lib  │
├─────────────────────┤       ┌───────────────────────────┐
│ Templates:           │──────►│   Kubernetes Resources     │
│  deployment.yaml     │       │   Deployment, Service,     │
│  service.yaml        │       │   Ingress, HPA, ConfigMap, │
│  ingress.yaml        │       │   Secret, ServiceAccount   │
│  hpa.yaml            │       └───────────────────────────┘
│  configmap.yaml      │
│  serviceaccount.yaml │
│  NOTES.txt           │
└─────────────────────┘
         │
         │ documented in
         ▼
┌─────────────────────┐       ┌───────────────────────────┐
│   Per-Chart README   │       │   Chart Catalog (CHARTS.md)│
│   charts/<name>/     │◄──────│   Links to all READMEs     │
│   README.md          │       └───────────────────────────┘
└─────────────────────┘
```

---

## 2. Entities

### 2.1 Library Chart (common-lib)

| Field | Type | Description |
|-------|------|-------------|
| `apiVersion` | string | Always `v2` |
| `name` | string | `common-lib` |
| `type` | string | `library` |
| `version` | SemVer | Independent version, SemVer |
| `description` | string | Purpose of the library |

**Rules**:
- MUST NOT render standalone resources
- MUST expose named helper definitions prefixed `common-lib.*`
- Major version bump required for breaking helper signature changes

### 2.2 Application Chart

| Field | Type | Description |
|-------|------|-------------|
| `apiVersion` | string | Always `v2` |
| `name` | string | Chart name (e.g., `web-app`) |
| `type` | string | `application` |
| `version` | SemVer | Chart version |
| `appVersion` | string | Application version |
| `dependencies[].name` | string | `common-lib` |
| `dependencies[].version` | SemVer range | Version constraint (e.g., `>=0.1.0 <1.0.0`) |
| `dependencies[].repository` | string | `file://../common-lib` (local) or `oci://ghcr.io/<org>/charts` (CI) |

**Rules**:
- MUST declare dependency on common-lib
- MUST delegate standard resources to common-lib helpers
- MUST include values.yaml, README.md, CHANGELOG.md

### 2.3 Values File (Canonical Shape)

All application charts MUST use this canonical root structure:

| Key | Type | Default | Required | Description |
|-----|------|---------|----------|-------------|
| `workloadType` | string | `deployment` | YES | Initially: `deployment`. Future: `cronjob`, `worker` |
| `image.repository` | string | — | YES | Container image repository |
| `image.tag` | string | `""` | YES (validated) | Container image tag |
| `image.pullPolicy` | string | `IfNotPresent` | no | Image pull policy |
| `replicaCount` | int | `1` | no | Number of replicas |
| `service.type` | string | `ClusterIP` | no | Service type |
| `service.port` | int | `80` | no | Service port |
| `ingress.enabled` | bool | `false` | no | Enable Ingress resource |
| `ingress.className` | string | `""` | no | IngressClass name |
| `ingress.hosts` | list | `[]` | no | Ingress host rules |
| `ingress.tls` | list | `[]` | no | TLS configuration |
| `autoscaling.enabled` | bool | `false` | no | Enable HPA |
| `autoscaling.minReplicas` | int | `1` | no | HPA min replicas |
| `autoscaling.maxReplicas` | int | `10` | no | HPA max replicas |
| `autoscaling.targetCPUUtilizationPercentage` | int | `80` | no | HPA CPU target |
| `resources.requests.cpu` | string | `100m` | no | CPU request |
| `resources.requests.memory` | string | `128Mi` | no | Memory request |
| `resources.limits.cpu` | string | `500m` | no | CPU limit |
| `resources.limits.memory` | string | `256Mi` | no | Memory limit |
| `podSecurityContext.runAsNonRoot` | bool | `true` | no | Pod runs as non-root |
| `podSecurityContext.fsGroup` | int | `1000` | no | FS group |
| `securityContext.readOnlyRootFilesystem` | bool | `true` | no | Read-only root FS |
| `securityContext.runAsNonRoot` | bool | `true` | no | Container non-root |
| `securityContext.allowPrivilegeEscalation` | bool | `false` | no | Block privilege escalation |
| `serviceAccount.create` | bool | `true` | no | Create ServiceAccount |
| `serviceAccount.name` | string | `""` | no | SA name override |
| `serviceAccount.annotations` | map | `{}` | no | SA annotations |
| `nodeSelector` | map | `{}` | no | Node selector |
| `tolerations` | list | `[]` | no | Tolerations |
| `affinity` | map | `{}` | no | Affinity rules |
| `podAnnotations` | map | `{}` | no | Extra pod annotations |
| `podLabels` | map | `{}` | no | Extra pod labels |
| `labels` | map | `{}` | no | Extra resource labels |
| `annotations` | map | `{}` | no | Extra resource annotations |
| `extraEnv` | list | `[]` | no | Extra environment variables |
| `extraVolumes` | list | `[]` | no | Extra volumes |
| `extraVolumeMounts` | list | `[]` | no | Extra volume mounts |
| `livenessProbe` | map | (http /) | no | Liveness probe config |
| `readinessProbe` | map | (http /) | no | Readiness probe config |
| `global.annotationPrefix` | string | `platform.example.com` | no | Org annotation prefix |

**Validation Rules**:
- `image.repository` — MUST be present (template-level `required`)
- `workloadType` — MUST be one of `deployment`, `cronjob` (template-level `fail` for invalid)
- `image.tag` — MUST NOT be empty string (template-level `fail`)
- When `autoscaling.enabled: true`, `replicaCount` is initial only; HPA governs

### 2.4 Helper Template

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Definition name (e.g., `common-lib.deployment`) |
| `input` | context | Root context (`.`) or dict with `root` key |
| `output` | string | Rendered Kubernetes resource YAML |

**Helper catalog** (initial scope):

| Helper | Output Resource | Input Contract |
|--------|----------------|----------------|
| `common-lib.fullname` | string | Root context |
| `common-lib.chart` | string | Root context |
| `common-lib.labels` | label map YAML | `dict "root" . ["extraLabels" map]` |
| `common-lib.selectorLabels` | label map YAML | Root context |
| `common-lib.annotations` | annotation map YAML | `dict "root" . ["extraAnnotations" map]` |
| `common-lib.deployment` | Deployment YAML | `dict "root" . ["component" string]` |
| `common-lib.service` | Service YAML | `dict "root" . ["component" string]` |
| `common-lib.ingress` | Ingress YAML | `dict "root" . ["component" string]` |
| `common-lib.hpa` | HPA YAML | `dict "root" . ["component" string]` |
| `common-lib.configmap` | ConfigMap YAML | `dict "root" . "data" map` |
| `common-lib.secrets` | Secret YAML | `dict "root" . "data" map` |
| `common-lib.podsecurity` | SecurityContext YAML | Root context |
| `common-lib.serviceaccount` | ServiceAccount YAML | Root context |

### 2.5 Feature Flag

| Key Pattern | Type | Default | Behavior |
|-------------|------|---------|----------|
| `<feature>.enabled` | bool | `false` | When false, template produces no output |

**Current flags**: `ingress.enabled`, `autoscaling.enabled`, `serviceAccount.create`

### 2.6 Kubernetes Resource (Output)

Resources rendered by charts. All carry:
- **6 base labels**: `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/managed-by`, `app.kubernetes.io/part-of`, `helm.sh/chart`
- **2 base annotations**: `meta.helm.sh/release-name`, `meta.helm.sh/release-namespace`

**State transitions**: N/A (Helm manages resource lifecycle via install/upgrade/delete)

### 2.7 Documentation Entities

| Entity | Location | Required Sections |
|--------|----------|-------------------|
| Root README | `README.md` | Overview, Prerequisites, Install, Uninstall, Troubleshooting, links to Getting Started + Catalog |
| Getting Started | `docs/getting-started.md` | Ingress controller install, sample app deploy, verify, clean up |
| Per-Chart README | `charts/<name>/README.md` | Overview, Prerequisites, Installation, Configuration, Examples, Upgrade Notes, Troubleshooting |
| Chart Catalog | `CHARTS.md` | Table: chart name, description, workload types, link to README |
| README Template | `docs/templates/chart-readme.md` | Scaffold for new chart READMEs |
| CHANGELOG | `charts/<name>/CHANGELOG.md` | Added, Changed, Deprecated, Removed, Fixed, Security |

---

## 3. Dependency Graph

```
CHARTS.md ──references──► charts/web-app/README.md
                           charts/common-lib/README.md

README.md ──links──► docs/getting-started.md
                     CHARTS.md

charts/web-app/ ──depends──► charts/common-lib/
                 ──renders──► Deployment, Service, Ingress, HPA, ConfigMap, ServiceAccount

charts/common-lib/ ──provides──► Helper templates (no rendered resources)

.github/workflows/ ──uses──► ct (lint), helm (template, package, push), kind (install tests)
```
