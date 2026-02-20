# web-app

General-purpose application chart for deploying services on Kubernetes. Supports Deployment and CronJob workload types.

## Overview

`web-app` is an application chart that uses [`common-lib`](../common-lib/) helpers to render standard Kubernetes resources with consistent labels, annotations, and security defaults.

It deploys a generic HTTP service (Deployment + Service) with optional Ingress, HPA, and ServiceAccount support.

## Prerequisites

- Helm ≥ 3.12
- Kubernetes ≥ 1.26
- (Optional) An Ingress controller if enabling `ingress.enabled`

## Installation

### From OCI Registry

```bash
helm install my-app oci://ghcr.io/pkumar26/charts/web-app --version 0.1.0 \
  --set image.repository=<your-image> \
  --set image.tag=<your-tag>
```

### From Source

```bash
helm dependency build charts/web-app
helm install my-app charts/web-app \
  --set image.repository=nginx \
  --set image.tag=1.27-alpine
```

### Uninstall

```bash
helm uninstall my-app
```

## Configuration

The following table lists the configurable parameters and their default values.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `workloadType` | string | `deployment` | Workload type. Supported: `deployment` |
| `image.repository` | string | `""` | Container image repository (**required**) |
| `image.tag` | string | `""` | Container image tag (**required**, must not be empty) |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `replicaCount` | int | `1` | Number of replicas (ignored when `autoscaling.enabled: true`) |
| `service.type` | string | `ClusterIP` | Service type |
| `service.port` | int | `80` | Service port |
| `ingress.enabled` | bool | `false` | Enable Ingress resource |
| `ingress.className` | string | `""` | IngressClass name |
| `ingress.hosts` | list | `[]` | Ingress host rules |
| `ingress.tls` | list | `[]` | TLS configuration |
| `ingress.annotations` | map | `{}` | Extra ingress annotations |
| `autoscaling.enabled` | bool | `false` | Enable HPA |
| `autoscaling.minReplicas` | int | `1` | HPA minimum replicas |
| `autoscaling.maxReplicas` | int | `10` | HPA maximum replicas |
| `autoscaling.targetCPUUtilizationPercentage` | int | `80` | HPA CPU target |
| `resources.requests.cpu` | string | `100m` | CPU request |
| `resources.requests.memory` | string | `128Mi` | Memory request |
| `resources.limits.cpu` | string | `500m` | CPU limit |
| `resources.limits.memory` | string | `256Mi` | Memory limit |
| `podSecurityContext.runAsNonRoot` | bool | `true` | Pod runs as non-root |
| `podSecurityContext.fsGroup` | int | `1000` | FS group |
| `securityContext.readOnlyRootFilesystem` | bool | `true` | Read-only root FS |
| `securityContext.runAsNonRoot` | bool | `true` | Container non-root |
| `securityContext.allowPrivilegeEscalation` | bool | `false` | Block privilege escalation |
| `serviceAccount.create` | bool | `true` | Create a ServiceAccount |
| `serviceAccount.name` | string | `""` | ServiceAccount name override |
| `serviceAccount.annotations` | map | `{}` | ServiceAccount annotations |
| `nodeSelector` | map | `{}` | Node selector |
| `tolerations` | list | `[]` | Tolerations |
| `affinity` | map | `{}` | Affinity rules |
| `podAnnotations` | map | `{}` | Extra pod annotations |
| `podLabels` | map | `{}` | Extra pod labels |
| `labels` | map | `{}` | Extra resource labels |
| `annotations` | map | `{}` | Extra resource annotations |
| `extraEnv` | list | `[]` | Extra environment variables |
| `extraVolumes` | list | `[]` | Extra volumes |
| `extraVolumeMounts` | list | `[]` | Extra volume mounts |
| `livenessProbe` | map | `httpGet: {path: /, port: http}` | Liveness probe |
| `readinessProbe` | map | `httpGet: {path: /, port: http}` | Readiness probe |
| `global.annotationPrefix` | string | `platform.example.com` | Annotation prefix for ownership annotations |

> **Note**: When `autoscaling.enabled: true`, the `replicaCount` value is used only as the initial replica count. The HPA governs scaling after deployment.

## Examples

### Minimal

```bash
helm install my-app charts/web-app \
  --set image.repository=nginx \
  --set image.tag=1.27-alpine
```

Or with a values file:

```bash
helm install my-app charts/web-app -f examples/web-app-minimal.yaml
```

### Production

```bash
helm install my-app charts/web-app -f examples/web-app-production.yaml
```

See [examples/](../../examples/) for complete example values files.

## Upgrade Notes

### 0.1.0

Initial release — no prior versions.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `image.repository is required` | Provide `--set image.repository=<image>` |
| `image.tag must not be empty` | Provide `--set image.tag=<tag>` (do not use `latest`) |
| `workloadType must be one of: deployment` | Set `workloadType` to `deployment` |
| Pods stuck in `CrashLoopBackOff` | Check container logs: `kubectl logs <pod>`. Ensure the image exists and the container starts correctly |
| Service not accessible | Verify the pod is running and the service port matches the container port |
| Ingress not working | Ensure an Ingress controller is installed and `ingress.className` matches your controller |
