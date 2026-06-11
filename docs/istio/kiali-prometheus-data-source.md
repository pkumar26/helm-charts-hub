# Kiali Prometheus Data Source (Dev vs. Production)

Kiali builds its entire service graph, traffic metrics, and health views from
Istio telemetry (`istio_requests_total`, etc.) by querying a **Prometheus PromQL
API** (`/api/v1/query`, `/api/v1/query_range`). Without a reachable query
endpoint, Kiali shows errors like:

```
Could not fetch metrics: error in metric request_count:
Post "http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/query_range":
dial tcp: lookup prometheus-server.monitoring.svc.cluster.local ... no such host
```

This is almost always a **wrong or unreachable `external_services.prometheus.url`**.

---

## Do I need the Istio Prometheus addon in production if I already use Azure Managed Prometheus + Managed Grafana?

**No — do not use the Istio sample addon
(`samples/addons/prometheus.yaml`) in production.** It is a demo deployment:
single replica, no persistent storage, no retention tuning, no HA. It is fine
for **dev only**.

But there is an important catch with the managed stack:

> **Azure Managed Prometheus does NOT, by itself, give Kiali a usable query
> endpoint.**

Azure Managed Prometheus (the `ama-metrics` pods in `kube-system`) is a
**collection / remote-write agent**. It scrapes metrics and pushes them to an
**Azure Monitor Workspace (AMW)** in the cloud. It does **not** expose an
in-cluster PromQL **query** API for Kiali to call. Azure Managed Grafana solves
dashboards and alerting, but Kiali specifically needs the **query** API.

So even with the managed stack, you must give Kiali one of the following.

---

## Production options

### Option A — Point Kiali at the Azure Monitor Workspace query endpoint (stay fully managed)

- AMW exposes a Prometheus-compatible query endpoint, but it is authenticated
  with **Microsoft Entra ID** (Azure AD) bearer tokens that expire (~hourly).
- Kiali cannot refresh Entra tokens on its own, so you run a small **auth proxy
  sidecar / reverse proxy** that injects a managed-identity token, then set:

  ```yaml
  kiali-server:
    external_services:
      prometheus:
        url: "http://localhost:8080"   # the local auth proxy in front of AMW
  ```

- **Pro:** no self-managed Prometheus to operate.
- **Con:** extra proxy + workload-identity / managed-identity IAM plumbing.

### Option B — Run a dedicated in-cluster Prometheus for Kiali (most common)

- Deploy a production-grade Prometheus (e.g. `kube-prometheus-stack` via Helm)
  with persistence and retention, scraping Istio metrics, and point Kiali at it:

  ```yaml
  kiali-server:
    external_services:
      prometheus:
        url: "http://prometheus-operated.monitoring:9090"  # your prod Prometheus
  ```

- You can still keep **Azure Managed Prometheus + Managed Grafana** in parallel
  for long-term storage and org-wide dashboards (remote-write both).
- **Pro:** simple, Kiali-supported, works out of the box.
- **Con:** one more component to operate.

| Environment | Recommended approach |
| ----------- | -------------------- |
| **Dev**     | Lightweight in-cluster Prometheus (Istio addon or a minimal `kube-prometheus-stack`) so Kiali works for troubleshooting |
| **Production** | Option A (managed-only, with auth proxy) **or** Option B (dedicated prod Prometheus). Most teams pick **B** for Kiali and keep AMW/Grafana for everything else |

Either way, `external_services.prometheus.url` must point at a reachable PromQL
endpoint.

---

## Dev setup (what this repo uses)

1. Install the Istio Prometheus addon (dev only):

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.30/samples/addons/prometheus.yaml
   ```

   This creates a `prometheus` Deployment + Service in `istio-system` on
   port `9090`.

2. Point Kiali at it in
   [`environments/dev/kiali.values.yaml`](../../environments/dev/kiali.values.yaml):

   ```yaml
   kiali-server:
     external_services:
       prometheus:
         url: "http://prometheus.istio-system:9090"
       grafana:
         enabled: false   # no in-cluster Grafana in dev
   ```

3. Apply:

   ```bash
   helm upgrade --install kiali charts/istio/kiali \
     --namespace istio-system \
     --values charts/istio/kiali/values-dev.yaml \
     --values environments/dev/kiali.values.yaml
   ```

4. Verify connectivity (Prometheus should be `1/1` and answering queries):

   ```bash
   kubectl get deploy prometheus -n istio-system
   kubectl exec -n istio-system deploy/prometheus -- \
     wget -qO- 'http://localhost:9090/api/v1/query?query=up' | head -c 200
   ```

Generate some mesh traffic and the Kiali graph will populate.

---

## Related docs

- [grafana-integration.md](grafana-integration.md) — connect Azure Managed Grafana to Istio metrics
- [kiali-access-options.md](kiali-access-options.md) — exposing the Kiali UI (LoadBalancer / internal / Ingress)
