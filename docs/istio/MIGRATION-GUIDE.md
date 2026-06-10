# Migration Guide: Manual Setup to Helm Charts

This guide helps you migrate from manual Istio Ambient Mode setup to Helm chart-based deployment.

## Why Migrate to Helm?

✅ **Version Control**: Track configuration changes via Git  
✅ **Repeatability**: Same configuration across dev/staging/prod  
✅ **Automation**: Automatic externalTrafficPolicy patching  
✅ **Upgrades**: Easy rollback and version management  
✅ **Customization**: Environment-specific values files  

## Prerequisites

Your manual setup should have:
- Istio ambient mode installed
- Gateway working with externalTrafficPolicy: Local patch
- HTTPRoutes routing traffic
- Kiali dashboard (optional)

## Migration Steps

### Step 1: Export Current Configuration

```bash
# Export your current Gateway
kubectl get gateway -n istio-system -o yaml > current-gateway.yaml

# Export HTTPRoutes
kubectl get httproute -A -o yaml > current-httproutes.yaml

# Export ReferenceGrants
kubectl get referencegrant -A -o yaml > current-referencegrants.yaml

# Export Kiali deployment (if using)
kubectl get deployment,service,configmap -n istio-system -l app=kiali -o yaml > current-kiali.yaml
```

### Step 2: Create Values Files

**For Gateway API:**

```yaml
# values-gateway-prod.yaml
gateway:
  name: istio-gateway
  namespace: istio-system
  service:
    type: LoadBalancer
    externalTrafficPolicy: Local  # Auto-applied by chart
    internal: false  # Change to true for internal LB
    azure:
      healthProbe:
        enabled: true

referenceGrant:
  enabled: true
  namespaces:
    - default
    - app1-namespace
    - app2-namespace

rbac:
  enabled: true
  platformAdmins:
    - "platform-team@company.com"
  applicationTeams:
    - name: "app-team-1"
      namespaces:
        - app1-namespace
```

**For Kiali:**

```yaml
# values-kiali-prod.yaml
enabled: true

kiali-server:
  service:
    type: LoadBalancer
    externalTrafficPolicy: Local
  external_services:
    prometheus:
      url: "http://prometheus.istio-system:9090"
  auth:
    strategy: token  # Change from anonymous for production
```

### Step 3: Test in Dry-Run Mode

```bash
# Test Gateway API chart
helm install istio-gateway charts/istio/gateway-api \
  --namespace istio-system \
  --values values-gateway-prod.yaml \
  --dry-run --debug

# Test Kiali chart
helm install kiali charts/istio/kiali \
  --namespace istio-system \
  --values values-kiali-prod.yaml \
  --dry-run --debug
```

Review the output to ensure it matches your manual configuration.

### Step 4: Delete Manual Resources (Backup First!)

```bash
# Backup everything first!
kubectl get all,gateway,httproute,referencegrant -A -o yaml > full-backup-$(date +%Y%m%d-%H%M%S).yaml

# Delete manual Gateway (Helm will recreate)
kubectl delete gateway istio-gateway -n istio-system

# Wait for service to be cleaned up
kubectl wait --for=delete svc/istio-gateway-istio -n istio-system --timeout=60s

# Delete manual Kiali (if migrating)
kubectl delete deployment,service,configmap,serviceaccount,clusterrole,clusterrolebinding \
  -n istio-system -l app=kiali
```

⚠️ **IMPORTANT**: DO NOT delete HTTPRoutes yet - they can coexist with the new Gateway

### Step 5: Install Helm Charts

```bash
# Install Gateway API chart
helm install istio-gateway charts/istio/gateway-api \
  --namespace istio-system \
  --values values-gateway-prod.yaml

# Verify Gateway is ready
kubectl get gateway -n istio-system
kubectl get svc -n istio-system

# Verify externalTrafficPolicy was set
kubectl get svc istio-gateway-istio -n istio-system \
  -o jsonpath='{.spec.externalTrafficPolicy}'
# Should output: Local

# Install Kiali (if using)
helm install kiali charts/istio/kiali \
  --namespace istio-system \
  --values values-kiali-prod.yaml

# Wait for Kiali to be ready
kubectl rollout status deployment/kiali -n istio-system
```

### Step 6: Verify Traffic Flow

```bash
# Get Gateway IP
GATEWAY_IP=$(kubectl get svc istio-gateway-istio -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test HTTPRoutes
curl -v http://$GATEWAY_IP/your-path

# Check HTTPRoute status
kubectl get httproute -A
```

All existing HTTPRoutes should continue working with the new Gateway!

