# Istio Control Plane (istiod) Chart

Helm chart for deploying the Istio control plane (istiod) with FIPS 140-2 compliance and security baseline for Azure Kubernetes Service (AKS).

## Overview

The istiod chart deploys the Istio control plane components:
- **Pilot**: Service discovery and traffic management
- **Citadel**: Certificate authority for mTLS
- **Galley**: Configuration validation
- **Sidecar Injector**: Automatic envoy proxy injection

## Prerequisites

- Kubernetes 1.26+ (AKS recommended)
- Helm 3.10+
- istio-base chart installed first
- For FIPS mode: AKS FIPS-enabled node pools

## Installation

### Quick Start (Development)

```bash
helm install istiod charts/istio/istiod \
  --namespace istio-system \
  --values charts/istio/istiod/values-dev.yaml \
  --wait
```

### Production with FIPS

```bash
helm install istiod charts/istio/istiod \
  --namespace istio-system \
  --values charts/istio/istiod/values-prod.yaml \
  --wait
```

## Configuration

See `values.yaml` for all configuration options. Key settings:

| Parameter | Description | Default | Production |
|-----------|-------------|---------|------------|
| `global.fips.enabled` | Enable FIPS 140-2 mode | `false` | `true` |
| `global.tag` | Image tag (use `-distroless` suffix for FIPS) | `1.23.0` | `1.23.0-distroless` |
| `istiod.pilot.replicaCount` | Number of istiod replicas | `1` | `3` |
| `istiod.pilot.autoscaleEnabled` | Upstream subchart HPA (keep `false`; use `customAutoscaling`) | `false` | `false` |
| `istiod.pilot.env` | Pilot environment variables (e.g. `GOFIPS`, `FIPS_MODE`) | `{}` | FIPS vars |
| `customAutoscaling.enabled` | Enable this chart's HPA | `false` | `true` |
| `security.peerAuthentication.mode` | mTLS mode | `PERMISSIVE` | `STRICT` |
| `security.networkPolicy.enabled` | Enable network isolation | `false` | `true` |

> **Important:** Pilot settings (replicas, resources, env, affinity, image tag)
> are forwarded to the upstream `istiod` subchart. Helm only auto-propagates the
> `global` key, so these values **must** be nested under `istiod.pilot`. Values
> placed at the top level (e.g. a bare `pilot:` block) are silently ignored.

## Verification

```bash
# Check istiod pods
kubectl get pods -n istio-system -l app=istiod

# Verify FIPS mode (production)
kubectl exec -n istio-system deploy/istiod -- env | grep GOFIPS

# Check control plane status
istioctl proxy-status
```

## Security Baseline

Production deployment includes:
- STRICT mTLS enforcement (FR-004)
- Default-deny authorization policies (FR-005)
- Network policies for control plane isolation (FR-010)
- Pod security standards (FR-006)

## Canary Upgrades

Istio supports **canary upgrades** to minimize risk by running multiple control plane revisions side-by-side. This enables gradual traffic migration from the old version to the new version.

### Overview

Canary upgrade process:
1. Install new istiod revision alongside existing version
2. Test new revision with a subset of workloads
3. Gradually migrate workloads to new revision
4. Retire old revision once all workloads are migrated

### Step 1: Install Canary Revision

```bash
# Current version (e.g., 1.22.0) is running as "default" revision
helm list -n istio-system

# Install new version (e.g., 1.23.0) with revision tag
helm install istiod-1-23 charts/istio/istiod \
  --namespace istio-system \
  --values charts/istio/istiod/values-prod.yaml \
  --set revision=1-23 \
  --wait

# Verify both revisions are running
kubectl get pods -n istio-system -l app=istiod
```

Expected output:
```
NAME                             READY   STATUS    AGE
istiod-1-22-5c9f8b9c4d-abcde    1/1     Running   30d   (old revision)
istiod-1-22-5c9f8b9c4d-fghij    1/1     Running   30d   (old revision)
istiod-1-23-6d8g9c0e5f-klmno    1/1     Running   2m    (new revision)
istiod-1-23-6d8g9c0e5f-pqrst    1/1     Running   2m    (new revision)
```

### Step 2: Tag Revisions for Traffic Management

```bash
# Tag old revision as "stable"
istioctl tag set stable --revision default --overwrite

# Tag new revision as "canary"
istioctl tag set canary --revision 1-23 --overwrite

# Verify tags
istioctl tag list
```

### Step 3: Test New Revision with Canary Namespace

