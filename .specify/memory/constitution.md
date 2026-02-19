<!--
  Sync Impact Report
  ====================
  Version change: N/A → 1.0.0 (initial creation)
  Modified principles: N/A (initial creation)
  Added sections:
    - 1. Purpose and Scope
    - 2. Core Design Principles (Simplicity, Consistency, Modularity,
         Flexibility, Best Practices)
    - 3. Repository Structure and Conventions
    - 4. Shared Library Chart Design
    - 5. Configuration and Customization
    - 6. Labels and Annotations Conventions
    - 7. Extensibility and New Charts
    - 8. Testing, Validation, and CI/CD
    - 9. Documentation Standards
    - 10. Governance and Contribution Workflow
    - 11. Evolution and Versioning Policy
  Removed sections: N/A (initial creation)
  Templates requiring updates:
    - .specify/templates/plan-template.md ✅ no changes required
    - .specify/templates/spec-template.md ✅ no changes required
    - .specify/templates/tasks-template.md ✅ no changes required
  Follow-up TODOs: none
-->

# Helm Charts Hub Constitution

## 1. Purpose and Scope

### 1.1 Primary Goals

The **helm-charts-hub** repository hosts a growing collection of reusable,
production-ready Helm charts for services and microservices running on
Kubernetes. The project exists to:

- Provide simple, consistent, and modular Helm charts that teams can
  adopt with minimal friction.
- Ship opinionated defaults that work out of the box while allowing
  deep customization through `values.yaml` overrides.
- Ensure long-term maintainability as new charts, helpers, and
  capabilities are added over time.

### 1.2 In-Scope

- Application Helm charts for Kubernetes workloads.
- A shared **common-lib** Helm library chart containing reusable
  templates and helpers.
- Helper templates (`_*.tpl`) that encapsulate best-practice
  Kubernetes resource patterns.
- Shared values patterns and conventions that all charts follow.

### 1.3 Out-of-Scope

- Cluster provisioning or infrastructure-as-code (Terraform, Pulumi,
  Crossplane, etc.).
- Raw (non-Helm) Kubernetes manifests.
- Application source code — charts deploy applications but do not
  contain them.
- Non-Kubernetes deployment targets.

---

## 2. Core Design Principles

### 2.1 Simplicity

- Charts MUST be easy to understand with minimal surprises.
- Defaults MUST be sensible so that `helm install <chart>` produces a
  working deployment without requiring overrides.
- Template logic MUST avoid deeply nested conditionals; extract
  complexity into named helpers instead.

### 2.2 Consistency

- All charts MUST follow identical naming, labeling, annotation, and
  directory-layout conventions defined in this constitution.
- Values keys MUST use the canonical names listed in
  §5 (Configuration and Customization).
- Resource names MUST be derived from `{{ .Release.Name }}` combined
  with the chart name using standard Helm conventions.

### 2.3 Modularity

- Charts MUST prefer composable templates and helpers over
  copy-paste duplication.
- Shared logic MUST live in the `common-lib` library chart and be
  consumed via `{{ include }}`.
- Application charts SHOULD consist primarily of thin wrappers that
  delegate to `common-lib` helpers.

### 2.4 Flexibility

- All meaningful behavior MUST be configurable through
  `values.yaml`.
- Every configurable knob MUST be documented with inline comments
  and in the chart README.
- Charts MUST support disabling optional components (ingress, HPA,
  service mesh sidecars, etc.) via boolean feature flags.

### 2.5 Best Practices

- Charts MUST follow Helm best practices for chart structure,
  versioning, and hook usage.
- Kubernetes resources MUST include proper namespacing, resource
  naming, security contexts, liveness/readiness probes, and
  resource requests/limits by default.
- Pod security standards (e.g., `runAsNonRoot`, read-only root
  filesystem) MUST be applied through `common-lib` helpers and
  overridable via values.

---

## 3. Repository Structure and Conventions

### 3.1 Standard Folder Layout

