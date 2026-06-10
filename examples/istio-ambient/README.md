# Istio Ambient Mode - Manual Setup Examples

This directory contains manual Kubernetes manifests for setting up Istio in ambient mode on Azure AKS. These files were used during the initial setup and testing phase and serve as examples for the Helm charts.

## 📁 Files Overview

| File | Managed By | Purpose |
|------|------------|---------|
| `gateway.yaml` | **Platform Team** | Shared Gateway in istio-system namespace |
| `httproute-example.yaml` | **Application Teams** | Example HTTPRoute for routing traffic |
| `kiali.yaml` | **Platform Team** | Kiali observability dashboard |
| `rbac.yaml` | **Platform Team** | Multi-tenant RBAC policies |
| `mtls-strict.yaml` | **Platform Team** | PeerAuthentication for strict mTLS |
| `authorization-policy.yaml` | **Platform Team** | AuthorizationPolicy (default-deny allowlist) |
| `network-policy.yaml` | **Platform Team** | NetworkPolicy for L3/L4 gateway isolation |
| `reference-grant.yaml` | **Application Teams** | ReferenceGrant for cross-namespace access |
| `prometheus-annotations.yaml` | **Platform Team** | Service annotations for Azure Monitor |
| `team-httproute-template.yaml` | **Application Teams** | Full template for team onboarding |
| `traefik-ingress-workaround.yaml` | **Platform Team** | Workaround for Azure LB issues |

## 🚀 Quick Start

### Prerequisites

