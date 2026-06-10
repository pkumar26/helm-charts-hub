# helm-charts-hub Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-19

## Active Technologies
- Helm chart templates (Go templates), Kubernetes 1.28+ + common-lib (library chart), Envoy Gateway v1.3.x, Gateway API CRDs v1.2+ (003-envoy-gateway-chart)
- Markdown (documentation only) + N/A — no code changes (005-readme-chart-catalog-update)
- Markdown (GitHub Flavored Markdown) + shields.io (external badge service), GitHub API (badge data source) (006-repo-badges)
- N/A (documentation-only change) (006-repo-badges)
- Helm 3.10+, Kubernetes 1.26+ (007-istio-aks-chart)
- Not applicable (infrastructure chart, no persistent data) (007-istio-aks-chart)

- Helm 3.12+ (Go templates / Kubernetes YAML) + Helm 3.12+, chart-testing (ct) 3.10+, helm-docs 1.14+, kind 0.20+ (001-foundational-spec)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Helm 3.12+ (Go templates / Kubernetes YAML)

## Code Style

Helm 3.12+ (Go templates / Kubernetes YAML): Follow standard conventions

## Recent Changes
- 007-istio-aks-chart: Added Helm 3.10+, Kubernetes 1.26+
- 006-repo-badges: Added Markdown (GitHub Flavored Markdown) + shields.io (external badge service), GitHub API (badge data source)
- 005-readme-chart-catalog-update: Added Markdown (documentation only) + N/A — no code changes


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
