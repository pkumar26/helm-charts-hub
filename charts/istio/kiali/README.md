# Kiali Chart - Optional Mesh Observability

**Optional Component**: This chart deploys [Kiali](https://kiali.io/), a management console for Istio service mesh. It is **not required** for mesh operation but provides valuable visualization and troubleshooting capabilities.

## Overview

Kiali provides a graphical interface to visualize your service mesh topology, monitor traffic flows, and troubleshoot issues. It integrates with Prometheus and Grafana to display metrics and dashboards.

### When to Use Kiali

**Use Kiali if:**
- You need visual service mesh topology and traffic flow
- You want real-time monitoring of mesh health and performance
- You need troubleshooting tools for mesh configuration
- You have Prometheus available for metrics

**Skip Kiali if:**
- Running in air-gapped environments with limited connectivity
- You prefer CLI tools (`istioctl`, `kubectl`) for troubleshooting
- You already have comprehensive monitoring (Prometheus + Grafana)
- You want to minimize cluster resource usage

## Prerequisites

1. **Istio installed**: Base and Istiod charts must be deployed
2. **Prometheus**: A Prometheus instance collecting Istio metrics
   - AKS users: Enable Azure Monitor managed Prometheus or deploy Prometheus Operator
   - Update `external_services.prometheus.url` in values file
3. **Grafana** (optional): For dashboard links
   - Update `external_services.grafana.in_cluster_url` in values file

## Installation

### Step 1: Update Dependencies

```bash
cd charts/istio/kiali
helm dependency update
```

### Step 2: Configure Prometheus Endpoint

Edit the values file for your environment to point to your Prometheus instance:

```yaml
kiali-server:
  external_services:
    prometheus:
      url: "http://prometheus-server.monitoring.svc.cluster.local:80"
    grafana:
      enabled: true
      in_cluster_url: "http://grafana.monitoring.svc.cluster.local:80"
```

**Common Prometheus URLs:**
- **kube-prometheus-stack**: `http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090`
- **Azure Monitor Prometheus**: `http://ama-metrics-prometheus-server.kube-system.svc.cluster.local:80`
- **Custom Prometheus**: Update to match your service name and namespace

### Step 3: Deploy Kiali

```bash
# Development (anonymous auth, enabled)
helm upgrade --install kiali charts/istio/kiali \
  --namespace istio-system \
  --values charts/istio/kiali/values-dev.yaml

# Staging (token auth, enabled)
helm upgrade --install kiali charts/istio/kiali \
  --namespace istio-system \
  --values charts/istio/kiali/values-staging.yaml

# Production (token auth, disabled by default)
# Enable by setting enabled=true
helm upgrade --install kiali charts/istio/kiali \
  --namespace istio-system \
  --values charts/istio/kiali/values-prod.yaml \
  --set enabled=true
```

## Authentication Strategies

### 1. Anonymous (Development Only)

No authentication required. Anyone with access to the service can view the dashboard.

```yaml
auth:
  strategy: anonymous
```

### 2. Token Authentication (Recommended for Production)

Users must provide a Kubernetes service account token to access Kiali.

```yaml
auth:
  strategy: token
```

**Get a token for access:**

```bash
# Create a service account
kubectl create serviceaccount kiali-viewer -n istio-system

# Grant view permissions
kubectl create clusterrolebinding kiali-viewer \
  --clusterrole=view \
  --serviceaccount=istio-system:kiali-viewer

# Get the token
kubectl create token kiali-viewer -n istio-system --duration=24h
```

### 3. OpenID Connect (Enterprise)

Integrate with your identity provider (Azure AD, Okta, etc.).

```yaml
auth:
  strategy: openid
  openid:
    client_id: "kiali"
    issuer_uri: "https://login.microsoftonline.com/<tenant-id>/v2.0"
    username_claim: "preferred_username"
```

## Accessing Kiali Dashboard

### Port Forward (Quick Access)

```bash
kubectl port-forward -n istio-system svc/kiali 20001:20001
# Open http://localhost:20001
```

### NodePort (Development)

The dev values use NodePort for easy local access:

```bash
# Get the node port
kubectl get svc kiali -n istio-system

# Access via node IP
http://<node-ip>:30020
```

### Ingress (Production)

Enable ingress in values file:

```yaml
kiali-server:
  ingress:
    enabled: true
    class_name: nginx
    hosts:
    - kiali.example.com
    tls:
    - secretName: kiali-tls
      hosts:
      - kiali.example.com
```

## Configuration

### Environment-Specific Values

| Environment | Authentication | Replicas | Resources | Enabled by Default |
|-------------|----------------|----------|-----------|-------------------|
| **Development** | Anonymous | 1 | Minimal | ✅ Yes |
| **Staging** | Token | 1 | Moderate | ✅ Yes |
| **Production** | Token/OpenID | 1 | Full | ❌ No (opt-in) |

### Key Configuration Options

```yaml
enabled: false  # Set to true to deploy

kiali-server:
  deployment:
    replicas: 1
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 1Gi
  
  auth:
    strategy: token  # anonymous, token, openid
  
  external_services:
    prometheus:
      url: "http://prometheus-server.monitoring.svc.cluster.local:80"
    grafana:
      enabled: true
      in_cluster_url: "http://grafana.monitoring.svc.cluster.local:80"
```

## Features

### Service Graph

Visualize service mesh topology with traffic flows, success rates, and latency metrics.

### Traffic Metrics

View request rates, error rates, and latencies for services, workloads, and applications.

### Configuration Validation

Detect configuration issues in Istio resources (VirtualServices, DestinationRules, etc.).

### Distributed Tracing

Integrate with Jaeger or Zipkin for distributed tracing (if enabled).

### Istio Config

View and validate Istio configuration objects directly from the UI.

## Troubleshooting

### Kiali Can't Connect to Prometheus

**Symptoms**: "Prometheus not available" error in Kiali UI

**Solution**:
1. Verify Prometheus is running:
   ```bash
   kubectl get svc -n monitoring
   ```
2. Test connectivity from Kiali pod:
   ```bash
   kubectl exec -n istio-system deploy/kiali -- \
     curl -v http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/query?query=up
   ```
3. Update `external_services.prometheus.url` to match your Prometheus service

### Authentication Token Expired

**Symptoms**: "Unauthorized" error after token login

**Solution**: Generate a new token:
```bash
kubectl create token kiali-viewer -n istio-system --duration=24h
```

### Service Graph Shows "Unknown"

**Symptoms**: Services appear as "Unknown" in the graph

**Solution**: Enable Istio metrics on workloads:
```bash
# Check if sidecar is injected
kubectl get pods -n <namespace> -o jsonpath='{.items[*].spec.containers[*].name}'

# Enable injection if missing
kubectl label namespace <namespace> istio-injection=enabled
```

## Uninstallation

```bash
helm uninstall kiali -n istio-system
```

## Additional Resources

- [Kiali Documentation](https://kiali.io/docs/)
- [Kiali GitHub](https://github.com/kiali/kiali)
- [Istio Telemetry](https://istio.io/latest/docs/tasks/observability/)

## Support

For issues specific to this chart, see [CONTRIBUTING.md](../../../CONTRIBUTING.md).

For Kiali-specific issues, see [Kiali Support](https://kiali.io/docs/community/).
