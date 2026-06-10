# Changelog

All notable changes to the istio-gateway chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1]

### Fixed
- AuthorizationPolicy now renders the full allowlist. The previous field-by-field
  template dropped `namespaces`/`methods`/`principals`, producing an empty
  `source:`/`operation:` which, under `action: ALLOW`, matched all traffic
  (effectively allow-all instead of the intended default-deny). Rules are now
  passed through in native Istio format via `toYaml`.

## [1.0.0] - 2026-05-20

### Added
- Initial release of Istio gateway chart for AKS
- FIPS 140-2 compliance support via distroless images with BoringSSL
- Security baseline templates:
  - Gateway resource with TLS configuration
  - PeerAuthentication for STRICT mTLS enforcement
  - AuthorizationPolicy for access control with explicit allowlists
  - NetworkPolicy for L3/L4 network isolation
  - HorizontalPodAutoscaler with 80% CPU target
- Three environment configurations (dev, staging, production)
- Production-ready values with HA configuration (3 replicas, pod anti-affinity)
- LoadBalancer and NodePort service types
- Pod security standards (runAsNonRoot, readOnlyRootFilesystem, capabilities drop)
- Environment-specific overlays in environments/ directory
- Comprehensive README with installation, verification, and troubleshooting
- FIPS validation instructions and verification commands

### Security
- STRICT mTLS enforcement in production
- Default-deny AuthorizationPolicy with explicit allowlists
- NetworkPolicy for ingress/egress traffic control
- Pod security context with restricted policies
- FIPS-approved TLS cipher suites in production

### Dependencies
- Istio gateway chart 1.23.0 (upstream)
- Requires Istio base chart and istiod control plane

[1.0.0]: https://github.com/pkumar26/helm-charts-hub/releases/tag/istio-gateway-1.0.0
