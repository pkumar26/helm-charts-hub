# Tasks: Helm Charts Hub — Foundational Spec (001)

**Input**: Design documents from `/specs/001-foundational-spec/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Not explicitly requested — test tasks are omitted. CI validation and verification tasks are included where they confirm acceptance criteria.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing. US1 (Deploy) and US2 (Add Chart) share a phase because creating web-app (US2) and verifying deployment (US1) produce the same artifacts.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- File paths are relative to repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository scaffold — directories, tooling configuration, contribution docs

- [ ] T001 Create repository directory structure: charts/common-lib/templates/, charts/web-app/templates/, charts/web-app/ci/, docs/templates/, examples/, environments/dev/, environments/staging/, environments/production/, .github/workflows/
- [ ] T002 Create chart-testing configuration with chart-dirs, target-branch, and check-version-increment in ct.yaml
- [ ] T003 [P] Create global Helm ignore patterns (.git, .specify, specs/, environments/, examples/, *.md except Chart.yaml) in .helmignore
- [ ] T004 [P] Create contribution guide covering library-first workflow, chart creation checklist, versioning rules, and PR process in CONTRIBUTING.md
- [ ] T005 [P] Create pull request template with chart checklist (lint, template, README, CHANGELOG, CHARTS.md) in .github/PULL_REQUEST_TEMPLATE.md

---

## Phase 2: Foundational — common-lib Core Helpers (Blocking Prerequisites)

**Purpose**: Library chart with metadata and core resource helpers. ALL user stories depend on common-lib existing.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T006 Create common-lib Chart.yaml (apiVersion: v2, type: library, version: 0.1.0) in charts/common-lib/Chart.yaml
- [ ] T007 [P] Create metadata helpers — fullname (63-char truncated) and chart (name-version) — in charts/common-lib/templates/_helpers.tpl
- [ ] T008 [P] Create label helpers — labels (6 base labels + extraLabels merge) and selectorLabels (name + instance) — in charts/common-lib/templates/_labels.tpl
- [ ] T009 [P] Create annotation helpers — 2 base annotations + extraAnnotations merge + configurable global.annotationPrefix — in charts/common-lib/templates/_annotations.tpl
- [ ] T010 Create Deployment helper with workloadType guard (reject unsupported types with clear error listing valid options), image validation (required repository, fail on empty tag), probes, security context, resource limits, extraEnv, extraVolumes, and extraVolumeMounts in charts/common-lib/templates/_deployment.tpl
- [ ] T011 [P] Create Service helper with workloadType guard (deployment only) and selectorLabels in charts/common-lib/templates/_service.tpl
- [ ] T012 [P] Create pod security context helper (runAsNonRoot: true, readOnlyRootFilesystem: true, allowPrivilegeEscalation: false) in charts/common-lib/templates/_podsecurity.tpl
- [ ] T013 [P] Create ServiceAccount helper with serviceAccount.create guard and name default to fullname in charts/common-lib/templates/_serviceaccount.tpl
- [ ] T014 Create values.yaml with canonical defaults (see data-model.md §2.3) in charts/common-lib/values.yaml
- [ ] T015 [P] Create initial CHANGELOG.md (v0.1.0 — Added: metadata helpers, Deployment, Service, ServiceAccount, pod security) in charts/common-lib/CHANGELOG.md

**Checkpoint**: `helm lint charts/common-lib` passes with zero errors. All helper definitions are callable via `include "common-lib.<helper>"`. User story implementation can begin.

---

## Phase 3: US1 + US2 — Deploy a Service / Add a New Chart (Priority: P1) 🎯 MVP

**Goal**: Create the web-app chart demonstrating full common-lib integration. Users can `helm install` with minimal overrides and get a working Deployment + Service with correct labels.

**Independent Test**: `helm install web-app charts/web-app --set image.repository=nginx --set image.tag=stable` on a kind cluster → healthy Deployment, Service, 6 base labels, 2 base annotations.

### Implementation

- [ ] T016 [US2] Create web-app Chart.yaml (apiVersion: v2, type: application, version: 0.1.0, dependency on common-lib >=0.1.0 <1.0.0 via file://../common-lib) in charts/web-app/Chart.yaml
- [ ] T017 [US2] Create values.yaml with full canonical shape — image.*, replicaCount, workloadType, resources, service.*, podSecurityContext, securityContext, serviceAccount.*, nodeSelector, tolerations, affinity, livenessProbe, readinessProbe, podAnnotations, podLabels, labels, annotations, global.annotationPrefix — in charts/web-app/values.yaml
- [ ] T018 [P] [US2] Create chart-specific _helpers.tpl with nameOverride and fullnameOverride support in charts/web-app/templates/_helpers.tpl
- [ ] T019 [US1] Create deployment.yaml delegating to common-lib.deployment via `include "common-lib.deployment" (dict "root" .)` in charts/web-app/templates/deployment.yaml
- [ ] T020 [P] [US1] Create service.yaml delegating to common-lib.service via `include "common-lib.service" (dict "root" .)` in charts/web-app/templates/service.yaml
- [ ] T021 [P] [US1] Create serviceaccount.yaml delegating to common-lib.serviceaccount in charts/web-app/templates/serviceaccount.yaml
- [ ] T022 [US1] Create NOTES.txt with post-install guidance (kubectl get pods, kubectl get svc, port-forward example) in charts/web-app/templates/NOTES.txt
- [ ] T023 [P] [US2] Create initial CHANGELOG.md (v0.1.0 — Added: Deployment, Service, ServiceAccount via common-lib) in charts/web-app/CHANGELOG.md
- [ ] T024 [US2] Run `helm dependency build charts/web-app` and verify common-lib is resolved into charts/web-app/charts/
- [ ] T025 [US2] Verify `helm lint charts/web-app` passes with zero errors
- [ ] T026 [US1] Verify `helm template web-app charts/web-app --set image.repository=nginx --set image.tag=stable` renders Deployment + Service with all 6 base labels and 2 base annotations
- [ ] T027 [US1] Verify template validation: missing image.repository → clear error, empty image.tag → clear error, invalid workloadType → clear error listing valid options

**Checkpoint**: web-app chart is functional. `helm install` with image overrides produces a healthy Deployment + Service. US1 and US2 acceptance criteria are met.

---

## Phase 4: US3 — Extend Chart with Optional Features (Priority: P2)

**Goal**: Add Ingress, HPA, ConfigMap, and Secret capabilities gated behind feature flags. Users who don't enable features see zero change in rendered output (SC-005).

**Independent Test**: Render with all flags disabled → diff vs Phase 3 output is empty. Render with `ingress.enabled: true` → valid Ingress resource. Render with `autoscaling.enabled: true` → valid HPA resource.

### Implementation

- [ ] T028 [P] [US3] Create Ingress helper (networking.k8s.io/v1) with ingress.enabled guard, className, hosts, TLS, and ingress.annotations merge in charts/common-lib/templates/_ingress.tpl
- [ ] T029 [P] [US3] Create HPA helper (autoscaling/v2) with autoscaling.enabled guard, min/maxReplicas, CPU/memory targets in charts/common-lib/templates/_hpa.tpl
- [ ] T030 [P] [US3] Create ConfigMap helper accepting data dict argument in charts/common-lib/templates/_configmap.tpl
- [ ] T031 [P] [US3] Create Secret helper with base64 encoding accepting data dict argument in charts/common-lib/templates/_secrets.tpl
- [ ] T032 [US3] Create ingress.yaml delegating to common-lib.ingress in charts/web-app/templates/ingress.yaml
- [ ] T033 [P] [US3] Create hpa.yaml delegating to common-lib.hpa in charts/web-app/templates/hpa.yaml
- [ ] T034 [US3] Add ingress.*, autoscaling.*, extraEnv, extraVolumes, and extraVolumeMounts sections to values.yaml (all feature flags default false) in charts/web-app/values.yaml
- [ ] T035 [P] [US3] Create minimal example values (image only, all features disabled) in examples/web-app-minimal.yaml
- [ ] T036 [P] [US3] Create production example values (ingress enabled, HPA, TLS, resource tuning, ownership annotations under global.annotationPrefix per FR-020) in examples/web-app-production.yaml
- [ ] T037 [P] [US3] Create CI test values (basic install with nginx image) in charts/web-app/ci/test-values.yaml
- [ ] T038 [P] [US3] Create CI ingress test values (ingress.enabled: true, test host) in charts/web-app/ci/test-ingress-values.yaml
- [ ] T039 [US3] Bump common-lib to v0.2.0 and update CHANGELOG (Added: Ingress, HPA, ConfigMap, Secret helpers) in charts/common-lib/Chart.yaml and charts/common-lib/CHANGELOG.md
- [ ] T040 [US3] Verify `helm template` with all feature flags disabled produces identical output to Phase 3 (zero diff)

**Checkpoint**: Optional features work. Feature-off output is unchanged from Phase 3. `ingress.enabled: true` renders a valid Ingress. `autoscaling.enabled: true` renders a valid HPA.

---

## Phase 5: US9 — Per-Chart README (Priority: P1)

**Goal**: Every chart has a standardized README with all 7 required sections (Constitution §9.2). Configuration tables document every values key with type, default, and description.

**Independent Test**: Open any chart's README and confirm: Overview, Prerequisites, Installation, Configuration table, Examples, Upgrade Notes, Troubleshooting are present. Every values.yaml key has a table row.

### Implementation

- [ ] T041 [P] [US9] Create common-lib README.md documenting each helper definition name, expected inputs (dict pattern), output, usage example from an application chart, and the opt-out pattern for charts needing custom templates (FR-010) in charts/common-lib/README.md
- [ ] T042 [P] [US9] Create web-app README.md with all 7 sections — Overview, Prerequisites, Installation (OCI commands), Configuration (full parameters table including HPA/replicaCount interaction per FR-015), Examples (minimal + production), Upgrade Notes ("Initial release"), Troubleshooting — in charts/web-app/README.md
- [ ] T043 [P] [US9] Create helm-docs template for web-app config table generation in charts/web-app/README.md.gotmpl
- [ ] T044 [P] [US9] Create helm-docs template for common-lib documentation in charts/common-lib/README.md.gotmpl
- [ ] T045 [US9] Create README template scaffold for new chart authors in docs/templates/chart-readme.md

**Checkpoint**: Both charts have complete READMEs. Configuration tables list every values key (SC-011). common-lib documents all helpers (FR-039).

---

## Phase 6: US7 — Root README (Priority: P1)

**Goal**: Repository-root README provides the entry point for all users: project overview, prerequisites, install/uninstall commands, and links to Getting Started guide and chart catalog.

**Independent Test**: A user with Helm ≥ 3.12 and kubectl can follow the README from OCI install to uninstall without guessing any prerequisites or commands (SC-009).

### Implementation

- [ ] T046 [US7] Create root README.md with 8 sections — Project Overview (architecture: common-lib → app charts), Prerequisites (Helm ≥ 3.12, K8s ≥ 1.26, Ingress vs Gateway note), Quick Start (link to docs/getting-started.md), Install (OCI command), Uninstall, Chart Catalog (link to CHARTS.md), Contributing (link to CONTRIBUTING.md) — in README.md
- [ ] T047 [US7] Add Troubleshooting section covering OCI pull failures, image pull errors, values validation errors, and namespace-not-found to README.md

**Checkpoint**: Root README is complete with all sections per FR-026. All install/uninstall commands use OCI references (FR-028).

---

## Phase 7: US8 — Getting Started Flow (Priority: P1)

**Goal**: Step-by-step guide takes a new user from zero to a running sample app on a kind cluster in under 5 minutes (SC-009). All commands are copy-pasteable (FR-032).

**Independent Test**: Follow the guide on a fresh kind cluster — create cluster, install ingress controller, deploy web-app with nginx, verify pods + curl, clean up.

**Depends on**: US3 (ingress helper must exist for the ingress demo section)

### Implementation

- [ ] T048 [US8] Create Getting Started guide — prerequisites check, kind cluster creation, ingress controller install (Traefik and NGINX options using upstream charts) — in docs/getting-started.md
- [ ] T049 [US8] Add web-app installation (OCI install with sample nginx image), verification (kubectl get pods, kubectl get svc, curl test), optional ingress routing, and clean-up (helm uninstall, kind delete cluster) sections to docs/getting-started.md

**Checkpoint**: Getting Started guide is complete. Every command is self-contained and copy-pasteable. A tester can go from zero to running app in under 5 minutes.

---

## Phase 8: US4 — Environment-Specific Configuration (Priority: P2)

**Goal**: Demonstrate environment-specific values layering (dev, staging, production) as example overlays without forking the chart.

**Independent Test**: Render with base values + production overlay → confirm replicas=3, ingress enabled, HPA enabled. Render with dev overlay → confirm replicas=1, ingress disabled.

### Implementation

- [ ] T050 [P] [US4] Create dev environment values (replicaCount: 1, minimal resources, ingress disabled) in environments/dev/web-app.values.yaml
- [ ] T051 [P] [US4] Create staging environment values (replicaCount: 2, ingress enabled with staging host) in environments/staging/web-app.values.yaml
- [ ] T052 [P] [US4] Create production environment values (replicaCount: 3, ingress + TLS, HPA enabled, full resources) in environments/production/web-app.values.yaml
- [ ] T053 [US4] Verify values layering: `helm template -f environments/production/web-app.values.yaml` renders 3 replicas, Ingress, and HPA

**Checkpoint**: Environment overlays merge correctly. Later files override earlier ones. Production overlay enables ingress and HPA as documented.

---

## Phase 9: US10 — Chart Catalog (Priority: P2)

**Goal**: Central CHARTS.md lists all charts with name, description, workload types, and README links for discoverability (FR-041).

**Independent Test**: Open CHARTS.md → confirm every `charts/*/` directory has an entry. Follow each link → arrives at a valid README.

### Implementation

- [ ] T054 [US10] Create CHARTS.md with catalog table (columns: Chart, Description, Workload Types, README link) listing common-lib and web-app in CHARTS.md
- [ ] T055 [US10] Add chart catalog link to root README.md Quick Start and Chart Catalog sections

**Checkpoint**: Catalog is complete. Every chart directory has a corresponding entry with a valid README link (SC-010).

---

## Phase 10: US5 — Update Library Chart (Priority: P2)

**Goal**: Document and verify the workflow for updating common-lib helpers and propagating changes to dependent charts via version bumps.

**Independent Test**: Modify a helper in common-lib, bump version, run `helm dependency build` on web-app, render → confirm the change propagates.

### Implementation

- [ ] T056 [US5] Add library versioning section to CONTRIBUTING.md — version bump rules (major/minor/patch), dependency update workflow (`helm dependency build`), independent release policy (FR-049), and breaking-change dual-write rule: changes MUST be documented in both chart README upgrade notes and CHANGELOG (FR-040)
- [ ] T057 [US5] Verify common-lib version bump propagates to web-app: update dependency constraint, run `helm dependency build charts/web-app`, confirm new version in charts/web-app/charts/

**Checkpoint**: Library update workflow is documented. Version bumps are understood and propagate correctly.

---

## Phase 11: CI/CD Pipelines (Cross-Cutting)

**Purpose**: Automated chart linting, testing, and OCI publishing via GitHub Actions (FR-022, FR-047).

- [ ] T058 Create chart-lint-test.yaml PR gate — checkout (full history), setup-helm, setup-python, chart-testing-action, ct list-changed, ct lint (blocking), kind-action, ct install (advisory, continue-on-error) — in .github/workflows/chart-lint-test.yaml
- [ ] T059 [P] Create chart-release.yaml — checkout, setup-helm, GHCR login with GITHUB_TOKEN, helm package + push common-lib then web-app to oci://ghcr.io — in .github/workflows/chart-release.yaml
- [ ] T060 [P] Create docs-check.yaml advisory — verify every charts/*/ has README.md, CHARTS.md lists every chart dir, required README sections present, helm-docs freshness check — in .github/workflows/docs-check.yaml

