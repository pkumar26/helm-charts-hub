# Quickstart: Deploy Istio to AKS with FIPS and Security Baseline

**Feature**: 007-istio-aks-chart  
**Date**: 2026-05-20  
**Time to Complete**: ~30 minutes

## Overview

This quickstart guide walks you through deploying Istio service mesh to Azure Kubernetes Service (AKS) using Helm charts with FIPS 140-2 compliance and classified security baseline.

---

## Prerequisites

### Tools Required

```bash
# Check tool versions
helm version       # v3.10 or later
kubectl version    # v1.26 or later
az version         # Azure CLI 2.50 or later
istioctl version   # 1.23.0 (optional, for verification)
```

**Install missing tools:**
```bash
# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# kubectl
az aks install-cli

# istioctl (optional)
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.23.0 sh -
cd istio-1.23.0
export PATH=$PWD/bin:$PATH
```

---

### AKS Cluster Setup

#### Option A: Create New FIPS-Enabled AKS Cluster (Production)

```bash
# Variables
RESOURCE_GROUP="rg-istio-prod"
CLUSTER_NAME="aks-istio-prod"
LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create AKS cluster with FIPS-enabled node pool
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --zones 1 2 3 \
  --enable-fips-image \
  --network-plugin azure \
  --network-policy calico \
  --kubernetes-version 1.28 \
  --generate-ssh-keys

# Get credentials
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
```

**Verify FIPS is enabled:**
```bash
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.osImage}'
# Expected: CBL-Mariner/Linux (FIPS Enabled) or Ubuntu with FIPS kernel
```

---

#### Option B: Use Existing AKS Cluster (Dev/Staging)

```bash
# Connect to existing cluster
az aks get-credentials --resource-group <your-rg> --name <your-cluster>

# Verify connectivity
kubectl cluster-info
kubectl get nodes
```

---

## Step 1: Install Istio Base (CRDs)

### Deploy Base Chart

```bash
# Navigate to charts directory
cd charts/istio/base

# Install CRDs (works for all environments)
helm install istio-base . \
  --namespace istio-system \
  --create-namespace \
  --wait

# Verify CRDs are created
kubectl get crds | grep istio.io
```

**Expected Output:**
```
authorizationpolicies.security.istio.io
destinationrules.networking.istio.io
envoyfilters.networking.istio.io
gateways.networking.istio.io
peerauthentications.security.istio.io
...
```

---

## Step 2: Install istiod (Control Plane)

### Development Environment

```bash
cd ../istiod

# Install with dev values
helm install istiod . \
  --namespace istio-system \
  -f values-dev.yaml \
  --wait \
  --timeout 10m

# Verify istiod is running
kubectl get pods -n istio-system -l app=istiod
kubectl get svc -n istio-system istiod
```

---

### Production Environment (FIPS + Security Baseline)

```bash
cd ../istiod

# Install with production values
helm install istiod . \
  --namespace istio-system \
  -f values-prod.yaml \
  --wait \
  --timeout 10m

# Verify FIPS image
kubectl get deploy -n istio-system istiod -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: docker.io/istio/pilot:1.23.0-distroless

# Verify GOFIPS is set
kubectl exec -n istio-system deploy/istiod -c discovery -- env | grep GOFIPS
# Expected: GOFIPS=1

# Check mTLS policy
kubectl get peerauthentication -n istio-system
# Expected: default policy with STRICT mode

# Check authorization policies
kubectl get authorizationpolicy -n istio-system
# Expected: deny-all, allow-api-server-webhook, allow-xds-clients
```

---

### Verify Installation

```bash
# Check istiod logs
kubectl logs -n istio-system deploy/istiod -c discovery --tail=50

# Verify webhook is registered
kubectl get validatingwebhookconfiguration istiod-istio-system

# Test with istioctl (if installed)
istioctl verify-install
```

**Expected Output:**
```
✅ Istio is installed and verified successfully
```

---

## Step 3: Install Istio Gateway (Ingress)

### Development Environment

```bash
cd ../gateway

# Install with dev values
helm install istio-ingressgateway . \
  --namespace istio-system \
  -f values-dev.yaml \
  --wait \
  --timeout 10m

# Get LoadBalancer external IP
kubectl get svc -n istio-system istio-ingressgateway
```

---

### Production Environment (FIPS + Security Baseline)

