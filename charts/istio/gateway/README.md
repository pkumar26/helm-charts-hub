# Istio Gateway Helm Chart

Istio ingress gateway Helm chart for Azure Kubernetes Service (AKS) with FIPS 140-2 compliance and production security baseline.

## Overview

This chart deploys an Istio ingress gateway with pre-configured security policies including STRICT mTLS enforcement, AuthorizationPolicy access control, and NetworkPolicy isolation. It supports FIPS 140-2 compliance for classified workloads.

## Prerequisites

- Kubernetes 1.26+ (AKS)
- Helm 3.10+
- **Istio base chart** must be installed first
- **Istio istiod (control plane)** must be running and healthy
- For FIPS mode: AKS cluster with FIPS-enabled node pools (`az aks nodepool add --enable-fips-image`)

## Installation

### Basic Installation (Development)

```bash
helm install istio-ingressgateway ./charts/istio/gateway \
  --namespace istio-system \
  --values ./charts/istio/gateway/values-dev.yaml
```

### Production Installation with FIPS

```bash
# Verify istiod is healthy first
kubectl get pods -n istio-system -l app=istiod

# Install gateway with production values
helm install istio-ingressgateway ./charts/istio/gateway \
  --namespace istio-system \
  --values ./charts/istio/gateway/values-prod.yaml

# Verify FIPS compliance
POD=$(kubectl get pod -n istio-system -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config bootstrap $POD -n istio-system | grep -i boring
```

Expected output for FIPS validation:
```
"BoringSSL"
```

### Using Environment Overlays

```bash
helm install istio-ingressgateway ./charts/istio/gateway \
  --namespace istio-system \
  --values ./charts/istio/gateway/values-prod.yaml \
  --values ./environments/production/istio-gateway.values.yaml
```

## Configuration

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.fips.enabled` | Enable FIPS 140-2 mode (distroless images with BoringSSL) | `false` |
| `replicaCount` | Number of gateway replicas | `1` |
| `service.type` | Service type (LoadBalancer, NodePort, ClusterIP) | `LoadBalancer` |
| `security.peerAuthentication.mode` | mTLS mode (PERMISSIVE, STRICT) | `PERMISSIVE` |
| `security.authorizationPolicy.enabled` | Enable AuthorizationPolicy | `false` |
| `security.networkPolicy.enabled` | Enable NetworkPolicy | `false` |
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.targetCPUUtilizationPercentage` | HPA CPU target | `80` |

### Environment-Specific Values

- **Dev** (`values-dev.yaml`): NodePort service, 1 replica, PERMISSIVE mTLS, no FIPS
- **Staging** (`values-staging.yaml`): LoadBalancer, 2 replicas, STRICT mTLS, HPA enabled
- **Production** (`values-prod.yaml`): LoadBalancer, 3 replicas, FIPS enabled, STRICT mTLS, full security baseline

## Verification

### Check Gateway Status

```bash
kubectl get pods -n istio-system -l istio=ingressgateway
kubectl get svc -n istio-system istio-ingressgateway
```

### Get External IP (LoadBalancer)

```bash
kubectl get svc -n istio-system istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Verify mTLS Enforcement

```bash
# Check PeerAuthentication
kubectl get peerauthentication -n istio-system

# Verify STRICT mode
kubectl get peerauthentication -n istio-system -o yaml | grep mode
```

### Verify Security Policies

```bash
# Check AuthorizationPolicy
kubectl get authorizationpolicy -n istio-system

# Check NetworkPolicy
kubectl get networkpolicy -n istio-system
```

## Troubleshooting

### Gateway Pods Not Starting

```bash
# Check events
kubectl describe pod -n istio-system -l istio=ingressgateway

# Check istiod logs
kubectl logs -n istio-system -l app=istiod

# Verify istiod is healthy
kubectl get pods -n istio-system -l app=istiod
```

### FIPS Validation Failures

```bash
# Check if FIPS-enabled node pool is available
kubectl get nodes -l fips=enabled

# Verify distroless image is being used
kubectl get deployment -n istio-system istio-ingressgateway -o yaml | grep image:

# Check GOFIPS environment variable
kubectl get deployment -n istio-system istio-ingressgateway -o yaml | grep GOFIPS
```

### Connection Refused Errors

```bash
# Check service endpoints
kubectl get endpoints -n istio-system istio-ingressgateway

# Verify NetworkPolicy allows ingress traffic
kubectl get networkpolicy -n istio-system -o yaml

# Test connectivity from another pod
kubectl run test-curl --image=curlimages/curl -it --rm -- curl http://istio-ingressgateway.istio-system.svc.cluster.local:80
```

### mTLS Certificate Issues

```bash
# Check gateway certificates
istioctl proxy-config secret $POD -n istio-system

