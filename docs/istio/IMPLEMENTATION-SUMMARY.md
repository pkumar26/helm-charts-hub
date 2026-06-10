# Istio Ambient Mode Implementation Summary

This document summarizes the Istio ambient mode implementation on Azure AKS, including all learnings, fixes, and best practices discovered during manual setup.

## 📂 Repository Structure

```
charts/istio/
├── base/                    # Istio base CRDs
├── istiod/                  # Istio control plane
├── gateway-api/             # NEW: Gateway API for ambient mode
│   ├── templates/
│   │   ├── gateway.yaml    # Gateway + auto-patch for externalTrafficPolicy
│   │   ├── httproute.yaml
│   │   ├── referencegrant.yaml
│   │   └── rbac.yaml
│   └── values.yaml
└── kiali/                   # Service mesh observability
    └── values.yaml          # UPDATED: externalTrafficPolicy, Prometheus, mTLS config

examples/istio-ambient/      # NEW: Manual setup examples
├── README.md
├── gateway-httproute.yaml
├── kiali.yaml
├── rbac.yaml
├── mtls-strict.yaml
├── reference-grant.yaml
└── team-httproute-template.yaml

docs/istio/                  # NEW: Documentation
├── azure-lb-externaltrafficpolicy-fix.md
├── kiali-access-options.md
├── grafana-integration.md
└── verify-mtls.md
```

## 🎯 What We Achieved

### 1. Istio Ambient Mode Deployment
- Deployed Istio 1.30.0 in **ambient mode** (sidecar-less)
- Components: istiod, ztunnel DaemonSet, istio-cni
- Uses **Kubernetes Gateway API** v1 (not legacy VirtualService)
- Gateway auto-deployment via `PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER`

### 2. Multi-Tenant Gateway Architecture
- **Platform team**: Centralized Gateway in `istio-system`
- **Application teams**: HTTPRoutes in their own namespaces
- Cross-namespace routing via `allowedRoutes.namespaces.from: All`
- ReferenceGrant for security

### 3. RBAC Security Model
- `platform-gateway-admin`: Full Gateway/GatewayClass management
- `gateway-reader`: Read-only Gateway access
- `httproute-manager`: Per-namespace HTTPRoute creation

### 4. Zero-Trust mTLS
- Automatic mTLS between pods in labeled namespaces
- No sidecar injection required (ztunnel handles L4)
- PERMISSIVE mode (easy upgrade to STRICT)

### 5. Observability
- **Kiali**: Service mesh visualization with mTLS status
- **Prometheus**: Bundled metrics for Istio telemetry
- **Azure Monitor**: Integration via scrape annotations
- **Grafana**: Dashboard IDs and KQL queries documented

### 6. Critical Azure AKS Fix ⚠️
**Problem**: LoadBalancer services timeout despite getting external IPs

**Root Cause**: Azure LB health probe coordination bug with `externalTrafficPolicy: Cluster` (default)

**Solution**: Set `externalTrafficPolicy: Local` on all LoadBalancer services

**Implementation**:
- Helm chart: Auto-patches via post-install hook
- Manual: `kubectl patch svc <name> -n istio-system -p '{"spec":{"externalTrafficPolicy":"Local"}}'`

See [docs/azure-lb-externaltrafficpolicy-fix.md](docs/azure-lb-externaltrafficpolicy-fix.md)

## 🚀 Quick Start

### Option 1: Helm Charts (Recommended for Production)

```bash
# 1. Install Istio base
helm install istio-base charts/istio/base -n istio-system --create-namespace

# 2. Install Istio control plane
# NOTE: pilot.* settings must be nested under `istiod:` so they reach the
# upstream istiod subchart (only `global` is auto-propagated by Helm).
helm install istiod charts/istio/istiod -n istio-system \
  --set istiod.pilot.env.PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER=true

# 3. Install Gateway API
helm install istio-gateway charts/istio/gateway-api -n istio-system

# 4. Install Kiali (optional)
helm install kiali charts/istio/kiali -n istio-system \
  --set enabled=true
```

### Option 2: Manual Setup (For Learning/Testing)

See [examples/istio-ambient/README.md](examples/istio-ambient/README.md) for step-by-step manual setup.