**Checkpoint**: PRs trigger lint/test gate. Merges to main trigger OCI publish. Documentation checks run as advisory.

---

## Final Phase: Polish & Cross-Cutting Concerns

**Purpose**: Hardening, deprecation patterns (US6), schema validation, and end-to-end verification.

- [ ] T061 [P] Document deprecation patterns (US6) — announce in minor release, deprecation window, removal in major release, migration steps in CHANGELOG + README, catalog entry marking (strikethrough + planned removal version per FR-044) — in CONTRIBUTING.md
- [ ] T062 [P] Create optional values.schema.json for web-app input validation (FR-024, SHOULD) in charts/web-app/values.schema.json
- [ ] T063 Run quickstart.md end-to-end validation on a fresh environment per specs/001-foundational-spec/quickstart.md
- [ ] T064 Verify all charts pass `helm lint` and `helm template` with both default values and CI test values
- [ ] T065 [P] Verify all README files contain required section headings (Overview, Prerequisites, Installation, Configuration, Examples, Upgrade Notes, Troubleshooting) per constitution §9.2

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — **BLOCKS all user stories**
- **US1+US2 (Phase 3)**: Depends on Foundational (common-lib must exist)
- **US3 (Phase 4)**: Depends on Phase 3 (web-app must exist to consume new helpers)
- **US9 (Phase 5)**: Depends on Phase 4 (needs full feature set for accurate config tables)
- **US7 (Phase 6)**: Depends on Phase 3 (needs OCI install commands for a real chart)
- **US8 (Phase 7)**: Depends on Phase 4 (needs ingress helper for demo flow)
- **US4 (Phase 8)**: Depends on Phase 4 (needs ingress/HPA values for overlays)
- **US10 (Phase 9)**: Depends on Phase 5 (needs READMEs to link to)
- **US5 (Phase 10)**: Depends on Phase 4 (needs version-bumped common-lib to demonstrate)
- **CI/CD (Phase 11)**: Depends on Phase 3 (needs charts for CI to lint/test)
- **Polish (Final)**: Depends on all previous phases

