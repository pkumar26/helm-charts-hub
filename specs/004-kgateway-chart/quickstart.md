# Quickstart: kgateway-controller Chart

**Feature Branch**: `004-kgateway-chart`

---

## Prerequisites

1. **Kubernetes 1.31+** cluster running
2. **Helm 3.12+** installed
3. **Gateway API CRDs v1.5.0** installed:
   ```bash
   kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
   ```
4. **kgateway CRDs** installed:
   ```bash
   helm upgrade -i kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds --version v2.2.1
   ```

---

## Install (Minimal)

```bash
helm install kgateway-controller ./charts/kgateway-controller \
  --namespace kgateway-system \
  --create-namespace
```

### Verify

```bash
# Check controller pod is running
kubectl get pods -n kgateway-system -l app.kubernetes.io/name=kgateway-controller

# Check service is available
kubectl get svc -n kgateway-system -l app.kubernetes.io/name=kgateway-controller

# Check controller logs
kubectl logs -n kgateway-system -l app.kubernetes.io/name=kgateway-controller --tail=50
```

---

## Install (Production)

```bash
helm install kgateway-controller ./charts/kgateway-controller \
  --namespace kgateway-system \
  --create-namespace \
  -f environments/production/kgateway-controller.values.yaml
```

---

## Test: Create a Gateway + HTTPRoute

Once the controller is running, exercise the Gateway API:

```bash
# 1. Create a GatewayClass (if not using chart-managed one)
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: kgateway
spec:
  controllerName: kgateway.dev/kgateway
EOF

# 2. Create a Gateway (this triggers kgateway to provision Envoy proxy pods)
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: default
spec:
  gatewayClassName: kgateway
  listeners:
    - name: http
      protocol: HTTP
      port: 8080
EOF

# 3. Create an HTTPRoute
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
  namespace: default
spec:
  parentRefs:
    - name: my-gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: my-service
          port: 80
EOF

# 4. Verify Gateway is accepted
kubectl get gateway my-gateway -o jsonpath='{.status.conditions}' | jq .

# 5. Verify proxy pods were provisioned
kubectl get pods -l gateway.networking.k8s.io/gateway-name=my-gateway
```

---

## Uninstall

```bash
# Remove test resources
kubectl delete httproute my-route
kubectl delete gateway my-gateway
kubectl delete gatewayclass kgateway

# Uninstall chart
helm uninstall kgateway-controller -n kgateway-system

# (Optional) Remove CRDs
helm uninstall kgateway-crds
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
```

---

## Helm Lint / Template Test

```bash
# Lint with minimal values
helm lint ./charts/kgateway-controller

# Lint with full values
helm lint ./charts/kgateway-controller -f ./charts/kgateway-controller/ci/test-full-values.yaml

# Template render (dry-run)
helm template kgateway-controller ./charts/kgateway-controller --namespace kgateway-system

# Template with all features enabled
helm template kgateway-controller ./charts/kgateway-controller \
  --namespace kgateway-system \
  -f ./charts/kgateway-controller/ci/test-full-values.yaml
```