# Verify istiod can issue certificates
kubectl logs -n istio-system -l app=istiod | grep -i cert
```

## Upgrade

### Upgrading the Gateway

```bash
# Step 1: Verify istiod is healthy and on target version
kubectl get pods -n istio-system -l app=istiod
istioctl version

# Step 2: Check current gateway version
helm list -n istio-system | grep gateway

# Step 3: Dry-run upgrade
helm upgrade istio-ingressgateway ./charts/istio/gateway \
  --namespace istio-system \
  --values ./charts/istio/gateway/values-prod.yaml \
  --dry-run --debug

# Step 4: Apply upgrade
helm upgrade istio-ingressgateway ./charts/istio/gateway \
  --namespace istio-system \
  --values ./charts/istio/gateway/values-prod.yaml \
  --wait \
  --timeout 5m

# Step 5: Verify upgrade
kubectl rollout status deployment istio-ingressgateway -n istio-system
```

### Upgrade Verification Steps

After upgrading the gateway, perform these verification checks:

#### 1. Pod Health Check

```bash
# Verify all gateway pods are running
kubectl get pods -n istio-system -l istio=ingressgateway

# Check pod readiness
kubectl get pods -n istio-system -l istio=ingressgateway \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'
```

Expected output: All pods should be `Running` with `True` ready status.

#### 2. Proxy Version Verification

```bash
# Check Envoy proxy version
istioctl proxy-status | grep ingressgateway