### User Story Dependencies

```
Phase 1: Setup
    │
    ▼
Phase 2: Foundational (common-lib) ─── BLOCKS ALL ───┐
    │                                                  │
    ▼                                                  │
Phase 3: US1+US2 (web-app core) ◄─────────────────────┘
    │
    ├───────────────────────────────────┐
    ▼                                   ▼
Phase 4: US3 (optional features)   Phase 6: US7 (root README)
    │                               Phase 11: CI/CD
    ├──────────────────┐
    ▼                  ▼
Phase 5: US9       Phase 7: US8 (getting started)
(per-chart README) Phase 8: US4 (env config)
    │              Phase 10: US5 (library update)
    ▼
Phase 9: US10 (catalog)
    │
    ▼
Final Phase: Polish
```

### Within Each User Story Phase

1. Common-lib helpers before web-app wrappers (within US3)
2. Values updates before verification tasks
3. Core implementation before examples and test values
4. Story complete at checkpoint before moving to next priority

---

## Parallel Opportunities

### After Phase 2 (Foundational) completes:

All Phase 3 tasks begin (sequential within phase due to dependencies).

### After Phase 3 (US1+US2) completes:

- **Phase 4 (US3)**, **Phase 6 (US7)**, and **Phase 11 (CI/CD)** can all start in parallel

