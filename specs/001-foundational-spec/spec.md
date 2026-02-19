# Feature Specification: Helm Charts Hub — Foundational Specification

**Feature Branch**: `001-foundational-spec`
**Created**: 2026-02-19
**Status**: Draft
**Input**: User description: "Create a functional specification for helm-charts-hub, a curated set of reusable Helm charts for deploying services and microservices on Kubernetes."

---

## 1. Overview and Goals

### 1.1 Purpose

The **helm-charts-hub** repository provides a curated catalog of production-ready Helm charts for deploying services and microservices on Kubernetes. It exists to give teams a fast, consistent, and safe path from "I need to deploy a service" to a running workload — without reinventing boilerplate for every new application.

### 1.2 Goals

- **Easy consumption** — Teams can adopt a chart with minimal configuration and get a working deployment out of the box.
- **Consistency** — Every chart follows the same values structure, labeling scheme, naming conventions, and documentation standards.
- **Reuse** — A shared `common-lib` library chart provides composable helpers so application charts stay thin and DRY.
- **Flexibility** — All behavior is configurable through values, supporting environment-specific overrides, optional features, and multiple deployment patterns.
- **Maintainability** — The repository evolves safely through semantic versioning, deprecation windows, and backwards-compatibility rules defined in the project constitution.

### 1.3 Non-Goals

- Managing or provisioning Kubernetes clusters.
- Building, compiling, or packaging application source code.
- Producing raw (non-Helm) Kubernetes manifests.
- Deploying to non-Kubernetes targets.

---

## Clarifications

### Session 2026-02-19

- Q: Should `common-lib` include helpers for observability resources (e.g., Prometheus ServiceMonitor, PodMonitor) in the initial scope? → A: Deferred. Initial scope focuses on core workload resources only; observability helpers are planned for a future minor release.
- Q: Should different workload patterns (HTTP API, worker, CronJob) be separate charts or a single chart with a workload-type selector? → A: Single chart per service with a `workloadType` values key to switch pattern.
- Q: Should `values.schema.json` be required (MUST) for all charts in the initial release, or remain optional (SHOULD)? → A: SHOULD. Schema files are encouraged but optional; template-level `required`/`fail` checks are mandatory for critical values (image.repository, workloadType).
- Q: What annotation prefix should be used for organization-specific platform metadata? → A: `platform.example.com` as a configurable placeholder default. Organizations replace it when adopting the charts.
- Q: Should CI install/upgrade tests in a disposable cluster be merge-blocking or advisory-only? → A: Advisory-only. Linting and template rendering are merge-blocking; cluster install tests run but do not block merge.

---

## 2. Users and Use Cases

### 2.1 User Roles

| Role | Description |
|---|---|
| **Platform Engineer** | Builds and maintains the chart catalog, `common-lib` helpers, and CI pipelines. |
| **Service Owner** | Owns one or more application charts; adds new charts and extends existing ones. |
| **SRE** | Deploys and operates services in staging/production; tunes values for reliability and performance. |
| **Application Developer** | Consumes charts to deploy their service and provides environment-specific value overrides. |

### 2.2 Core Use Cases

1. **Deploy a service using an existing chart** — An application developer selects a chart, provides values overrides, and runs a Helm install to get a working deployment.
2. **Add a new service chart** — A service owner scaffolds a new chart that depends on `common-lib`, fills in service-specific values, and submits for review.
3. **Extend an existing chart** — A service owner adds an optional capability (e.g., ingress, autoscaling, sidecar) to an existing chart without breaking current users.
4. **Configure for multiple environments** — An SRE or developer layers environment-specific values files (dev, staging, production) onto a shared base chart.
5. **Update the shared library** — A platform engineer adds or modifies a helper in `common-lib` and rolls the change out to dependent charts.
6. **Deprecate and migrate** — A platform engineer deprecates a chart feature or values key, communicates the change, and provides a migration path.

---

## 3. User Scenarios & Testing *(mandatory)*

### User Story 1 — Deploy a Service with an Existing Chart (Priority: P1)

As an **application developer**, I want to deploy my service to a Kubernetes namespace by selecting a chart from the catalog and supplying minimal overrides, so that I get a running, correctly-labeled deployment without writing any Kubernetes manifests.

**Why this priority**: This is the primary value proposition — consuming charts must work before anything else matters.

