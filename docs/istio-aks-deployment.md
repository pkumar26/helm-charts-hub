# Istio on AKS Deployment and Upgrade Guide

Complete guide for deploying and upgrading Istio service mesh on Azure Kubernetes Service (AKS) using Helm charts with FIPS 140-2 compliance support.

## Table of Contents

- [Version Compatibility](#version-compatibility)
- [Initial Deployment](#initial-deployment)
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
| **1.23.x** | 1.23.x | 1.23.x | 1.23.x | 1.26-1.30 | 1.28+ |
| **1.22.x** | 1.22.x | 1.22.x | 1.22.x | 1.25-1.29 | 1.27+ |
| **1.21.x** | 1.21.x | 1.21.x | 1.21.x | 1.24-1.28 | 1.26+ |

**Critical Rules:**
- ✅ **All components must be on the same minor version** (e.g., all 1.23.x)
- ✅ **Control plane can manage proxies up to 2 versions older** (e.g., 1.23 control plane with 1.21 proxies)
- ❌ **N-1 version skew is NOT supported** between base and istiod
- ✅ **Patch version differences are acceptable** (e.g., 1.23.0 and 1.23.2)

### Helm Chart Versions

| Chart | Version | Istio Version | Status |
|-------|---------|---------------|--------|
| istio/base | 1.0.0 | 1.23.0 | Stable |
| istio/istiod | 1.0.0 | 1.23.0 | Stable |
| istio/gateway | 1.0.0 | 1.23.0 | Stable |
| istio/kiali | 1.0.0 | 1.86.0 | Optional |

### AKS Kubernetes Version Support

| AKS Version | Support Status | Istio Compatibility | FIPS Support |
|-------------|----------------|---------------------|--------------|
| 1.30.x | Preview | 1.23.x | ✅ Yes |
| 1.29.x | GA | 1.23.x | ✅ Yes |
| 1.28.x | GA | 1.22.x, 1.23.x | ✅ Yes |
| 1.27.x | GA | 1.22.x | ✅ Yes |
| 1.26.x | Deprecated | 1.21.x, 1.22.x | ✅ Yes |

**Recommendation**: Use AKS 1.28+ for production workloads.

---

## Initial Deployment

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

1. **Base Chart** - CRDs and cluster-wide resources
2. **Istiod Chart** - Control plane
3. **Gateway Chart** - Ingress/egress gateways
4. **Kiali Chart** - (Optional) Mesh observability

### Step-by-Step Installation

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
# Expected: docker.io/istio/pilot:1.23.0 (no -distroless suffix)
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
# Expected: docker.io/istio/pilot:1.23.0-distroless

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
