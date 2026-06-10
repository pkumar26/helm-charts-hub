# Gateway API Chart for Istio Ambient Mode

Kubernetes Gateway API resources for Istio Ambient Mode, optimized for Azure AKS with automatic `externalTrafficPolicy: Local` configuration to fix Azure Load Balancer health probe issues.

## Features

- ✅ Kubernetes Gateway API v1 (not legacy Istio VirtualService)
- ✅ Automatic externalTrafficPolicy patching for Azure AKS
- ✅ Multi-tenant architecture with RBAC
- ✅ Cross-namespace routing with ReferenceGrants
- ✅ Azure/AWS/GCP LoadBalancer annotations
- ✅ Health probe configuration for Istio ambient mode
- ✅ Security baseline: PeerAuthentication (mTLS), AuthorizationPolicy, NetworkPolicy
- ✅ FIPS 140-2 posture and progressive dev/staging/production overlays

## Prerequisites

1. **Istio Ambient Mode installed** (v1.23+)
   ```bash
   istioctl install --set profile=ambient --skip-confirmation
   ```

2. **Gateway API CRDs installed**
   ```bash
   kubectl get crd gateways.gateway.networking.k8s.io
   ```

3. **Istio Gateway API controller enabled**
   ```bash
   kubectl set env deployment/istiod -n istio-system \
     PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER=true
   ```

## Installation

### Basic Installation (Azure AKS)

```bash
helm install istio-gateway charts/istio/gateway-api \
  --namespace istio-system \
  --create-namespace
```

### With Custom Values

```bash
helm install istio-gateway charts/istio/gateway-api \
  --namespace istio-system \
  --values my-values.yaml
```

### Environment-Specific Installation

Progressive security overlays are provided (dev → staging → production):

```bash
# Development: PERMISSIVE mTLS, no FIPS, no network isolation
helm install istio-gateway charts/istio/gateway-api \
  --namespace istio-system \
  --values charts/istio/gateway-api/values-dev.yaml

# Staging: STRICT mTLS, AuthorizationPolicy allowlist, NetworkPolicy
helm install istio-gateway charts/istio/gateway-api \
  --namespace istio-system \
  --values charts/istio/gateway-api/values-staging.yaml

# Production: FIPS posture, STRICT mTLS, default-deny AuthZ, NetworkPolicy, RBAC
helm install istio-gateway charts/istio/gateway-api \
  --namespace istio-system \
  --values charts/istio/gateway-api/values-prod.yaml
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `gateway.name` | Gateway resource name | `istio-gateway` |
| `gateway.namespace` | Gateway namespace (must be istio-system) | `istio-system` |
| `gateway.service.type` | Service type | `LoadBalancer` |
| `gateway.service.externalTrafficPolicy` | Traffic policy (CRITICAL for Azure) | `Local` |
| `gateway.service.internal` | Use internal LoadBalancer | `false` |
| `gateway.service.azure.healthProbe.enabled` | Enable Azure health probe annotations | `true` |
| `referenceGrant.enabled` | Create ReferenceGrants for cross-namespace routing | `true` |
| `rbac.enabled` | Enable RBAC policies | `false` |
| `global.fips.enabled` | FIPS 140-2 posture (ztunnel/waypoint distroless) | `false` |
| `security.peerAuthentication.enabled` | Create PeerAuthentication (mTLS) | `false` |
| `security.peerAuthentication.mode` | mTLS mode (`PERMISSIVE` / `STRICT`) | `PERMISSIVE` |
| `security.authorizationPolicy.enabled` | Attach AuthorizationPolicy to the Gateway | `false` |
| `security.authorizationPolicy.action` | `ALLOW` (with rules) = default-deny | `ALLOW` |
| `security.networkPolicy.enabled` | L3/L4 NetworkPolicy for gateway pods | `false` |

### Security Baseline (ambient mode)

This chart ships the same security primitives as the sidecar `gateway` chart,
adapted for ambient mode and the Gateway API:

- **PeerAuthentication** — mTLS is enforced by **ztunnel**; the policy applies to
  the gateway namespace (or the gateway workload when `namespaceWide: false`).
- **AuthorizationPolicy** — attached to the Gateway via `targetRefs` (the
  ambient-native mechanism) rather than a pod selector. `action: ALLOW` with an
  explicit `rules` allowlist yields default-deny for everything else.
- **NetworkPolicy** — selects the auto-created gateway Deployment pods via the
  `gateway.networking.k8s.io/gateway-name` label and permits only DNS, istiod
  (xDS/webhook), ztunnel (HBONE 15008), the listener ports, and mesh egress.

> **FIPS in ambient mode:** FIPS-validated crypto is provided by the ztunnel and
> waypoint proxies, so FIPS is enabled on the istiod/ztunnel install and the
> chart should run on FIPS-enabled AKS node pools. `global.fips.enabled` here
> documents and gates the expected posture for this chart's resources.

```yaml
security:
  peerAuthentication:
    enabled: true
    mode: STRICT
  authorizationPolicy:
    enabled: true
    action: ALLOW   # default-deny with the allowlist below
    rules:
      - from:
          - source:
              namespaces: ["istio-system", "production"]
        to:
          - operation:
              methods: ["GET", "POST"]
  networkPolicy:
    enabled: true