**Independent Test**: Can be verified by running `helm install` with only `image.repository` and `image.tag` overrides against a disposable cluster and confirming a healthy Deployment, Service, and correct labels.

**Acceptance Scenarios**:

1. **Given** a published chart (e.g., `my-api`) with default values, **When** a user installs the chart providing only the container image, **Then** the chart renders a Deployment, a Service, and all resources carry the required base labels.
2. **Given** a chart with `ingress.enabled: false` by default, **When** a user installs without overriding ingress settings, **Then** no Ingress resource is created.
3. **Given** a chart installed with defaults, **When** the user inspects the rendered Deployment, **Then** it includes resource requests/limits, a security context with `runAsNonRoot: true`, and liveness/readiness probes.
4. **Given** an invalid image tag (empty string), **When** the user attempts to install, **Then** the chart fails with a clear validation error before any resource is applied.

---

### User Story 2 — Add a New Service Chart (Priority: P1)

As a **service owner**, I want to add a new chart to the catalog that reuses `common-lib` helpers and follows all repository conventions, so that my service gains standard labeling, security defaults, and documentation without duplicating logic.

**Why this priority**: Growing the catalog is the second-highest value driver; every new chart added multiplies the project's utility.

**Independent Test**: Can be verified by scaffolding a new chart directory, declaring the `common-lib` dependency, running `helm lint`, and confirming that rendered templates match expected resource shapes.

**Acceptance Scenarios**:

1. **Given** the `common-lib` library chart exists, **When** a service owner creates a new chart with Deployment and Service templates that delegate to common-lib helpers, **Then** `helm lint` and `helm template` succeed with no errors.
2. **Given** a new chart, **When** the chart is rendered, **Then** all resources carry the full set of base labels defined in the constitution (§6).
3. **Given** a new chart, **When** the service owner runs CI checks, **Then** linting, template rendering, and structural validation all pass.
4. **Given** a new chart, **When** a reviewer inspects it, **Then** it includes a README with all required sections (overview, prerequisites, installation, configuration table, examples, upgrade notes, troubleshooting).

---

### User Story 3 — Extend a Chart with an Optional Feature (Priority: P2)

As a **service owner**, I want to add an optional capability (e.g., HPA, ingress, sidecar container) to an existing chart, gated behind a feature flag in values, so that users who do not enable the feature see no change in rendered output.

**Why this priority**: Extensibility drives long-term value, but depends on the catalog and library being functional first.

**Independent Test**: Can be verified by rendering the chart with the feature flag enabled and disabled, and diffing the output to confirm the feature is fully additive.

**Acceptance Scenarios**:

1. **Given** an existing chart with `autoscaling.enabled: false` by default, **When** a contributor adds HPA support gated on `autoscaling.enabled`, **Then** rendering with defaults produces exactly the same resources as before.
2. **Given** the same chart, **When** a user sets `autoscaling.enabled: true` with `minReplicas` and `maxReplicas`, **Then** an HPA resource is rendered with the correct settings.
3. **Given** the feature addition, **When** CI runs, **Then** the chart version is bumped as a minor release and the CHANGELOG documents the addition.

---

### User Story 4 — Environment-Specific Configuration (Priority: P2)

As an **SRE**, I want to layer environment-specific values files on top of a chart's defaults, so that I can tune replicas, resources, ingress hosts, and feature flags per environment without forking the chart.

**Why this priority**: Multi-environment support is essential for production use but is a configuration concern built on top of core chart functionality.

**Independent Test**: Can be verified by composing a base values file with a staging overlay and a production overlay, rendering each, and confirming the differences are exactly the intended overrides.

**Acceptance Scenarios**:

1. **Given** a chart with default `replicaCount: 1`, **When** a user provides `values-production.yaml` with `replicaCount: 3`, **Then** the rendered Deployment has 3 replicas.
2. **Given** a chart with `ingress.enabled: false` by default, **When** a user provides `values-staging.yaml` with `ingress.enabled: true` and host entries, **Then** an Ingress resource is rendered with the specified hosts.
3. **Given** multiple values files layered with `-f`, **When** the user renders the chart, **Then** values are merged in the expected left-to-right order with later files winning.

---

### User Story 5 — Update the Shared Library Chart (Priority: P2)

As a **platform engineer**, I want to update a helper in `common-lib` (e.g., add a new label or fix a security context default), so that all dependent application charts inherit the change on their next version bump.

