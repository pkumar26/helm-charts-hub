# Contract: Istio Chart Structure and Dependencies

**Feature**: 007-istio-aks-chart  
**Contract Type**: Chart Architecture  
**Date**: 2026-05-20

## Purpose

This contract defines the structure, dependencies, and relationships between the three Istio Helm charts: base, istiod, and gateway.

---

## Chart Structure Contract

### Directory Layout

```
charts/istio/
├── base/
│   ├── Chart.yaml               # v1.0.0, type: application
│   ├── README.md
│   ├── values.yaml              # Default values (all environments)
│   ├── values-dev.yaml          # Development overrides
│   ├── values-staging.yaml      # Staging overrides
│   ├── values-prod.yaml         # Production overrides (FIPS + security)
│   └── templates/
│       ├── namespace.yaml       # istio-system namespace
│       ├── _helpers.tpl         # Common template helpers
│       └── crds/                # Istio CRD manifests
│           ├── gateway.yaml
│           ├── virtualservice.yaml
│           ├── destinationrule.yaml
│           ├── serviceentry.yaml
│           ├── peerauthentication.yaml
│           └── authorizationpolicy.yaml
│
├── istiod/
│   ├── Chart.yaml               # v1.0.0, type: application, depends on upstream istiod
│   ├── README.md
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-staging.yaml
│   ├── values-prod.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── peerauthentication.yaml      # Mesh-wide mTLS policy
│       ├── authorizationpolicy.yaml     # Control plane access control
│       └── networkpolicy.yaml           # Control plane network isolation
│
└── gateway/
    ├── Chart.yaml               # v1.0.0, type: application, depends on upstream gateway
    ├── README.md
    ├── values.yaml
    ├── values-dev.yaml
    ├── values-staging.yaml
    ├── values-prod.yaml
    └── templates/
        ├── _helpers.tpl
        ├── gateway.yaml                 # Istio Gateway resource
        ├── peerauthentication.yaml      # Gateway mTLS policy
        ├── authorizationpolicy.yaml     # Gateway access control
        └── networkpolicy.yaml           # Gateway network isolation
```

---

## Chart.yaml Contracts

### Base Chart

```yaml
apiVersion: v2
name: istio-base
description: Istio base chart containing CRDs and cluster-wide resources for AKS
type: application
version: 1.0.0
appVersion: "1.23.0"
keywords:
  - istio
  - service-mesh
  - aks
  - azure
  - crds
home: https://github.com/pkumar26/helm-charts-hub
sources:
  - https://github.com/istio/istio
maintainers:
  - name: Platform Team
icon: https://istio.io/latest/img/istio-bluelogo-whitebackground-unframed.svg
```

**Guarantees:**
- ✅ No dependencies on other charts
- ✅ Idempotent (can be upgraded without breaking existing resources)
- ✅ CRDs are additive (no field removals)
- ✅ Creates `istio-system` namespace if it doesn't exist

### istiod Chart

```yaml
apiVersion: v2
name: istio-istiod
description: Istio control plane (istiod) for AKS with FIPS and security baseline
type: application
version: 1.0.0
appVersion: "1.23.0"
keywords:
  - istio
  - service-mesh
  - control-plane
  - aks
  - fips
home: https://github.com/pkumar26/helm-charts-hub
sources:
  - https://github.com/istio/istio
maintainers:
  - name: Platform Team
dependencies:
  - name: istiod
    version: "1.23.0"
    repository: "https://istio-release.storage.googleapis.com/charts"
```

**Guarantees:**
- ✅ Depends on upstream Istio `istiod` chart via Helm dependencies
- ✅ Requires `istio-base` to be installed first (CRDs must exist)
- ✅ Merges our security baseline values with upstream defaults
- ✅ Supports canary upgrades (multiple revisions running simultaneously)

### gateway Chart

```yaml
apiVersion: v2
name: istio-gateway
description: Istio ingress gateway for AKS with FIPS and security baseline
type: application
version: 1.0.0
appVersion: "1.23.0"
keywords:
  - istio
  - service-mesh
  - ingress-gateway
  - aks
  - fips
home: https://github.com/pkumar26/helm-charts-hub
sources:
  - https://github.com/istio/istio
maintainers:
  - name: Platform Team
dependencies:
  - name: gateway
    version: "1.23.0"
    repository: "https://istio-release.storage.googleapis.com/charts"
```

