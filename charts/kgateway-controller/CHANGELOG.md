# Changelog

All notable changes to the kgateway-controller chart will be documented in this file.

## [0.1.0] - 2026-02-26

### Added

- Initial release of kgateway-controller chart
- Deployment with environment variable-based configuration
- Service exposing xDS (9977), health (9093), and metrics (9092) ports
- ServiceAccount via common-lib helper
- ClusterRole and ClusterRoleBinding with Gateway API + kgateway CRD permissions
- Optional GatewayClass resource (gated by `gatewayApi.createGatewayClass`)
- HPA via common-lib helper (gated by `autoscaling.enabled`)
- PodDisruptionBudget (gated by `podDisruptionBudget.enabled`)
- VerticalPodAutoscaler (gated by `verticalPodAutoscaler.enabled`)
- Prometheus scrape annotations (gated by `metrics.enabled`)
- CI test values (minimal and comprehensive)
- Environment overlays for dev, staging, and production