```bash
cd ../gateway

# Install with production values
helm install istio-ingressgateway . \
  --namespace istio-system \
  -f values-prod.yaml \
  --wait \
  --timeout 10m

# Verify FIPS image
kubectl get deploy -n istio-system istio-ingressgateway -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: docker.io/istio/proxyv2:1.23.0-distroless

# Get LoadBalancer external IP (Azure public IP)
kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Check gateway authorization policies
kubectl get authorizationpolicy -n istio-system -l app=istio-ingressgateway
```

---

### Verify Gateway Health

```bash
# Check gateway pods
kubectl get pods -n istio-system -l app=istio-ingressgateway

# Check LoadBalancer service
kubectl get svc -n istio-system istio-ingressgateway

# Test health endpoint
GATEWAY_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -v http://$GATEWAY_IP:15021/healthz/ready
# Expected: HTTP 200 OK
```

---

## Step 4: Deploy Test Workload

### Create Test Namespace

```bash
# Create namespace with Istio injection enabled
kubectl create namespace test-app
kubectl label namespace test-app istio-injection=enabled

# Verify label
kubectl get namespace test-app --show-labels
```

---

### Deploy Sample Application

```bash
# Deploy httpbin test service
kubectl apply -n test-app -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  ports:
  - name: http
    port: 8000
    targetPort: 80
  selector:
    app: httpbin
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
EOF

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=httpbin -n test-app --timeout=120s

# Check sidecar injection
kubectl get pod -n test-app -l app=httpbin -o jsonpath='{.items[0].spec.containers[*].name}'
# Expected: httpbin istio-proxy (two containers)
```

---

### Configure Gateway and VirtualService

```bash
# Create Gateway resource
kubectl apply -n test-app -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: httpbin-gateway
spec:
  selector:
    app: istio-ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "httpbin.example.com"
EOF

# Create VirtualService
kubectl apply -n test-app -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin
spec:
  hosts:
  - "httpbin.example.com"
  gateways:
  - httpbin-gateway
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF
```

---

### Test External Access

```bash
# Get gateway IP
GATEWAY_IP=$(kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test HTTP request (with Host header)
curl -H "Host: httpbin.example.com" http://$GATEWAY_IP/get

# Expected JSON response from httpbin
```

---

## Step 5: Verify mTLS is Working

### Check mTLS Status

```bash
# View proxy status
istioctl proxy-status

# Check mTLS for httpbin service
istioctl authn tls-check deploy/httpbin.test-app -n test-app

# Expected output (STRICT mode):
# HOST:PORT              STATUS     SERVER     CLIENT     AUTHN POLICY
# httpbin.test-app.svc   OK         mTLS       mTLS       default/istio-system
```

---

### Test mTLS Between Services

```bash
# Deploy sleep pod as a client
kubectl apply -n test-app -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: sleep
  labels:
    app: sleep
spec:
  ports:
  - name: http
    port: 80
  selector:
    app: sleep
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      labels:
        app: sleep
    spec:
      containers:
      - name: sleep
        image: curlimages/curl:latest
        command: ["/bin/sleep", "infinity"]
EOF

# Wait for pod
kubectl wait --for=condition=ready pod -l app=sleep -n test-app --timeout=120s

# Test mTLS connection from sleep to httpbin
kubectl exec -n test-app deploy/sleep -c sleep -- curl -s http://httpbin:8000/get

# Check if connection is encrypted (inspect Envoy access logs)
kubectl logs -n test-app deploy/httpbin -c istio-proxy --tail=5
# Look for "- -" in client cert fields (indicates mTLS)
```

---

## Step 6: Validate FIPS Compliance (Production Only)

### Run FIPS Validation Checklist

```bash
# 1. Check image tags
echo "=== Checking FIPS Images ==="
kubectl get deploy -n istio-system -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.spec.template.spec.containers[0].image)"'

# Expected: All images have "-distroless" suffix

# 2. Verify GOFIPS environment
echo "=== Checking GOFIPS Environment ==="
for pod in $(kubectl get pod -n istio-system -l app=istiod -o name); do
  kubectl exec -n istio-system $pod -c discovery -- env | grep GOFIPS
done
# Expected: GOFIPS=1

# 3. Check BoringSSL in Envoy
echo "=== Validating BoringSSL ==="
ISTIOD_POD=$(kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config bootstrap -n istio-system $ISTIOD_POD | grep -i boring
# Expected: References to BoringSSL/CryptoMb

# 4. Verify mTLS cipher suites
echo "=== Checking TLS Ciphers ==="
GW_POD=$(kubectl get pod -n istio-system -l app=istio-ingressgateway -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config listener $GW_POD -n istio-system -o json | \
  jq '.[].filterChains[].tlsContext.commonTlsContext.tlsParams' | head -20
# Expected: Only FIPS-approved ciphers (AES-GCM)
```