### Step 7: Migrate HTTPRoutes (Optional)

If you want Helm to manage HTTPRoutes:

```yaml
# values-gateway-prod.yaml (add this section)
httpRoute:
  enabled: true
  name: main-route
  namespace: default
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: main-service
          port: 80
```

Then upgrade:

```bash
helm upgrade istio-gateway charts/istio/gateway-api \
  --namespace istio-system \
  --values values-gateway-prod.yaml
```

## Rollback Plan

If something goes wrong:

```bash
# Uninstall Helm charts
helm uninstall istio-gateway -n istio-system
helm uninstall kiali -n istio-system

# Restore from backup
kubectl apply -f full-backup-<timestamp>.yaml

# Re-apply externalTrafficPolicy patch
kubectl patch svc istio-gateway-istio -n istio-system \
  -p '{"spec":{"externalTrafficPolicy":"Local"}}'
```

## Comparison: Manual vs Helm

| Aspect | Manual Setup | Helm Chart |
|--------|--------------|------------|
| externalTrafficPolicy | Manual patch required | Auto-patched via hook |
| ReferenceGrants | One file per namespace | Templated, auto-generated |
| RBAC | Manual management | Configured via values |
| Upgrades | Manual re-apply | `helm upgrade` |
| Version Control | Raw YAML in Git | Values files in Git |
| Rollback | Manual restore | `helm rollback` |
| Multi-Environment | Multiple YAML files | Multiple values files |

## Environment-Specific Configuration

**Development:**
```yaml
# values-gateway-dev.yaml
gateway:
  service:
    type: LoadBalancer
    externalTrafficPolicy: Local
    internal: false  # Public for easy access

rbac:
  enabled: false  # Simplified permissions
```

**Staging:**
```yaml
# values-gateway-staging.yaml
gateway:
  service:
    type: LoadBalancer
    externalTrafficPolicy: Local
    internal: true  # Private network

rbac:
  enabled: true
```

**Production:**
```yaml
# values-gateway-prod.yaml
gateway:
  service:
    type: LoadBalancer
    externalTrafficPolicy: Local
    internal: true
    azure:
      subnet: "gateway-subnet"
      # loadBalancerIP: "10.0.1.100"  # Static IP

rbac:
  enabled: true
  platformAdmins:
    - "platform-team@company.com"
```

Deploy to each environment:

```bash
# Dev
helm install istio-gateway charts/istio/gateway-api -n istio-system -f values-gateway-dev.yaml

# Staging
helm install istio-gateway charts/istio/gateway-api -n istio-system -f values-gateway-staging.yaml

# Production
helm install istio-gateway charts/istio/gateway-api -n istio-system -f values-gateway-prod.yaml
```

## Keeping Manual Examples

The manual setup files remain useful for:
- Learning how things work under the hood
- Troubleshooting Helm-generated resources
- Quick testing without Helm
- Documentation and training

Keep them in `examples/istio-ambient/` for reference!

## Next Steps

1. ✅ Migrate Gateway to Helm
2. ✅ Migrate Kiali to Helm
3. ⏭️ Create CI/CD pipeline with Helm
4. ⏭️ Set up GitOps with ArgoCD/Flux
5. ⏭️ Document team onboarding process

## Troubleshooting

### Gateway Not Creating After Migration

Check if old service still exists:
```bash
kubectl get svc istio-gateway-istio -n istio-system
```

If it exists, delete it manually and let Helm recreate:
```bash
kubectl delete svc istio-gateway-istio -n istio-system
helm upgrade --reuse-values istio-gateway charts/istio/gateway-api -n istio-system
```

### externalTrafficPolicy Not Set

The chart uses a post-install hook Job. Check if it ran:
```bash
kubectl get jobs -n istio-system
kubectl logs job/istio-gateway-service-patcher -n istio-system
```

If failed, manually patch and create a bug report:
```bash
kubectl patch svc istio-gateway-istio -n istio-system \
  -p '{"spec":{"externalTrafficPolicy":"Local"}}'
```

### HTTPRoutes Stop Working

Verify Gateway allows your namespace:
```bash
kubectl get gateway istio-gateway -n istio-system -o yaml | grep -A 10 listeners
```

Should see `from: All` under allowedRoutes.

## Support

- 📚 [Implementation Summary](IMPLEMENTATION-SUMMARY.md)
- 🐛 [Azure LB Fix](../azure-lb-externaltrafficpolicy-fix.md)
- 📖 [Gateway API Chart README](../../charts/istio/gateway-api/README.md)
- 💬 Open an issue on GitHub for questions