**Why this priority**: Library maintenance is critical for consistency but requires the library and at least one consumer chart to exist first.

**Independent Test**: Can be verified by modifying a helper, rendering a dependent chart before and after, and confirming the change propagates correctly.

**Acceptance Scenarios**:

1. **Given** a change to `common-lib` that adds a new base label, **When** a dependent chart pins to the updated library version and is rendered, **Then** the new label appears on all resources.
2. **Given** a backwards-compatible change to `common-lib`, **When** the library version is bumped as a minor release, **Then** dependent charts that pin to `^major.minor` receive the change without manual edits.
3. **Given** a breaking change to a helper signature, **When** the library is released, **Then** its major version is bumped, migration instructions are documented, and dependent charts are not silently broken.

---

### User Story 6 — Deprecate and Migrate a Feature (Priority: P3)

As a **platform engineer**, I want to deprecate a chart feature or values key and communicate a migration path, so that users have time to adapt before the feature is removed.

**Why this priority**: Deprecation is a governance concern that becomes relevant once the catalog is mature enough to have evolved past its first design.

**Independent Test**: Can be verified by marking a feature deprecated in one minor release, confirming the deprecation notice appears in output/docs, and verifying removal only in the next major release.

**Acceptance Scenarios**:

1. **Given** a feature to be deprecated, **When** the deprecation is introduced in a minor release, **Then** the chart README, CHANGELOG, and any rendered notes include a deprecation warning.
2. **Given** a deprecated feature, **When** the next major release removes it, **Then** the CHANGELOG and upgrade notes provide explicit migration steps.
3. **Given** a deprecated values key, **When** a user still supplies the old key, **Then** the chart either maps it to the replacement key with a warning or fails with a clear message.

---

### Edge Cases

- What happens when a user supplies an unknown values key? Charts should ignore unknown keys (standard Helm behavior), but schema validation (if present) should emit a warning.
- What happens when `common-lib` is not available or the dependency version is incompatible? `helm dependency build` must fail with a clear version-mismatch error before rendering.
- What happens when conflicting feature flags are set (e.g., `autoscaling.enabled: true` and `replicaCount: 5`)? HPA takes precedence; `replicaCount` is used only as the initial count before the autoscaler acts. This must be documented.
- What happens when a values file contains a type mismatch (e.g., string where integer expected)? Schema validation should reject the input before rendering.
- What happens when an application chart needs a resource type not covered by `common-lib`? The chart may define its own template, but must still apply common labels and annotations by calling the label/annotation helpers.
- What happens when an unsupported `workloadType` value is provided? The chart MUST fail with a clear validation error listing the supported types.

---

## 4. Requirements *(mandatory)*

### 4.1 Feature Set — Chart Catalog

- **FR-001**: The repository MUST provide a catalog of charts, one per service or component, each in its own directory under `charts/`.
- **FR-002**: Every application chart MUST declare a dependency on `common-lib` and delegate standard resource rendering to its helpers.
- **FR-003**: Every chart MUST include a `values.yaml` with sensible defaults sufficient for a working deployment without additional overrides.
- **FR-004**: Charts MUST support optional features (ingress, HPA, service mesh sidecars, extra containers) via boolean feature flags in values.
- **FR-005**: Charts MUST support multiple deployment patterns — at minimum HTTP API (Deployment + Service), worker/job (Deployment without Service), and CronJob — via a `workloadType` values key (e.g., `workloadType: deployment`, `workloadType: cronjob`) within a single chart. The `common-lib` helpers MUST support rendering the appropriate top-level workload resource based on this selector.

### 4.2 Feature Set — Shared Library Chart (common-lib)

- **FR-006**: The `common-lib` chart MUST be declared as a library chart and MUST NOT render standalone Kubernetes resources.
- **FR-007**: `common-lib` MUST expose helpers for: Deployment, Service, Ingress, HPA, ConfigMap, Secret, pod security context, labels, and annotations. Observability resources (e.g., Prometheus ServiceMonitor, PodMonitor) are explicitly out of initial scope and deferred to a future minor release.
- **FR-008**: Helpers MUST accept the full root context or a dictionary argument to support flexible usage from application charts.
- **FR-009**: Application charts MUST be able to plug in extra labels, annotations, and resource-specific customizations by passing additional values to helpers.
- **FR-010**: Application charts MUST be able to opt out of a specific library helper and provide their own template for advanced cases without losing base labels/annotations.

