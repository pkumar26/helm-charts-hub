# Istio on AKS Deployment and Upgrade Guide

Complete guide for deploying and upgrading Istio service mesh on Azure Kubernetes Service (AKS) using Helm charts with FIPS 140-2 compliance support.

## Table of Contents

- [Version Compatibility](#version-compatibility)
- [Why Helm over istioctl?](#why-helm-over-istioctl)
- [Initial Deployment](#initial-deployment)
  - [Sidecar Mode Installation](#step-by-step-installation)
  - [Ambient Mode with Gateway API](#alternative-ambient-mode-with-gateway-api)
- [Multi-Environment Deployment Strategy](#multi-environment-deployment-strategy)
- [Upgrade Guide](#upgrade-guide)
- [Pre-Upgrade Checklist](#pre-upgrade-checklist)
- [Upgrade Procedures](#upgrade-procedures)
- [Post-Upgrade Validation](#post-upgrade-validation)
- [Rollback Procedures](#rollback-procedures)
- [Troubleshooting](#troubleshooting)

---

## Version Compatibility

### Istio Component Compatibility Matrix

| Istio Version | Base Chart | Istiod Chart | Gateway Chart | Kubernetes | AKS |
|---------------|------------|--------------|---------------|------------|-----|
| **1.30.x** | 1.30.x | 1.30.x | 1.30.x | 1.27-1.31 | 1.29+ |
| **1.29.x** | 1.29.x | 1.29.x | 1.29.x | 1.26-1.30 | 1.28+ |
| **1.28.x** | 1.28.x | 1.28.x | 1.28.x | 1.25-1.29 | 1.27+ |

**Critical Rules:**
- ✅ **All components must be on the same minor version** (e.g., all 1.30.x)
- ✅ **Control plane can manage proxies up to 2 versions older** (e.g., 1.30 control plane with 1.28 proxies)
- ❌ **N-1 version skew is NOT supported** between base and istiod
- ✅ **Patch version differences are acceptable** (e.g., 1.30.0 and 1.30.2)

### Helm Chart Versions

| Chart | Version | Istio Version | Status | Mode |
|-------|---------|---------------|--------|------|
| istio/base | 1.0.0 | 1.30.0 | Stable | Both |
| istio/istiod | 1.0.0 | 1.30.0 | Stable | Both |
| istio/gateway | 1.0.0 | 1.30.0 | Stable | Sidecar |
| istio/gateway-api | 0.2.0 | 1.30.0 | Stable | Ambient |
| istio/kiali | 1.1.0 | 2.10.0 | Optional | Both |

**Note**: `gateway` chart is for sidecar mode (VirtualService/Gateway). `gateway-api` chart is for ambient mode (Gateway API).

### AKS Kubernetes Version Support

| AKS Version | Support Status | Istio Compatibility | FIPS Support |
|-------------|----------------|---------------------|--------------|
| 1.31.x | Preview | 1.30.x | ✅ Yes |
| 1.30.x | GA | 1.29.x, 1.30.x | ✅ Yes |
| 1.29.x | GA | 1.28.x, 1.29.x | ✅ Yes |
| 1.28.x | GA | 1.28.x | ✅ Yes |
| 1.27.x | Deprecated | 1.27.x | ✅ Yes |

**Recommendation**: Use AKS 1.29+ for production workloads.

---

## Why Helm over istioctl?

This repository uses Helm for Istio deployment instead of `istioctl`. While `istioctl` is simpler for quick installations, Helm provides significant advantages for production and enterprise environments.

### Key Advantages of Helm

#### 1. GitOps & CI/CD Integration
- **Native support** in GitOps tools (ArgoCD, Flux, Jenkins X)
- **Declarative configuration** version-controlled alongside application code
- **Seamless CI/CD integration** without custom scripting
- `istioctl` requires custom scripts and workarounds for automation

#### 2. Environment-Based Configuration
```bash
# Dev: Single replica, PERMISSIVE mTLS
./install-istio-ambient.sh --environment dev

# Production: 3 replicas, STRICT mTLS, FIPS compliance
./install-istio-ambient.sh --environment production
```
- Separate values files for dev/staging/production
- Consistent deployment patterns across environments
- Easy configuration comparison and auditing
- With `istioctl`, requires managing multiple IstioOperator YAML files

#### 3. Release Management & Rollback
```bash
helm list -n istio-system                    # See deployed releases
helm history istiod -n istio-system          # View release history
helm rollback istiod 2 -n istio-system       # One-command rollback
```
- Built-in release versioning and history
- Simple rollback to any previous revision
- Track deployment metadata (who, when, what)
- `istioctl` requires manual kubectl operations for rollback

#### 4. Granular Component Control
```bash
helm upgrade istiod charts/istio/istiod --values new-values.yaml     # Update only istiod
helm upgrade gateway-api charts/istio/gateway-api --reuse-values     # Update only gateway
```
- Install/upgrade/delete components independently
- Each component is a separate Helm release
- Easier troubleshooting and staged rollouts
- `istioctl install` typically updates the entire mesh

#### 5. Multi-Cluster & Multi-Tenant Management
```bash
# Same chart, different configurations
helm install istiod charts/istio/istiod -n istio-system-team-a --values team-a.yaml
helm install istiod charts/istio/istiod -n istio-system-team-b --values team-b.yaml
```
- Consistent patterns across clusters
- Tools like Helmfile for multi-cluster deployments
- Manage multiple Istio installations easily

#### 6. Ecosystem Integration
- **Terraform**: Use `helm_release` provider for IaC
- **Monitoring**: Prometheus Operator expects Helm releases
- **Policy**: OPA/Kyverno can validate Helm values pre-deployment
- **Cost Management**: Track costs by Helm release

#### 7. Templating & Customization
- Go templating with conditional logic
- Reusable template functions
- Complex value substitution
- Library charts for shared configuration

#### 8. Dependency Management
```yaml
# Chart.yaml
dependencies:
  - name: base
    version: 1.30.0
  - name: common-lib
    version: 0.1.0
```
- Declare and resolve chart dependencies
- Version locking for reproducible deployments

### When to Use istioctl

**Use istioctl for**:
- Quick demos or local development
- Istio-specific diagnostics: `istioctl proxy-status`, `istioctl analyze`, `istioctl bug-report`
- IstioOperator CRD preference
- Small teams without GitOps infrastructure

**Use Helm for**:
- Production deployments with multiple environments
- GitOps workflows (ArgoCD, Flux)
- Granular component control
- Multi-cluster management
- Integration with existing Helm-based infrastructure

### Hybrid Approach

Many organizations use both:
- **Helm** for deployment and lifecycle management
- **istioctl** for operational tasks

```bash
# Deployment with Helm
helm upgrade istiod charts/istio/istiod --values production.yaml

# Operations with istioctl
istioctl proxy-status
istioctl analyze -A
istioctl dashboard kiali
```

---

## Initial Deployment

### Complete Cleanup (If Reinstalling)

If you have an existing Istio installation and want to start fresh:

```bash
# 1. Uninstall all Helm releases
helm uninstall gateway-api -n istio-system 2>/dev/null || true
helm uninstall kiali -n istio-system 2>/dev/null || true
helm uninstall istio-ingressgateway -n istio-system 2>/dev/null || true
helm uninstall istiod -n istio-system 2>/dev/null || true
helm uninstall ztunnel -n istio-system 2>/dev/null || true
helm uninstall istio-cni -n istio-system 2>/dev/null || true
helm uninstall istio-base -n istio-system 2>/dev/null || true

# 2. Delete cluster-wide resources
kubectl delete clusterrole,clusterrolebinding -l app.kubernetes.io/part-of=istio --ignore-not-found=true
kubectl delete clusterrole istiod-clusterrole-istio-system istiod-gateway-controller-istio-system \
  istio-reader-clusterrole-istio-system istio-cni istio-cni-ambient istio-cni-repair-role \
  --ignore-not-found=true
kubectl delete clusterrolebinding istiod-clusterrole-istio-system istiod-gateway-controller-istio-system \
  istio-reader-clusterrole-istio-system istio-cni istio-cni-ambient istio-cni-repair-rolebinding \
  --ignore-not-found=true
kubectl delete mutatingwebhookconfiguration istio-sidecar-injector istio-revision-tag-default \
  --ignore-not-found=true
kubectl delete validatingwebhookconfiguration istio-validator-istio-system istiod-default-validator \
  --ignore-not-found=true

# 3. Delete namespace (will remove all remaining resources)
kubectl delete namespace istio-system --ignore-not-found=true

# 4. Wait for namespace deletion to complete
kubectl wait --for=delete namespace/istio-system --timeout=60s 2>/dev/null || true

# 5. Verify cleanup
kubectl get crds | grep istio.io
# Expected: No output (all CRDs removed)
```

### Prerequisites

1. **AKS Cluster** (1.28+)
   ```bash
   az aks create \
     --resource-group my-rg \
     --name my-aks-cluster \
     --kubernetes-version 1.28 \
     --node-count 3 \
     --node-vm-size Standard_D4s_v3 \
     --network-plugin azure \
     --enable-addons monitoring
   ```

2. **FIPS Node Pool** (for production with FIPS compliance)
   ```bash
   az aks nodepool add \
     --resource-group my-rg \
     --cluster-name my-aks-cluster \
     --name fipspool \
     --node-count 3 \
     --node-vm-size Standard_D4s_v3 \
     --enable-fips-image \
     --labels fips=enabled
   ```

3. **Helm 3.10+**
   ```bash
   helm version
   # Version: v3.10.0 or higher
   ```

4. **kubectl**
   ```bash
   az aks get-credentials --resource-group my-rg --name my-aks-cluster
   kubectl version --client
   ```

### Installation Sequence

**CRITICAL**: Components must be installed in this exact order:

**Sidecar Mode (Traditional):**
1. **Base Chart** - CRDs and cluster-wide resources
2. **Istiod Chart** - Control plane
3. **Gateway Chart** - Ingress/egress gateways
4. **Kiali Chart** - (Optional) Mesh observability

**Ambient Mode (Sidecar-less):**
1. **Base Chart** - CRDs and cluster-wide resources (local chart)
2. **CNI Chart** - Istio CNI plugin (official Istio repo) - **REQUIRED before istiod**
3. **Ztunnel Chart** - L4 proxy DaemonSet (official Istio repo) - **REQUIRED before istiod**
4. **Istiod Chart** - Control plane with CNI enabled (local chart)
5. **Gateway API CRDs** - Kubernetes Gateway API
6. **Gateway API Chart** - Gateway/HTTPRoute resources (local chart)
7. **Kiali Chart** - (Optional) Mesh observability (local chart)

See [Alternative: Ambient Mode with Gateway API](#alternative-ambient-mode-with-gateway-api) for ambient mode installation.

### Step-by-Step Installation (Sidecar Mode)

#### 1. Install Base Chart

```bash
helm install istio-base charts/istio/base \
  --namespace istio-system \
  --create-namespace \
  --values charts/istio/base/values-prod.yaml

# Verify CRDs
kubectl get crds | grep istio.io
# Expected: 30+ Istio CRDs
```

#### 2. Install Istiod (Control Plane)

```bash
helm install istiod charts/istio/istiod \
  --namespace istio-system \
  --values charts/istio/istiod/values-prod.yaml \
  --wait \
  --timeout 5m

# Verify control plane
kubectl get pods -n istio-system -l app=istiod
# Expected: 3 istiod pods (READY 1/1)
```

#### 3. Install Gateway

```bash
helm install istio-ingressgateway charts/istio/gateway \
  --namespace istio-system \
  --values charts/istio/gateway/values-prod.yaml \
  --wait \
  --timeout 5m

# Verify gateway
kubectl get pods -n istio-system -l istio=ingressgateway
# Expected: 3 gateway pods (READY 1/1)
```

#### 4. Install Kiali (Optional)

```bash
helm install kiali charts/istio/kiali \
  --namespace istio-system \
  --values charts/istio/kiali/values-prod.yaml \
  --set enabled=true
```

### Post-Installation Validation

```bash
# Check all Istio components
helm list -n istio-system

# Verify proxy status
istioctl proxy-status

# Run configuration analysis
istioctl analyze --all-namespaces

# Check FIPS mode (production)
kubectl exec -n istio-system deploy/istiod -- env | grep GOFIPS
# Expected: GOFIPS=1
```

### Alternative: Ambient Mode with Gateway API

Istio Ambient Mode provides a **sidecar-less** architecture using **ztunnel** (Layer 4) and optional **waypoint proxies** (Layer 7), managed via the Kubernetes Gateway API instead of Istio's legacy VirtualService/Gateway resources.

#### When to Use Ambient Mode

| Use Case | Sidecar Mode | Ambient Mode |
|----------|--------------|--------------|
| **Resource overhead** | Higher (sidecar per pod) | Lower (shared ztunnel DaemonSet) |
| **L7 features** | Always available | Optional (waypoint proxy) |
| **Configuration** | VirtualService/Gateway | Gateway API (HTTPRoute) |
| **Maturity** | Stable (5+ years) | GA (Istio 1.30+) |
| **Migration complexity** | N/A | Moderate (config rewrite) |
| **Best for** | Full L7 control, mature | Cost reduction, L4 mesh |

**Recommendation**: Use **sidecar mode** (above) for production unless you specifically need ambient mode's reduced overhead.

#### Ambient Mode Installation Sequence

**CRITICAL**: Components must be installed in this exact order:

1. **Base Chart** - Istio CRDs (local chart)
2. **CNI Chart** - Istio CNI plugin (official Istio repo) ⚠️ **MUST be installed before istiod**
3. **Istiod Chart** - Control plane with CNI enabled (local chart) - Creates `istio-ca-root-cert` ConfigMap
4. **Ztunnel Chart** - L4 proxy DaemonSet (official Istio repo) ⚠️ **MUST be installed after istiod** (requires CA cert)
5. **Gateway API CRDs** - Kubernetes Gateway API
6. **Gateway API Chart** - Gateway/HTTPRoute resources (local chart)
7. **Kiali Chart** - (Optional) Mesh observability (local chart)

**Important Notes**:
- CNI and ztunnel charts are not included in this repository
- They must be installed from the official Istio Helm repository: `istio/cni` and `istio/ztunnel`
- **Istiod must be installed before ztunnel** - ztunnel requires the `istio-ca-root-cert` ConfigMap created by istiod
- **Do NOT skip CNI** - istiod pods will fail to start without CNI plugin

#### Automated Installation (Recommended)

Use the provided installation script for a complete, properly-ordered ambient mode setup:

```bash
# Development environment (default)
./examples/install-istio-ambient.sh

# Staging environment with Kiali
./examples/install-istio-ambient.sh --environment staging --with-kiali

# Production environment with FIPS compliance
./examples/install-istio-ambient.sh --environment production --with-kiali

# Custom namespace
./examples/install-istio-ambient.sh --environment production --namespace custom-istio
```

**Script Options**:
- `--environment ENV`: Environment configuration (dev, staging, or production, default: dev)
  - **dev**: Single replica, PERMISSIVE mTLS, standard images
  - **staging**: 2 replicas with HPA 2-4, STRICT mTLS, standard images
  - **production**: 3 replicas with HPA 3-5, STRICT mTLS, FIPS-compliant distroless images
- `--namespace NAMESPACE`: Target namespace (default: istio-system)
- `--with-kiali`: Include Kiali observability dashboard (optional)
- `--help`: Show usage information

The automated script handles:
- Official Istio Helm repository setup
- Correct installation order (base → CNI → ztunnel → istiod → Gateway API)
- Environment-specific configuration (dev/staging/production)
- Component health verification
- Gateway API CRDs installation

**Before reinstalling**, use the cleanup script:
```bash
./examples/cleanup-istio.sh
```

#### Manual Step-by-Step Installation

If you prefer manual installation or need to customize individual components:

#### Step-by-Step Ambient Mode Installation

##### 1. Add Official Istio Helm Repository

```bash
# Add official Istio repo for CNI and ztunnel
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update istio

# Verify available charts
helm search repo istio/
```

##### 2. Install Base Chart (Istio CRDs)

```bash
helm install istio-base charts/istio/base \
  --namespace istio-system \
  --create-namespace \
  --values charts/istio/base/values-dev.yaml

# Verify CRDs
kubectl get crds | grep istio.io
# Expected: 14+ Istio CRDs including wasmplugins, virtualservices, gateways, etc.
```

##### 3. Install CNI Plugin

**CRITICAL**: CNI must be installed before istiod in ambient mode.

```bash
helm install istio-cni istio/cni \
  --namespace istio-system \
  --version 1.30.0 \
  --set profile=ambient \
  --wait \
  --timeout 5m

# Verify CNI DaemonSet
kubectl get daemonset -n istio-system istio-cni-node
kubectl get pods -n istio-system -l app=istio-cni
# Expected: istio-cni-node pods running on all nodes (READY 1/1)
```

##### 4. Install Istiod with CNI Enabled

**CRITICAL**: Istiod is required in ambient mode for control plane operations and **must be installed before ztunnel**. Istiod creates the `istio-ca-root-cert` ConfigMap that ztunnel needs.

```bash
helm install istiod charts/istio/istiod \
  --namespace istio-system \
  --values charts/istio/istiod/values-dev.yaml \
  --set global.cni.enabled=true \
  --set pilot.env.PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER=true \
  --wait \
  --timeout 5m

# Verify control plane
kubectl get pods -n istio-system -l app=istiod
# Expected: istiod pod(s) READY 1/1

# Verify Gateway API controller is enabled
kubectl get deploy istiod -n istio-system -o yaml | grep PILOT_ENABLE_GATEWAY_API
# Expected: PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER: "true"

# Verify CA cert ConfigMap was created (required by ztunnel)
kubectl get configmap istio-ca-root-cert -n istio-system
```

##### 5. Install Ztunnel (L4 Proxy)

**Ztunnel** provides Layer 4 mTLS and is the core component of ambient mode. **Must be installed after istiod** because it requires the `istio-ca-root-cert` ConfigMap.

```bash
helm install ztunnel istio/ztunnel \
  --namespace istio-system \
  --version 1.30.0 \
  --wait \
  --timeout 5m

# Verify ztunnel DaemonSet
kubectl get daemonset -n istio-system ztunnel
kubectl get pods -n istio-system -l app=ztunnel
# Expected: ztunnel pods running on all nodes (READY 1/1)

# If ztunnel pods fail with "configmap istio-ca-root-cert not found",
# verify istiod is running and created the ConfigMap:
kubectl get pods -n istio-system -l app=istiod
kubectl get configmap istio-ca-root-cert -n istio-system
```

##### 6. Install Gateway API CRDs

```bash
# Check if Gateway API CRDs already exist
kubectl get crd gateways.gateway.networking.k8s.io 2>/dev/null

# If not present, install Gateway API CRDs v1.2.0
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# Verify Gateway API CRDs
kubectl get crd | grep gateway.networking.k8s.io
# Expected: gatewayclasses, gateways, httproutes, referencegrants
```

##### 7. Install Gateway API Chart

```bash
helm install gateway-api charts/istio/gateway-api \
  --namespace istio-system \
  --values charts/istio/gateway-api/values-dev.yaml \
  --wait \
  --timeout 5m

# Verify Gateway resource
kubectl get gateway -n istio-system
# Expected: istio-gateway with PROGRAMMED=True (may take 30-60s)

# Get Gateway external IP
kubectl get svc -n istio-system -l istio.io/gateway-name=istio-gateway
# Expected: LoadBalancer service with EXTERNAL-IP
```

##### 8. Install Kiali (Optional)

```bash
helm install kiali charts/istio/kiali \
  --namespace istio-system \
  --values charts/istio/kiali/values-dev.yaml

# Access Kiali dashboard
kubectl port-forward -n istio-system svc/kiali 20001:20001
# Open http://localhost:20001
```

#### Ambient Mode Validation

```bash
# Check all Istio components
helm list -n istio-system
# Expected: istio-base, istio-cni, ztunnel, istiod, gateway-api

# Verify all pods are running
kubectl get pods -n istio-system
# Expected: All pods in Running state

# Verify ztunnel (L4 proxy) is running on all nodes
kubectl get daemonset -n istio-system ztunnel
kubectl get pods -n istio-system -l app=ztunnel
# Expected: 1 ztunnel pod per node (READY 1/1)

# Verify CNI plugin
kubectl get daemonset -n istio-system istio-cni-node
kubectl get pods -n istio-system -l app=istio-cni
# Expected: 1 istio-cni-node pod per node (READY 1/1)

# Verify Gateway API controller is enabled
kubectl get deploy istiod -n istio-system -o yaml | grep PILOT_ENABLE_GATEWAY_API
# Expected: PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER: "true"

# Test Gateway connectivity
GATEWAY_IP=$(kubectl get svc -n istio-system -l istio.io/gateway-name=istio-gateway \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
echo "Gateway IP: $GATEWAY_IP"
curl -I http://$GATEWAY_IP/healthz/ready
# Expected: HTTP 404 (gateway is ready but no routes configured)

# Verify Gateway API resources
kubectl get gateway,httproute -A
# Expected: Gateway in istio-system namespace

# Check control plane status
istioctl proxy-status
# Expected: No sidecars (ambient mode uses ztunnel)

# Run configuration analysis
istioctl analyze --all-namespaces
# Expected: No validation errors
```

#### Adding Workloads to Ambient Mesh

```bash
# Label namespace for ambient mode (L4 mTLS via ztunnel)
kubectl label namespace my-app istio.io/dataplane-mode=ambient

# Verify ztunnel captures traffic
kubectl get pods -n my-app -o yaml | grep istio.io/dataplane-mode
# Expected: ambient

# (Optional) Deploy waypoint proxy for L7 features
istioctl x waypoint apply -n my-app --name my-app-waypoint

# Verify waypoint proxy
kubectl get pods -n my-app -l gateway.istio.io/managed=istio.io-mesh-controller
```

#### Sidecar vs Ambient Comparison

| Feature | Sidecar Mode | Ambient Mode |
|---------|--------------|--------------|
| **Deployment** | Sidecar per pod | Shared ztunnel DaemonSet |
| **L4 mTLS** | ✅ istio-proxy | ✅ ztunnel |
| **L7 routing** | ✅ istio-proxy | ⚠️ Optional (waypoint) |
| **Resource overhead** | High (~200MB per pod) | Low (~50MB per node) |
| **Configuration API** | VirtualService/Gateway | Gateway API (HTTPRoute) |
| **Upgrade complexity** | Pod restarts required | ztunnel DaemonSet rolling update |
| **Maturity** | Stable | GA (1.30+) |
| **Gateway chart** | `istio/gateway` | `istio/gateway-api` |

#### Migration from Sidecar to Ambient

If you're migrating an existing sidecar-mode deployment to ambient:

1. **Backup configurations**:
   ```bash
   kubectl get virtualservices,destinationrules,gateways -A -o yaml > backup-istio-configs.yaml
   ```

2. **Convert VirtualService → HTTPRoute** (manual):
   - Rewrite routing rules using Gateway API syntax
   - Replace `spec.http.match` with `matches`
   - Replace `spec.http.route` with `rules.backendRefs`

3. **Install ambient mode** (follow steps above)

4. **Migrate workloads gradually**:
   ```bash
   # Remove sidecar injection label
   kubectl label namespace my-app istio-injection-

   # Add ambient label
   kubectl label namespace my-app istio.io/dataplane-mode=ambient

   # Restart pods
   kubectl rollout restart deployment -n my-app
   ```

5. **Validate traffic flow** and test L7 features

6. **Remove legacy gateway** (if using Gateway API exclusively):
   ```bash
   helm uninstall istio-ingressgateway -n istio-system
   ```

---

## Multi-Environment Deployment Strategy

Istio charts support **progressive security** across development, staging, and production environments using environment-specific values files.

### Environment Comparison

| Feature | Development | Staging | Production |
|---------|-------------|---------|------------|
| **Purpose** | Local testing, rapid iteration | Pre-production validation | Production workloads |
| **Replicas** | 1 per component | 2 per component | 3 per component |
| **Autoscaling** | Disabled | HPA 2-4 replicas | HPA 3-5 replicas |
| **mTLS Mode** | PERMISSIVE | STRICT | STRICT |
| **FIPS** | Disabled | Disabled | ✅ Enabled |
| **Security** | Minimal | Moderate | Full baseline |
| **Resources** | Minimal (250m CPU) | Moderate (500m CPU) | Production (500m-1000m CPU) |
| **Anti-Affinity** | None | Preferred | Required |
| **Monitoring** | Optional | Recommended | Required |
| **Auth (Kiali)** | Anonymous | Token | Token/OpenID |

### Development Environment

**Use case**: Rapid development, local testing, debugging

**Characteristics**:
- Single replica for all components (cost-effective)
- PERMISSIVE mTLS (allows both plaintext and mTLS traffic)
- No FIPS compliance requirement
- Minimal resource requests (250m CPU, 512Mi memory)
- Anonymous authentication for Kiali
- Suitable for quick iteration cycles

**Deployment**:
```bash
# Using automated script
./examples/deploy-istio-dev.sh --namespace istio-system --with-kiali

# Or manual deployment
helm install istio-base charts/istio/base \
  --namespace istio-system --create-namespace \
  --values charts/istio/base/values-dev.yaml

helm install istiod charts/istio/istiod \
  --namespace istio-system \
  --values charts/istio/istiod/values-dev.yaml \
  --wait

helm install istio-ingressgateway charts/istio/gateway \
  --namespace istio-system \
  --values charts/istio/gateway/values-dev.yaml \
  --wait
```

**Validation**:
```bash
# Verify single replica
kubectl get pods -n istio-system -l app=istiod
# Expected: 1 istiod pod

# Verify PERMISSIVE mTLS
kubectl get peerauthentication -n istio-system -o yaml | grep mode
# Expected: mode: PERMISSIVE

# Check standard images (no FIPS)
kubectl get pods -n istio-system -l app=istiod \
  -o jsonpath='{.items[0].spec.containers[0].image}'
# Expected: docker.io/istio/pilot:1.30.0 (no -distroless suffix)
```

### Staging Environment

**Use case**: Pre-production testing, integration validation, performance testing

**Characteristics**:
- 2 replicas per component (moderate HA)
- HPA enabled (2-4 replicas based on load)
- STRICT mTLS (enforced mutual TLS)
- No FIPS (cost optimization for pre-prod)
- Moderate security baseline
- Token-based Kiali authentication
- Mirrors production topology without FIPS overhead

**Deployment**:
```bash
# Using automated script
./examples/deploy-istio-staging.sh --namespace istio-staging --with-kiali

# Or manual deployment
helm install istio-base charts/istio/base \
  --namespace istio-staging --create-namespace \
  --values charts/istio/base/values-staging.yaml

helm install istiod charts/istio/istiod \
  --namespace istio-staging \
  --values charts/istio/istiod/values-staging.yaml \
  --wait

helm install istio-ingressgateway charts/istio/gateway \
  --namespace istio-staging \
  --values charts/istio/gateway/values-staging.yaml \
  --wait
```

**Validation**:
```bash
# Verify 2 replicas
kubectl get pods -n istio-staging -l app=istiod
# Expected: 2 istiod pods

# Verify STRICT mTLS
kubectl get peerauthentication -n istio-staging -o yaml | grep mode
# Expected: mode: STRICT

# Verify HPA
kubectl get hpa -n istio-staging
# Expected: HPA with min=2, max=4
```

### Production Environment

**Use case**: Production traffic, compliance requirements, mission-critical workloads

**Characteristics**:
- 3 replicas per component (high availability)
- HPA enabled (3-5 replicas based on load)
- STRICT mTLS (enforced mutual TLS)
- **FIPS 140-2 compliance** (distroless images with BoringSSL/Certificate #4407)
- Full security baseline (PeerAuthentication, AuthorizationPolicy, NetworkPolicy)
- Pod anti-affinity across availability zones
- Production resource limits (500m-1000m CPU, 1-2Gi memory)
- Token or OpenID authentication for Kiali
- Requires FIPS-enabled node pool

**Prerequisites**:
```bash
# Create FIPS node pool
az aks nodepool add \
  --resource-group my-rg \
  --cluster-name my-aks-cluster \
  --name fipspool \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-fips-image \
  --labels fips=enabled
```

**Deployment**:
```bash
# Using automated script (recommended)
./examples/deploy-istio-production.sh --namespace istio-system --with-kiali

# Or manual deployment
helm install istio-base charts/istio/base \
  --namespace istio-system --create-namespace \
  --values charts/istio/base/values-prod.yaml

helm install istiod charts/istio/istiod \
  --namespace istio-system \
  --values charts/istio/istiod/values-prod.yaml \
  --wait --timeout 10m

helm install istio-ingressgateway charts/istio/gateway \
  --namespace istio-system \
  --values charts/istio/gateway/values-prod.yaml \
  --wait --timeout 10m
```

**Validation**:
```bash
# Verify 3 replicas
kubectl get pods -n istio-system -l app=istiod -o wide
# Expected: 3 istiod pods spread across zones

# Verify STRICT mTLS
kubectl get peerauthentication -n istio-system -o yaml | grep mode
# Expected: mode: STRICT

# Verify FIPS images
kubectl get pods -n istio-system -l app=istiod \
  -o jsonpath='{.items[0].spec.containers[0].image}'
# Expected: docker.io/istio/pilot:1.30.0-distroless

# Verify FIPS environment
kubectl get pods -n istio-system -l app=istiod \
  -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="GOFIPS")].value}'
# Expected: 1

# Verify security policies
kubectl get peerauthentication,authorizationpolicy,networkpolicy -n istio-system
# Expected: Multiple policies enforcing security baseline

# Verify pod anti-affinity
kubectl get pods -n istio-system -l app=istiod -o yaml | grep -A 5 podAntiAffinity
# Expected: requiredDuringSchedulingIgnoredDuringExecution

# Verify HPA
kubectl get hpa -n istio-system
# Expected: HPA with min=3, max=5
```

### Migration Path: Dev → Staging → Production

**Phase 1: Development**
1. Deploy with dev values for initial testing
2. Verify sidecar injection works
3. Test application connectivity with PERMISSIVE mTLS
4. Debug any issues with minimal overhead

**Phase 2: Staging**
1. Deploy to staging namespace with STRICT mTLS
2. Verify applications work with enforced mutual TLS
3. Performance test with HPA under load
4. Validate security policies don't block legitimate traffic
5. Test upgrade procedures

**Phase 3: Production**
1. Create FIPS node pool (if required)
2. Deploy with production values
3. Verify FIPS compliance
4. Validate full security baseline
5. Monitor performance and adjust HPA thresholds
6. Document runbooks and operational procedures

### Environment-Specific Configuration Examples

**Development - Gradual mTLS Adoption**:
```yaml
# istiod values-dev.yaml
global:
  mtls:
    mode: PERMISSIVE  # Allow both plaintext and mTLS

replicaCount: 1
autoscaling:
  enabled: false

resources:
  requests:
    cpu: 250m
    memory: 512Mi
```

**Staging - Pre-Production Testing**:
```yaml
# istiod values-staging.yaml
global:
  mtls:
    mode: STRICT  # Enforce mTLS

replicaCount: 2
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 4

resources:
  requests:
    cpu: 500m
    memory: 1Gi
```

**Production - Full Security**:
```yaml
# istiod values-prod.yaml
global:
  fips:
    enabled: true  # FIPS 140-2 compliance
  mtls:
    mode: STRICT

replicaCount: 3
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 5

podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution: true

security:
  peerAuthentication:
    enabled: true  # STRICT mTLS
  authorizationPolicy:
    enabled: true  # Default-deny + allowlists
  networkPolicy:
    enabled: true  # L3/L4 isolation

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: "1"
    memory: 2Gi

nodeSelector:
  fips: enabled  # Schedule on FIPS node pool
```

### Deployment Scripts Reference

| Environment | Script | Command |
|-------------|--------|---------|
| **Development** | `examples/deploy-istio-dev.sh` | `./examples/deploy-istio-dev.sh --with-kiali` |
| **Staging** | `examples/deploy-istio-staging.sh` | `./examples/deploy-istio-staging.sh --with-kiali` |
| **Production** | `examples/deploy-istio-production.sh` | `./examples/deploy-istio-production.sh --with-kiali --dry-run` |

**Script Features**:
- ✅ Prerequisites checking (kubectl, helm, cluster connectivity)
- ✅ Namespace creation and labeling
- ✅ Sequential component installation (base → istiod → gateway)
- ✅ Post-deployment validation
- ✅ Optional Kiali installation
- ✅ Production readiness checklist (for production script)
- ✅ FIPS node pool verification (for production script)
- ✅ Dry-run mode (for production script)
- ✅ Color-coded output and progress tracking

### Cost Optimization Considerations

**Development**:
- Single replicas: ~70% cost reduction vs production
- No FIPS overhead: Standard images
- Minimal resources: 250m CPU, 512Mi memory per component
- **Monthly cost**: ~$30-50 (assuming Standard_D2s_v3 nodes)

**Staging**:
- 2 replicas: ~50% cost reduction vs production
- No FIPS: Cost optimization for pre-prod
- Moderate resources: 500m CPU, 1Gi memory
- **Monthly cost**: ~$100-150

**Production**:
- 3 replicas + HPA: Full HA configuration
- FIPS enabled: Requires FIPS node pool
- Production resources: 500m-1000m CPU, 1-2Gi memory
- **Monthly cost**: ~$200-300 (base infrastructure)

**Recommendation**: Use development for local testing, staging for pre-release validation, production only for live traffic.

---

## Upgrade Guide

### Upgrade Strategy

Istio supports **in-place upgrades** and **canary upgrades**:

| Strategy | Use Case | Downtime | Risk | Rollback |
|----------|----------|----------|------|----------|
| **In-Place** | Minor patches, dev/staging | ~30 seconds | Low | Helm rollback |
| **Canary** | Major versions, production | Zero | Very Low | Revision switch |

### When to Upgrade

- **Security patches**: Upgrade within 7 days
- **Bug fixes**: Upgrade within 30 days
- **Feature releases**: Test thoroughly, upgrade in maintenance window
- **Major versions**: Use canary upgrade approach

---

## Pre-Upgrade Checklist

Complete this checklist before any upgrade:

### 1. Review Release Notes

- [ ] Read [Istio release notes](https://istio.io/latest/news/releases/) for target version
- [ ] Check for breaking changes
- [ ] Review deprecated APIs
- [ ] Note any configuration changes required
- [ ] Check for known issues

### 2. Backup Current State

```bash
# Backup Helm release values
helm get values istio-base -n istio-system > backup-base-values.yaml
helm get values istiod -n istio-system > backup-istiod-values.yaml
helm get values istio-ingressgateway -n istio-system > backup-gateway-values.yaml

# Backup CRDs
kubectl get crds -o yaml > backup-istio-crds.yaml

# Backup Istio configurations
kubectl get virtualservices,destinationrules,gateways,serviceentries --all-namespaces -o yaml > backup-istio-configs.yaml

# Backup deployment state
kubectl get deployments,services,pods -n istio-system -o yaml > backup-istio-deployments.yaml
```

### 3. Verify Current Health

```bash
# Check all pods are healthy
kubectl get pods -n istio-system

# Verify no config errors
istioctl analyze --all-namespaces

# Check proxy sync status
istioctl proxy-status | grep -v SYNCED
# Expected: No output (all proxies synced)

# Review recent errors
kubectl logs -n istio-system -l app=istiod --tail=100 | grep -i error

# Check metrics
kubectl exec -n istio-system deploy/istiod -- \
  curl -s localhost:15014/metrics | grep pilot_xds_push_errors
```

### 4. Test in Non-Production

- [ ] Upgrade dev environment first
- [ ] Run integration tests
- [ ] Validate application functionality
- [ ] Monitor for 24 hours
- [ ] Repeat in staging environment

### 5. Plan Maintenance Window

- [ ] Schedule during low-traffic period
- [ ] Notify stakeholders
- [ ] Prepare rollback plan
- [ ] Assign on-call team
- [ ] Document expected duration

### 6. Verify Dependencies

```bash
# Check Kubernetes version compatibility
kubectl version

# Verify Helm version
helm version

# Check node pool readiness (for FIPS)
kubectl get nodes -l fips=enabled

# Verify monitoring is functional
kubectl get pods -n monitoring  # Prometheus, Grafana
```

### 7. Prepare Rollback Plan

- [ ] Document current versions: `helm list -n istio-system`
- [ ] Test rollback in dev: `helm rollback istiod 1 -n istio-system`
- [ ] Identify rollback triggers (error rate > 5%, latency > 2x baseline)
- [ ] Prepare communication templates
- [ ] Assign rollback decision maker

---

## Upgrade Procedures

### Option A: In-Place Upgrade (Recommended for Patches)

Use for patch upgrades (e.g., 1.23.0 → 1.23.1) with minimal risk.

#### Step 1: Upgrade Base Chart

```bash
# Update chart dependencies
cd charts/istio/base
helm dependency update

# Dry-run upgrade
helm upgrade istio-base . \
  --namespace istio-system \
  --values values-prod.yaml \
  --dry-run --debug | less

# Apply upgrade
helm upgrade istio-base . \
  --namespace istio-system \
  --values values-prod.yaml

# Verify CRDs updated
kubectl get crds | grep istio.io
```

**Wait 2 minutes for CRD propagation**

#### Step 2: Upgrade Istiod (Control Plane)

```bash
cd ../istiod
helm dependency update

# Upgrade istiod
helm upgrade istiod . \
  --namespace istio-system \
  --values values-prod.yaml \
  --wait \
  --timeout 5m

# Verify upgrade
kubectl get pods -n istio-system -l app=istiod
kubectl logs -n istio-system -l app=istiod --tail=50
```

**Wait for all istiod pods to be READY (1/1)**

#### Step 3: Upgrade Gateway

```bash
cd ../gateway

# Upgrade gateway with zero-downtime settings
helm upgrade istio-ingressgateway . \
  --namespace istio-system \
  --values values-prod.yaml \
  --set gateway.rollingUpdate.maxSurge=1 \
  --set gateway.rollingUpdate.maxUnavailable=0 \
  --wait \
  --timeout 5m

# Verify gateway
kubectl rollout status deployment istio-ingressgateway -n istio-system
```

#### Step 4: Restart Workload Sidecars (if needed)

```bash
# Check sidecar versions
istioctl proxy-status

# Restart deployments to get new sidecars (only if sidecar version matters)
kubectl rollout restart deployment -n my-app
kubectl rollout status deployment -n my-app
```

### Option B: Canary Upgrade (Recommended for Major Versions)

Use for major/minor upgrades (e.g., 1.22.x → 1.23.x) with zero downtime.

See detailed canary upgrade procedure in [charts/istio/istiod/README.md](../charts/istio/istiod/README.md#canary-upgrades).

**Summary:**
1. Install new istiod revision alongside old version
2. Tag revisions (stable, canary)
3. Test with canary namespace
4. Gradually migrate workloads (10% → 25% → 50% → 100%)
5. Monitor metrics at each step
6. Complete migration and remove old revision

### Upgrade Command Summary

```bash
# One-command upgrade (use with caution)
./examples/upgrade-istio.sh --version 1.23.0 --environment production

# Or step-by-step
helm upgrade istio-base charts/istio/base -n istio-system -f charts/istio/base/values-prod.yaml
sleep 120
helm upgrade istiod charts/istio/istiod -n istio-system -f charts/istio/istiod/values-prod.yaml --wait
helm upgrade istio-ingressgateway charts/istio/gateway -n istio-system -f charts/istio/gateway/values-prod.yaml --wait
```

---

## Post-Upgrade Validation

### Validation Checklist

Execute these checks after each upgrade:

#### 1. Component Health

```bash
# All pods running
kubectl get pods -n istio-system
# Expected: All READY 1/1 or 2/2

# Helm releases updated
helm list -n istio-system
# Expected: All charts showing new version

# Check resource versions
istioctl version
# Expected: Control plane and data plane versions match
```

#### 2. Control Plane Validation

```bash
# Istiod health
kubectl get pods -n istio-system -l app=istiod
kubectl logs -n istio-system -l app=istiod --tail=100 | grep -i error

# Webhook configuration
kubectl get validatingwebhookconfiguration istiod-default-validator
kubectl get mutatingwebhookconfiguration istio-sidecar-injector

# XDS push metrics
kubectl exec -n istio-system deploy/istiod -- \
  curl -s localhost:15014/metrics | grep -E "pilot_xds_push|pilot_proxy_convergence"
```

#### 3. Data Plane Validation

```bash
# Proxy sync status
istioctl proxy-status
# Expected: All proxies show SYNCED

# Sidecar injection working
kubectl run test-nginx --image=nginx -n default --labels="app=test" --dry-run=client -o yaml | \
  istioctl kube-inject -f - | kubectl apply -f -
kubectl get pods test-nginx -o jsonpath='{.spec.containers[*].name}'
# Expected: nginx, istio-proxy

# Cleanup
kubectl delete pod test-nginx
```

#### 4. Gateway Validation

```bash
# Gateway service
kubectl get svc istio-ingressgateway -n istio-system

# Test gateway connectivity
GATEWAY_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -I http://$GATEWAY_IP/healthz/ready
# Expected: HTTP/1.1 200 OK

# Envoy admin interface
kubectl exec -n istio-system deploy/istio-ingressgateway -- \
  curl -s localhost:15000/stats | grep "^listener\."
```

#### 5. mTLS Verification

```bash
# Verify mTLS is enabled
kubectl get peerauthentication --all-namespaces

# Check certificate rotation
kubectl exec -n istio-system deploy/istiod -- \
  curl -s localhost:15014/metrics | grep citadel_server_csr_count

# Verify workload certificates
istioctl proxy-config secret deploy/my-app -n my-namespace
# Expected: ACTIVE certificates
```

#### 6. Configuration Analysis

```bash
# Run Istio analyzer
istioctl analyze --all-namespaces
# Expected: No errors

# Check for deprecated APIs
kubectl get virtualservices,destinationrules --all-namespaces -o yaml | \
  grep -E "apiVersion.*v1alpha3"
# Expected: No v1alpha3 (use v1beta1)

# Verify CRD versions
kubectl get crds -o custom-columns=NAME:.metadata.name,VERSION:.spec.versions[*].name | grep istio
```

#### 7. Application Testing

```bash
# Deploy test application
kubectl create namespace test-upgrade
kubectl label namespace test-upgrade istio-injection=enabled
kubectl apply -f examples/httpbin.yaml -n test-upgrade

# Test service-to-service communication
kubectl exec -n test-upgrade deploy/httpbin -c istio-proxy -- \
  curl -s http://httpbin:8000/headers

# Verify mTLS between services
istioctl experimental authz check deploy/httpbin -n test-upgrade

# Cleanup
kubectl delete namespace test-upgrade
```

#### 8. Performance Validation

```bash
# Control plane resource usage
kubectl top pods -n istio-system

# XDS push latency
kubectl exec -n istio-system deploy/istiod -- \
  curl -s localhost:15014/metrics | grep pilot_xds_push_time

# Data plane latency (check Grafana or)
kubectl exec -n istio-system deploy/istio-ingressgateway -- \
  curl -s localhost:15000/stats | grep upstream_rq_time
```

### Success Criteria

Upgrade is successful if:
- ✅ All pods are READY and RUNNING
- ✅ All proxies show SYNCED status
- ✅ No configuration errors in `istioctl analyze`
- ✅ Gateway responds to health checks
- ✅ mTLS certificates are valid
- ✅ Application traffic flows normally
- ✅ Error rate < 1% (baseline)
- ✅ P99 latency < 2x baseline

---

## Rollback Procedures

### When to Rollback

Initiate rollback if:
- ❌ Pods stuck in CrashLoopBackOff for > 5 minutes
- ❌ Error rate > 5% sustained for > 2 minutes
- ❌ P99 latency > 3x baseline
- ❌ Proxies not syncing with control plane
- ❌ mTLS certificate failures
- ❌ Gateway rejecting all traffic

### Quick Rollback (In-Place Upgrades)

```bash
# Rollback in reverse order: gateway → istiod → base

# 1. Rollback gateway
helm rollback istio-ingressgateway -n istio-system
kubectl rollout status deployment istio-ingressgateway -n istio-system

# 2. Rollback istiod
helm rollback istiod -n istio-system
kubectl rollout status deployment istiod -n istio-system

# 3. Rollback base (if CRD issues)
helm rollback istio-base -n istio-system

# Verify versions
helm list -n istio-system
istioctl version
```

### Rollback to Specific Version

```bash
# List release history
helm history istio-ingressgateway -n istio-system

# Rollback to specific revision number
helm rollback istio-ingressgateway 3 -n istio-system
helm rollback istiod 5 -n istio-system
helm rollback istio-base 2 -n istio-system
```

### Canary Rollback

For canary upgrades, simply revert workloads to old revision:

```bash
# Revert namespace to old revision
kubectl label namespace my-app istio.io/rev=1-22 --overwrite

# Restart workloads
kubectl rollout restart deployment -n my-app

# Verify
istioctl proxy-status | grep my-app
```

### Post-Rollback Validation

After rollback, verify system health:

```bash
# Check component versions
helm list -n istio-system
istioctl version

# Verify all proxies synced
istioctl proxy-status | grep -v SYNCED

# Test application traffic
curl -I http://$GATEWAY_IP/healthz/ready

# Check error rates
kubectl exec -n istio-system deploy/istio-ingressgateway -- \
  curl -s localhost:15000/stats | grep upstream_rq_5xx
```

---

## Troubleshooting

### Common Upgrade Issues

#### Issue 1: Pods Not Starting After Upgrade

**Symptoms:**
- Pods stuck in `Pending` or `CrashLoopBackOff`
- Error: `ImagePullBackOff`

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n istio-system
kubectl logs <pod-name> -n istio-system --previous
```

**Solutions:**
- Check image tag is correct: `kubectl get deploy istiod -n istio-system -o yaml | grep image:`
- Verify image registry access
- Check node resources: `kubectl top nodes`
- Review pod events: `kubectl get events -n istio-system --sort-by='.lastTimestamp'`

#### Issue 2: Proxies Not Syncing

**Symptoms:**
- `istioctl proxy-status` shows `STALE`
- Data plane not receiving config updates

**Diagnosis:**
```bash
istioctl proxy-status
kubectl logs -n istio-system -l app=istiod | grep -i error
```

**Solutions:**
- Restart istiod: `kubectl rollout restart deployment istiod -n istio-system`
- Check istiod service: `kubectl get svc istiod -n istio-system`
- Verify network policies aren't blocking: `kubectl get networkpolicy -n istio-system`
- Restart stale proxies: `kubectl delete pod <pod-name> -n <namespace>`

#### Issue 3: CRD Upgrade Failures

**Symptoms:**
- `helm upgrade` fails with CRD errors
- Custom resources showing validation errors

**Diagnosis:**
```bash
kubectl get crds | grep istio
kubectl describe crd virtualservices.networking.istio.io
```

**Solutions:**
- Manually apply CRDs: `kubectl apply -f base-crds.yaml`
- Check for CRD conflicts: `kubectl get crds -o yaml | grep -A5 istio.io`
- Restore from backup: `kubectl apply -f backup-istio-crds.yaml`
- Delete and recreate (DANGEROUS): `kubectl delete crd <crd-name>`

#### Issue 4: mTLS Certificate Issues

**Symptoms:**
- Services can't communicate
- TLS handshake errors in logs

**Diagnosis:**
```bash
istioctl proxy-config secret deploy/my-app -n my-namespace
kubectl logs <pod-name> -n <namespace> -c istio-proxy | grep -i tls
```

**Solutions:**
- Restart istiod to trigger cert refresh: `kubectl rollout restart deploy/istiod -n istio-system`
- Check cert expiry: `istioctl proxy-config secret deploy/my-app -n my-namespace -o json | jq '.dynamicActiveSecrets[0].secret.validationContext.trustedCa.filename'`
- Verify CA config: `kubectl get cm istio-ca-root-cert -n istio-system`

#### Issue 5: High Resource Usage After Upgrade

**Symptoms:**
- Istiod CPU/memory spiking
- Pods being OOMKilled

**Diagnosis:**
```bash
kubectl top pods -n istio-system
kubectl describe pod istiod-* -n istio-system | grep -A5 Limits
```

**Solutions:**
- Increase resources in values: `pilot.resources.requests/limits`
- Enable HPA: `autoscaling.enabled=true`
- Check for config loops: `istioctl analyze --all-namespaces`
- Review XDS push frequency: `kubectl exec -n istio-system deploy/istiod -- curl localhost:15014/metrics | grep pilot_xds_pushes`

### Getting Help

1. **Check logs**: `kubectl logs -n istio-system <pod-name> --previous`
2. **Run analyzer**: `istioctl analyze --all-namespaces`
3. **Collect debug info**: `istioctl bug-report --include ns1,ns2`
4. **Review Istio docs**: https://istio.io/latest/docs/ops/diagnostic-tools/
5. **GitHub issues**: https://github.com/istio/istio/issues

---

## Additional Resources

- [Istio Official Documentation](https://istio.io/latest/docs/)
- [Istio Release Notes](https://istio.io/latest/news/releases/)
- [AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)
- [Chart Repository](https://github.com/pkumar26/helm-charts-hub)
- [FIPS 140-2 Guide](https://istio.io/latest/docs/ops/configuration/security/fips-140/)

---

## Appendix: Upgrade Script Usage

See [examples/upgrade-istio.sh](../examples/upgrade-istio.sh) for automated upgrade script.

```bash
# Basic usage
./examples/upgrade-istio.sh --version 1.23.0 --environment production

# Dry-run mode
./examples/upgrade-istio.sh --version 1.23.0 --environment production --dry-run

# Skip specific component
./examples/upgrade-istio.sh --version 1.23.0 --skip-gateway
```
