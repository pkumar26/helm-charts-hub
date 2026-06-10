# Azure LoadBalancer Health Probe Fix: externalTrafficPolicy

## Problem

Istio Gateway with LoadBalancer service type on Azure AKS fails to route traffic despite:
- Gateway showing PROGRAMMED status
- Service getting external IP
- Pod being healthy and ready
- HTTPRoute being accepted
- NodePort access working correctly

Symptoms:
- `curl http://<LOADBALANCER-IP>` times out
- Azure LB health probes fail
- Manual probe configuration in Azure Portal doesn't help
- Both internal and external LoadBalancer types fail

## Root Cause

Azure AKS cloud-provider has issues with health probe coordination when:
1. Using `externalTrafficPolicy: Cluster` (default)
2. Custom health probe annotations on non-standard ports (15021)
3. Multiple nodes in the cluster

With `externalTrafficPolicy: Cluster`:
- Traffic can route to any node
- Azure LB probes all nodes in backend pool
- Health probe requires cluster-wide coordination
- Some AKS versions/configurations fail this coordination
- Probes fail even though pods are healthy

## Solution

Set `externalTrafficPolicy: Local` on the LoadBalancer service.

### One-Time Fix (Existing Service)

```bash
# Patch the auto-created Gateway service
kubectl patch svc <gateway-service-name> -n istio-system \
  -p '{"spec":{"externalTrafficPolicy":"Local"}}'

# Example:
kubectl patch svc d2-gateway-istio -n istio-system \
  -p '{"spec":{"externalTrafficPolicy":"Local"}}'
```

### Permanent Fix (Gateway Annotation)

Add annotation to Gateway resource to set externalTrafficPolicy automatically:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: istio-gateway
  namespace: istio-system
  annotations:
    # Health probe configuration
    service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: "/healthz/ready"
    service.beta.kubernetes.io/azure-load-balancer-health-probe-protocol: "http"
    service.beta.kubernetes.io/azure-load-balancer-health-probe-port: "15021"
    
    # Set traffic policy to Local (critical for Azure LB health probes)
    networking.istio.io/traffic-policy: Local
```

**Note**: The Gateway controller may not respect `networking.istio.io/traffic-policy` annotation in all versions. If not, apply the patch command after Gateway creation.

## How externalTrafficPolicy: Local Fixes It

### Cluster Mode (Default - Broken)
- Traffic routes to any node
- kube-proxy forwards to pods on other nodes if needed
- Azure LB health probes all nodes
- Health probe coordination fails across cluster
- All nodes marked unhealthy by LB

### Local Mode (Working)
- Traffic only routes to nodes with Gateway pods
- No cross-node forwarding
- Azure LB health probes per-node basis
- Nodes without pods automatically removed from backend pool
- Simple per-node health check (no coordination needed)

## Trade-offs

**Pros:**
- ✅ LoadBalancer actually works
- ✅ Lower latency (no cross-node forwarding)
- ✅ Source IP preservation

**Cons:**
- ⚠️ Uneven load distribution if pods not evenly spread
- ⚠️ Traffic only sent to nodes with local pods
- ⚠️ May need pod anti-affinity or more replicas

## Verification

```bash
# 1. Check externalTrafficPolicy is set
kubectl get svc <gateway-service> -n istio-system -o jsonpath='{.spec.externalTrafficPolicy}'
# Should output: Local

# 2. Test LoadBalancer access
LB_IP=$(kubectl get svc <gateway-service> -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -v http://$LB_IP/

# 3. Verify health probes in Azure
az network lb probe list -g <node-resource-group> --lb-name kubernetes --query "[?port==15021]" -o table
```

## Why Traefik Worked

Traefik LoadBalancer worked on the same cluster because:
1. Traefik uses dedicated health port 9000 with `/ping` endpoint
2. May have had `externalTrafficPolicy: Local` in chart defaults
3. Different health probe implementation by Traefik controller

## Affected AKS Versions

This issue has been observed on:
- Older AKS clusters (420+ days old) - often work without this fix
- Newer AKS clusters - require this fix
- Likely related to Azure cloud-provider version differences

## References

- Kubernetes docs: [Service External Traffic Policy](https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#preserving-the-client-source-ip)
- Azure docs: [Load Balancer health probes](https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-custom-probe-overview)
- Istio docs: [Gateway API](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/)