---

## Step 7: Enable Observability (Optional)

### Install Prometheus and Grafana

```bash
# Add Prometheus community Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open http://localhost:3000 (admin/prom-operator)

# Import Istio dashboards (IDs: 7639, 7636, 7630)
```

---

### View Istio Metrics

```bash
# Port-forward istiod metrics
kubectl port-forward -n istio-system deploy/istiod 15014:15014

# Open http://localhost:15014/metrics in browser
# Metrics: pilot_xds_pushes, pilot_k8s_cfg_events, etc.
```

---

## Troubleshooting

### Issue: Pods Not Getting Sidecar

**Symptom:**
```bash
kubectl get pod -n test-app -l app=httpbin -o jsonpath='{.items[0].spec.containers[*].name}'
# Output: httpbin (missing istio-proxy)
```

**Resolution:**
```bash
# Check namespace label
kubectl get namespace test-app --show-labels
# Must have: istio-injection=enabled

# If missing, add label and recreate pod
kubectl label namespace test-app istio-injection=enabled
kubectl rollout restart deployment httpbin -n test-app
```

---

### Issue: Gateway Not Getting External IP

**Symptom:**
```bash
kubectl get svc -n istio-system istio-ingressgateway
# EXTERNAL-IP shows <pending>
```

**Resolution:**
```bash
# Check Azure Load Balancer status
az network lb list --resource-group MC_<rg>_<cluster>_<location> -o table

# Check service events
kubectl describe svc -n istio-system istio-ingressgateway

# If stuck, delete and recreate
helm uninstall istio-ingressgateway -n istio-system
helm install istio-ingressgateway . -n istio-system -f values-prod.yaml --wait
```

---

### Issue: mTLS Not Enforced

**Symptom:**
```bash
istioctl authn tls-check deploy/httpbin.test-app
# Shows: CLIENT: PLAINTEXT
```

**Resolution:**
```bash
# Check PeerAuthentication policy
kubectl get peerauthentication -n istio-system

# If missing, reinstall istiod with correct values
helm upgrade istiod charts/istio/istiod -n istio-system -f values-prod.yaml
```

---

## Cleanup

### Remove Test Workload

```bash
kubectl delete namespace test-app
```

---

### Uninstall Istio (Complete)

```bash
# IMPORTANT: Uninstall in reverse order!

# 1. Delete gateway
helm uninstall istio-ingressgateway -n istio-system

# 2. Delete control plane
helm uninstall istiod -n istio-system

# 3. Delete CRDs (WARNING: Deletes all Istio configurations!)
helm uninstall istio-base -n istio-system

# 4. Delete namespace
kubectl delete namespace istio-system

# Verify cleanup
kubectl get crds | grep istio.io
# Should return no results
```

---

## Step 7 (Optional): Install Kiali for Mesh Observability

Kiali provides mesh visualization, traffic metrics, and configuration validation. This step is **optional** and can be skipped for:
- Air-gapped environments without access to Kiali images
- Dev environments using `istioctl` directly
- Cost-constrained clusters (< 3 nodes)
- Classified environments pending RBAC approval

### Install Kiali

```bash
# Production: Install with token authentication
helm install kiali charts/istio/kiali \
  --namespace istio-system \
  -f charts/istio/kiali/values-prod.yaml \
  --wait

# Verify Kiali deployment
kubectl get pods -n istio-system -l app=kiali
kubectl get svc -n istio-system kiali

# Check Kiali logs
kubectl logs -n istio-system -l app=kiali
```

### Access Kiali UI

**Option 1: Port Forward (Dev/Staging)**
```bash
kubectl port-forward -n istio-system svc/kiali 20001:20001

# Access Kiali UI
open http://localhost:20001
```

**Option 2: LoadBalancer (Production)**
```bash
# Get external IP
kubectl get svc -n istio-system kiali

# Access via external IP (configure DNS as needed)
# Example: https://kiali.example.com
```

**Option 3: Ingress (Production)**
```yaml
# Create Ingress for Kiali
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kiali-ingress
  namespace: istio-system
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx  # or traefik
  tls:
  - hosts:
    - kiali.example.com
    secretName: kiali-tls
  rules:
  - host: kiali.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kiali
            port:
              number: 20001
```