### 4.3 Values and Configuration Model

- **FR-011**: All charts MUST use the canonical values shape defined by the constitution, including: `image`, `replicaCount`, `resources`, `service`, `ingress`, `autoscaling`, `podAnnotations`, `podLabels`, `podSecurityContext`, `securityContext`, `serviceAccount`, `nodeSelector`, `tolerations`, `affinity`, `extraEnv`, and `extraVolumes`.
- **FR-012**: Users MUST be able to supply environment-specific overrides via layered values files (e.g., `values-staging.yaml`, `values-production.yaml`) and/or CI/CD `--set` flags.
- **FR-013**: Charts MUST provide template-level validation (using `required` or `fail`) for critical values: at minimum `image.repository` and `workloadType`. Missing or invalid critical values MUST cause a clear, actionable error before any resource is applied. Optional values MUST fall back to documented defaults.
- **FR-014**: Feature flags (e.g., `ingress.enabled`, `autoscaling.enabled`) MUST default to `false`. When disabled, the corresponding template MUST produce no output.
- **FR-015**: When `autoscaling.enabled` is `true` and `replicaCount` is also set, `replicaCount` MUST serve only as the initial replica count; the HPA governs scaling thereafter. This behavior MUST be documented.

### 4.4 Labels, Annotations, and Metadata