```text
charts/
├── common-lib/            # Helm library chart (type: library)
│   ├── Chart.yaml
│   ├── README.md
│   ├── values.yaml        # Default values consumed by helpers
│   └── templates/
│       ├── _deployment.tpl
│       ├── _service.tpl
│       ├── _ingress.tpl
│       ├── _hpa.tpl
│       ├── _podsecurity.tpl
│       ├── _configmap.tpl
│       ├── _secrets.tpl
│       ├── _labels.tpl
│       └── _annotations.tpl
│
├── <service-name>/        # Application chart
│   ├── Chart.yaml         # Declares dependency on common-lib
│   ├── README.md
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       └── ...            # Extra resources as needed
```

### 3.2 Application Chart Templates

- Templates such as `deployment.yaml`, `service.yaml`, and
  `ingress.yaml` MUST primarily delegate to `common-lib` helpers:

  ```yaml
  {{- include "common-lib.deployment" (dict "root" .) }}
  ```

- Application charts MAY define additional resources when the
  workload has unique needs, but MUST NOT duplicate logic already
  available in `common-lib`.

### 3.3 Naming Conventions

| Artifact | Convention |
|---|---|
| Chart directory | lowercase, hyphenated (e.g., `my-service`) |
| Helper template files | `_<resource>.tpl` |
| Helper definition names | `common-lib.<resource>` (e.g., `common-lib.deployment`) |
| Values keys | camelCase (e.g., `replicaCount`, `podSecurityContext`) |
| Kubernetes resource names | `{{ include "common-lib.fullname" . }}` |

---

## 4. Shared Library Chart Design

### 4.1 Library Chart Declaration

- `common-lib` MUST declare `type: library` in its `Chart.yaml` and
  MUST NOT render standalone Kubernetes resources.
- It MUST expose well-named helper definitions:
  - `common-lib.deployment`
  - `common-lib.service`
  - `common-lib.ingress`
  - `common-lib.hpa`
  - `common-lib.configmap`
  - `common-lib.secrets`
  - `common-lib.podsecurity`
  - `common-lib.labels`
  - `common-lib.annotations`
  - `common-lib.fullname`
  - `common-lib.chart`

### 4.2 Helper Signatures

- Helpers MUST accept the full root context (`.`) as their default
  argument.
- When additional parameters are required, helpers MUST accept a
  `dict`, for example:

  ```yaml
  {{ include "common-lib.deployment" (dict "root" .
      "name" "api" "extraLabels" .Values.api.labels) }}
  ```

- Helpers MUST document their expected input values in the library
  chart README.

### 4.3 Versioning

- `common-lib` MUST follow semantic versioning (SemVer).
- Breaking changes to helper signatures or behavior are only
  permitted in **major** version bumps.
- Every breaking change MUST include clear documentation and
  migration instructions in the CHANGELOG.

### 4.4 Documentation

- `common-lib/README.md` MUST document:
  - Each helper definition and its purpose.
  - Expected input values and their types.
  - Usage examples showing how application charts call each helper.

---

## 5. Configuration and Customization

### 5.1 Values Defaults

- Every chart MUST include a `values.yaml` with sensible defaults,
  inline comments, and examples.
- `values.yaml` MUST be sufficient for a working deployment without
  additional overrides.

### 5.2 Canonical Values Shape

All charts MUST use the following top-level values structure
(sections are omitted when not applicable to the workload):

| Key | Purpose |
|---|---|
| `image` | Container image repository, tag, and pull policy |
| `replicaCount` | Default number of replicas |
| `resources` | CPU/memory requests and limits |
| `service` | Service type, port, and annotations |
| `ingress` | Ingress enabled flag, hosts, TLS, annotations |
| `autoscaling` | HPA enabled flag, min/max replicas, metrics |
| `podAnnotations` | Additional pod-level annotations |
| `podLabels` | Additional pod-level labels |
| `podSecurityContext` | Pod-level security context |
| `securityContext` | Container-level security context |
| `serviceAccount` | Service account creation and name |
| `nodeSelector` | Node selector constraints |
| `tolerations` | Tolerations for taints |
| `affinity` | Affinity and anti-affinity rules |

### 5.3 Overriding Values

Users override values through standard Helm mechanisms:

- Environment-specific files (e.g., `values-staging.yaml`,
  `values-production.yaml`).
- CI/CD pipeline `--set` or `--values` flags.
- Helm value layering (multiple `-f` files merged left to right).

### 5.4 Backwards Compatibility

- Changes to `values.yaml` keys or template behavior that alter
  the rendered output in a non-additive way MUST be treated as
  breaking changes and require a **major** version bump.