### Authenticate to Kiali

**Token Strategy (Recommended for Production):**
```bash
# Get Kiali ServiceAccount token
kubectl -n istio-system create token kiali --duration=24h

# Copy token and paste in Kiali login page
```

**Anonymous Access (Dev Only):**
```yaml
# values-dev.yaml - WARNING: Do not use in production
auth:
  strategy: anonymous
```

### Verify Kiali Features

1. **Mesh Topology**: View graph of services and traffic flows
   - Graph → Namespace → Select test-app namespace
   - See httpbin → nginx connections with request rates

2. **Traffic Metrics**: Check service-level metrics
   - Applications → httpbin → Inbound Metrics
   - View request rate, latency, error rate

3. **mTLS Status**: Verify mesh security
   - Graph → Display → Security → Show
   - Lock icons indicate mTLS is active

4. **Configuration Validation**: Check for misconfigurations
   - Istio Config → VirtualServices
   - Warnings/errors appear for invalid configs

5. **Distributed Tracing** (if Jaeger configured):
   - Workloads → Select pod → Traces tab
   - View end-to-end request paths

### Kiali Troubleshooting

**Kiali pod not starting:**
```bash
# Check events
kubectl describe pod -n istio-system -l app=kiali

# Common issues:
# - istiod not healthy (Kiali requires control plane)
# - RBAC permissions missing (check ClusterRole/ClusterRoleBinding)
# - ConfigMap misconfigured (check external_services.istio settings)
```

**Kiali UI shows no services:**
```bash
# Verify Kiali can access istiod
kubectl exec -n istio-system -l app=kiali -- curl -s http://istiod.istio-system:15014/version

# Check Kiali RBAC
kubectl auth can-i get virtualservices.networking.istio.io --as=system:serviceaccount:istio-system:kiali -n istio-system
```

**Authentication fails:**
```bash
# Token expired - generate new token
kubectl -n istio-system create token kiali --duration=168h  # 7 days

# For OpenID Connect issues, check Kiali ConfigMap auth settings
kubectl get cm -n istio-system kiali -o yaml | grep -A 10 auth
```

---

## Step 8: Cleanup

Delete Istio installation in reverse order:

```bash
# 1. Delete optional Kiali (if installed)
helm uninstall kiali -n istio-system

# 2. Delete gateway
helm uninstall istio-ingressgateway -n istio-system

# 3. Delete control plane
helm uninstall istiod -n istio-system

# 4. Delete CRDs (WARNING: Deletes all Istio configurations!)
helm uninstall istio-base -n istio-system

# 5. Delete namespace
kubectl delete namespace istio-system

# Verify cleanup
kubectl get crds | grep istio.io
# Should return no results
```

---

## Next Steps

- **Security Hardening**: Review [security-baseline.md](./contracts/security-baseline.md) for additional policies
- **FIPS Validation**: Run full compliance check from [fips-validation.md](./contracts/fips-validation.md)
- **Production Deployment**: Use GitOps (ArgoCD/Flux) to manage Istio installations
- **Advanced Observability**: 
  - Install Prometheus for metrics storage (if not already present)
  - Install Grafana for custom dashboards
  - Install Jaeger for distributed tracing
  - Configure Kiali to integrate with all three
- **Upgrade Planning**: Follow [chart-structure.md](./contracts/chart-structure.md) upgrade sequence

---

## Reference Commands

```bash
# Check Istio version
istioctl version

# View mesh configuration
kubectl get configmap istio -n istio-system -o yaml

# Debug sidecar injection
istioctl analyze -n test-app

# Check proxy sync status
istioctl proxy-status

# View proxy configuration
istioctl proxy-config all <pod-name> -n <namespace>

# Generate bug report
istioctl bug-report

# Validate mesh config
istioctl validate -f <resource.yaml>
```

---

## Success Criteria

✅ **Installation Complete** when:
1. All three charts are deployed (base, istiod, gateway)
2. istiod pods are running and healthy
3. Gateway has an external IP assigned
4. Test workload has sidecar injected
5. mTLS is enforced (STRICT mode in production)
6. FIPS validation passes (production only)
7. External traffic reaches test application through gateway

**Congratulations!** You now have a production-ready Istio service mesh on AKS with FIPS compliance and security baseline. 🎉
