# envoy-controller

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

## Installation

```bash
# From the Helm repository
helm repo add helm-charts-hub https://pkumar26.github.io/helm-charts-hub/
helm install envoy-controller helm-charts-hub/envoy-controller

# Or install from local source
helm dependency build charts/envoy-controller
helm install envoy-controller ./charts/envoy-controller
```

### With Gateway enabled

```bash
# Install Gateway API CRDs first (if not already installed)
kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml

# Install with a default Gateway
helm install envoy-controller helm-charts-hub/envoy-controller \
  --set gateway.enabled=true

# Or install from local source
helm dependency build charts/envoy-controller
helm install envoy-controller ./charts/envoy-controller \
  --set gateway.enabled=true

# Or use a values file
helm install envoy-controller helm-charts-hub/envoy-controller \
  -f environments/production/envoy-controller.values.yaml
```

> **Tip**: Use `envoy-controller` as the release name to keep resource names clean.
> If the release name differs from the chart name (e.g., `helm install envoy-gateway charts/envoy-controller`),
> Kubernetes resources will have a compound name like `envoy-gateway-envoy-controller`.

## Uninstalling the Chart

```bash
helm uninstall envoy-controller
```

## Next Steps

After the controller pod is running, create a Gateway, deploy a sample app, and route traffic:

```bash
# 1. Create a Gateway (Envoy Gateway will provision Envoy proxy pods)
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: envoy
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

# 2. Deploy a sample application
kubectl create deployment httpbin --image=kennethreitz/httpbin --port=80
kubectl expose deployment httpbin --port=80

# 3. Create an HTTPRoute to send traffic to the app
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-route
spec:
  parentRefs:
    - name: my-gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: httpbin
          port: 80
EOF

# 4. Verify the Gateway is accepted and proxy pods are running
kubectl get gateway my-gateway
kubectl get pods -l gateway.envoyproxy.io/owning-gateway-name=my-gateway

# 5. Test the route (port-forward the Gateway Service)
GATEWAY_SVC=$(kubectl get svc -l gateway.envoyproxy.io/owning-gateway-name=my-gateway -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward svc/$GATEWAY_SVC 8080:80 &
curl -s http://localhost:8080/get | head -20
```

The Envoy Gateway controller watches for `Gateway` resources and automatically provisions Envoy Proxy pods as the data plane. When you create an `HTTPRoute`, traffic flows through the provisioned proxy to your backend service.

> **Tip**: If you installed with `--set gateway.enabled=true`, the chart already created a Gateway for you. Skip step 1 and reference the chart-created Gateway name (`envoy-gateway` by default) in steps 3–5.

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

### Certificate Generation

| Parameter | Description | Default |
|-----------|-------------|---------|
| `certgen.enabled` | Run pre-install Job to generate xDS TLS certs | `true` |

The certgen Job runs as a Helm pre-install/pre-upgrade hook. It generates self-signed TLS
certificates that the controller uses for secure xDS communication with the data plane (Envoy Proxy pods).
If you manage certificates externally (e.g., cert-manager), set `certgen.enabled: false` and ensure a
Secret named `envoy-gateway` exists with `tls.crt`, `tls.key`, and `ca.crt` keys.

## Chart Dependencies

| Repository | Name | Version |
|------------|------|---------|
| `file://../common-lib` | common-lib | `>=0.1.0 <1.0.0` |

## Environment Overlays

| Environment | File |
|-------------|------|
| Development | `environments/dev/envoy-controller.values.yaml` |
| Staging | `environments/staging/envoy-controller.values.yaml` |
| Production | `environments/production/envoy-controller.values.yaml` |

## Further Reading

- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Getting Started](../../docs/getting-started.md)

## Troubleshooting

### Data plane pod / service naming

When a Gateway is created, the Envoy Gateway controller automatically provisions data plane Envoy Proxy
pods, Deployments, and Services. These resources are named by the controller using the pattern:

```
envoy-<namespace>-<gateway-name>-<hash>
```

For example, a Gateway named `envoy-gateway` in the `default` namespace produces:

```
envoy-default-envoy-gateway-12b6bb46   (Deployment, Service, Pod prefix)
```

This naming is **internal to the Envoy Gateway controller binary** and is not configurable via this
Helm chart. The `envoy-` prefix and `<namespace>-` segment are hardcoded in the controller's
infrastructure provisioning logic.

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
kubectl describe clusterrole <release-name>-envoy-controller
kubectl describe clusterrolebinding <release-name>-envoy-controller
```

Verify Gateway API CRDs are installed:

```bash
kubectl get crd gatewayclasses.gateway.networking.k8s.io
```

### GatewayClass not accepted

Check the controller logs:

```bash
kubectl logs -n <namespace> -l app.kubernetes.io/name=envoy-controller
```

### Data plane pods stuck in ContainerCreating

If Envoy Proxy pods show `secret "envoy" not found`, the controller TLS certificates are missing.
Verify the certgen Job completed:

```bash
kubectl get jobs -n <namespace> -l app.kubernetes.io/component=certgen
kubectl get secret envoy-gateway -n <namespace>
```

If the secret is missing, delete the release and reinstall (the certgen hook runs on install):

```bash
helm uninstall <release-name> -n <namespace>
helm install <release-name> charts/envoy-controller -n <namespace>
```
