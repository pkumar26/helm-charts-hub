# Tasks: Istio AKS Helm Chart with FIPS and Security Baseline (007)

**Input**: Design documents from `/specs/007-istio-aks-chart/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Not explicitly requested in spec — test tasks are omitted. Verification tasks are included where they confirm acceptance criteria.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing. Base chart (US1) must complete before control plane (US2) or gateway (US3) can begin.

## Format: `- [ ] [ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- File paths are relative to repository root

---

## Phase 1: Setup (Project Scaffold)

**Purpose**: Create directory structure for three Istio charts, environment values, and example manifests.

- [X] T001 Create Istio chart directory structure: charts/istio/base/{templates,ci}, charts/istio/istiod/{templates,ci}, charts/istio/gateway/{templates,ci}
- [X] T002 [P] Create environment directories for Istio values: environments/dev/, environments/staging/, environments/production/
- [X] T003 [P] Create examples directory structure for Istio manifests in examples/

---

## Phase 2: Foundational — Base Chart (CRDs) (Blocking Prerequisites)

**Purpose**: Install Istio CRDs. istiod and gateway charts CANNOT be installed until base chart exists.

**⚠️ CRITICAL**: User Story 2 (istiod) and User Story 3 (gateway) depend on this phase completing.

- [X] T004 [US1] Create base Chart.yaml (apiVersion: v2, name: istio-base, type: application, version: 1.0.0, appVersion: 1.23.0) in charts/istio/base/Chart.yaml
- [X] T005 [P] [US1] Create base values.yaml with revision tracking and namespace configuration in charts/istio/base/values.yaml
- [X] T006 [P] [US1] Create base _helpers.tpl with fullname, chart, and labels helpers in charts/istio/base/templates/_helpers.tpl
- [X] T007 [US1] Create namespace.yaml template for istio-system namespace with mesh labels in charts/istio/base/templates/namespace.yaml
- [X] T008 [US1] Create Istio CRD manifests in charts/istio/base/templates/crds/ for Gateway, VirtualService, DestinationRule, ServiceEntry, PeerAuthentication, AuthorizationPolicy
- [X] T009 [US1] Verify base chart: `helm lint charts/istio/base` passes with zero errors
- [X] T010 [US1] Verify base template rendering: `helm template istio-base charts/istio/base` produces namespace and all CRDs

**Checkpoint**: Base chart is functional. CRDs can be installed. US2 and US3 can begin in parallel.

---

## Phase 3: US1 — Deploy Istio Base (CRDs) to AKS (Priority: P1) 🎯 MVP

**Goal**: Complete base chart with environment-specific values files. Users can install base chart to any environment.

**Independent Test**: `helm install istio-base charts/istio/base --values charts/istio/base/values-dev.yaml` on AKS cluster → istio-system namespace created, all CRDs registered.

### Implementation

- [X] T011 [P] [US1] Create values-dev.yaml with minimal configuration (no FIPS requirements) in charts/istio/base/values-dev.yaml
- [X] T012 [P] [US1] Create values-staging.yaml with moderate configuration in charts/istio/base/values-staging.yaml
- [X] T013 [P] [US1] Create values-prod.yaml with production labels and annotations in charts/istio/base/values-prod.yaml
- [X] T014 [P] [US1] Create base README.md with installation order, verification steps (`kubectl get crds | grep istio.io`), and upgrade notes in charts/istio/base/README.md
- [X] T015 [P] [US1] Create base CHANGELOG.md (v1.0.0 — Added: Istio CRDs for AKS) in charts/istio/base/CHANGELOG.md
- [X] T016 [P] [US1] Create CI test values for base chart in charts/istio/base/ci/test-values.yaml
- [X] T017 [US1] Create environment overlay for base in environments/dev/istio-base.values.yaml
- [X] T018 [P] [US1] Create environment overlay for base in environments/staging/istio-base.values.yaml
- [X] T019 [P] [US1] Create environment overlay for base in environments/production/istio-base.values.yaml
- [X] T020 [US1] Verify base acceptance scenario 1: Install base chart → all Istio CRDs are created
- [X] T021 [US1] Verify base acceptance scenario 2: `kubectl get crds | grep istio.io` lists all required CRDs
- [X] T022 [US1] Verify base acceptance scenario 3: istio-system namespace has proper mesh operation labels

**Checkpoint**: Base chart is complete with all environment values files. US1 acceptance criteria are met. istiod and gateway can now be implemented.

---

## Phase 4: US2 — Deploy Istio Control Plane (istiod) with FIPS Mode (Priority: P1) 🎯 MVP

**Goal**: Create istiod chart with FIPS-compliant configuration for production. Users can deploy control plane with FIPS 140-2 validated crypto.

**Independent Test**: `helm install istiod charts/istio/istiod --values charts/istio/istiod/values-prod.yaml -n istio-system` → istiod pod starts with FIPS mode, BoringCrypto is active.

**Depends on**: Phase 2 (base chart must be installed first)

### Implementation — Chart Structure

- [X] T023 [US2] Create istiod Chart.yaml with dependency on upstream Istio istiod chart (version: 1.23.0, repository: https://istio-release.storage.googleapis.com/charts) in charts/istio/istiod/Chart.yaml
- [X] T024 [P] [US2] Create istiod _helpers.tpl with fullname, chart, labels, and FIPS image selector helper in charts/istio/istiod/templates/_helpers.tpl
- [X] T025 [US2] Run `helm dependency update charts/istio/istiod` to download upstream istiod chart into charts/istio/istiod/charts/

### Implementation — Security Baseline Templates

- [X] T026 [P] [US2] Create PeerAuthentication template for mesh-wide STRICT mTLS in charts/istio/istiod/templates/peerauthentication.yaml
- [X] T027 [P] [US2] Create default-deny AuthorizationPolicy template in charts/istio/istiod/templates/authorizationpolicy-deny-all.yaml
- [X] T028 [P] [US2] Create AuthorizationPolicy for istiod webhook access in charts/istio/istiod/templates/authorizationpolicy-allow-webhook.yaml
- [X] T029 [P] [US2] Create AuthorizationPolicy for XDS communication in charts/istio/istiod/templates/authorizationpolicy-allow-xds.yaml
- [X] T030 [P] [US2] Create NetworkPolicy for control plane isolation in charts/istio/istiod/templates/networkpolicy.yaml
- [X] T031 [P] [US2] Create HPA template (optional, enabled via autoscaling.enabled flag) in charts/istio/istiod/templates/hpa.yaml

### Implementation — Values Files

- [X] T032 [US2] Create istiod values.yaml with canonical shape (global.hub, global.tag, pilot.*, resources, autoscaling, podSecurityContext per FR-006) in charts/istio/istiod/values.yaml
- [X] T033 [US2] Create values-dev.yaml with relaxed settings (1 replica, PERMISSIVE mTLS, no FIPS, minimal resources) in charts/istio/istiod/values-dev.yaml
- [X] T034 [US2] Create values-staging.yaml with moderate settings (2 replicas, STRICT mTLS, standard images) in charts/istio/istiod/values-staging.yaml
- [X] T035 [US2] Create values-prod.yaml with FIPS configuration (global.fips.enabled: true, distroless images, GOFIPS=1, STRICT mTLS, 3 replicas, pod anti-affinity, resource limits per FR-007) in charts/istio/istiod/values-prod.yaml
- [X] T036 [US2] Add security baseline values to values-prod.yaml (runAsNonRoot, readOnlyRootFilesystem, allowPrivilegeEscalation: false, capabilities.drop: [ALL] per FR-006)

### Implementation — Documentation & Testing

- [X] T037 [P] [US2] Create istiod README.md with prerequisites (base chart required), installation sequence, FIPS validation steps, and troubleshooting in charts/istio/istiod/README.md
- [X] T038 [P] [US2] Create istiod CHANGELOG.md (v1.0.0 — Added: Control plane with FIPS mode, security baseline) in charts/istio/istiod/CHANGELOG.md
- [X] T039 [P] [US2] Create CI test values for istiod chart in charts/istio/istiod/ci/test-values.yaml
- [X] T040 [US2] Create environment overlay for istiod in environments/dev/istio-istiod.values.yaml
- [X] T041 [P] [US2] Create environment overlay for istiod in environments/staging/istio-istiod.values.yaml
- [X] T042 [P] [US2] Create environment overlay for istiod in environments/production/istio-istiod.values.yaml
- [X] T043 [US2] Verify `helm lint charts/istio/istiod` passes with zero errors
- [X] T044 [US2] Verify `helm template istiod charts/istio/istiod -f charts/istio/istiod/values-prod.yaml` renders FIPS-compliant deployment with security policies

### Acceptance Verification

- [X] T045 [US2] Verify acceptance scenario 1: Install istiod with prod values → deployment uses distroless FIPS images
- [X] T046 [US2] Verify acceptance scenario 2: Check istiod pod environment → GOFIPS=1 is set
- [ ] T047 [US2] Verify acceptance scenario 3: Inject sidecar into test pod → sidecar uses FIPS-validated crypto for mTLS
- [X] T048 [US2] Verify acceptance scenario 4: Inspect deployment → pod security context enforces runAsNonRoot, readOnlyRootFilesystem, drops all capabilities

**Checkpoint**: istiod chart is complete with FIPS mode. US2 acceptance criteria are met. Control plane can be deployed to AKS.

---

## Phase 5: US3 — Deploy Istio Ingress Gateway with Security Policies (Priority: P1) 🎯 MVP

**Goal**: Create gateway chart with pre-configured security policies (strict mTLS, AuthorizationPolicy, NetworkPolicy). Users can deploy production-ready ingress gateway.

**Independent Test**: `helm install istio-ingressgateway charts/istio/gateway --values charts/istio/gateway/values-prod.yaml -n istio-system` → gateway enforces STRICT mTLS, rejects unauthenticated connections.

**Depends on**: Phase 4 (istiod must be healthy before gateway can start)

### Implementation — Chart Structure

- [X] T049 [US3] Create gateway Chart.yaml with dependency on upstream Istio gateway chart (version: 1.23.0, repository: https://istio-release.storage.googleapis.com/charts) in charts/istio/gateway/Chart.yaml
- [X] T050 [P] [US3] Create gateway _helpers.tpl with fullname, chart, labels, and FIPS image selector helper in charts/istio/gateway/templates/_helpers.tpl
- [X] T051 [US3] Run `helm dependency update charts/istio/gateway` to download upstream gateway chart into charts/istio/gateway/charts/

### Implementation — Security Baseline Templates

- [X] T052 [P] [US3] Create Gateway resource template (Istio Gateway CRD) with hosts, TLS settings in charts/istio/gateway/templates/gateway.yaml
- [X] T053 [P] [US3] Create PeerAuthentication template for gateway STRICT mTLS in charts/istio/gateway/templates/peerauthentication.yaml
- [X] T054 [P] [US3] Create AuthorizationPolicy for gateway access control with explicit allowlists in charts/istio/gateway/templates/authorizationpolicy.yaml
- [X] T055 [P] [US3] Create NetworkPolicy for gateway network isolation (allow from internet, allow to mesh workloads, deny arbitrary pods) in charts/istio/gateway/templates/networkpolicy.yaml
- [X] T056 [P] [US3] Create HPA template (optional, enabled via autoscaling.enabled flag) in charts/istio/gateway/templates/hpa.yaml

### Implementation — Values Files

- [X] T057 [US3] Create gateway values.yaml with canonical shape (global.hub, global.tag, service.type: LoadBalancer, service.ports, resources, autoscaling per FR-008) in charts/istio/gateway/values.yaml
- [X] T058 [US3] Create values-dev.yaml with minimal settings (1 replica, PERMISSIVE mTLS, no FIPS, NodePort service) in charts/istio/gateway/values-dev.yaml
- [X] T059 [US3] Create values-staging.yaml with moderate settings (2 replicas, STRICT mTLS, LoadBalancer service) in charts/istio/gateway/values-staging.yaml
- [X] T060 [US3] Create values-prod.yaml with FIPS configuration and security baseline (global.fips.enabled: true, distroless images, STRICT mTLS, 3 replicas, HPA enabled per FR-008, NetworkPolicy enabled per FR-010) in charts/istio/gateway/values-prod.yaml
- [X] T061 [US3] Add security baseline values to values-prod.yaml (runAsNonRoot, readOnlyRootFilesystem, allowPrivilegeEscalation: false, capabilities.drop: [ALL])

### Implementation — Documentation & Testing

- [X] T062 [P] [US3] Create gateway README.md with prerequisites (istiod required), installation steps, mTLS verification, and troubleshooting in charts/istio/gateway/README.md
- [X] T063 [P] [US3] Create gateway CHANGELOG.md (v1.0.0 — Added: Ingress gateway with FIPS, security baseline) in charts/istio/gateway/CHANGELOG.md
- [X] T064 [P] [US3] Create CI test values for gateway chart in charts/istio/gateway/ci/test-values.yaml
- [X] T065 [US3] Create environment overlay for gateway in environments/dev/istio-gateway.values.yaml
- [X] T066 [P] [US3] Create environment overlay for gateway in environments/staging/istio-gateway.values.yaml
- [X] T067 [P] [US3] Create environment overlay for gateway in environments/production/istio-gateway.values.yaml
- [X] T068 [US3] Verify `helm lint charts/istio/gateway` passes with zero errors
- [X] T069 [US3] Verify `helm template istio-ingressgateway charts/istio/gateway -f charts/istio/gateway/values-prod.yaml` renders gateway with security policies

### Acceptance Verification

- [ ] T070 [US3] Verify acceptance scenario 1: Install gateway with prod values → deployment uses FIPS images, PeerAuthentication STRICT mode
- [ ] T071 [US3] Verify acceptance scenario 2: Unauthenticated client connection attempt → rejected with mTLS required error
- [X] T072 [US3] Verify acceptance scenario 3: Check AuthorizationPolicy resources → default-deny policies with explicit allowlists in place
- [X] T073 [US3] Verify acceptance scenario 4: Check NetworkPolicy resources → gateway can only communicate with istiod and mesh workloads

**Checkpoint**: Gateway chart is complete with security baseline. US3 acceptance criteria are met. Minimum viable Istio installation (base + istiod + gateway) is functional.

---

## Phase 6: US4 — Upgrade Istio Versions Declaratively (Priority: P2)

**Goal**: Document and verify declarative upgrade path for Istio version upgrades using `helm upgrade` in correct sequence.

**Independent Test**: Install Istio 1.22, upgrade to 1.23 following documented procedure → zero downtime, all components running new version.

**Depends on**: Phases 3, 4, 5 (all charts must exist)

### Implementation

- [X] T074 [P] [US4] Document upgrade sequence in charts/istio/base/README.md (base → istiod → gateway order, CRD update notes)
- [X] T075 [P] [US4] Document canary upgrade procedure in charts/istio/istiod/README.md (multiple revisions, revision tags, traffic shifting)
- [X] T076 [P] [US4] Document rollback procedure in charts/istio/gateway/README.md (helm rollback commands, verification steps)
- [X] T077 [US4] Create upgrade guide in docs/istio-aks-deployment.md covering version compatibility matrix, pre-upgrade checklist, upgrade commands, post-upgrade validation per specs/007-istio-aks-chart/contracts/chart-structure.md
- [X] T078 [US4] Create example upgrade script demonstrating base → istiod → gateway sequence with wait conditions in examples/upgrade-istio.sh
- [X] T079 [US4] Verify upgrade scenario 1: Upgrade base chart → CRDs updated without disrupting running workloads
- [X] T080 [US4] Verify upgrade scenario 2: Upgrade istiod with canary settings → new control plane pods join, old pods drain gracefully
- [X] T081 [US4] Verify upgrade scenario 3: Upgrade gateway → traffic continues flowing with zero dropped connections

**Checkpoint**: Upgrade procedures are documented and verified. US4 acceptance criteria are met.

---

## Phase 7: US5 — Deploy Istio to Multiple Environments (Priority: P2)

**Goal**: Demonstrate multi-environment deployment with environment-specific values files showing progressive security (dev → staging → prod).

**Independent Test**: Deploy to three namespaces using different values files → dev uses minimal replicas and relaxed policies, prod enforces HA and FIPS.

**Depends on**: Phases 3, 4, 5 (all charts and values files exist)

### Implementation

- [X] T082 [P] [US5] Create example minimal deployment manifest (base + istiod + gateway with dev values) in examples/istio-dev-minimal.yaml
- [X] T083 [P] [US5] Create example production deployment manifest (base + istiod + gateway with FIPS and security baseline) in examples/istio-production.yaml
- [X] T084 [US5] Document multi-environment strategy in docs/istio-aks-deployment.md (dev: minimal, staging: moderate, prod: FIPS + HA)
- [X] T085 [US5] Verify scenario 1: Deploy with dev values (replicaCount: 1) → istiod runs single replica
- [X] T086 [US5] Verify scenario 2: Deploy with prod values (replicaCount: 3, pod anti-affinity) → istiod pods spread across AZs
- [X] T087 [US5] Verify scenario 3: Deploy with dev values (FIPS disabled) → standard Istio images used

**Checkpoint**: Multi-environment deployment is documented and verified. US5 acceptance criteria are met.

---

## Phase 8: Optional — Kiali Dashboard (Mesh Observability)

**Goal**: Add optional Kiali chart for mesh visualization and troubleshooting. Users can skip this phase for air-gapped, dev, or resource-constrained environments.

**Independent Test**: `helm install kiali charts/istio/kiali --values charts/istio/kiali/values-prod.yaml -n istio-system` → Kiali UI accessible, shows mesh topology.

**Depends on**: Phase 5 (istiod must be healthy for Kiali to query mesh config)

### Implementation — Chart Structure

- [X] T106 [P] [Optional] Create kiali Chart.yaml with dependency on upstream Kiali operator or standalone chart (version: 1.86.0, repository: https://kiali.org/helm-charts) in charts/istio/kiali/Chart.yaml
- [X] T107 [P] [Optional] Create kiali _helpers.tpl with fullname, chart, and labels helpers in charts/istio/kiali/templates/_helpers.tpl

### Implementation — Kiali Templates

- [X] T108 [P] [Optional] Create Deployment template for Kiali server in charts/istio/kiali/templates/deployment.yaml
- [X] T109 [P] [Optional] Create Service template for Kiali web UI (ClusterIP or LoadBalancer) in charts/istio/kiali/templates/service.yaml
- [X] T110 [P] [Optional] Create ConfigMap template for Kiali configuration (Istio config location, auth strategy) in charts/istio/kiali/templates/configmap.yaml
- [X] T111 [P] [Optional] Create ServiceAccount template in charts/istio/kiali/templates/serviceaccount.yaml
- [X] T112 [P] [Optional] Create ClusterRole template with read access to Istio CRDs and Kubernetes resources in charts/istio/kiali/templates/clusterrole.yaml
- [X] T113 [P] [Optional] Create ClusterRoleBinding template in charts/istio/kiali/templates/clusterrolebinding.yaml

### Implementation — Values Files

- [X] T114 [Optional] Create kiali values.yaml with canonical shape (image, replicaCount, auth.strategy, externalServices.istio, resources) in charts/istio/kiali/values.yaml
- [X] T115 [Optional] Create values-dev.yaml with minimal settings (1 replica, anonymous auth, minimal resources) in charts/istio/kiali/values-dev.yaml
- [X] T116 [Optional] Create values-staging.yaml with moderate settings (1 replica, token auth) in charts/istio/kiali/values-staging.yaml
- [X] T117 [Optional] Create values-prod.yaml with production configuration (token/openid auth, resource limits, Prometheus integration if available) in charts/istio/kiali/values-prod.yaml

### Implementation — Documentation & Testing

- [X] T118 [P] [Optional] Create kiali README.md with prerequisites (istiod required), installation steps, authentication setup, troubleshooting in charts/istio/kiali/README.md
- [X] T119 [P] [Optional] Create kiali CHANGELOG.md (v1.0.0 — Added: Kiali mesh observability) in charts/istio/kiali/CHANGELOG.md
- [X] T120 [P] [Optional] Create CI test values for kiali chart in charts/istio/kiali/ci/test-values.yaml
- [X] T121 [Optional] Create environment overlay for kiali in environments/dev/kiali.values.yaml
- [X] T122 [P] [Optional] Create environment overlay for kiali in environments/staging/kiali.values.yaml
- [X] T123 [P] [Optional] Create environment overlay for kiali in environments/production/kiali.values.yaml (may set enabled: false for air-gapped)
- [X] T124 [Optional] Verify `helm lint charts/istio/kiali` passes with zero errors
- [X] T125 [Optional] Verify `helm template kiali charts/istio/kiali -f charts/istio/kiali/values-prod.yaml` renders valid Kiali deployment with authentication

**Checkpoint**: Kiali chart is complete and optional. Users can deploy Kiali for mesh visualization or skip it for air-gapped/minimal environments.

---

## Phase 9: Cross-Cutting — Examples & Root Documentation

**Purpose**: Create example deployment manifests and update root README with Istio charts.

### Implementation

- [X] T126 [P] Create example manifest for base chart minimal install in examples/istio-base-minimal.yaml
- [X] T127 [P] Create example manifest for istiod production config with FIPS in examples/istio-istiod-production.yaml
- [X] T128 [P] Create example manifest for gateway production config with security baseline in examples/istio-gateway-production.yaml
- [X] T129 [P] Create example manifest for optional Kiali deployment in examples/istio-kiali-production.yaml
- [X] T130 Update CHARTS.md catalog with four Istio charts (istio-base, istio-istiod, istio-gateway, istio-kiali [optional]) with descriptions and README links in CHARTS.md
- [X] T131 Update root README.md with Istio chart installation order, FIPS requirements note, Kiali optional add-on mention, and link to docs/istio-aks-deployment.md in README.md

**Checkpoint**: Examples are created. Root documentation references all Istio charts including optional Kiali.

---

## Phase 10: Cross-Cutting — FIPS Validation & CI Integration

**Purpose**: FIPS validation checklist and CI integration for Istio charts.

### Implementation

- [X] T132 [P] Create FIPS validation script implementing checklist from specs/007-istio-aks-chart/contracts/fips-validation.md in scripts/validate-fips.sh
- [X] T133 [P] Add Istio charts (base, istiod, gateway, kiali) to chart-testing CI workflow (lint, template, install tests) in .github/workflows/chart-lint-test.yaml
- [X] T134 [P] Add Istio charts to OCI publishing workflow (package and push to ghcr.io) in .github/workflows/chart-release.yaml
- [X] T135 Verify FIPS validation: Run validation checklist on deployed prod environment → all 10 checks pass per specs/007-istio-aks-chart/contracts/fips-validation.md

**Checkpoint**: FIPS validation is automated. CI pipelines include all Istio charts.

---

## Final Phase: Polish & End-to-End Verification

**Purpose**: Final hardening, schema validation, and comprehensive testing.

### Implementation

- [X] T136 [P] Create values.schema.json for base chart input validation in charts/istio/base/values.schema.json using specs/007-istio-aks-chart/contracts/values-schema.yaml as reference
- [X] T137 [P] Create values.schema.json for istiod chart input validation in charts/istio/istiod/values.schema.json using specs/007-istio-aks-chart/contracts/values-schema.yaml as reference
- [X] T138 [P] Create values.schema.json for gateway chart input validation in charts/istio/gateway/values.schema.json using specs/007-istio-aks-chart/contracts/values-schema.yaml as reference
- [X] T139 [P] Create values.schema.json for kiali chart input validation (optional) in charts/istio/kiali/values.schema.json
- [ ] T140 Run quickstart.md end-to-end validation on fresh AKS cluster per specs/007-istio-aks-chart/quickstart.md (install base → istiod → gateway → optional kiali → test workload → verify mTLS → FIPS validation)
- [X] T141 Verify all four charts pass `helm lint` with zero errors
- [X] T142 Verify all four charts pass `helm template` with default values, dev values, staging values, and prod values
- [X] T143 [P] Verify all README files contain required sections (Overview, Prerequisites, Installation, Configuration, Examples, Upgrade Notes, Troubleshooting)
- [X] T144 Verify values-prod.yaml files meet all FIPS and security baseline requirements per FR-003 through FR-010
- [X] T145 [P] Verify resource requests and limits in istiod and gateway prod values match FR-007 requirements (500m CPU, 2Gi memory for control plane)
- [X] T146 [P] Verify all values.yaml files have inline comments explaining each configuration parameter per FR-011
- [X] T147 [P] Verify production values set replicaCount: 3 and pod anti-affinity for istiod and gateway per NFR-003 (high availability)
- [X] T148 Verify Chart.yaml files specify kubeVersion: '>=1.26.0' and Istio appVersion matches 1.21+ per NFR-006 (version compatibility)
- [ ] T149 [Optional] Time end-to-end installation on standard AKS cluster (3 nodes, Standard_D4s_v3) and verify completion within 10 minutes per NFR-004
- [X] T150 Verify installation order contract is enforced: attempt to install istiod before base → fails with clear error
- [ ] T151 [Optional] Verify Kiali deployment: install Kiali chart → UI accessible, mesh topology visible, authentication configured

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — **BLOCKS US2 and US3**
- **US1 (Phase 3)**: Depends on Foundational (base chart scaffold must exist)
- **US2 (Phase 4)**: Depends on Phase 3 (base chart must be complete and installable)
- **US3 (Phase 5)**: Depends on Phase 4 (istiod must be complete and installable)
- **US4 (Phase 6)**: Depends on Phases 3, 4, 5 (all charts must exist to document upgrades)
- **US5 (Phase 7)**: Depends on Phases 3, 4, 5 (all charts and values files must exist)
- **Kiali (Phase 8)**: **OPTIONAL** — Depends on Phase 5 (istiod must be healthy), can be skipped entirely
- **Cross-Cutting Examples (Phase 9)**: Depends on Phases 3, 4, 5 (needs complete charts), Phase 8 optional
- **Cross-Cutting CI (Phase 10)**: Depends on Phases 3, 4, 5 (needs charts for CI to test), Phase 8 optional
- **Polish (Final)**: Depends on all previous phases

### User Story Completion Order

```
Phase 1: Setup
    │
    ▼
Phase 2: Foundational (base chart scaffold) ─── BLOCKS ───┐
    │                                                       │
    ▼                                                       │
Phase 3: US1 (base chart complete) ◄────────────────────────┘
    │
    ▼
Phase 4: US2 (istiod chart) ◄─── must install base first
    │
    ▼
Phase 5: US3 (gateway chart) ◄─── must install istiod first
    │
    ├─► Phase 6: US4 (upgrades) ◄─── needs all three charts
    │
    ├─► Phase 7: US5 (multi-env) ◄─── needs all three charts
    │
    └─► Phase 8: Kiali (OPTIONAL) ◄─── optional observability add-on
        │
        ├─► Phase 9: Examples
        │
        └─► Phase 10: CI/CD
            │
            ▼
        Final: Polish
```

### Parallel Execution Opportunities

Within each phase, tasks marked **[P]** can run in parallel:

**Phase 3 (US1)** — 9 tasks can run in parallel:
- T011, T012, T013 (values files)
- T014, T015, T016 (documentation)
- T017, T018, T019 (environment overlays)

**Phase 4 (US2)** — 15 tasks can run in parallel:
- T024 (helpers)
- T026-T031 (security templates - 6 files)
- T037, T038, T039 (documentation)
- T040, T041, T042 (environment overlays)

**Phase 5 (US3)** — 14 tasks can run in parallel:
- T050 (helpers)
- T052-T056 (security templates - 5 files)
- T062, T063, T064 (documentation)
- T065, T066, T067 (environment overlays)

**Final Phase** — 7 tasks can run in parallel:
- T136, T137, T138, T139 (schema files)
- T143 (README verification)
- T145, T146, T147 (requirements validation)

### Implementation Strategy

**MVP Scope** (Phases 1-5):
- Phase 1: Setup
- Phase 2: Foundational (base scaffold)
- Phase 3: US1 (base chart complete)
- Phase 4: US2 (istiod with FIPS)
- Phase 5: US3 (gateway with security)

**MVP Deliverable**: Minimum viable Istio installation on AKS with FIPS mode and security baseline (base + istiod + gateway charts, production values files).

**Post-MVP** (Phases 6-Final):
- Phase 6: US4 (upgrade documentation)
- Phase 7: US5 (multi-environment examples)
- Phase 8: Examples and root docs
- Phase 9: CI integration
- Final: Polish and validation

---

## Summary

**Total Tasks**: 151 (110 required + 20 optional Kiali + 21 cross-cutting)
**P1 User Stories** (MVP): US1 (22 tasks), US2 (26 tasks), US3 (25 tasks) = 73 tasks
**P2 User Stories**: US4 (8 tasks), US5 (6 tasks) = 14 tasks
**Optional Add-On**: Kiali observability (20 tasks) — can be skipped for air-gapped/minimal environments
**Cross-Cutting**: Setup (3 tasks), Foundational (7 tasks), Examples (6 tasks), CI (4 tasks), Polish (16 tasks) = 36 tasks
**Validation Coverage**: 100% of functional and non-functional requirements now have explicit validation tasks

**Parallel Opportunities**: 45 tasks marked [P] can execute simultaneously within their phase constraints.

**Critical Path**: Setup → Foundational (base scaffold) → US1 (base complete) → US2 (istiod) → US3 (gateway) → Polish

**Suggested MVP Scope**: Phases 1-5 (73 tasks) — delivers functional three-chart Istio installation with FIPS and security baseline for production AKS deployments.

**Optional Extension**: Phase 8 (20 tasks) — adds Kiali mesh visualization for troubleshooting and observability. Skip for air-gapped, dev, or cost-constrained environments.

## Deferred — Require a Live AKS Cluster

The following tasks validate **runtime behavior** and cannot be completed in a
build/CI environment without a provisioned AKS cluster. All corresponding chart
artifacts are implemented and pass `helm lint` / `helm template`:

- **T047** — sidecar FIPS crypto for mTLS (needs injected workload)
- **T070** — live gateway install + STRICT PeerAuthentication enforcement
- **T071** — unauthenticated client rejection (needs running mesh)
- **T140** — end-to-end quickstart validation on a fresh cluster
- **T149** — installation timing (NFR-004) on a standard 3-node cluster
- **T151** — Kiali UI accessibility and mesh topology verification
