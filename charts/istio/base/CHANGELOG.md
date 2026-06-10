# Changelog

All notable changes to the istio-base chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-20

### Added
- Initial release of istio-base chart for AKS deployment
- Istio 1.23.0 CRDs via upstream chart dependency
- istio-system namespace creation with mesh labels
- Environment-specific values files (dev, staging, production)
- Validation webhook configuration
- Support for Istio revision tracking (canary upgrades)
- Comprehensive README with installation and troubleshooting guides
- CI test values for automated validation

### Features
- FIPS 140-2 compliance support for classified environments
- GitOps-ready declarative configuration
- Compatible with Azure Kubernetes Service (AKS) 1.26+
- Helm 3.10+ support

### Security
- Validation webhook enabled by default
- Production values include security baseline labels and annotations

[1.0.0]: https://github.com/pkumar26/helm-charts-hub/releases/tag/istio-base-1.0.0
