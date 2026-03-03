# common-lib

[![Helm 3](https://img.shields.io/badge/Helm-3-blue?logo=helm&logoColor=white)](https://helm.sh)
[![Chart Version](https://img.shields.io/badge/chart%20version-0.2.0-blue?logo=helm)](https://github.com/pkumar26/helm-charts-hub/tree/master/charts/common-lib)

Reusable Helm library chart for **helm-charts-hub** — provides standard helpers for Deployments, Services, Ingress, HPA, labels, annotations, and security contexts.

## Overview

`common-lib` is a Helm **library chart** (`type: library`) that cannot be installed on its own. It provides reusable helper templates that application charts include via `{{ include "common-lib.<helper>" ... }}`.

All application charts in this repository declare `common-lib` as a dependency, ensuring consistent resource rendering, labeling, annotations, and security defaults across the entire catalog.

## Prerequisites

- Helm ≥ 3.12

This chart is consumed as a dependency by application charts. You do not install it directly.

## Installation

Library charts cannot be installed. To use `common-lib`, declare it as a dependency in your application chart's `Chart.yaml`:

```yaml
dependencies:
  - name: common-lib
    version: ">=0.1.0 <1.0.0"
    repository: "file://../common-lib"
```

Then run:

```bash
helm dependency build charts/<your-chart>
```

## Configuration

`common-lib` does not have user-facing configuration. Its helpers consume values from the application chart's `values.yaml`. See [data-model §2.3](../../specs/001-foundational-spec/data-model.md) for the canonical values shape.

## Helper Reference

All helpers are prefixed `common-lib.*`. Resource-generating helpers use the **dict pattern**: `{{ include "common-lib.<helper>" (dict "root" .) }}`. Metadata helpers accept root context directly.

### Metadata Helpers

| Helper | File | Input | Output |
|--------|------|-------|--------|
| `common-lib.fullname` | `_helpers.tpl` | Root context (`.`) | Resource name string (63-char truncated) |
| `common-lib.chart` | `_helpers.tpl` | Root context (`.`) | `<chart-name>-<chart-version>` string |

**Usage:**

```yaml
metadata:
  name: {{ include "common-lib.fullname" . }}
```

### Label Helpers

| Helper | File | Input | Output |
|--------|------|-------|--------|
| `common-lib.labels` | `_labels.tpl` | `dict "root" . ["extraLabels" map]` | 6 base labels + extras |
| `common-lib.selectorLabels` | `_labels.tpl` | Root context (`.`) | 2 immutable selector labels |

**Base labels** (6):
- `app.kubernetes.io/name`
- `app.kubernetes.io/instance`
- `app.kubernetes.io/version`
- `app.kubernetes.io/managed-by`
- `app.kubernetes.io/part-of`
- `helm.sh/chart`

**Usage:**

```yaml
metadata:
  labels:
    {{- include "common-lib.labels" (dict "root" .) | nindent 4 }}
```

### Annotation Helpers

| Helper | File | Input | Output |
|--------|------|-------|--------|
| `common-lib.annotations` | `_annotations.tpl` | `dict "root" . ["extraAnnotations" map]` | 2 base annotations + extras |

**Base annotations** (2):
- `meta.helm.sh/release-name`
- `meta.helm.sh/release-namespace`

**Usage:**

```yaml
metadata:
  annotations:
    {{- include "common-lib.annotations" (dict "root" .) | nindent 4 }}
```

### Resource Helpers

| Helper | File | Input | Guard | Output |
|--------|------|-------|-------|--------|
| `common-lib.deployment` | `_deployment.tpl` | `dict "root" .` | `workloadType == "deployment"` | Full Deployment YAML |
| `common-lib.service` | `_service.tpl` | `dict "root" .` | `workloadType == "deployment"` | Full Service YAML |
| `common-lib.ingress` | `_ingress.tpl` | `dict "root" .` | `ingress.enabled` | Full Ingress YAML |
| `common-lib.hpa` | `_hpa.tpl` | `dict "root" .` | `autoscaling.enabled` | Full HPA YAML |
| `common-lib.configmap` | `_configmap.tpl` | `dict "root" . "data" map` | data non-empty | Full ConfigMap YAML |
| `common-lib.secrets` | `_secrets.tpl` | `dict "root" . "data" map` | data non-empty | Full Secret YAML |
| `common-lib.serviceaccount` | `_serviceaccount.tpl` | Root context (`.`) | `serviceAccount.create` | Full ServiceAccount YAML |
| `common-lib.podsecurity` | `_podsecurity.tpl` | Root context (`.`) | — | Security context YAML fragment |

**Usage (application chart templates):**

```yaml
# deployment.yaml
{{- include "common-lib.deployment" (dict "root" .) }}

# service.yaml
{{- include "common-lib.service" (dict "root" .) }}

# ingress.yaml
{{- include "common-lib.ingress" (dict "root" .) }}

# hpa.yaml
{{- include "common-lib.hpa" (dict "root" .) }}

# serviceaccount.yaml
{{- include "common-lib.serviceaccount" . }}
```

### Opt-Out Pattern

If a chart needs a custom template instead of a `common-lib` helper, simply write the resource directly in the chart's template file instead of calling `{{ include }}`. The library helpers are opt-in — charts choose which to use.

## Examples

See the [web-app](../web-app/) chart for a complete example of `common-lib` integration.

## Upgrade Notes

### 0.2.0

Added Ingress, HPA, ConfigMap, and Secret helpers. No breaking changes from 0.1.0.

### 0.1.0

Initial release — no prior versions.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Error: found in Chart.yaml, but missing in charts/ directory` | Run `helm dependency build charts/<your-chart>` |
| Helper not found: `common-lib.<name>` | Ensure `common-lib` is listed in `Chart.yaml` dependencies and `helm dependency build` was run |
| Labels or annotations missing | Verify you are calling `common-lib.labels` / `common-lib.annotations` with the dict pattern |