1. **Install Istio Ambient Mode** (follow [official guide](https://istio.io/latest/docs/ambient/install/))
   ```bash
   istioctl install --set profile=ambient --skip-confirmation
   ```

2. **Enable Gateway API Controller**
   ```bash
   kubectl set env deployment/istiod -n istio-system \
     PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER=true
   ```

3. **Deploy Bundled Prometheus** (for Kiali metrics)
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.30/samples/addons/prometheus.yaml
   ```

### Deploy the Gateway

```bash
# 1. Deploy Gateway (Platform Team)
kubectl apply -f gateway.yaml

# 2. CRITICAL: Patch service for Azure AKS
kubectl patch svc istio-gateway-istio -n istio-system \
  -p '{"spec":{"externalTrafficPolicy":"Local"}}'

# 3. Verify Gateway is ready
kubectl get gateway -n istio-system
kubectl get svc -n istio-system
```

### Create HTTPRoute (Application Team)

```bash
# 1. Application team deploys HTTPRoute in their namespace
kubectl apply -f httproute-example.yaml

# 2. Verify HTTPRoute is accepted
kubectl get httproute -n default
kubectl describe httproute sampleapp-route -n default
```

### Deploy Kiali Dashboard

```bash
# 1. Deploy Kiali
kubectl apply -f kiali.yaml

# 2. CRITICAL: Patch service for Azure AKS
kubectl patch svc kiali -n istio-system \
  -p '{"spec":{"externalTrafficPolicy":"Local"}}'

# 3. Access Kiali
KIALI_IP=$(kubectl get svc kiali -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Kiali URL: http://$KIALI_IP:20001/kiali"
```

### Enable mTLS on Your Namespace

```bash
# Enable ambient mode
kubectl label namespace default istio.io/dataplane-mode=ambient

# Optional: Deploy strict mTLS policy
kubectl apply -f mtls-strict.yaml
```

### Apply the Security Baseline (Platform Team)

The manual manifests below provide the same security controls as the
`gateway-api` Helm chart. Apply them after the Gateway is ready.

```bash
# 1. STRICT mTLS for the gateway workload (handled by ztunnel in ambient mode)
kubectl apply -f mtls-strict.yaml

# 2. Default-deny AuthorizationPolicy attached to the Gateway via targetRefs
#    (edit the namespaces/methods allowlist for your environment first)
kubectl apply -f authorization-policy.yaml

# 3. L3/L4 NetworkPolicy isolating the gateway pods
#    (requires a NetworkPolicy-capable CNI; see notes below)
kubectl apply -f network-policy.yaml

# Verify
kubectl get peerauthentication,authorizationpolicy -n istio-system
kubectl get networkpolicy -n istio-system
```

> **Tip:** In ambient mode, mTLS and the AuthorizationPolicy are enforced by
> **ztunnel** and the gateway/waypoint — no sidecars or pod restarts required.

### Setup Multi-Tenant Routing

```bash
# 1. Deploy RBAC policies
kubectl apply -f rbac.yaml

# 2. Application teams use the template
kubectl apply -f team-httproute-template.yaml
```

## ⚠️ Critical Azure AKS Fix

**Problem:** LoadBalancer services get external IPs but traffic times out.

**Root Cause:** Azure LB health probe coordination bug with `externalTrafficPolicy: Cluster` (default).

**Solution:** Set `externalTrafficPolicy: Local` on all LoadBalancer services:

```bash
kubectl patch svc <service-name> -n istio-system \
  -p '{"spec":{"externalTrafficPolicy":"Local"}}'
```

See [docs/azure-lb-externaltrafficpolicy-fix.md](../../docs/azure-lb-externaltrafficpolicy-fix.md) for detailed explanation.

## 🔒 Security Baseline (parity with the Helm chart)

When you set up Istio manually, you must apply the same security controls the
`gateway-api` Helm chart applies for you. The table below maps each control to
its manifest:

| Control | Manifest | What it does |
|---------|----------|--------------|
| mTLS | `mtls-strict.yaml` | `PeerAuthentication` \u2014 ztunnel enforces STRICT mTLS for mesh traffic |
| Access control | `authorization-policy.yaml` | `AuthorizationPolicy` attached to the Gateway via `targetRefs`; `ALLOW` + allowlist = default-deny |
| Network isolation | `network-policy.yaml` | `NetworkPolicy` restricting gateway pod ingress/egress to required ports |
| Tenant RBAC | `rbac.yaml` | Only the platform team can manage Gateways |

> **Default-deny gotcha:** An `AuthorizationPolicy` with `action: ALLOW` and an
> *empty* rule matches **all** traffic. Always specify
> `namespaces`/`methods`/`principals` in `authorization-policy.yaml` so the
> allowlist actually restricts access.

### Progressive hardening (dev \u2192 staging \u2192 prod)

The Helm chart ships `values-dev/staging/prod.yaml` overlays. To reproduce them
manually:

- **dev** \u2014 set `mtls.mode: PERMISSIVE`; skip `authorization-policy.yaml` and
  `network-policy.yaml`.
- **staging** \u2014 `mtls.mode: STRICT`; apply `authorization-policy.yaml` (with a
  staging allowlist) and `network-policy.yaml`.
- **production** \u2014 STRICT mTLS, default-deny `authorization-policy.yaml`,
  `network-policy.yaml`, RBAC, and the HTTPS listener in `gateway.yaml`.

## 🛡️ FIPS 140-2 (Federal/Regulated workloads)

The Helm charts support a FIPS posture using Istio **distroless** images built
with BoringSSL/BoringCrypto (FIPS 140-2 Certificate #4407). In ambient mode the
FIPS-validated crypto lives in the **ztunnel** and **waypoint** proxies, so FIPS
is configured at install time \u2014 not on the Gateway resource:

```bash
# Install ambient with FIPS-capable distroless images
istioctl install --set profile=ambient \
  --set values.global.tag=1.23.0-distroless \
  --set values.global.hub=docker.io/istio \
  --skip-confirmation

# Run gateway/ztunnel on FIPS-enabled AKS node pools
```

After installing, the security manifests above (`mtls-strict.yaml`,
`authorization-policy.yaml`, `network-policy.yaml`) apply unchanged \u2014 the FIPS
guarantee comes from the distroless data-plane images.

## 🎯 Multi-Tenant Architecture

```
┌─────────────────────────────────────────────┐
│    Platform Team (istio-system)            │
│  ┌─────────────────────────────────────┐   │
│  │  gateway.yaml                       │   │
│  │  - Gateway resource                 │   │
│  │  - LoadBalancer service             │   │
│  │  - externalTrafficPolicy: Local     │   │
│  │  - allowedRoutes.from: All          │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  kiali.yaml, rbac.yaml,             │   │
│  │  mtls-strict.yaml,                  │   │
│  │  authorization-policy.yaml,         │   │
│  │  network-policy.yaml                │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│  Application Teams (their namespaces)      │
│  ┌──────────────┐  ┌──────────────────┐   │
│  │ HTTPRoute    │  │ ReferenceGrant   │   │
│  │ - References │  │ - Allows Gateway │   │
│  │   Gateway in │  │   to access      │   │
│  │   istio-system│ │   Services       │   │
│  └──────────────┘  └──────────────────┘   │
│                                             │
│  Files: httproute-example.yaml,            │
│         reference-grant.yaml,              │
│         team-httproute-template.yaml       │
└─────────────────────────────────────────────┘
```

### Workflow

1. **Platform Team** deploys:
   - `gateway.yaml` → Creates shared Gateway
   - `kiali.yaml` → Deploys observability
   - `rbac.yaml` → Sets up RBAC policies
   - Applies `externalTrafficPolicy: Local` patch

2. **Application Teams** deploy:
   - `httproute-example.yaml` → Routes traffic to their services
   - `reference-grant.yaml` → Grants Gateway access to their namespace
   - No need to modify the shared Gateway!

3. **Traffic flows**:
   - External → Gateway (istio-system)
   - Gateway → HTTPRoute (team namespace)
   - HTTPRoute → Service (team namespace)
   - Service → Pods (with mTLS via ztunnel)

## 🤝 For Application Teams

### Quick Start

1. **Copy the HTTPRoute example**:
   ```bash
   cp httproute-example.yaml my-app-route.yaml
   ```

2. **Customize for your app**:
   ```yaml
   metadata:
     name: my-app-route
     namespace: my-namespace  # Your team's namespace
   spec:
     parentRefs:
     - name: istio-gateway
       namespace: istio-system  # Reference shared Gateway
     rules:
     - matches:
       - path:
           type: PathPrefix
           value: /myapp
       backendRefs:
       - name: my-service
         port: 8080
   ```

3. **Deploy**:
   ```bash
   kubectl apply -f my-app-route.yaml
   ```

4. **Test**:
   ```bash
   GATEWAY_IP=$(kubectl get svc istio-gateway-istio -n istio-system \
     -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   curl http://$GATEWAY_IP/myapp
   ```

### Enable mTLS for Your Namespace

```bash
# Label namespace for ambient mode
kubectl label namespace my-namespace istio.io/dataplane-mode=ambient

# Restart your pods to inject ambient capabilities
kubectl rollout restart deployment -n my-namespace
```

### When to Create ReferenceGrant

ReferenceGrant is needed if the Gateway needs to reference resources in your namespace:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-gateway-access
  namespace: my-namespace
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: Gateway
    namespace: istio-system
  to:
  - group: ""
    kind: Service
```

## 📊 Verification

### Check Gateway Status
```bash
kubectl get gateway -n istio-system
# Should show: PROGRAMMED=True, ADDRESS=<IP>
```

### Check HTTPRoute Status
```bash
kubectl get httproute -A
# Should show: Accepted=True
```

### Test Routing
```bash
GATEWAY_IP=$(kubectl get svc -n istio-system -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].ip}')
curl -v http://$GATEWAY_IP/your-path
```

### Verify mTLS
```bash
# Check ztunnel logs for mTLS connections
kubectl logs -n istio-system -l app=ztunnel | grep "connection_security_policy"

# Or use the verification guide
cat ../../docs/istio/verify-mtls.md
```

## 🔗 Related Documentation

- [Azure LB externalTrafficPolicy Fix](../../docs/azure-lb-externaltrafficpolicy-fix.md)
- [Kiali Access Options](../../docs/istio/kiali-access-options.md)
- [Grafana Integration](../../docs/istio/grafana-integration.md)
- [mTLS Verification](../../docs/istio/verify-mtls.md)

## 🎓 Key Learnings

1. **Gateway must be in `istio-system`** namespace for auto-deployment
2. **externalTrafficPolicy: Local is required** on Azure AKS for LoadBalancer to work
3. **Health probe port 15021** must be configured for Azure LB
4. **Kiali Security badges** disabled by default - enable in Display settings
5. **Ambient mode requires no code changes** - just namespace label

## 🚀 Migrate to Helm Charts

Once you're familiar with these manifests, use the Helm charts for production:

```bash
# Deploy using Helm
helm install istio-base charts/istio/base -n istio-system
helm install istio-gateway charts/istio/gateway-api -n istio-system
helm install kiali charts/istio/kiali -n istio-system
```

The Helm charts incorporate all these learnings with configurable values for different environments.