- **FR-016**: All resources MUST carry the following base labels: `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `app.kubernetes.io/managed-by`, `app.kubernetes.io/part-of`, and `helm.sh/chart`.
- **FR-017**: All resources MUST carry base annotations: `meta.helm.sh/release-name` and `meta.helm.sh/release-namespace`.
- **FR-018**: Charts MUST allow users to add custom labels and annotations through `.Values.labels`, `.Values.podLabels`, `.Values.annotations`, and `.Values.podAnnotations` without modifying core helpers.
- **FR-019**: The annotation prefix `platform.example.com/*` MUST be reserved for platform/SRE metadata (ownership, SLOs, runbook URLs, cost-center tags). This prefix is a configurable placeholder default; organizations MUST be able to override it via a values key (e.g., `global.annotationPrefix`) when adopting the charts.
- **FR-020**: Charts MUST support organization-specific ownership metadata (team name, service name, runbook URL) as annotations under the configurable platform prefix.

### 4.5 Quality, Validation, and Testing

- **FR-021**: Every chart MUST pass `helm lint` with zero errors.
- **FR-022**: Pull requests that modify charts MUST trigger automated chart-testing that includes at minimum: linting, template rendering, and structural validation.
- **FR-023**: Charts SHOULD support install/upgrade tests against a disposable cluster (e.g., kind) in CI. These tests are advisory-only and MUST NOT block PR merges; linting and template rendering remain the merge-blocking gates. Cluster install tests may be promoted to merge-blocking in a future release once CI stability is proven.
- **FR-024**: Charts SHOULD provide a `values.schema.json` for input validation; when present, invalid input MUST be rejected before rendering. Schema files are planned to be promoted from SHOULD to MUST in a future release once values patterns stabilize.

### 4.6 Documentation and Discoverability

- **FR-025**: Every chart MUST include a `README.md` with: overview, prerequisites, installation instructions, configuration table, examples, upgrade notes, and troubleshooting.
- **FR-026**: The repository MUST provide a central catalog (e.g., a root-level README or index) that lists all charts, their purpose, and key capabilities.
- **FR-027**: Charts MUST include sample values snippets for at least two common patterns (e.g., minimal install) and one production-oriented pattern.
- **FR-028**: Breaking changes MUST be documented in both the chart README (upgrade notes) and the CHANGELOG with explicit migration steps.

### 4.7 CI/CD and Release

- **FR-029**: Chart releases MUST be automated via CI, publishing to an OCI-compatible registry or Helm repository.
- **FR-030**: All charts MUST follow semantic versioning; breaking changes are major bumps, new features are minor, bug fixes are patch.
- **FR-031**: The `common-lib` chart MUST be released independently; its version MUST NOT be bumped by changes to application charts.

### Key Entities

- **Application Chart**: A Helm chart that deploys a specific service or component. Depends on `common-lib`. Contains `Chart.yaml`, `values.yaml`, `README.md`, and templates that delegate to library helpers.
- **Library Chart (common-lib)**: A Helm library chart (`type: library`) that contains only reusable helper templates. Not installable on its own.
- **Values File**: A YAML file providing configuration for chart rendering. May be the chart default (`values.yaml`) or an environment-specific overlay.
- **Helper Template**: A named template definition (e.g., `common-lib.deployment`) that generates Kubernetes resource YAML from values input.
- **Feature Flag**: A boolean values key (e.g., `ingress.enabled`) that controls whether an optional chart component is rendered.

---

## 5. Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new contributor can add a chart that passes all CI checks in under 4 hours, following only the README, constitution, and `common-lib` documentation.
- **SC-002**: 100% of charts pass `helm lint` and template rendering on every CI run with zero errors.
- **SC-003**: Every chart renders a working deployment when installed with only the container image overridden, on a supported Kubernetes version.
- **SC-004**: All resources produced by any chart carry the full base label set (6 labels) and base annotation set (2 annotations) — verifiable by automated template rendering checks.
- **SC-005**: Adding an optional feature to an existing chart produces zero diff in rendered output for users who have not enabled that feature.
- **SC-006**: Breaking changes are never introduced without a major version bump and documented migration instructions.
- **SC-007**: 100% of charts include a README with all required sections (overview, prerequisites, installation, configuration table, examples, upgrade notes, troubleshooting).
- **SC-008**: Environment-specific values overlays merge correctly, with later files overriding earlier ones as expected by Helm.

---

## 6. Constraints and Non-Functional Requirements

### 6.1 Compatibility

- Charts MUST support Kubernetes versions 1.26 and above.
- Charts MUST be installable with Helm 3.12 and above.
- Charts MUST be renderable without access to a live cluster (i.e., `helm template` must work offline).

### 6.2 Performance

- Chart rendering (via `helm template`) SHOULD complete in under 5 seconds for any single chart.
- Charts SHOULD NOT generate excessive resource objects; a single service chart should produce fewer than 15 resource objects under typical configuration.

### 6.3 Security

- Pod security contexts MUST default to `runAsNonRoot: true` and a read-only root filesystem.
- Charts MUST NOT contain hard-coded secrets or credentials; secrets must be supplied via values or external secret managers.
- Container images MUST default to a non-`latest` tag policy (tag must be explicitly specified by users).

### 6.4 Maintainability

- Backwards-compatible changes MUST NOT alter rendered output for users who have not changed their values.
- Breaking changes MUST follow the deprecation process defined in the constitution (announce → deprecation window → major version removal).
- Each chart MUST maintain a CHANGELOG with entries formatted consistently (Added, Changed, Deprecated, Removed, Fixed, Security).

---

## 7. Assumptions

- A project constitution (`.specify/memory/constitution.md`) exists and governs naming conventions, directory layout, labels/annotations standards, versioning policy, and governance workflow. This spec aligns with and references that constitution.
- The `common-lib` chart will be the first chart implemented; application charts depend on it.
- CI infrastructure (e.g., GitHub Actions or equivalent) is available for automated linting, rendering, and testing.
- A Helm chart registry (OCI or classic) is available for publishing releases.
- Teams deploying charts have standard Helm and kubectl access to their target clusters.

---

## 8. Open Questions and Future Expansion

### 8.1 Open Questions

- **Multi-tenant patterns**: Should charts support namespace-per-tenant isolation, or is that out of scope for individual charts and handled at the cluster level?
- **Multi-cluster deployments**: Should values or chart structure accommodate deploying the same service across multiple clusters (e.g., via Argo CD ApplicationSets or Fleet)?
- **Operator integration**: Observability operator resources (ServiceMonitor, PodMonitor) are deferred to a future release. Istio VirtualService and other operator-consumed resources remain an open question for later evaluation.

### 8.2 Future Capabilities

- **Umbrella charts** — Composed charts that deploy multiple related services together (e.g., a frontend + backend + database stack) as a single release.
- **Opinionated environment stacks** — Pre-built values bundles for common environments (e.g., "production-hardened" or "dev-fast") that users can adopt as a starting point.
- **Schema-driven documentation** — Auto-generating README configuration tables from `values.schema.json` to reduce manual documentation effort.
- **Drift detection** — Tooling to detect when deployed releases drift from the chart catalog's latest version, prompting upgrades.