### After Phase 4 (US3) completes:

- **Phase 5 (US9)**, **Phase 7 (US8)**, **Phase 8 (US4)**, and **Phase 10 (US5)** can all start in parallel

### Within Phase 4 (US3) — Example:

```
# Launch all common-lib helpers together (different files, no cross-deps):
T028: _ingress.tpl  |  T029: _hpa.tpl  |  T030: _configmap.tpl  |  T031: _secrets.tpl

# Then launch web-app wrappers together:
T032: ingress.yaml  |  T033: hpa.yaml

# Then launch all example/test values together:
T035: web-app-minimal.yaml  |  T036: web-app-production.yaml
T037: test-values.yaml      |  T038: test-ingress-values.yaml
```

### Within Phase 5 (US9) — Example:

```
# All READMEs and templates are independent files:
T041: common-lib/README.md  |  T042: web-app/README.md
T043: web-app/README.md.gotmpl  |  T044: common-lib/README.md.gotmpl
```

---

## Implementation Strategy

### MVP First (Phases 1–3 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (common-lib core — **CRITICAL**)
3. Complete Phase 3: US1+US2 (web-app core)
4. **STOP and VALIDATE**: `helm lint` + `helm template` + `helm install` on kind cluster
5. Deploy/demo if ready — **this is the MVP**

