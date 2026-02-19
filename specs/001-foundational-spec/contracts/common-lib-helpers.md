# Contract: common-lib Helper Template Interfaces

**Date**: 2026-02-19

This document defines the input/output contracts for each `common-lib` helper template.
Application charts depend on these interfaces. Changes to signatures require a major version bump.

---

## Metadata Helpers

### `common-lib.fullname`

**Purpose**: Generate the fully-qualified resource name.
**Input**: Root context (`.`)
**Output**: String — `<release-name>-<chart-name>` (truncated to 63 chars)

```yaml
# Usage
{{ include "common-lib.fullname" . }}
# Output: "my-release-web-app"
```

### `common-lib.chart`

**Purpose**: Generate chart name + version string for labels.
**Input**: Root context (`.`)
**Output**: String — `<chart-name>-<chart-version>`

```yaml
# Usage
{{ include "common-lib.chart" . }}
# Output: "web-app-0.1.0"
```

### `common-lib.labels`

**Purpose**: Render the full base label set.
**Input**: `dict "root" <context> ["extraLabels" <map>]`
**Output**: Multi-line YAML label block

```yaml
# Usage (basic)
{{ include "common-lib.labels" (dict "root" .) }}

# Usage (with extra labels)
{{ include "common-lib.labels" (dict "root" . "extraLabels" .Values.labels) }}

# Output
app.kubernetes.io/name: web-app
app.kubernetes.io/instance: my-release
app.kubernetes.io/version: "1.0.0"
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/part-of: helm-charts-hub
helm.sh/chart: web-app-0.1.0
```

### `common-lib.selectorLabels`

**Purpose**: Render the immutable selector labels (subset of full labels).
**Input**: Root context (`.`)
**Output**: Multi-line YAML label block

```yaml
# Output
app.kubernetes.io/name: web-app
app.kubernetes.io/instance: my-release
```

### `common-lib.annotations`

**Purpose**: Render the base annotation set.
**Input**: `dict "root" <context> ["extraAnnotations" <map>]`
**Output**: Multi-line YAML annotation block

```yaml
# Output
meta.helm.sh/release-name: my-release
meta.helm.sh/release-namespace: default
```

---

## Resource Helpers

### `common-lib.deployment`

**Purpose**: Render a complete Deployment resource.
**Input**: `dict "root" <context> ["component" <string>]`
**Output**: Full Deployment YAML
**Values consumed**: `image.*`, `replicaCount`, `resources`, `podSecurityContext`, `securityContext`, `nodeSelector`, `tolerations`, `affinity`, `extraEnv`, `extraVolumes`, `extraVolumeMounts`, `livenessProbe`, `readinessProbe`, `podAnnotations`, `podLabels`, `serviceAccount`

**Behavior**:
- Only rendered when `workloadType` is `deployment`
- Includes labels, annotations, selector labels, security context, probes, resource limits
- Merges `podAnnotations` and `podLabels` from values
- Mounts `extraVolumes` and `extraVolumeMounts`

### `common-lib.service`

**Purpose**: Render a complete Service resource.
**Input**: `dict "root" <context> ["component" <string>]`
**Output**: Full Service YAML
**Values consumed**: `service.type`, `service.port`, `service.targetPort`, `service.annotations`

**Behavior**:
- Only rendered when `workloadType` is `deployment` (workers and CronJobs have no Service)
- Selector uses `common-lib.selectorLabels`

### `common-lib.ingress`

**Purpose**: Render a complete Ingress resource.
**Input**: `dict "root" <context> ["component" <string>]`
**Output**: Full Ingress YAML (or empty string if disabled)
**Values consumed**: `ingress.enabled`, `ingress.className`, `ingress.hosts`, `ingress.tls`, `ingress.annotations`

**Behavior**:
- Produces no output when `ingress.enabled: false`
- Uses `networking.k8s.io/v1` API version
- Applies base labels and annotations plus `ingress.annotations`

### `common-lib.hpa`

**Purpose**: Render a HorizontalPodAutoscaler resource.
**Input**: `dict "root" <context> ["component" <string>]`
**Output**: Full HPA YAML (or empty string if disabled)
**Values consumed**: `autoscaling.enabled`, `autoscaling.minReplicas`, `autoscaling.maxReplicas`, `autoscaling.targetCPUUtilizationPercentage`, `autoscaling.targetMemoryUtilizationPercentage`

**Behavior**:
- Produces no output when `autoscaling.enabled: false`
- Uses `autoscaling/v2` API version
- Targets the Deployment by name

### `common-lib.configmap`

**Purpose**: Render a ConfigMap resource.
**Input**: `dict "root" <context> "data" <map>`
**Output**: Full ConfigMap YAML
**Values consumed**: None directly — data is passed as argument

### `common-lib.secrets`

**Purpose**: Render a Secret resource.
**Input**: `dict "root" <context> "data" <map>`
**Output**: Full Secret YAML (base64-encoded)
**Values consumed**: None directly — data is passed as argument

### `common-lib.podsecurity`

**Purpose**: Render the combined pod + container security context block.
**Input**: Root context (`.`)
**Output**: YAML fragment for `securityContext` and `containers[].securityContext`
**Values consumed**: `podSecurityContext`, `securityContext`

**Defaults** (from constitution §2.5):
- `runAsNonRoot: true`
- `readOnlyRootFilesystem: true`
- `allowPrivilegeEscalation: false`

### `common-lib.serviceaccount`

**Purpose**: Render a ServiceAccount resource.
**Input**: Root context (`.`)
**Output**: Full ServiceAccount YAML (or empty string if disabled)
**Values consumed**: `serviceAccount.create`, `serviceAccount.name`, `serviceAccount.annotations`

**Behavior**:
- Produces no output when `serviceAccount.create: false`
- Name defaults to `common-lib.fullname` if not overridden

---

## Validation Contracts

Templates MUST enforce the following at render time:

| Check | Implementation | Error Message Pattern |
|-------|---------------|----------------------|
| `image.repository` required | `{{ required "image.repository is required" .Values.image.repository }}` | `image.repository is required` |
| `image.tag` non-empty | `{{ if not .Values.image.tag }}{{ fail "image.tag must not be empty" }}{{ end }}` | `image.tag must not be empty` |
| `workloadType` valid | `{{ if not (has .Values.workloadType (list "deployment")) }}{{ fail ... }}{{ end }}` | `workloadType must be one of: deployment` |