## 📋 Key Configuration Values

### Gateway API Chart

```yaml
# charts/istio/gateway-api/values.yaml
gateway:
  name: istio-gateway
  namespace: istio-system  # MUST be istio-system
  service:
    type: LoadBalancer
    externalTrafficPolicy: Local  # CRITICAL for Azure
    azure:
      healthProbe:
        enabled: true
        port: "15021"
        path: "/healthz/ready"
```

### Kiali Chart

```yaml
# charts/istio/kiali/values.yaml
enabled: true
kiali-server:
  service:
    type: LoadBalancer
    externalTrafficPolicy: Local  # CRITICAL for Azure
  external_services:
    prometheus:
      url: "http://prometheus.istio-system:9090"
  kiali_feature_flags:
    istio_injection_action: true
  health_config:  # For mTLS status display
    rate: [...]
```

## 🎓 Key Learnings

1. **Gateway MUST be in `istio-system`** for auto-deployment to work
2. **externalTrafficPolicy: Local is CRITICAL** on Azure AKS for LoadBalancer
3. **Health probe port 15021** (not 80) must be configured for Azure LB
4. **Traefik worked because** it uses dedicated health port 9000 with `/ping`
5. **Kiali Security badges** are disabled by default - enable in Display settings
6. **Ambient mode requires no code changes** - just namespace label + pod restart

## 🔧 Common Issues & Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| LoadBalancer times out | externalTrafficPolicy: Cluster | Patch to Local |
| Gateway not creating service | Wrong namespace | Move to istio-system |
| HTTPRoute not working | No ReferenceGrant | Create ReferenceGrant |
| Kiali no mTLS icons | Display settings | Enable Security badges |
| Kiali metrics errors | Wrong Prometheus URL | Use bundled Prometheus |

## 📊 Architecture

```
External Traffic
    ↓
Azure LB (externalTrafficPolicy: Local)
    ↓
Istio Gateway Pod (istio-system)
    ↓
HTTPRoute (team namespace)
    ↓
Backend Service
    ↓
Pod ←→ ztunnel (mTLS encryption)
```

## 🔐 Security Considerations

### For Production:
1. Set `externalTrafficPolicy: Local` on all LoadBalancer services
2. Enable RBAC (`rbac.enabled: true`)
3. Use internal LoadBalancer or ClusterIP + Ingress
4. Enable strict mTLS (`mtls.mode: STRICT`)
5. Use token or OpenID auth for Kiali (not anonymous)
6. Add TLS/HTTPS via gateway certificates

### For Development/Testing:
- External LoadBalancer with anonymous auth is acceptable
- Lock down by IP using Azure NSG
- Use PERMISSIVE mTLS mode

## 📚 Documentation

- [Azure LB externalTrafficPolicy Fix](docs/azure-lb-externaltrafficpolicy-fix.md) - Root cause and solution
- [Kiali Access Options](docs/istio/kiali-access-options.md) - Different access patterns
- [Grafana Integration](docs/istio/grafana-integration.md) - Azure Managed Grafana setup
- [Verify mTLS](docs/istio/verify-mtls.md) - Check mTLS is working
- [Manual Setup Examples](examples/istio-ambient/README.md) - Step-by-step guides

## 🤝 For Application Teams

**Create an HTTPRoute in your namespace:**

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-route
  namespace: my-namespace
spec:
  parentRefs:
  - name: istio-gateway
    namespace: istio-system
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /myapp
    backendRefs:
    - name: my-service
      port: 8080
```

**Enable mTLS on your namespace:**

```bash
kubectl label namespace my-namespace istio.io/dataplane-mode=ambient
kubectl rollout restart deployment -n my-namespace
```

## 🔗 Related Resources

- [Istio Ambient Mode Docs](https://istio.io/latest/docs/ambient/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Azure AKS LoadBalancer](https://learn.microsoft.com/en-us/azure/aks/load-balancer-standard)
- [Kiali Documentation](https://kiali.io/docs/)

## 📝 Version History

- v0.1.0 - Initial implementation with Azure AKS optimizations
  - Gateway API chart with auto-patching
  - Kiali chart with externalTrafficPolicy
  - Complete documentation and examples
