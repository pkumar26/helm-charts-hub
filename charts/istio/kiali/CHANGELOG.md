# Changelog

All notable changes to the Kiali chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-05-20

### Added
- Initial release of Kiali chart wrapper
- Support for Kiali 1.86.0 upstream chart
- Anonymous authentication for development
- Token authentication for staging/production
- OpenID Connect configuration support
- Prometheus integration for metrics
- Grafana integration for dashboards
- Environment-specific values (dev, staging, production)
- Comprehensive README with authentication setup
- CI test values for automated testing
- Optional deployment (disabled by default in production)

### Configuration
- `enabled: false` - Deploy as optional component (opt-in for production)
- Support for anonymous, token, and OpenID auth strategies
- Configurable Prometheus and Grafana endpoints
- Minimal resources for dev (64Mi), moderate for staging (512Mi), full for production (1Gi)
- NodePort service for dev, ClusterIP for staging/production
- Security context hardening for production deployments

### Security
- Token authentication required in staging/production by default
- Read-only root filesystem in production
- Drop all capabilities in production
- Run as non-root user in production

### Documentation
- Installation guide with prerequisites
- Authentication strategy comparison
- Prometheus endpoint configuration examples
- Troubleshooting guide for common issues
- Access methods (port-forward, NodePort, Ingress)
