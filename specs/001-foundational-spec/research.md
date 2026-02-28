# Research: Helm Charts Hub — Foundational Specification

**Date**: 2026-02-19
**Spec**: [spec.md](spec.md)

---

## R-01: Helm Library Chart Patterns

**Decision**: Use `type: library` in `Chart.yaml` with helper-only `_*.tpl` files. Application charts reference `common-lib` via `file://../common-lib` for local dev and `oci://ghcr.io/<org>/charts` for CI/published releases.

**Rationale**: The `file://` approach allows `helm lint`, `ct lint`, and local `helm template` to work without publishing. `helm package` embeds resolved dependencies, so the published `.tgz` is self-contained regardless of the `repository:` scheme used during build.

**Alternatives considered**:
- **chart-releaser-action**: Uses GitHub Releases + GitHub Pages with a classic Helm repo `index.yaml`. Rejected because the project chose OCI-first publishing to ghcr.io (spec clarification Q3).
- **Git submodules for library**: Over-complicated; Helm's native dependency resolution with `file://` is simpler and standard.

**Key findings**:
- Library charts cannot be installed (`helm install` rejects them).
- Helper naming: `<chart-name>.<resource>` (e.g., `common-lib.deployment`).
- The dict pattern (`dict "root" . "component" "api"`) is the 2026 best practice for parameterized helpers — avoids the fragile list/merge pattern.
- `helm dependency build charts/web-app/` resolves `file://` by packaging the sibling directory into `charts/web-app/charts/common-lib-0.1.0.tgz`.

---

## R-02: OCI Publishing to GitHub Container Registry

**Decision**: Publish charts as OCI artifacts to `ghcr.io/<org>/charts/<chart-name>` using `helm push` from GitHub Actions with the workflow's `GITHUB_TOKEN`.

**Rationale**: OCI is the modern Helm standard (stable since Helm 3.8). GHCR is free for public repos, auto-linked to the repository, and requires no separate infrastructure. The `GITHUB_TOKEN` provides scoped authentication with `packages: write`.

**Alternatives considered**:
- **GitHub Pages + classic Helm repo**: Requires index.yaml management and the chart-releaser tool. More moving parts for no benefit in a monorepo with two charts.
- **External registry (ECR, ACR, Docker Hub)**: Adds an external dependency. GHCR is co-located with the GitHub Actions CI.

**Key findings**:
- Build order matters: `common-lib` must be published before `web-app` in the same CI run (if `web-app` uses `oci://` dependency). Using `file://` for `helm package` avoids this issue — the packaged archive is self-contained.
- New GHCR packages default to **private**. Must manually set visibility to public or use the API.
- Users install via: `helm install my-release oci://ghcr.io/<org>/charts/web-app --version 0.1.0`.
- Workflow needs `permissions: { contents: read, packages: write }`.

---

## R-03: Chart-Testing (ct) Tool Integration

**Decision**: Use `ct` (chart-testing) for automated lint and optional install testing in GitHub Actions. Configure via `ct.yaml` at repo root.

**Rationale**: `ct` is the Helm ecosystem standard for monorepo chart CI. It handles changed-chart detection (`git diff`), runs `helm lint`, `yamllint`, and validates `Chart.yaml` structure. The `helm/chart-testing-action` provides a turnkey GitHub Actions integration.

**Alternatives considered**:
- **Raw `helm lint` + custom scripts**: Works but loses changed-chart detection, yamllint integration, and the install-test framework.
- **Helmfile with diff**: Different problem domain (deployment orchestration, not chart CI).

**Key findings**:
- `ct` configuration: `chart-dirs: [charts]`, `target-branch: main`, `check-version-increment: true`.
- `ct lint` does not need a cluster. `ct install` needs a running cluster (kind in CI).
- Library charts are skipped by `ct install` (not installable) but `ct lint` works on them.
- Full git history (`fetch-depth: 0`) is required in the checkout step for `ct` diff detection.

---

## R-04: Kubernetes Gateway API Status and Integration

**Decision**: Include `common-lib.httproute` as an optional helper alongside `common-lib.ingress`. Keep `Gateway`/`GatewayClass` out of the library chart — those are cluster-scoped infrastructure managed by platform teams. Gateway API support is a Phase 2 concern; Ingress is the initial baseline.

