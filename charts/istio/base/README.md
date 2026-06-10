# Istio Base Chart

This Helm chart installs Istio's Custom Resource Definitions (CRDs) and cluster-wide resources required for Istio service mesh operation on Azure Kubernetes Service (AKS).

## Overview

The istio-base chart is the **first component** that must be installed in the Istio installation sequence. It provides:

- Istio Custom Resource Definitions (CRDs)
- Cluster-wide RBAC resources
- Validation webhook configuration
- istio-system namespace

## Prerequisites

- Kubernetes 1.26+ (AKS recommended)
- Helm 3.10+
- kubectl configured to access your cluster

## Installation

### Quick Start (Development)

```bash
helm install istio-base charts/istio/base \
  --namespace istio-system \
  --create-namespace \
  --values charts/istio/base/values-dev.yaml
```

### Production Installation

```bash
helm install istio-base charts/istio/base \
  --namespace istio-system \
  --create-namespace \
  --values charts/istio/base/values-prod.yaml
```

## Installation Order

⚠️ **CRITICAL**: Istio components must be installed in this order:

1. **istio-base** (this chart) - CRDs and cluster-wide resources
2. **istiod** - Control plane (Pilot, CA, admission controller)
3. **istio-gateway** - Ingress/egress gateways

## Verification

After installation, verify that all Istio CRDs are registered:

```bash
# Check that CRDs are installed
kubectl get crds | grep istio.io

# You should see:
# authorizationpolicies.security.istio.io
# destinationrules.networking.istio.io
# envoyfilters.networking.istio.io
# gateways.networking.istio.io
# peerauthentications.security.istio.io
# proxyconfigs.networking.istio.io
# requestauthentications.security.istio.io
# serviceentries.networking.istio.io
# sidecars.networking.istio.io
# telemetries.telemetry.istio.io
# virtualservices.networking.istio.io
# wasmplugins.extensions.istio.io
# workloadentries.networking.istio.io
# workloadgroups.networking.istio.io

# Verify namespace is created with proper labels
kubectl get namespace istio-system --show-labels
```

## Configuration

### Values Files

- `values.yaml` - Default values with documentation
- `values-dev.yaml` - Development environment (minimal config)
- `values-staging.yaml` - Staging environment (moderate config)
- `values-prod.yaml` - Production environment (strict policies)

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `revision` | Istio revision label for canary upgrades | `""` (default) |
| `namespace` | Target namespace for Istio installation | `istio-system` |
| `validationWebhook` | Enable admission webhook validation | `true` |
| `labels` | Additional labels for resources | `{}` |
| `annotations` | Additional annotations for resources | `{}` |

## Upgrade

### Upgrade Sequence

⚠️ **CRITICAL**: Istio components must be upgraded in this exact order to prevent downtime:

1. **istio-base** (this chart) - CRDs and cluster-wide resources
2. **istiod** - Control plane (wait for ready before proceeding)
3. **istio-gateway** - Ingress/egress gateways

**Never skip versions** - upgrade one minor version at a time (e.g., 1.22.0 → 1.23.0 → 1.24.0).

### Upgrading the Base Chart

```bash
# Step 1: Check current version
helm list -n istio-system

# Step 2: Review release notes for CRD changes
# https://istio.io/latest/news/releases/

# Step 3: Update Chart.yaml dependency version
# Edit charts/istio/base/Chart.yaml to target Istio version

# Step 4: Update dependencies
helm dependency update charts/istio/base

# Step 5: Dry-run to preview changes
helm upgrade istio-base charts/istio/base \
  --namespace istio-system \
  --values charts/istio/base/values-prod.yaml \
  --dry-run --debug

# Step 6: Apply upgrade
helm upgrade istio-base charts/istio/base \
  --namespace istio-system \
  --values charts/istio/base/values-prod.yaml

# Step 7: Verify CRD updates
kubectl get crds | grep istio.io
kubectl api-resources | grep istio.io
```

### CRD Update Notes

**What gets updated:**
- VirtualService, DestinationRule, Gateway CRD schemas
- ServiceEntry, WorkloadEntry definitions
- Security policies (PeerAuthentication, AuthorizationPolicy, RequestAuthentication)
- Telemetry configuration (Telemetry CRD)

