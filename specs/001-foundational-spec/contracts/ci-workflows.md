# Contract: CI Workflow Interfaces

**Date**: 2026-02-19

---

## Workflow 1: Chart Lint & Test (PR gate)

**Trigger**: Pull request targeting `main` with changes in `charts/**`
**File**: `.github/workflows/chart-lint-test.yaml`

### Pipeline Stages

```
checkout (full history) → setup-helm → setup-python → setup-ct
  → list-changed → ct-lint → create-kind-cluster → ct-install (advisory)
```

### Inputs
- Source branch with chart changes
- Target branch: `main`
- `ct.yaml` configuration at repo root

### Outputs (checks)
| Check | Blocking? | Tool |
|-------|-----------|------|
| `ct lint` (includes `helm lint`, yamllint, Chart.yaml validation) | YES | chart-testing |
| `helm template` rendering with test values | YES | helm |
| `ct install` against kind cluster | NO (advisory) | chart-testing + kind |

### Required GitHub Actions
- `actions/checkout@v4` (with `fetch-depth: 0`)
- `azure/setup-helm@v4`
- `actions/setup-python@v5`
- `helm/chart-testing-action@v2`
- `helm/kind-action@v1` (for install tests only)

---

## Workflow 2: Chart Release (publish to OCI)

**Trigger**: Push to `main` with changes in `charts/**`
**File**: `.github/workflows/chart-release.yaml`

### Pipeline Stages

```
checkout → setup-helm → detect-changed-charts
  → login-ghcr → package-common-lib → push-common-lib
  → package-web-app → push-web-app
```

### Inputs
- Merged commit on `main`
- `GITHUB_TOKEN` (automatic, needs `packages: write`)

### Outputs
- OCI artifacts at `ghcr.io/<org>/charts/<chart-name>:<version>`

### Permissions
```yaml
permissions:
  contents: read
  packages: write
```

### Publishing Order
1. `common-lib` MUST be packaged and pushed first (if changed)
2. `web-app` MUST be packaged and pushed after (if changed)
3. If only `web-app` changed, `common-lib` is not re-published

### OCI Artifact Naming
```
ghcr.io/<org>/charts/common-lib:<version>
ghcr.io/<org>/charts/web-app:<version>
```

---

## Workflow 3: Documentation Check (optional, advisory)

**Trigger**: Pull request targeting `main`
**File**: `.github/workflows/docs-check.yaml`

### Checks
| Check | Implementation |
|-------|---------------|
| Every `charts/*/` has a `README.md` | Shell script: `find charts -maxdepth 1 -mindepth 1 -type d | while read d; do test -f "$d/README.md"; done` |
| `CHARTS.md` lists every chart directory | Shell script: compare `charts/*/` dirs against entries in `CHARTS.md` |
| Required README sections present | grep for `## Overview`, `## Prerequisites`, etc. in each chart README |
| helm-docs up to date | Run `helm-docs` and `git diff --exit-code` |

---

## ct.yaml Contract

```yaml
# ct.yaml (repo root)
chart-dirs:
  - charts
target-branch: main
remote: origin
validate-maintainers: false
check-version-increment: true
helm-extra-args: --timeout 120s
```
