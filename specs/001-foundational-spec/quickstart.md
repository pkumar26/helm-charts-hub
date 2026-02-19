# Quickstart: Helm Charts Hub — Developer Setup

**Date**: 2026-02-19

This guide gets a contributor from zero to a working local environment where they can lint, render, and test charts.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Helm | ≥ 3.12 | `brew install helm` or [helm.sh/docs/intro/install](https://helm.sh/docs/intro/install/) |
| kubectl | ≥ 1.26 | `brew install kubectl` |
| kind | ≥ 0.20 | `brew install kind` or [kind.sigs.k8s.io](https://kind.sigs.k8s.io/) |
| helm-docs | ≥ 1.14 | `brew install norwoodj/tap/helm-docs` |
| Python 3 | ≥ 3.9 | Required by `ct` (chart-testing) |
| ct (chart-testing) | ≥ 3.10 | `pip install chart-testing` or [github.com/helm/chart-testing](https://github.com/helm/chart-testing) |
| yamllint | ≥ 1.35 | `pip install yamllint` |
| Git | ≥ 2.30 | Required for `ct` changed-chart detection |

---

## 1. Clone and Build Dependencies

```bash
git clone https://github.com/<org>/helm-charts-hub.git
cd helm-charts-hub

# Build common-lib dependency for web-app
helm dependency build charts/web-app
```

## 2. Lint All Charts

```bash
# Quick lint
helm lint charts/common-lib
helm lint charts/web-app

# Full lint with ct (matches CI)
ct lint --all --config ct.yaml
```

## 3. Render Templates Locally

```bash
# Render web-app with defaults
helm template my-release charts/web-app

# Render with custom values
helm template my-release charts/web-app -f examples/web-app-production.yaml

# Render and verify labels
helm template my-release charts/web-app | grep "app.kubernetes.io/"
```

## 4. Test in a Local Cluster

```bash
# Create a kind cluster
kind create cluster --name helm-test

# Install web-app
helm install my-release charts/web-app \
  --set image.repository=nginx \
  --set image.tag=1.27-alpine

# Verify
kubectl get pods -l app.kubernetes.io/instance=my-release
kubectl get svc -l app.kubernetes.io/instance=my-release

# Clean up
helm uninstall my-release
kind delete cluster --name helm-test
```

## 5. Run Full CI Locally (ct install)

```bash
# Create kind cluster
kind create cluster --name ct-test

# Run chart-testing install (matches CI advisory check)
ct install --all --config ct.yaml

# Clean up
kind delete cluster --name ct-test
```

## 6. Generate Documentation

```bash
# Generate/update README configuration tables
helm-docs --chart-search-root charts

# Verify docs match generated output
helm-docs --chart-search-root charts --dry-run
```

## 7. Add a New Chart

```bash
# 1. Create chart directory
mkdir -p charts/my-service/templates

# 2. Copy from template
cp docs/templates/chart-readme.md charts/my-service/README.md

# 3. Create Chart.yaml with common-lib dependency
cat > charts/my-service/Chart.yaml <<EOF
apiVersion: v2
name: my-service
description: My new service chart
type: application
version: 0.1.0
appVersion: "1.0.0"
dependencies:
  - name: common-lib
    version: ">=0.1.0 <1.0.0"
    repository: "file://../common-lib"
EOF

# 4. Copy and customize values.yaml from web-app
cp charts/web-app/values.yaml charts/my-service/values.yaml

# 5. Create templates that delegate to common-lib
# (See charts/web-app/templates/ for examples)

# 6. Build dependencies and lint
helm dependency build charts/my-service
helm lint charts/my-service

# 7. Update CHARTS.md with the new entry
# 8. Commit and open PR
```

---

## Common Issues

| Problem | Solution |
|---------|----------|
| `Error: found in Chart.yaml, but missing in charts/ directory` | Run `helm dependency build charts/<name>` |
| `ct lint` says "no charts found" | Ensure you have commits differing from `main`. Use `--all` to lint everything. |
| Kind cluster unreachable | Run `kind get clusters` and `kubectl cluster-info --context kind-helm-test` |
| `helm-docs` not found | Install via `brew install norwoodj/tap/helm-docs` |