### Incremental Delivery

1. Setup + Foundational → common-lib helpers exist
2. US1+US2 → web-app deploys with minimal overrides (MVP!)
3. US3 → optional features: Ingress, HPA, ConfigMap, Secret
4. US9 → complete per-chart READMEs with config tables
5. US7 + US8 → root README and Getting Started guide
6. US4 + US10 + US5 → environment overlays, catalog, library workflow
7. CI/CD → automated lint, test, OCI publish pipelines
8. Polish → schema validation, deprecation docs, end-to-end check

Each increment adds value without breaking previous phases.

### Parallel Team Strategy

With multiple contributors after Foundational phase:

1. Team completes Setup + Foundational together
2. Once Phase 3 (US1+US2) is done:
   - **Contributor A**: US3 (optional features) → US8 (getting started) → US4 (env config)
   - **Contributor B**: US7 (root README) → US9 (per-chart READMEs) → US10 (catalog)
   - **Contributor C**: CI/CD pipelines → US5 (library workflow) → Polish
3. Stories complete and integrate independently at each checkpoint

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks within the same phase
- [Story] label maps each task to its user story for traceability
- Plan-to-task phase mapping: Plan P1 = Tasks P1+P2, Plan P2 = Tasks P3, Plan P3 = Tasks P4, Plan P4 = Tasks P5–P7+P11, Plan P5 = Tasks P8–P10+Final. Plan README deliverables listed in P1/P2 are deferred to task Phases 5–6 (US9/US7) for story-based grouping
- Each user story phase is independently verifiable at its checkpoint
- Helm chart monorepo: no `src/` or `tests/` — charts ARE the source, CI does the testing
- Commit after each task or logical group of parallel tasks
- Verify `helm lint` passes after each phase that modifies chart files
- Future phases (Traefik, NGINX, Gateway API) from plan.md phases 6–9 are **NOT** included — they are post-initial-release scope
- All helper signatures use the dict pattern (`dict "root" .`) per contracts/common-lib-helpers.md
- OCI artifact references: `oci://ghcr.io/<org>/charts/<name>:<version>` — `<org>` is a placeholder for the GitHub org
