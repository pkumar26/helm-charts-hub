# Changelog

All notable changes to the `gateway-api` chart are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0]

### Added

- Security baseline parity with the sidecar `gateway` chart, adapted for ambient mode:
  - `PeerAuthentication` template for mTLS (namespace-wide or workload-scoped).
  - `AuthorizationPolicy` template attached to the Gateway via `targetRefs`
    (ambient-native) with `action: ALLOW` allowlists for default-deny.
  - `NetworkPolicy` template selecting gateway pods by the
    `gateway.networking.k8s.io/gateway-name` label, permitting only DNS, istiod,
    ztunnel (HBONE 15008), listener ports, and mesh egress.
- `global` block (`hub`, `tag`, `istioNamespace`, `fips.enabled`) documenting the
  FIPS 140-2 posture for the chart.
- `security` values block (`peerAuthentication`, `authorizationPolicy`, `networkPolicy`).
- Progressive environment overlays: `values-dev.yaml` (PERMISSIVE, no FIPS),
  `values-staging.yaml` (STRICT mTLS + allowlist + NetworkPolicy),
  `values-prod.yaml` (FIPS posture, STRICT mTLS, default-deny AuthZ, NetworkPolicy, RBAC).
- `NOTES.txt` summarizing ambient/security/FIPS status after install.

### Notes

- AuthorizationPolicy `rules` are passed through in native Istio format via
  `toYaml`, avoiding the field-by-field rendering that previously dropped
  `namespaces`/`methods` allowlist entries.

## [0.1.0]

### Added

- Initial Gateway API chart for Istio ambient mode with Azure AKS optimizations
  (Gateway, HTTPRoute, ReferenceGrant, RBAC, LoadBalancer annotations).
