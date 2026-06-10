# Troubleshooting: Gateway LoadBalancer Not Responding

## Symptom
- Gateway shows `PROGRAMMED: True` with external IP
- Gateway pod is running and healthy
- HTTPRoute shows `Accepted: True`
- Backend services exist and have endpoints
- **But**: Connection times out when accessing LoadBalancer IP

## Root Cause
Azure Load Balancer health probe is misconfigured and marks backend as unhealthy.

## Why It Happens

### Istio Gateway Auto-Created Service
When you create a Gateway resource, Istio's gateway controller automatically creates a LoadBalancer service. However, the health probe configuration depends on:

1. **Istio version** - Newer versions add health probe annotations automatically
2. **AKS version** - Different cloud-provider implementations
3. **Timing** - Race conditions during service creation

### Default Behavior (Bad)
- Azure LB probes **port 80** (application port)
- No HTTP path specified
- Gateway pod can't respond to probe correctly
- Backend marked as unhealthy
- Traffic never reaches pod

### Correct Behavior (Good)
- Azure LB probes **port 15021** (Envoy health port) with path **/healthz/ready**
- Gateway pod responds with HTTP 200
- Backend marked as healthy
- Traffic flows normally

## Diagnosis Steps

### 1. Verify Gateway Pod is Healthy
```bash
kubectl get pods -n istio-system -l gateway.istio.io/managed=istio-gateway-controller
kubectl logs -n istio-system <gateway-pod> | grep -i ready
```

Should see: `Envoy proxy is ready` and `Readiness succeeded`

### 2. Check Service Endpoints
```bash
kubectl get endpoints <gateway-service> -n istio-system
```

Should show: `<pod-ip>:80,<pod-ip>:15021`

### 3. Test from Inside Cluster
```bash
kubectl run test --rm -it --image=curlimages/curl -- curl -v http://<gateway-lb-ip>/path
```

If this **works** but external access **doesn't** → Health probe issue

### 4. Check Azure LB Health Probe
```bash
az network lb list --query "[?contains(name,'gateway') || contains(name,'kubernetes')].{Name:name, RG:resourceGroup}" -o table

az network lb probe list --lb-name <lb-name> --resource-group <rg-name> \
  --query "[].{Name:name, Protocol:protocol, Port:port, Path:requestPath}" -o table
```

Look for:
- ❌ Port 80 with no path - **BAD**
- ✅ Port 15021 or port 80 with path `/healthz/ready` - **GOOD**

## Solution

### Quick Fix (Existing Cluster)
Patch the service to add health probe annotations:

```bash
kubectl annotate svc <gateway-service> -n istio-system \
  service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path=/healthz/ready \
  service.beta.kubernetes.io/azure-load-balancer-health-probe-protocol=http \
  --overwrite
```

Wait 2-3 minutes for Azure to update the health probe, then test.

### Permanent Fix (New Deployments)
Add health probe annotations to Gateway resource YAML:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: istio-gateway
  namespace: istio-system
  annotations:
    # Azure Load Balancer health probe configuration
    service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: "/healthz/ready"
    service.beta.kubernetes.io/azure-load-balancer-health-probe-protocol: "http"
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    port: 80
    protocol: HTTP
```

Apply:
```bash
kubectl apply -f gateway.yaml
```

### Verify Fix
```bash
# Wait 2-3 minutes, then check probe configuration
az network lb probe list --lb-name <lb-name> --resource-group <rg-name> -o table

# Test connectivity
curl -v http://<gateway-lb-ip>/your-path
```

## Prevention

**Always include health probe annotations** in Gateway definitions for Azure AKS:

```yaml
annotations:
  service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: "/healthz/ready"
  service.beta.kubernetes.io/azure-load-balancer-health-probe-protocol: "http"
```

## Related Issues

- **Internal LoadBalancer not working**: Same solution applies
- **Gateway works from inside cluster but not outside**: Health probe issue
- **502/503 errors**: Check backend health in Azure portal

## Additional Notes

### Why This Doesn't Affect All Clusters
- Newer Istio versions (1.20+) may add annotations automatically
- AKS versions have different cloud-provider implementations
- Some installations get lucky with timing

### Alternative: Use NodePort + Manual LB
If auto-created service continues to have issues:
1. Set Gateway service type to ClusterIP
2. Create LoadBalancer manually with correct health probe
3. Point LB backend pool to nodes

### AWS/GCP Equivalent
Similar issues occur on other clouds with different annotation keys:
- AWS: `service.beta.kubernetes.io/aws-load-balancer-healthcheck-path`
- GCP: Usually auto-configured correctly
