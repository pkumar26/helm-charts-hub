# Quickstart: Envoy Gateway Controller Chart

**Feature Branch**: `003-envoy-gateway-chart`
**Date**: 2026-02-26

---

## Prerequisites

1. **Kubernetes 1.28+** cluster running
2. **Helm 3.x** installed
3. **Gateway API CRDs** installed:
   ```bash
   kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
   ```

## Installation

### Build Dependencies

```bash
helm dependency build charts/envoy-controller
```

### 1. Basic Install (GatewayClass only)

```bash
helm install envoy-controller charts/envoy-controller \
  --namespace envoy-gateway-system \
  --create-namespace
```

This deploys:
- Envoy Gateway controller Deployment
- GatewayClass named `envoy`
- ClusterRole + ClusterRoleBinding
- ServiceAccount
- ConfigMap with controller configuration
- ClusterIP Service on port 18000

### 2. Install with Default Gateway

```bash
helm install envoy-controller charts/envoy-controller \
  --namespace envoy-gateway-system \
  --create-namespace \
  --set gateway.enabled=true
```

This additionally creates a `Gateway` resource with HTTP (80) and HTTPS (443) listeners.

### 3. Install with Environment Overlay

```bash
helm install envoy-controller charts/envoy-controller \
  --namespace envoy-gateway-system \
  --create-namespace \
  -f environments/production/envoy-controller.values.yaml
```

## Verify Installation

```bash
# Check controller is running
kubectl get pods -n envoy-gateway-system

# Verify GatewayClass is accepted
kubectl get gatewayclass envoy

# Check Gateway status (if enabled)
kubectl get gateways -n envoy-gateway-system
```

## Create an HTTPRoute

Once the Gateway is provisioned, create routes:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-route
spec:
  parentRefs:
    - name: envoy-controller
      namespace: envoy-gateway-system
  hostnames:
    - "app.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: my-app-service
          port: 80
```

## Development Values

For local development with debug logging:

```bash
helm install envoy-controller charts/envoy-controller \
  --namespace envoy-gateway-system \
  --create-namespace \
  -f environments/dev/envoy-controller.values.yaml
```

## Uninstall

```bash
helm uninstall envoy-controller -n envoy-gateway-system
kubectl delete namespace envoy-gateway-system
```

**Note**: Gateway API CRDs are not removed by `helm uninstall`. Remove them manually if needed:
```bash
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
```