**Impact on running workloads:**
- ✅ **Safe**: CRD updates are backward compatible within the same major version
- ✅ **Non-disruptive**: Existing resources continue functioning during upgrade
- ⚠️ **Immediate action required**: Upgrade istiod and gateways within 24 hours

**Validation:**
```bash
# Check for deprecated CRD fields
kubectl get virtualservices,destinationrules,gateways --all-namespaces -o yaml | \
  istioctl experimental precheck

# Verify webhook configuration
kubectl get validatingwebhookconfiguration istiod-default-validator -o yaml
```

### Version Compatibility

| Base Chart | Istiod | Gateway | Kubernetes |
|------------|--------|---------|------------|
| 1.23.x | 1.23.x | 1.23.x | 1.26-1.30 |
| 1.22.x | 1.22.x | 1.22.x | 1.25-1.29 |
| 1.21.x | 1.21.x | 1.21.x | 1.24-1.28 |

**Compatibility rules:**
- Base, istiod, and gateway **must be on the same minor version**
- N-1 version skew is **not supported** for production
- Control plane can manage data plane proxies up to 2 minor versions older

### Pre-Upgrade Checklist

Before upgrading base chart:

- [ ] Review [Istio release notes](https://istio.io/latest/news/releases/) for breaking changes
- [ ] Backup existing CRD definitions: `kubectl get crds -o yaml > istio-crds-backup.yaml`
- [ ] Test upgrade in non-production environment first
- [ ] Ensure istiod and gateway are healthy: `kubectl get pods -n istio-system`
- [ ] Check for deprecated API usage: `istioctl experimental precheck`
- [ ] Plan maintenance window for control plane and gateway upgrades
- [ ] Prepare rollback plan (see below)

### Post-Upgrade Actions

After upgrading base chart:

1. **Immediately upgrade istiod** (within 1 hour):
   ```bash
   helm upgrade istiod charts/istio/istiod \
     --namespace istio-system \
     --values charts/istio/istiod/values-prod.yaml \
     --wait
   ```

2. **Upgrade gateways** (after istiod is ready):
   ```bash
   helm upgrade istio-ingressgateway charts/istio/gateway \
     --namespace istio-system \
     --values charts/istio/gateway/values-prod.yaml \
     --wait
   ```

3. **Validate mesh health**:
   ```bash
   istioctl proxy-status
   istioctl analyze --all-namespaces
   ```

### Rollback

If upgrade fails, rollback in reverse order:

```bash
# 1. Rollback gateway first
helm rollback istio-ingressgateway -n istio-system

# 2. Rollback control plane
helm rollback istiod -n istio-system

# 3. Rollback base (CRDs)
helm rollback istio-base -n istio-system

# 4. Verify rollback
helm list -n istio-system
kubectl get crds | grep istio.io
```

⚠️ **CRD Rollback Limitations**: 
- CRD downgrades may fail if new fields were added
- Custom resources using new CRD features may become invalid
- Always test rollback procedure in non-production first

## Uninstallation

⚠️ **DANGER**: Uninstalling this chart will delete all Istio CRDs and configurations!

```bash
# Delete in reverse order
helm uninstall istio-ingressgateway -n istio-system
helm uninstall istiod -n istio-system
helm uninstall istio-base -n istio-system

# Verify CRDs are removed
kubectl get crds | grep istio.io
```

## Troubleshooting

### CRDs Not Installing

**Symptom**: `kubectl get crds | grep istio.io` returns no results

**Solution**:
```bash
# Check Helm release status
helm list -n istio-system

# Check for errors in Helm release
helm get manifest istio-base -n istio-system | kubectl apply -f -
```

### Validation Webhook Errors

**Symptom**: Cannot create Istio resources, webhook validation errors

**Solution**:
```bash
# Check webhook configuration
kubectl get validatingwebhookconfiguration istiod-default-validator

# If istiod is not running, temporarily disable webhook
kubectl delete validatingwebhookconfiguration istiod-default-validator
```

### Namespace Already Exists

**Symptom**: `Error: namespace "istio-system" already exists`

**Solution**:
```bash
# Omit --create-namespace flag
helm install istio-base charts/istio/base \
  --namespace istio-system \
  --values charts/istio/base/values-prod.yaml
```

## Support

- [Istio Official Documentation](https://istio.io/latest/docs/)
- [Helm Charts Hub Repository](https://github.com/pkumar26/helm-charts-hub)

## License

This chart follows the licensing of Istio (Apache 2.0).
