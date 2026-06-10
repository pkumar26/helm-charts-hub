# Kiali Access Configuration Options

## Option 1: External LoadBalancer (Current)
**Current configuration** - Accessible from anywhere

```yaml
# In kiali-azure-prometheus.yaml
metadata:
  annotations: {}  # No annotations
spec:
  type: LoadBalancer
```

**Access:** http://PUBLIC-IP:20001/kiali

---

## Option 2: Internal LoadBalancer (Private Network Only)
**Secure** - Only accessible from within VNet or via VPN/Bastion

### Steps:
1. Edit `kiali-azure-prometheus.yaml`, uncomment the annotation:
```yaml
metadata:
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
```

2. Apply the change:
```bash
kubectl apply -f kiali-azure-prometheus.yaml
```

3. Get the private IP:
```bash
kubectl get svc kiali -n istio-system
```

**Access:** http://PRIVATE-IP:20001/kiali (from within VNet)

---

## Option 3: Expose via Istio Gateway (Recommended for Production)
**Best for production** - Use your existing gateway with proper routing

### Create HTTPRoute for Kiali:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kiali-route
  namespace: istio-system
spec:
  parentRefs:
  - name: istio-gateway
    namespace: istio-system
  hostnames:
  - "kiali.yourdomain.com"  # Your domain
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: kiali
      port: 20001
```

### Then change Kiali service to ClusterIP:
```yaml
spec:
  type: ClusterIP  # No external IP needed
```

**Access:** https://kiali.yourdomain.com (through gateway)

---

## Option 4: kubectl Port-Forward (Dev/Testing)
**No LoadBalancer needed** - Direct tunnel from your laptop

### Steps:
1. Change Kiali service to ClusterIP:
```yaml
spec:
  type: ClusterIP
```

2. Apply change:
```bash
kubectl apply -f kiali-azure-prometheus.yaml
```

3. Create port-forward:
```bash
kubectl port-forward -n istio-system svc/kiali 20001:20001
```

**Access:** http://localhost:20001/kiali

---

## Quick Switch to Internal LoadBalancer

```bash
# Patch the service to internal (no file edit needed)
kubectl patch svc kiali -n istio-system -p '{"metadata":{"annotations":{"service.beta.kubernetes.io/azure-load-balancer-internal":"true"}}}'

# Get new internal IP
kubectl get svc kiali -n istio-system
```

## Quick Switch Back to External LoadBalancer

```bash
# Remove internal annotation
kubectl annotate svc kiali -n istio-system service.beta.kubernetes.io/azure-load-balancer-internal-

# Get new external IP (may take a minute)
kubectl get svc kiali -n istio-system
```

---

## Security Recommendation

For production:
1. **Use Internal LoadBalancer** or **ClusterIP with Gateway/Ingress**
2. **Enable authentication** in Kiali (change from `anonymous` to `token` or `openid`)
3. **Use Azure AD integration** for access control
4. **Add TLS/HTTPS** via gateway or ingress

For development/testing:
- External LoadBalancer with anonymous auth is fine
- Lock down by IP using Azure NSG or LoadBalancer source ranges

---

## Kiali UI Configuration

### Enable mTLS Status Display

By default, Kiali doesn't show mTLS lock icons on the service graph. To see mTLS status:

1. Open Kiali dashboard
2. Click **Display** menu (top right corner, near the refresh button)
3. In the **Show Badges** section, enable:
   - ✅ **Security** - Shows mTLS lock icons 🔒
   - ✅ **Virtual Services** - Shows VS badges
   - ✅ **Gateways** - Shows Gateway badges

4. Refresh the Graph view

The 🔒 lock icon will appear on edges between services that are using mTLS encryption.

### Other Useful Display Options

- **Show Edge Labels**: Select "Response Time" or "Request Rate" to see metrics on graph edges
- **Traffic Animation**: Shows real-time traffic flow
- **Idle Nodes**: Toggle to show/hide services with no traffic
- **Service Nodes**: Choose between "App", "Workload", or "Service" view granularity

### Verify mTLS is Working

If you don't see lock icons even after enabling Security badges:

1. Ensure namespace has ambient mode enabled:
   ```bash
   kubectl label namespace <your-namespace> istio.io/dataplane-mode=ambient
   ```

2. Create PeerAuthentication policy:
   ```bash
   kubectl apply -f mtls-strict-mode.yaml
   ```

3. Generate traffic to see it in the graph:
   ```bash
   # Traffic is needed for Kiali to show connections
   curl http://<service-url>
   ```

4. Wait 1-2 minutes for Prometheus metrics to be scraped

5. Check ztunnel logs to confirm mTLS is active:
   ```bash
   kubectl logs -n istio-system -l app=ztunnel | grep -i "connection_security_policy"
   ```
