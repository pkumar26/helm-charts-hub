# Contributing to Helm Charts Hub

Thank you for your interest in contributing! This guide covers the workflow, conventions, and quality bar for contributing charts and improvements.

## Library-First Workflow

All reusable Kubernetes resource patterns belong in `common-lib`. Application charts delegate to library helpers via `{{ include "common-lib.<helper>" ... }}`.

**Workflow**:

1. **Check common-lib first** — If the resource pattern exists as a helper, use it.
2. **Extend common-lib** — If the pattern is reusable across charts, add a new helper to `common-lib`.
3. **Chart-specific templates** — Only use chart-specific templates for truly unique resources that no other chart would need.

## Chart Creation Checklist

Before submitting a new chart, verify:

- [ ] `Chart.yaml` has `apiVersion: v2` and a `common-lib` dependency
- [ ] Templates delegate to `common-lib` helpers where applicable
- [ ] `values.yaml` follows the canonical values shape (see data-model.md §2.3)
- [ ] `helm lint` passes with zero errors
- [ ] `helm template` renders all expected resources
- [ ] `README.md` contains all 7 required sections (Overview, Prerequisites, Installation, Configuration, Examples, Upgrade Notes, Troubleshooting)
- [ ] `CHANGELOG.md` is present with initial version entry
- [ ] CI test values exist in `ci/test-values.yaml`
- [ ] `CHARTS.md` is updated with the new chart entry

## Versioning Rules

Each chart is versioned independently using [SemVer](https://semver.org/):

| Change Type | Version Bump |
|-------------|-------------|
| New feature (backwards-compatible) | Minor |
| Bug fix | Patch |
| Breaking change (removed/renamed values, changed helper signatures) | Major |

### common-lib Versioning

| Change | Bump | Example |
|--------|------|---------|
| New helper added | Minor | 0.1.0 → 0.2.0 |
| Helper signature changed (breaking) | Major | 0.x → 1.0.0 |
| Bug fix in helper | Patch | 0.1.0 → 0.1.1 |

### Application Chart Versioning

| Change | Bump |
|--------|------|
| New optional values key (default preserves behavior) | Minor |
| Values key removed or renamed | Major |
| Template bug fix | Patch |

### Independent Release Policy

- `common-lib` version is NOT bumped by application chart changes
- Application chart versions are NOT bumped by `common-lib` changes unless the chart adopts a new helper

## Dependency Update Workflow

When `common-lib` is updated:

1. Bump the version in `charts/common-lib/Chart.yaml`
2. Update `charts/common-lib/CHANGELOG.md`
3. For each consuming chart, run `helm dependency build charts/<chart-name>`
4. Verify the updated library is resolved in `charts/<chart-name>/charts/`
5. Run `helm lint` and `helm template` on affected charts

## Pull Request Process

1. Create a feature branch from `main`
2. Make changes following the conventions above
3. Run `helm lint` on all modified charts
4. Run `helm template` to verify rendering
5. Update `CHANGELOG.md` for each modified chart
6. Update `CHARTS.md` if adding/removing a chart
7. Open a PR using the provided template
8. At least one maintainer review is required before merge

## Library Versioning and Update Workflow

### Version Bump Rules

When updating `common-lib`:

1. **Bump the version** in `charts/common-lib/Chart.yaml` (see versioning rules above)
2. **Update CHANGELOG** — document changes in `charts/common-lib/CHANGELOG.md`
3. **Update README** — document any new/changed helpers in `charts/common-lib/README.md` upgrade notes

### Dependency Update Workflow

After a `common-lib` version bump, update consuming charts:

```bash
# Remove stale lock
rm charts/web-app/Chart.lock

# Rebuild dependencies
helm dependency build charts/web-app

# Verify the new version is resolved
ls charts/web-app/charts/

# Lint and render
helm lint charts/web-app
helm template my-app charts/web-app --set image.repository=nginx --set image.tag=stable
```

### Independent Release Policy

- `common-lib` version is NOT bumped by application chart changes
- Application chart versions are NOT bumped by `common-lib` changes unless adopting a new helper
- Each chart is published independently to the OCI registry

### Breaking Change Documentation Rule

Breaking changes to `common-lib` MUST be documented in **both**:
1. The chart's **README.md** (Upgrade Notes section)
2. The chart's **CHANGELOG.md**

This dual-write rule ensures consumers can find migration guidance in either location.

## Deprecation Patterns

When deprecating a chart or feature:

1. **Announce in a minor release** — add deprecation notice to README and CHANGELOG
2. **Deprecation window** — maintain the deprecated feature for at least one minor version
3. **Removal in major release** — remove the deprecated feature in the next major version
4. **Migration steps** — document migration steps in both CHANGELOG and README Upgrade Notes
5. **Catalog marking** — mark the chart entry in CHARTS.md with ~~strikethrough~~ and note the planned removal version
