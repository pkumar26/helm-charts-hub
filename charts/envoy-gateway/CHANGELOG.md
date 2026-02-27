# Changelog

All notable changes to the `envoy-gateway` chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-02-26

### Added

- Initial release of the Envoy Gateway controller chart
- Deployment with Envoy Gateway v1.3.0 image
- ConfigMap for EnvoyGateway configuration
- ClusterRole / ClusterRoleBinding for Gateway API and core resource permissions
- Service exposing gRPC xDS port (18000) with optional metrics port (19001)
- ServiceAccount via common-lib helper
- HorizontalPodAutoscaler via common-lib helper
- GatewayClass resource (enabled by default)
- Optional Gateway resource with configurable listeners
- Health probes (liveness `/healthz`, readiness `/readyz` on port 8081)
- Pod security context (non-root, UID 65532, read-only root filesystem)
- Environment overlays for dev, staging, and production
- CI test values for basic and gateway-enabled scenarios
- Support for extraArgs, extraEnv, extraVolumes, extraVolumeMounts
