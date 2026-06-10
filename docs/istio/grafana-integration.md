# Steps to Configure Azure Managed Grafana with Istio Metrics
# ================================================================

## 1. Connect Azure Managed Grafana to Azure Monitor Workspace

# In Azure Portal:
# - Go to your Azure Managed Grafana instance
# - Settings > Configuration > Data sources
# - Click "Add data source"
# - Select "Azure Monitor"
# - Choose your Azure Monitor workspace (the one collecting AKS metrics)
# - Save & Test

## 2. Import Official Istio Dashboards

# Dashboard URLs to import in Grafana:
# Go to: Dashboards > Import > Load from Grafana.com

# Control Plane Dashboard
# - ID: 7645
# - URL: https://grafana.com/grafana/dashboards/7645

# Service Mesh Dashboard  
# - ID: 7636
# - URL: https://grafana.com/grafana/dashboards/7636

# Performance Dashboard
# - ID: 11829
# - URL: https://grafana.com/grafana/dashboards/11829

# Workload Dashboard
# - ID: 7630
# - URL: https://grafana.com/grafana/dashboards/7630

## 3. Alternative: Use kubectl to get dashboard JSONs

# If importing from Grafana.com doesn't work with Azure Monitor Prometheus,
# you can get the official dashboards from Istio:

# Control Plane Dashboard
curl -o istio-control-plane-dashboard.json \
  https://raw.githubusercontent.com/istio/istio/release-1.30/manifests/addons/dashboards/istio-control-plane-dashboard.json

# Mesh Dashboard
curl -o istio-mesh-dashboard.json \
  https://raw.githubusercontent.com/istio/istio/release-1.30/manifests/addons/dashboards/istio-mesh-dashboard.json

# Service Dashboard
curl -o istio-service-dashboard.json \
  https://raw.githubusercontent.com/istio/istio/release-1.30/manifests/addons/dashboards/istio-service-dashboard.json

# Workload Dashboard
curl -o istio-workload-dashboard.json \
  https://raw.githubusercontent.com/istio/istio/release-1.30/manifests/addons/dashboards/istio-workload-dashboard.json

# Performance Dashboard
curl -o istio-performance-dashboard.json \
  https://raw.githubusercontent.com/istio/istio/release-1.30/manifests/addons/dashboards/istio-performance-dashboard.json

# Then import these JSON files into Azure Managed Grafana:
# Dashboards > Import > Upload JSON file

## 4. Key Metrics to Monitor in Grafana

# Request Rate (QPS)
# Query: rate(istio_requests_total{destination_workload="sampleapp"}[5m])

# Request Latency (P95)
# Query: histogram_quantile(0.95, rate(istio_request_duration_milliseconds_bucket[5m]))

# Error Rate
# Query: rate(istio_requests_total{response_code=~"5.*"}[5m]) / rate(istio_requests_total[5m]) * 100

# Success Rate
# Query: rate(istio_requests_total{response_code=~"2.*"}[5m]) / rate(istio_requests_total[5m]) * 100

## 5. Create Alerts in Grafana (Optional)

# High Error Rate Alert:
# - Condition: error rate > 5% for 5 minutes
# - Query: rate(istio_requests_total{response_code=~"5.*"}[5m]) / rate(istio_requests_total[5m]) * 100 > 5

# High Latency Alert:
# - Condition: P95 latency > 1000ms for 5 minutes
# - Query: histogram_quantile(0.95, rate(istio_request_duration_milliseconds_bucket[5m])) > 1000