# Verify FIPS compliance (production only)
POD=$(kubectl get pod -n istio-system -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config bootstrap $POD -n istio-system | grep -i boring
```

Expected: Should show `BoringSSL` for FIPS-enabled gateways.

#### 3. Configuration Sync Check

```bash
# Verify gateway is synced with istiod
istioctl proxy-status | grep ingressgateway | grep SYNCED

# Check for config errors
kubectl logs -n istio-system -l istio=ingressgateway --tail=50 | grep -i error
```

#### 4. Traffic Flow Verification

```bash
# Test gateway connectivity
GATEWAY_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# HTTP health check (port 80)
curl -I http://$GATEWAY_IP/healthz/ready

# HTTPS health check (port 443, if configured)
curl -k -I https://$GATEWAY_IP/healthz/ready

# Check active connections
kubectl exec -n istio-system deploy/istio-ingressgateway -- \
  curl -s localhost:15000/stats | grep cx_active
```

#### 5. Security Policy Validation

```bash
# Verify mTLS mode
kubectl get peerauthentication gateway-mtls -n istio-system -o yaml

# Check authorization policies
kubectl get authorizationpolicy -n istio-system

# Validate network policies
kubectl get networkpolicy -n istio-system -l app=istio-ingressgateway
```

#### 6. End-to-End Test

Deploy a test service and route traffic through the gateway:

```bash
# Deploy httpbin test service
kubectl create namespace test-gateway
kubectl label namespace test-gateway istio-injection=enabled
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/httpbin/httpbin.yaml -n test-gateway

# Create Gateway and VirtualService
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: test-gateway
  namespace: test-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "httpbin.example.com"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: httpbin
  namespace: test-gateway
spec:
  hosts:
  - "httpbin.example.com"
  gateways:
  - test-gateway
  http:
  - route:
    - destination:
        host: httpbin
        port:
          number: 8000
EOF

# Test traffic flow
curl -H "Host: httpbin.example.com" http://$GATEWAY_IP/headers

# Cleanup
kubectl delete namespace test-gateway
```

### Zero-Downtime Upgrade Strategy

For production environments with strict uptime requirements:

```bash
# Use HPA to maintain minimum replica count during upgrade
kubectl get hpa istio-ingressgateway -n istio-system

# Upgrade with controlled rollout (max surge, max unavailable)
helm upgrade istio-ingressgateway ./charts/istio/gateway \
  --namespace istio-system \
  --values ./charts/istio/gateway/values-prod.yaml \
  --set gateway.rollingUpdate.maxSurge=1 \
  --set gateway.rollingUpdate.maxUnavailable=0 \
  --wait

# Monitor rollout progress
kubectl rollout status deployment istio-ingressgateway -n istio-system -w
```

## Rollback

If the upgrade causes issues, immediately rollback to the previous version.

### Quick Rollback

```bash
# Rollback to previous release
helm rollback istio-ingressgateway -n istio-system

# Verify rollback
helm history istio-ingressgateway -n istio-system
kubectl rollout status deployment istio-ingressgateway -n istio-system
```

### Rollback to Specific Version

```bash
# List release history
helm history istio-ingressgateway -n istio-system

# Rollback to specific revision number
helm rollback istio-ingressgateway 3 -n istio-system

# Wait for rollback to complete
kubectl rollout status deployment istio-ingressgateway -n istio-system --timeout=5m
```

### Post-Rollback Verification

After rollback, perform the same verification steps as upgrade:

```bash
# 1. Check pod health
kubectl get pods -n istio-system -l istio=ingressgateway

# 2. Verify proxy version matches expected (old version)
istioctl proxy-status | grep ingressgateway

# 3. Test traffic flow
GATEWAY_IP=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -I http://$GATEWAY_IP/healthz/ready

# 4. Check for errors
kubectl logs -n istio-system -l istio=ingressgateway --tail=100 | grep -i error

# 5. Verify configuration sync
istioctl proxy-status | grep ingressgateway | grep SYNCED
```

### Rollback Scenarios and Actions

| Issue | Symptoms | Rollback Action | Verification |
|-------|----------|----------------|--------------|
| **Pods CrashLooping** | `CrashLoopBackOff` status | Immediate rollback | Check pod logs for root cause |
| **Config Sync Failure** | `STALE` in proxy-status | Rollback + check istiod health | Verify istiod version compatibility |
| **Traffic Errors** | 5xx errors, connection resets | Immediate rollback | Monitor error rates return to baseline |
| **TLS Handshake Failures** | SSL/TLS errors in logs | Rollback + check certificates | Verify cert chain with `istioctl proxy-config secret` |
| **FIPS Validation Failure** | BoringSSL not detected | Rollback + check node pool | Ensure FIPS node selector is correct |
| **Performance Degradation** | High latency, CPU throttling | Rollback + adjust resources | Review resource requests/limits |

### Automated Rollback

For automated rollback based on metrics:

```bash
# Create a script to monitor and auto-rollback
cat > auto-rollback.sh << 'EOF'
#!/bin/bash
NAMESPACE="istio-system"
DEPLOYMENT="istio-ingressgateway"
ERROR_THRESHOLD=5  # Percentage

# Get current error rate
ERRORS=$(kubectl exec -n $NAMESPACE deploy/$DEPLOYMENT -- \
  curl -s localhost:15000/stats/prometheus | \
  grep envoy_cluster_upstream_rq_5xx | \
  awk '{sum+=$2} END {print sum}')

REQUESTS=$(kubectl exec -n $NAMESPACE deploy/$DEPLOYMENT -- \
  curl -s localhost:15000/stats/prometheus | \
  grep envoy_cluster_upstream_rq_total | \
  awk '{sum+=$2} END {print sum}')

ERROR_RATE=$(echo "scale=2; ($ERRORS / $REQUESTS) * 100" | bc)

if (( $(echo "$ERROR_RATE > $ERROR_THRESHOLD" | bc -l) )); then
  echo "Error rate $ERROR_RATE% exceeds threshold $ERROR_THRESHOLD%"
  echo "Initiating automatic rollback..."
  helm rollback $DEPLOYMENT -n $NAMESPACE
  exit 1
fi

echo "Error rate $ERROR_RATE% is within acceptable range"
EOF

chmod +x auto-rollback.sh

# Run check 5 minutes after upgrade
sleep 300 && ./auto-rollback.sh
```

### Rollback Best Practices

1. **Monitor First**: Check metrics for 5-10 minutes before deciding to rollback
2. **Communicate**: Notify team about rollback and reason
3. **Document**: Record what failed and why rollback was needed
4. **Root Cause**: Analyze logs and metrics to prevent recurrence
5. **Test**: Validate the fix in non-production before re-attempting upgrade

### When NOT to Rollback

- Minor log warnings (not impacting traffic)
- Temporary pod restarts during rollout (expected behavior)
- Initial health check failures (pods need startup time)
- Single pod issues (other replicas may be healthy)

Always check if issue is upgrade-related before rolling back.

## Uninstallation

```bash
helm uninstall istio-ingressgateway -n istio-system
```

**Note**: Uninstalling the gateway does NOT remove istiod or base chart. Follow proper uninstall order: gateway → istiod → base.

## Security Baseline

### Production Security Features (values-prod.yaml)

- ✅ FIPS 140-2 compliance via BoringSSL (Certificate #4407)
- ✅ STRICT mTLS enforcement (no plaintext allowed)
- ✅ AuthorizationPolicy with explicit allowlists
- ✅ NetworkPolicy for L3/L4 isolation
- ✅ Pod security standards (runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities)
- ✅ Pod anti-affinity for zone spreading (HA)
- ✅ HPA with 80% CPU target
- ✅ Resource limits enforced (500m CPU, 1Gi memory requests)

## Support

For issues or questions, refer to:
- [Istio documentation](https://istio.io/latest/docs/)
- [Chart repository](https://github.com/pkumar26/helm-charts-hub)
