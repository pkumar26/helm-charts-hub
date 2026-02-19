# Getting Started

This guide takes you from zero to a running sample application on a local Kubernetes cluster in under 5 minutes.

## Prerequisites

Verify you have the required tools installed:

```bash
# Check Helm (≥ 3.12)
helm version --short

# Check kubectl (≥ 1.26)
kubectl version --client --short

# Check kind (≥ 0.20)
kind version
```

If any tool is missing, install it:

| Tool | Install Command |
|------|----------------|
| Helm | `brew install helm` or see [helm.sh/docs/intro/install](https://helm.sh/docs/intro/install/) |
| kubectl | `brew install kubectl` |
| kind | `brew install kind` or see [kind.sigs.k8s.io](https://kind.sigs.k8s.io/) |

## 1. Create a Local Cluster

```bash
kind create cluster --name helm-demo
```

Verify the cluster is ready:

```bash
kubectl cluster-info --context kind-helm-demo
```

## 2. Install an Ingress Controller (Optional)

If you want to test Ingress routing, install an ingress controller. Choose one:

### Option A: NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.hostPort.enabled=true \
  --set controller.service.type=NodePort
```

### Option B: Traefik

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --set ports.web.hostPort=80 \
  --set ports.websecure.hostPort=443
```

Wait for the controller to be ready:

```bash
# For NGINX:
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s

# For Traefik:
kubectl wait --namespace traefik --for=condition=ready pod --selector=app.kubernetes.io/name=traefik --timeout=90s
```

## 3. Install the web-app Chart

### From Source (Local Development)

```bash
# Clone the repository (if you haven't already)
git clone https://github.com/<org>/helm-charts-hub.git
cd helm-charts-hub

# Build dependencies
helm dependency build charts/web-app

# Install with a sample nginx image
helm install my-app charts/web-app \
  --set image.repository=nginx \
  --set image.tag=1.27-alpine
```

### From OCI Registry

```bash
helm install my-app oci://ghcr.io/<org>/charts/web-app --version 0.1.0 \
  --set image.repository=nginx \
  --set image.tag=1.27-alpine
```

## 4. Verify the Deployment

```bash
# Check pods are running
kubectl get pods -l app.kubernetes.io/instance=my-app

# Check the service
kubectl get svc -l app.kubernetes.io/instance=my-app
```

Expected output:

```
NAME     READY   STATUS    RESTARTS   AGE
my-app   1/1     Running   0          30s

NAME     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
my-app   ClusterIP   10.96.x.x     <none>        80/TCP    30s
```

### Port-forward and Test

```bash
kubectl port-forward svc/my-app-web-app 8080:80 &
curl http://localhost:8080
```

You should see the NGINX welcome page.

## 5. Enable Ingress Routing (Optional)

If you installed an ingress controller in step 2:

```bash
helm upgrade my-app charts/web-app \
  --set image.repository=nginx \
  --set image.tag=1.27-alpine \
  --set ingress.enabled=true \
  --set "ingress.hosts[0].host=my-app.local" \
  --set "ingress.hosts[0].paths[0].path=/" \
  --set "ingress.hosts[0].paths[0].pathType=Prefix"
```

Test with:

```bash
curl -H "Host: my-app.local" http://localhost:80
```

## 6. Clean Up

```bash
# Uninstall the chart
helm uninstall my-app

# (Optional) Remove the ingress controller
helm uninstall ingress-nginx -n ingress-nginx  # or: helm uninstall traefik -n traefik

# Delete the kind cluster
kind delete cluster --name helm-demo
```

## Next Steps

- Explore [example values files](../examples/) for minimal and production configurations
- Read the [web-app README](../charts/web-app/README.md) for the full configuration reference
- Check the [Chart Catalog](../CHARTS.md) for all available charts
- See [CONTRIBUTING.md](../CONTRIBUTING.md) to add your own charts
