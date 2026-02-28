# envoy-gateway

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)
![AppVersion: 1.3.0](https://img.shields.io/badge/AppVersion-1.3.0-informational?style=flat-square)

Envoy Gateway controller chart for helm-charts-hub — Gateway API-native controller using Envoy Proxy as data plane.

## Prerequisites

- Kubernetes 1.28+
- Helm 3.x
- Gateway API CRDs v1.5+ installed in the cluster

Install Gateway API CRDs:

```bash
kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
```

> **Note**: `--force-conflicts` is required if CRDs were previously installed by another field manager (e.g., Helm or a prior `kubectl apply`).

## Installing the Chart

```bash
helm dependency build charts/envoy-gateway
helm install envoy-gateway charts/envoy-gateway
```

With custom values:

```bash
helm dependency build charts/envoy-gateway
helm install envoy-gateway charts/envoy-gateway -f environments/dev/envoy-gateway.values.yaml
```

## Uninstalling the Chart

```bash
helm uninstall envoy-gateway
```

## Configuration

### Image

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image repository | `docker.io/envoyproxy/gateway` |
| `image.tag` | Container image tag | `v1.3.0` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |

### Deployment

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of controller replicas | `1` |
| `terminationGracePeriodSeconds` | Termination grace period | `10` |
| `nodeSelector` | Node selector | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |
| `podAnnotations` | Extra pod annotations | `{}` |
| `podLabels` | Extra pod labels | `{}` |

### Service

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.ports.grpc` | xDS gRPC port | `18000` |
| `service.containerPorts.grpc` | Container gRPC port | `18000` |
| `service.containerPorts.ratelimit` | Container ratelimit port | `18001` |
| `service.containerPorts.health` | Container health probe port | `8081` |
| `service.containerPorts.metrics` | Container metrics port | `19001` |

### Security

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podSecurityContext.runAsNonRoot` | Run as non-root | `true` |
| `podSecurityContext.runAsUser` | Run as UID | `65532` |
| `securityContext.readOnlyRootFilesystem` | Read-only root filesystem | `true` |
| `securityContext.allowPrivilegeEscalation` | Allow privilege escalation | `false` |

### ServiceAccount & RBAC

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create ServiceAccount | `true` |
| `serviceAccount.name` | ServiceAccount name override | `""` |
| `serviceAccount.annotations` | ServiceAccount annotations | `{}` |
| `rbac.create` | Create ClusterRole/ClusterRoleBinding | `true` |

### GatewayClass

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gatewayClass.create` | Create GatewayClass resource | `true` |
| `gatewayClass.name` | GatewayClass name | `envoy` |
| `gatewayClass.controllerName` | Controller name | `gateway.envoyproxy.io/gatewayclass-controller` |

### Gateway

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gateway.enabled` | Create a Gateway resource | `false` |
| `gateway.name` | Gateway name | `envoy-gateway` |
| `gateway.namespace` | Gateway namespace (defaults to release namespace) | `""` |
| `gateway.listeners` | Listener list (name, port, protocol, hostname) | HTTP:80, HTTPS:443 |

### Controller Config

| Parameter | Description | Default |
|-----------|-------------|---------|
| `config.gateway.controllerName` | Controller name in config | `gateway.envoyproxy.io/gatewayclass-controller` |
| `config.provider.type` | Infrastructure provider | `Kubernetes` |
| `config.logging.level.default` | Default log level | `info` |
| `kubernetesClusterDomain` | Kubernetes cluster domain | `cluster.local` |

### Metrics & Autoscaling

| Parameter | Description | Default |
|-----------|-------------|---------|
| `metrics.enabled` | Expose metrics port on Service | `false` |
| `metrics.port` | Prometheus metrics port | `19001` |
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `5` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization | `80` |

### Resources

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `256Mi` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |

### Extensibility

| Parameter | Description | Default |
|-----------|-------------|---------|
| `extraEnv` | Extra environment variables | `[]` |
| `extraVolumes` | Extra volumes | `[]` |
| `extraVolumeMounts` | Extra volume mounts | `[]` |
| `extraArgs` | Extra container arguments | `[]` |
| `labels` | Extra resource labels | `{}` |
| `annotations` | Extra resource annotations | `{}` |

## Chart Dependencies

| Repository | Name | Version |
|------------|------|---------|
| `file://../common-lib` | common-lib | `>=0.1.0 <1.0.0` |

## Environment Overlays

| Environment | File |
|-------------|------|
| Development | `environments/dev/envoy-gateway.values.yaml` |
| Staging | `environments/staging/envoy-gateway.values.yaml` |
| Production | `environments/production/envoy-gateway.values.yaml` |

## Further Reading

- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Getting Started](../../docs/getting-started.md)

## Troubleshooting

### Gateway API CRD conflicts on apply

If you see errors like:

```
Apply failed with 3 conflicts: conflicts with "helm" using apiextensions.k8s.io/v1
```

This happens when the CRDs were previously managed by another field manager (e.g., Helm or a prior `kubectl apply`). Fix with:

```bash
kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
```

`--force-conflicts` tells the server-side apply to take ownership of the conflicting fields.

### Controller pods not starting

Check that RBAC resources were created:

```bash
kubectl describe clusterrole <release-name>-envoy-gateway
kubectl describe clusterrolebinding <release-name>-envoy-gateway
```

Verify Gateway API CRDs are installed:

```bash
kubectl get crd gatewayclasses.gateway.networking.k8s.io
```

### GatewayClass not accepted

Check the controller logs:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=envoy-gateway
```