```

### Azure AKS Configuration

```yaml
gateway:
  service:
    type: LoadBalancer
    externalTrafficPolicy: Local  # CRITICAL for Azure
    azure:
      healthProbe:
        enabled: true
        port: "15021"
        path: "/healthz/ready"
        protocol: "http"
      # Optional: internal LB
      # internal: true
      # subnet: "gateway-subnet"
```

### Multi-Tenant Configuration

```yaml
rbac:
  enabled: true
  platformAdmins:
    - "platform-team@example.com"
  applicationTeams:
    - name: "app-team-1"
      namespaces:
        - app1-namespace
    - name: "app-team-2"
      namespaces:
        - app2-namespace

referenceGrant:
  enabled: true
  namespaces:
    - app1-namespace
    - app2-namespace
```

## Usage

### Application Teams: Create HTTPRoute

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

Apply it:
```bash
kubectl apply -f my-route.yaml
```

### Verify Gateway

```bash
# Check Gateway status
kubectl get gateway -n istio-system

# Check auto-created service
kubectl get svc -n istio-system

# Check externalTrafficPolicy was set
kubectl get svc istio-gateway-istio -n istio-system \
  -o jsonpath='{.spec.externalTrafficPolicy}'
# Should output: Local

# Test routing
GATEWAY_IP=$(kubectl get svc istio-gateway-istio -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$GATEWAY_IP/myapp
```

## Troubleshooting

### LoadBalancer Gets IP But Times Out

This is a known Azure AKS issue. The chart automatically applies `externalTrafficPolicy: Local` via a post-install hook.

If it still doesn't work:
```bash
# Manually patch the service
kubectl patch svc istio-gateway-istio -n istio-system \
  -p '{"spec":{"externalTrafficPolicy":"Local"}}'
```

See [docs/azure-lb-externaltrafficpolicy-fix.md](../../../docs/azure-lb-externaltrafficpolicy-fix.md) for details.

### Gateway Not Creating Service

Ensure:
1. Gateway is in `istio-system` namespace
2. Istio Gateway API controller is enabled
3. Gateway controller has proper RBAC permissions

```bash
# Check istiod deployment
kubectl get deploy istiod -n istio-system -o yaml | grep PILOT_ENABLE_GATEWAY_API

# Check Gateway controller logs
kubectl logs -n istio-system -l app=istiod | grep gateway
```

### HTTPRoute Not Working

1. Check HTTPRoute status:
   ```bash
   kubectl get httproute -A
   ```

2. Verify ReferenceGrant exists:
   ```bash
   kubectl get referencegrant -n <your-namespace>
   ```

3. Check Gateway allows your namespace:
   ```bash
   kubectl get gateway istio-gateway -n istio-system -o yaml | grep -A 5 allowedRoutes
   ```

## Architecture

```
┌─────────────────────────────────────┐
│    Platform Team (istio-system)    │
│  ┌─────────────────────────────┐   │
│  │  Gateway Resource           │   │
│  │  - Multi-tenant config      │   │
│  │  - LoadBalancer service     │   │
│  │  - externalTrafficPolicy    │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  Application Teams (their NS)      │
│  ┌──────────────┐  ┌──────────────┐│
│  │  HTTPRoute   │  │ ReferenceGrant││
│  │  - Path      │  │ - Allow       ││
│  │  - Hostname  │  │   Gateway     ││
│  └──────────────┘  └──────────────┘│
└─────────────────────────────────────┘
```

## Examples

See [examples/istio-ambient/](../../../examples/istio-ambient/) for complete examples.

## Related Charts

- `charts/istio/base` - Istio base CRDs
- `charts/istio/istiod` - Istio control plane
- `charts/istio/kiali` - Service mesh observability

## References

- [Istio Ambient Mode](https://istio.io/latest/docs/ambient/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Azure AKS LoadBalancer](https://learn.microsoft.com/en-us/azure/aks/load-balancer-standard)