**Guarantees:**
- ✅ Depends on upstream Istio `gateway` chart via Helm dependencies
- ✅ Requires `istiod` to be healthy before gateway can start
- ✅ Supports multiple gateway instances (different release names)
- ✅ Azure LoadBalancer integration with health probes

---

## Installation Sequence Contract

### Mandatory Order

```
1. istio-base      (CRDs)
   ↓
2. istiod          (control plane, wait for ready)
   ↓
3. gateway         (ingress gateway, wait for ready)
```

### Commands

```bash
# Step 1: Install base (CRDs)
helm install istio-base charts/istio/base \
  --namespace istio-system \
  --create-namespace \
  -f charts/istio/base/values-prod.yaml

# Verify CRDs are created
kubectl get crds | grep istio.io

# Step 2: Install istiod (control plane)
helm install istiod charts/istio/istiod \
  --namespace istio-system \
  -f charts/istio/istiod/values-prod.yaml \
  --wait \
  --timeout 10m

# Verify istiod is healthy
kubectl get pods -n istio-system -l app=istiod
kubectl get validatingwebhookconfiguration istiod-istio-system
istioctl verify-install

# Step 3: Install gateway (ingress)
helm install istio-ingressgateway charts/istio/gateway \
  --namespace istio-system \
  -f charts/istio/gateway/values-prod.yaml \
  --wait \
  --timeout 10m

# Verify gateway is healthy
kubectl get pods -n istio-system -l app=istio-ingressgateway
kubectl get svc -n istio-system istio-ingressgateway
```

### Upgrade Sequence

**SAME ORDER as installation:**

```bash
# 1. Upgrade base (CRDs first)
helm upgrade istio-base charts/istio/base \
  -n istio-system \
  -f charts/istio/base/values-prod.yaml

# 2. Upgrade istiod (control plane canary recommended)
helm upgrade istiod charts/istio/istiod \
  -n istio-system \
  -f charts/istio/istiod/values-prod.yaml \
  --wait

# 3. Upgrade gateway (ingress gateway)
helm upgrade istio-ingressgateway charts/istio/gateway \
  -n istio-system \
  -f charts/istio/gateway/values-prod.yaml \
  --wait
```

**Violation Handling:**
- ❌ Installing gateway before istiod → Gateway pods will crash (no control plane to connect to)
- ❌ Installing istiod before base → Deployment will fail (CRDs missing)
- ❌ Upgrading gateway before istiod → May cause version mismatch, gateway may fail to apply new config

---

## Values File Contract

### File Naming Convention
- `values.yaml` - Base values (defaults for all environments)
- `values-dev.yaml` - Development environment (minimal resources, relaxed security)
- `values-staging.yaml` - Staging environment (moderate resources, semi-strict security)
- `values-prod.yaml` - Production environment (HA resources, FIPS, strict security)

### Values Merging Strategy

```
Base values.yaml (chart defaults)
         ↓
   + Upstream chart values (from dependencies)
         ↓
   + Environment-specific values (values-{env}.yaml)
         ↓
   = Final rendered configuration
```

**Helm applies precedence:**
1. Command-line `--set` flags (highest priority)
2. `-f values-prod.yaml` file
3. Chart's default `values.yaml`
4. Upstream dependency chart defaults (lowest priority)

### Required Top-Level Keys (All Charts)

```yaml
# All charts MUST have these top-level keys
global:
  istioVersion: string       # Istio version
  fips:
    enabled: boolean         # FIPS mode toggle

replicaCount: integer        # Number of replicas

image:
  repository: string         # Container registry
  pullPolicy: string         # Always, IfNotPresent, Never
  tag: string                # Image tag

resources:
  requests:
    cpu: string              # CPU request (e.g., "500m")
    memory: string           # Memory request (e.g., "2Gi")
  limits:
    cpu: string
    memory: string

podSecurityContext:
  runAsNonRoot: boolean      # Must be true for production
  runAsUser: integer         # UID (1337 for Istio)
  fsGroup: integer

securityContext:
  allowPrivilegeEscalation: boolean  # Must be false for production
  readOnlyRootFilesystem: boolean    # Should be true for production
  capabilities:
    drop: []string           # Must include "ALL" for production

autoscaling:
  enabled: boolean
  minReplicas: integer
  maxReplicas: integer
  targetCPUUtilizationPercentage: integer
```

---

## Dependency Management Contract

### Upstream Istio Charts

**istiod Chart Dependency:**
```yaml
# charts/istio/istiod/Chart.yaml
dependencies:
  - name: istiod
    version: "1.23.0"
    repository: "https://istio-release.storage.googleapis.com/charts"
```

