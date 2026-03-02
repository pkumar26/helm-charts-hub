# Quickstart: README Chart Catalog Update

**Feature**: 005-readme-chart-catalog-update  
**Date**: 2026-03-01

## What Changed

The root `README.md` was updated to include all 6 charts in the repository. Previously, `envoy-controller` and `kgateway-controller` were missing from:

1. The **Chart Catalog** table
2. The **Project Overview** architecture text block  
3. The **"Ingress and Gateway API"** subsection
4. The **Prerequisites** note

## Changes Required (4 sections in README.md)

### 1. Project Overview — Architecture Text Block

**Before:**
```text
common-lib (library)
    │
    ├── web-app (application)
    ├── traefik-controller (edge controller)
    └── nginx-controller (edge controller)
```

**After:**
```text
common-lib (library)
    │
    ├── web-app (application)
    ├── traefik-controller (edge controller — Ingress + Gateway API)
    ├── nginx-controller (edge controller — Ingress)
    ├── envoy-controller (edge controller — Gateway API-native)
    └── kgateway-controller (edge controller — Gateway API-native)
```

### 2. Ingress and Gateway API Subsection

**Before:** Only mentions Traefik for Gateway API.

**After:** Mentions all three Gateway API-capable controllers:
- **Ingress mode**: Traefik, NGINX
- **Gateway API-native**: Envoy Gateway, kgateway  
- **Dual-mode**: Traefik (opt-in Gateway API)

### 3. Prerequisites Note

**Before:** Only mentions Traefik for Gateway API CRDs.

**After:** Mentions Traefik, Envoy Gateway, and kgateway.

### 4. Chart Catalog Table

**Before:** 4 entries (common-lib, web-app, traefik-controller, nginx-controller)

**After:** 6 entries — adds:

| Chart | Description | Type |
|-------|-------------|------|
| [envoy-controller](charts/envoy-controller/) | Envoy Gateway controller — Gateway API-native (Envoy Proxy data plane) | Controller |
| [kgateway-controller](charts/kgateway-controller/) | kgateway controller — CNCF Gateway API implementation (Envoy proxy) | Controller |

## Verification

```bash
# Count chart entries in README table (should be 6)
grep -c '^\| \[' README.md

# Compare with CHARTS.md (should also be 6)  
grep -c '^\| \[' CHARTS.md

# Verify all chart directories are referenced
for chart in charts/*/; do
  name=$(basename "$chart")
  grep -q "$name" README.md && echo "✓ $name" || echo "✗ $name MISSING"
done
```
