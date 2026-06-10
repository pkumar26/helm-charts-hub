# Changelog

## [1.0.1] - 2026-05-20

### Fixed
- Pilot settings (replicas, resources, env, affinity) are now nested under the
  `istiod:` key so they actually propagate to the upstream istiod subchart.
  Previously a top-level `pilot:` block was silently ignored and istiod ran with
  upstream defaults (1 replica, no FIPS env, default resources).
- Production now sets `global.tag: 1.23.0-distroless` so the FIPS-compliant
  distroless image is actually pulled when `global.fips.enabled: true`.
- Removed a duplicate HorizontalPodAutoscaler: the upstream subchart HPA is
  disabled via `istiod.pilot.autoscaleEnabled: false`, leaving this chart's
  `customAutoscaling` HPA as the single source of truth.
- Renamed the chart-managed HPA values key from `autoscaling` to
  `customAutoscaling` to avoid collision with the upstream subchart.

## [1.0.0] - 2026-05-20

### Added
- Initial release of istiod chart for AKS
- FIPS 140-2 compliance support with BoringSSL
- Security baseline (STRICT mTLS, AuthZ policies, NetworkPolicy)
- Environment-specific values (dev, staging, production)
- HPA support with configurable scaling
- Pod anti-affinity for high availability

### Security
- STRICT mTLS enforcement in production
- Default-deny authorization policies
- Network isolation for control plane
- Pod security context per FR-006