```bash
# Create test namespace with canary revision
kubectl create namespace test-canary
kubectl label namespace test-canary istio.io/rev=1-23

# Deploy test workload
kubectl apply -f examples/httpbin.yaml -n test-canary

# Verify pods use new revision's sidecar
kubectl get pods -n test-canary -o jsonpath='{.items[*].spec.containers[?(@.name=="istio-proxy")].image}'
```

Expected: Image tag should match new Istio version (1.23.0)

### Step 4: Gradual Migration Strategy

**Option A: Namespace-by-Namespace**

```bash
# Migrate entire namespace to new revision
kubectl label namespace my-app istio.io/rev=1-23 --overwrite

# Restart pods to inject new sidecar
kubectl rollout restart deployment -n my-app

# Verify all pods are using new revision
istioctl proxy-status | grep my-app
```

**Option B: Deployment-by-Deployment**

```bash
# Add revision label to specific deployment
kubectl patch deployment my-app -n production \
  -p '{"spec":{"template":{"metadata":{"labels":{"istio.io/rev":"1-23"}}}}}'

# This triggers automatic rolling restart with new sidecar
kubectl rollout status deployment my-app -n production
```

**Option C: Traffic Percentage Split** (Advanced)

For gradual percentage-based rollout, use weighted revision tags:

```bash
# 10% of traffic to canary
istioctl tag set prod --revision default --overwrite
istioctl tag set canary --revision 1-23 --overwrite

# Label namespace for weighted split
kubectl label namespace production istio.io/rev=prod
kubectl annotate namespace production \
  "istio.io/rev-canary=1-23" \
  "istio.io/rev-canary-weight=10"

# Gradually increase canary weight: 10% → 25% → 50% → 75% → 100%
# Monitor metrics between each step
```

### Step 5: Monitor Canary Health

**Key metrics to monitor:**

```bash
# Control plane metrics
kubectl top pods -n istio-system -l app=istiod

# Proxy connection status
istioctl proxy-status | grep -E "1-23|SYNCED"

# Data plane error rates
kubectl exec -n istio-system deploy/istiod-1-23 -- \
  curl -s localhost:15014/metrics | grep pilot_xds_push_errors

# Certificate issuance (verify new CA is working)
istioctl proxy-config secret deploy/my-app -n production | grep "ACTIVE"
```

**Validation checklist:**
- [ ] All canary pods are RUNNING and READY
- [ ] Proxy status shows SYNCED for canary sidecars
- [ ] No increase in 5xx error rates
- [ ] mTLS certificates are being issued by new CA
- [ ] No XDS push errors in istiod logs
- [ ] Grafana dashboards show healthy metrics

### Step 6: Complete Migration

Once canary is validated:

```bash
# Make new revision the default
istioctl tag set default --revision 1-23 --overwrite

# Migrate remaining namespaces
for ns in $(kubectl get namespaces -l istio-injection=enabled -o jsonpath='{.items[*].metadata.name}'); do
  kubectl label namespace $ns istio.io/rev=1-23 istio-injection- --overwrite
  kubectl rollout restart deployments -n $ns
done

# Wait for all workloads to migrate
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.metadata.labels.istio\.io/rev}{"\n"}{end}' | grep -v "1-23"
```

### Step 7: Remove Old Revision

**Only after 100% migration is confirmed:**

```bash
# Verify no pods are using old revision
istioctl proxy-status | grep -v "1-23"

# Uninstall old revision
helm uninstall istiod -n istio-system

# Remove old tags
istioctl tag remove stable

# Clean up
kubectl delete mutatingwebhookconfigurations istiod-default-istio-system
```

### Rollback During Canary

If issues are detected with canary revision:

```bash
# Immediately stop migrating workloads
# Revert affected namespaces to old revision
kubectl label namespace my-app istio.io/rev=default --overwrite
kubectl rollout restart deployment -n my-app

# Uninstall canary revision
helm uninstall istiod-1-23 -n istio-system

# Remove canary tag
istioctl tag remove canary

# Verify old revision is handling all traffic
istioctl proxy-status
```

### Best Practices

1. **Start small**: Test with non-production namespace first
2. **Monitor closely**: Watch error rates, latency, and XDS sync status
3. **Use automation**: Script the migration for consistency
4. **Gradual rollout**: Migrate 10% → 25% → 50% → 100% with validation between steps
5. **Keep old revision running**: Don't uninstall until 100% migrated and stable for 24h
6. **Document decisions**: Track which namespaces are on which revision

### Revision Naming Convention

Use semantic versioning in revision names:
- ✅ `1-23-0` - Clear, matches Istio version
- ✅ `1-23` - Shorter, minor version only
- ❌ `canary` - Ambiguous, doesn't indicate version
- ❌ `prod` - Doesn't indicate version

## Troubleshooting

See full documentation in the README.

## License

Apache 2.0