**gateway Chart Dependency:**
```yaml
# charts/istio/gateway/Chart.yaml
dependencies:
  - name: gateway
    version: "1.23.0"
    repository: "https://istio-release.storage.googleapis.com/charts"
```

**Dependency Update Workflow:**
```bash
# After editing Chart.yaml to bump version
cd charts/istio/istiod
helm dependency update

# This downloads the upstream chart to charts/ subdirectory
ls charts/
# Output: istiod-1.23.0.tgz

# Chart.lock file is created/updated
cat Chart.lock
# dependencies:
# - name: istiod
#   repository: https://istio-release.storage.googleapis.com/charts
#   version: 1.23.0
```

**Commit to Git:**
```bash
git add charts/istio/istiod/Chart.lock
git add charts/istio/istiod/charts/istiod-1.23.0.tgz
git commit -m "Update Istio to 1.23.0"
```

---

## Template Helpers Contract

### Naming Convention

All charts MUST define these helpers in `templates/_helpers.tpl`:

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "istio-base.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "istio-base.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "istio-base.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels (aligns with common-lib.labels pattern from repo)
*/}}
{{- define "istio-base.labels" -}}
helm.sh/chart: {{ include "istio-base.chart" . }}
{{ include "istio-base.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: helm-charts-hub
{{- end }}

{{/*
Selector labels
*/}}
{{- define "istio-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "istio-base.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

**Reuse Pattern:**
Replace `istio-base` with `istio-istiod` or `istio-gateway` in each chart's helpers.

---

## Version Compatibility Matrix

| Istio Version | Kubernetes Version | Helm Version | AKS Version | Status |
|---------------|-------------------|--------------|-------------|--------|
| 1.23.0 | 1.26 - 1.30 | 3.10+ | 1.26+ | ✅ Supported |
| 1.22.0 | 1.25 - 1.29 | 3.10+ | 1.25+ | ✅ Supported |
| 1.21.0 | 1.24 - 1.28 | 3.10+ | 1.24+ | ⚠️ Upgrade recommended |
| 1.20.x | 1.23 - 1.27 | 3.8+ | 1.23+ | ❌ End of life |

**Upgrade Path:**
- ✅ Can upgrade from N-1 minor version (e.g., 1.22 → 1.23)
- ⚠️ Must upgrade sequentially for N-2 (e.g., 1.21 → 1.22 → 1.23)
- ❌ Cannot skip more than one minor version

---

## Testing Contract

### Chart Validation

```bash
# Lint all charts
helm lint charts/istio/base
helm lint charts/istio/istiod
helm lint charts/istio/gateway

# Template rendering test (dry-run)
helm template istio-base charts/istio/base \
  -f charts/istio/base/values-prod.yaml \
  > /tmp/base-manifests.yaml

kubectl apply --dry-run=server -f /tmp/base-manifests.yaml
```

### Integration Testing

```bash
# Deploy to test cluster
helm install istio-base charts/istio/base -n istio-system --create-namespace
helm install istiod charts/istio/istiod -n istio-system --wait
helm install istio-ingressgateway charts/istio/gateway -n istio-system --wait

# Verify installation
istioctl verify-install
kubectl get pods -n istio-system
istioctl proxy-status

# Cleanup
helm uninstall istio-ingressgateway -n istio-system
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system
kubectl delete namespace istio-system
```

---

## Rollback Contract

### Rollback Sequence

**REVERSE order of installation:**

```bash
# 1. Rollback gateway first
helm rollback istio-ingressgateway -n istio-system

# 2. Rollback istiod
helm rollback istiod -n istio-system

# 3. Rollback base (CRDs)
# WARNING: CRD rollbacks are dangerous and may require manual intervention
helm rollback istio-base -n istio-system
```

**Caution:**
- ❌ CRD rollbacks can cause data loss if newer CRD schemas stored data in removed fields
- ✅ Always test rollback in staging before production
- ✅ Take etcd snapshots before major upgrades

---

## Summary

This contract defines:
- ✅ Three-chart structure (base, istiod, gateway)
- ✅ Mandatory installation order
- ✅ Helm dependency management for upstream Istio charts
- ✅ Values file naming and merging strategy
- ✅ Template helper conventions
- ✅ Version compatibility matrix
- ✅ Testing and rollback procedures

All charts MUST adhere to these contracts to ensure consistent, maintainable, and upgrade-safe Istio deployments on AKS.