**Rationale**: HTTPRoute is app-developer-scoped and standardized across all conformant controllers (Traefik, NGINX Gateway Fabric, Envoy Gateway). Its fields (parentRefs, hostnames, rules with matches/filters/backendRefs) are controller-agnostic. GatewayClass and Gateway are cluster-scoped resources typically managed once by platform engineers, not by individual chart consumers.

**Alternatives considered**:
- **Full Gateway API in common-lib**: Too early; not all clusters have CRDs installed. Would increase initial scope without benefit until at least one controller chart supports it.
- **No Gateway API in common-lib at all**: Misses the opportunity to standardize HTTPRoute rendering across charts. Defers too much work to Phase 2.
- **Single unified ingress/gateway helper**: The APIs are too different (different API groups, different resource shapes) to unify cleanly.

**Key findings**:
- Gateway API v1.5.0 is current. GA resources: GatewayClass, Gateway, HTTPRoute, GRPCRoute, ReferenceGrant, BackendTLSPolicy.
- CRDs installed via: `kubectl apply --server-side --force-conflicts -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml`.
- **Traefik**: Native `kubernetesGateway` provider. Conformant for v1.4.0. Enable via `providers.kubernetesGateway.enabled: true`.
- **NGINX**: Two separate projects. `ingress-nginx` = Ingress only (no Gateway plans). `nginx-gateway-fabric` = purpose-built Gateway API implementation (conformant v1.4.1). They are separate deployments.
- Controller-specific features use **Policy Attachment** (not annotations), making HTTPRoute itself portable.

---

## R-05: Helm Chart README Generation

**Decision**: Use `helm-docs` (norwoodj/helm-docs) with `# --` comment annotations in `values.yaml`. Run as a CI check and provide a local `make docs` target.

**Rationale**: `helm-docs` is the de facto standard across the Helm ecosystem (used by Bitnami, most major OSS charts). It generates markdown tables from `values.yaml` with minimal annotation effort. Despite slower maintenance cadence (last commit ~2 years ago), it is functionally stable and widely adopted.

**Alternatives considered**:
- **bitnami/readme-generator**: Uses a different comment format (`## @param`) incompatible with `helm-docs`. Smaller community adoption. Being Bitnami-internal makes upstream contribution harder.
- **frigate**: Newer tool that supports `values.schema.json`. Less widely adopted, smaller community.
- **Manual documentation**: Error-prone and does not scale. Violates SC-011 (100% values coverage).

**Key findings**:
- Annotation format: `# -- Description of this field` above the key in `values.yaml`.
- Type annotations: `# -- (int) Number of replicas`.
- Default overrides: `# @default -- computed` for values with computed defaults.
- Custom templates via `README.md.gotmpl` per chart.
- Output: Key | Type | Default | Description table.
- Can be run as a pre-commit hook or CI step (generate and diff).

---

## R-06: User-Requested Architecture — Ingress Controllers

**Decision**: The user's plan request describes Traefik and NGINX controller charts. However, the **ratified spec** (FR-001) scopes the initial release to `common-lib` + `web-app` only. Controller charts (traefik-controller, nginx-controller) are **out of initial release scope** and are documented as future work. The plan will include them as later phases per the user's phased implementation request.

**Rationale**: The spec was clarified (Q6) to confirm one application chart (`web-app`) in the initial release. Controller charts are infrastructure components that extend the catalog but are not needed to demonstrate the core library pattern. Including them in the plan as later phases aligns with both the spec (which mentions Ingress support in FR-007, FR-031) and the user's explicit request for a phased roadmap.

**Alternatives considered**:
- **Include controller charts in initial release**: Contradicts the spec's scoped initial release. Would triple the initial implementation effort.
- **Omit controller charts from the plan entirely**: Conflicts with the user's explicit instruction to include Traefik and NGINX controller chart design.

**Key findings**:
- Traefik Helm chart: well-established upstream chart (traefik/traefik). Custom chart would wrap upstream or provide a thin config layer.
- NGINX: `ingress-nginx` (Ingress only) and `nginx-gateway-fabric` (Gateway API) are separate deployments with separate Helm charts.
- The Getting Started guide (FR-031) references "installing an ingress controller" — this can use upstream charts initially, with custom controller charts added later.