- Backwards-compatible additions (new optional keys with defaults
  that preserve prior behavior) are **minor** version bumps.
- Breaking changes MUST include migration notes in the chart
  README and CHANGELOG.

### 5.5 Feature Flags and Optional Components

- Optional components (ingress, HPA, service mesh sidecars, extra
  containers, etc.) MUST be gated behind a boolean `enabled` key:

  ```yaml
  ingress:
    enabled: false
  autoscaling:
    enabled: false
  ```

- When `enabled: false`, the corresponding template MUST produce no
  output.

---

## 6. Labels and Annotations Conventions

### 6.1 Common Labels Helper

The `common-lib.labels` helper MUST apply the following base labels
to every resource:

| Label | Source |
|---|---|
| `app.kubernetes.io/name` | Chart name |
| `app.kubernetes.io/instance` | Release name |
| `app.kubernetes.io/version` | App version |
| `app.kubernetes.io/managed-by` | `{{ .Release.Service }}` |
| `app.kubernetes.io/part-of` | `helm-charts-hub` |
| `helm.sh/chart` | `{{ include "common-lib.chart" . }}` |

### 6.2 Label Usage

- All application charts MUST use `common-lib.labels` in every
  `metadata.labels` block.
- Charts MAY merge additional labels from `.Values.labels` or
  resource-specific label values (e.g., `.Values.podLabels`).

### 6.3 Common Annotations Helper

The `common-lib.annotations` helper MUST provide:

| Annotation | Source |
|---|---|
| `meta.helm.sh/release-name` | `{{ .Release.Name }}` |
| `meta.helm.sh/release-namespace` | `{{ .Release.Namespace }}` |

- Charts MAY merge additional annotations from `.Values.annotations`
  or resource-specific annotation values
  (e.g., `.Values.podAnnotations`).

### 6.4 Organization Prefix

- The prefix `platform.example.com/*` is RESERVED for platform and
  SRE-related annotations such as ownership, SLOs, runbook URLs,
  and cost-center tags.
- Teams MUST NOT use this prefix for application-level metadata.
- Teams SHOULD use their own domain prefix for custom annotations
  (e.g., `team-name.example.com/*`).

### 6.5 Custom Labels and Annotations

- Contributors MUST add custom labels and annotations through the
  designated `.Values` keys (`labels`, `podLabels`, `annotations`,
  `podAnnotations`).
- Contributors MUST NOT modify the core label or annotation helpers
  to add team-specific metadata.

---

## 7. Extensibility and New Charts

### 7.1 Criteria for Adding a New Chart

A new chart MUST meet the following quality bar before merging:

- Follows all conventions in this constitution.
- Uses `common-lib` helpers wherever possible.
- Includes a complete `values.yaml` with defaults and comments.
- Includes a README with all required sections (see §9).
- Passes `helm lint` and CI validation checks.
- Is reviewed and approved by at least one maintainer.

### 7.2 Library-First Approach

- New charts MUST use `common-lib` helpers before introducing new
  template patterns.
- If a new pattern is broadly useful, it SHOULD be contributed back
  to `common-lib` rather than kept in a single application chart.

### 7.3 Extending Existing Charts

- New optional features MUST be keyed off `values.yaml` with
  sensible defaults that preserve existing behavior.
- Extending a chart MUST NOT change the rendered output for users
  who have not opted in to the new feature.

### 7.4 Deprecation Policy

- Deprecated charts or features MUST be announced with:
  - A CHANGELOG entry at the time of deprecation.
  - A deprecation notice in the chart README.
  - A minimum deprecation window of **one minor release cycle**
    before removal.
- Removal of deprecated items MUST occur only in a **major** version
  bump.

---

## 8. Testing, Validation, and CI/CD

### 8.1 Linting

- All charts MUST pass `helm lint` with zero errors.
- JSON Schema validation (via `values.schema.json`) SHOULD be used
  where applicable.

### 8.2 Chart Testing

- Pull requests MUST run chart-testing (`ct`) to verify:
  - Template rendering succeeds for all charts.
  - `helm lint` passes.
  - Basic install and upgrade tests pass against a disposable
    cluster (e.g., kind) when feasible.

### 8.3 Required CI Checks

The following checks MUST pass before a pull request can be merged:

- `helm lint` on all changed charts.
- Template rendering (`helm template`) on all changed charts.
- `ct lint` for structural and metadata validation.
- Optional: install/upgrade test in a disposable kind cluster for
  charts that have changed.

### 8.4 Automated Releases and Publishing

- Chart releases MUST be automated via CI (e.g., GitHub Actions).
- Charts MUST be published to an OCI-compatible registry or a
  Helm chart repository.
- Version promotion (e.g., from pre-release to stable) MUST follow
  the versioning policy in §11.

---

## 9. Documentation Standards

### 9.1 Chart README Requirement

Every chart MUST include a `README.md` in its chart directory.

### 9.2 Required README Sections

Each chart README MUST contain:

- **Overview** — what the chart deploys and its intended use case.
- **Prerequisites** — required Kubernetes version, Helm version,
  and any cluster-level dependencies.
- **Installation** — `helm install` commands and basic usage.
- **Configuration** — a parameters table listing every values key,
  its type, default, and description.
- **Examples** — sample `values.yaml` snippets for common
  deployment patterns.
- **Upgrade Notes** — migration steps for each major version.
- **Troubleshooting** — common issues and their resolutions.

### 9.3 Breaking Change Documentation

- Breaking changes MUST be documented in both the chart README
  (upgrade notes) and the CHANGELOG.
- Migration steps MUST be explicit and actionable.

### 9.4 Usage Examples

- Charts SHOULD include example `values.yaml` files for common
  scenarios (e.g., minimal install, production with ingress and
  HPA, development with debug settings).

---

## 10. Governance and Contribution Workflow

### 10.1 Contributor Expectations

Contributors MUST:

- Align changes with the design principles in §2.
- Include or update tests as required by §8.
- Include or update documentation as required by §9.
- Follow the repository structure and use `common-lib` helpers as
  required by §3 and §4.

### 10.2 Proposing Major Changes

- Major changes or new charts SHOULD be proposed via a lightweight
  RFC in a `proposals/` directory or as a GitHub Discussion before
  implementation begins.
- RFCs MUST describe the motivation, proposed design, alternatives
  considered, and impact on existing charts.

### 10.3 Pull Request Reviews

- Every pull request MUST be reviewed and approved by at least
  **one** maintainer before merging.
- Reviewers MUST verify compliance with this constitution,
  including naming conventions, library chart usage, values shape,
  labels/annotations, documentation, and tests.
- Disagreements MUST be resolved through discussion on the PR. If
  consensus cannot be reached, a second maintainer MUST arbitrate.

### 10.4 Amending This Constitution

- Amendments to this constitution MUST be proposed via a pull
  request modifying this file.
- Constitutional amendments MUST be reviewed and approved by at
  least **two** maintainers.
- Notable changes MUST be recorded in the Sync Impact Report at
  the top of this file and follow the versioning policy below.

---

## 11. Evolution and Versioning Policy

### 11.1 Semantic Versioning

All charts MUST follow Semantic Versioning (SemVer):

- **Major** (`X.0.0`): Breaking changes to values, templates, or
  rendered resources that require user action.
- **Minor** (`x.Y.0`): New features, optional values keys, or
  helpers added in a backwards-compatible manner.
- **Patch** (`x.y.Z`): Bug fixes, documentation improvements, and
  non-functional changes.

### 11.2 Breaking Change Process

Breaking changes MUST follow this process:

1. Announce deprecation in the current minor release with a
   CHANGELOG entry and README notice.
2. Maintain the deprecated behavior for at least one minor release
   cycle.
3. Remove or change behavior only in the next **major** release.
4. Provide explicit migration instructions in the CHANGELOG and
   README.

### 11.3 CHANGELOG

- Every chart MUST maintain a CHANGELOG (or use GitHub Releases)
  with entries for each version.
- Entries MUST follow a consistent format (e.g., Added, Changed,
  Deprecated, Removed, Fixed, Security).

### 11.4 Constitution Versioning

This constitution is versioned independently of the charts:

- **Major**: Removal or redefinition of principles or governance
  rules.
- **Minor**: New sections, principles, or materially expanded
  guidance.
- **Patch**: Clarifications, wording improvements, or typo fixes.

**Version**: 1.0.0 | **Ratified**: 2026-02-19 | **Last Amended**: 2026-02-19
