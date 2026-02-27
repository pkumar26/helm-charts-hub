# Tasks: kgateway Controller Chart

**Input**: Design documents from `/specs/004-kgateway-chart/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: Not explicitly requested — test tasks omitted. CI lint/template validation is included as standard chart-testing practice.

**Organization**: Tasks grouped by user story to enable independent implementation and testing of each increment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)
- Exact file paths included in every task description

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Create chart scaffolding, config, and common-lib dependency

- [ ] T001 Create chart directory and Chart.yaml in charts/kgateway-controller/Chart.yaml
- [ ] T002 Create values.yaml with canonical values shape in charts/kgateway-controller/values.yaml
- [ ] T003 [P] Create CHANGELOG.md with initial 0.1.0 entry in charts/kgateway-controller/CHANGELOG.md
- [ ] T004 Create _helpers.tpl with naming, labels, selector, and imageTag helpers in charts/kgateway-controller/templates/_helpers.tpl
- [ ] T005 Add common-lib dependency (helm dependency update) in charts/kgateway-controller/

**Checkpoint**: Chart scaffolding ready — `helm dependency update` succeeds, `helm lint` passes with empty templates.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: RBAC and ServiceAccount that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Create ServiceAccount template delegating to `common-lib.serviceaccount` in charts/kgateway-controller/templates/serviceaccount.yaml
- [ ] T007 Create ClusterRole template with full RBAC rules (Gateway API, kgateway CRDs, core, apps, autoscaling, coordination, discovery, apiextensions, authentication) in charts/kgateway-controller/templates/clusterrole.yaml
- [ ] T008 Create ClusterRoleBinding template in charts/kgateway-controller/templates/clusterrolebinding.yaml

**Checkpoint**: Foundation ready — `helm template` renders ServiceAccount, ClusterRole, ClusterRoleBinding with correct labels. User story implementation can begin.

---

## Phase 3: User Story 1 — Controller Deployment + Service (Priority: P1) 🎯 MVP

**Goal**: Deploy the kgateway controller pod with env-var configuration and expose it via a ClusterIP Service with xDS, health, and metrics ports.

**Independent Test**: `helm template | grep -A50 'kind: Deployment'` shows correct image, ports (9977/9093/9092), env vars, readiness+startup probes, and security context. `helm template | grep -A20 'kind: Service'` shows ClusterIP with three ports.

### Implementation for User Story 1

- [ ] T009 [P] [US1] Create Deployment template with kgateway container, env vars, ports, probes, and security context in charts/kgateway-controller/templates/deployment.yaml
- [ ] T010 [P] [US1] Create Service template with grpc-xds (9977), health (9093), metrics (9092) ports in charts/kgateway-controller/templates/service.yaml
- [ ] T011 [P] [US1] Create NOTES.txt with installation summary and connection instructions in charts/kgateway-controller/templates/NOTES.txt
- [ ] T012 [P] [US1] Create CI minimal test values in charts/kgateway-controller/ci/test-values.yaml
- [ ] T013 [US1] Validate: run `helm lint` and `helm template` with default values — verify Deployment, Service, ServiceAccount, ClusterRole, ClusterRoleBinding render correctly

**Checkpoint**: MVP complete — kgateway controller deploys with correct configuration, service exposes xDS/health/metrics, RBAC is applied.

---

## Phase 4: User Story 2 — GatewayClass Resource (Priority: P2)

**Goal**: Optionally create a GatewayClass resource that registers kgateway with controller name `kgateway.dev/kgateway`, gated behind `gatewayApi.createGatewayClass`.

**Independent Test**: `helm template --set gatewayApi.createGatewayClass=true` renders GatewayClass with correct controllerName. Default render produces no GatewayClass.

### Implementation for User Story 2

- [ ] T014 [US2] Create GatewayClass template gated by gatewayApi.createGatewayClass in charts/kgateway-controller/templates/gateway-class.yaml
- [ ] T015 [US2] Validate: run `helm template --set gatewayApi.createGatewayClass=true` — verify GatewayClass renders with controllerName: kgateway.dev/kgateway and correct labels

**Checkpoint**: GatewayClass gating works — present when enabled, absent by default.

---

## Phase 5: User Story 3 — HorizontalPodAutoscaler (Priority: P3)

**Goal**: Optionally create an HPA using common-lib helper, gated behind `autoscaling.enabled`.

**Independent Test**: `helm template --set autoscaling.enabled=true` renders HPA targeting the Deployment. Default render produces no HPA.

### Implementation for User Story 3

- [ ] T016 [US3] Create HPA template using common-lib.hpa helper in charts/kgateway-controller/templates/hpa.yaml
- [ ] T017 [US3] Validate: run `helm template --set autoscaling.enabled=true` — verify HPA renders with correct target and default thresholds

**Checkpoint**: HPA gating works — present when enabled, absent by default.

---

## Phase 6: User Story 4 — PDB + VPA Extended Resources (Priority: P4)

**Goal**: Add PodDisruptionBudget and VerticalPodAutoscaler as chart-specific gated templates for production resilience and resource right-sizing.

**Independent Test**: `helm template --set podDisruptionBudget.enabled=true --set verticalPodAutoscaler.enabled=true` renders both PDB and VPA. Default render produces neither.

### Implementation for User Story 4

- [ ] T018 [P] [US4] Create PDB template gated by podDisruptionBudget.enabled in charts/kgateway-controller/templates/pdb.yaml
- [ ] T019 [P] [US4] Create VPA template gated by verticalPodAutoscaler.enabled in charts/kgateway-controller/templates/vpa.yaml
- [ ] T020 [US4] Validate: run `helm template` with PDB and VPA enabled — verify both render with correct selectors and target refs

**Checkpoint**: Extended resources gating works — PDB and VPA each independently toggleable.

---

## Phase 7: User Story 5 — Documentation, CI & Environment Overlays (Priority: P5)

**Goal**: Provide complete documentation, CI test values for all features, environment overlays for dev/staging/production, and a production example.

**Independent Test**: `helm lint -f ci/test-full-values.yaml` passes. README contains all required sections per constitution §9. All three environment overlay files parse without error.

### Implementation for User Story 5

- [ ] T021 [P] [US5] Create comprehensive CI test values in charts/kgateway-controller/ci/test-full-values.yaml
- [ ] T022 [P] [US5] Create dev environment overlay in environments/dev/kgateway-controller.values.yaml
- [ ] T023 [P] [US5] Create staging environment overlay in environments/staging/kgateway-controller.values.yaml
- [ ] T024 [P] [US5] Create production environment overlay in environments/production/kgateway-controller.values.yaml
- [ ] T025 [P] [US5] Create production example in examples/kgateway-controller-production.yaml
- [ ] T026 [US5] Create README.md with all 7 required sections per constitution §9.2 (Overview, Prerequisites, Installation, Configuration, Examples, Upgrade Notes, Troubleshooting) in charts/kgateway-controller/README.md
- [ ] T027 [US5] Validate: run `helm lint` with default, test-values.yaml, and test-full-values.yaml — all must pass with zero errors

**Checkpoint**: Full documentation and CI artifacts complete. Chart is ready for review.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, CHARTS.md update, and quickstart walkthrough

- [ ] T028 [P] Update CHARTS.md to add kgateway-controller entry at repo root CHARTS.md
- [ ] T029 [P] Create values.schema.json with JSON Schema validation for required and typed values in charts/kgateway-controller/values.schema.json
- [ ] T030 Run full chart-testing lint: `ct lint --config ct.yaml --charts charts/kgateway-controller`
- [ ] T031 Run quickstart.md validation: verify `helm template` renders all resources for both minimal and production configurations

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup (Phase 1) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational (Phase 2) — MVP
- **US2 (Phase 4)**: Depends on Foundational (Phase 2) — can run in parallel with US1
- **US3 (Phase 5)**: Depends on US1 (needs Deployment target for HPA)
- **US4 (Phase 6)**: Depends on US1 (needs Deployment target for PDB/VPA) — can run in parallel with US3
- **US5 (Phase 7)**: Depends on US1–US4 (documentation covers all features)
- **Polish (Phase 8)**: Depends on US5

### User Story Dependencies

- **US1 (P1 — Controller Deployment+Service)**: Can start after Foundational. No dependency on other stories. **This is the MVP.**
- **US2 (P2 — GatewayClass)**: Can start after Foundational. Independent of US1. Only adds a non-namespaced resource.
- **US3 (P3 — HPA)**: Depends on US1 — HPA targets the Deployment created in US1.
- **US4 (P4 — PDB+VPA)**: Depends on US1 — PDB selector and VPA targetRef point to the Deployment from US1.
- **US5 (P5 — Docs & CI)**: Depends on US1–US4 — test-full-values.yaml exercises all features.

### Within Each User Story

- Templates before validation
- Core templates before optional templates
- CI values before lint validation

### Parallel Opportunities

**Phase 1 (Setup)**: T003 can run in parallel with T001/T002
**Phase 2 (Foundational)**: T006, T007, T008 are different files — but T008 references T007, so T006 ∥ T007, then T008
**Phase 3 (US1)**: T009 and T010 are independent files — can run in parallel
**Phase 4 (US2)**: Single template — no parallelism
**Phase 5 (US3)**: Single template — no parallelism
**Phase 6 (US4)**: T018 and T019 are independent files — can run in parallel
**Phase 7 (US5)**: T021–T025 are all independent files — can run in parallel

---

## Parallel Example: User Story 1

```text
# These can run in parallel (different files):
Task T009: "Create Deployment template in charts/kgateway-controller/templates/deployment.yaml"
Task T010: "Create Service template in charts/kgateway-controller/templates/service.yaml"
Task T011: "Create NOTES.txt in charts/kgateway-controller/templates/NOTES.txt"
Task T012: "Create CI test values in charts/kgateway-controller/ci/test-values.yaml"

# Then sequentially:
Task T013: "Validate helm lint + helm template" (depends on all above)
```

## Parallel Example: User Story 4

```text
# These can run in parallel (different files):
Task T018: "Create PDB template in charts/kgateway-controller/templates/pdb.yaml"
Task T019: "Create VPA template in charts/kgateway-controller/templates/vpa.yaml"

# Then sequentially:
Task T020: "Validate helm template with PDB+VPA enabled" (depends on both above)
```

## Parallel Example: User Story 5

```text
# All environment overlays + examples can run in parallel:
Task T021: "CI test-full-values.yaml"
Task T022: "dev overlay"
Task T023: "staging overlay"
Task T024: "production overlay"
Task T025: "production example"

# Then sequentially:
Task T026: "README.md" (may reference all features)
Task T027: "Validate all lint passes"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T005)
2. Complete Phase 2: Foundational — RBAC + ServiceAccount (T006–T008)
3. Complete Phase 3: User Story 1 — Deployment + Service (T009–T013)
4. **STOP and VALIDATE**: `helm lint` + `helm template` pass; Deployment has correct image, env vars, probes, security context; Service exposes 9977/9093/9092
5. MVP is deployable

### Incremental Delivery

1. Setup + Foundational → Scaffolding ready
2. US1 (Deployment + Service) → MVP deployable ✅
3. US2 (GatewayClass) → Gateway API integration complete ✅
4. US3 (HPA) → Autoscaling ready ✅
5. US4 (PDB + VPA) → Production resilience ✅
6. US5 (Docs + CI) → Chart fully documented ✅
7. Polish → Repository integration complete ✅

Each story adds value without breaking previous stories.

### Suggested MVP Scope

**User Story 1 (Phase 3)** — Controller Deployment + Service with RBAC. This alone gives a fully functional kgateway installation that can watch Gateway API resources and provision Envoy proxies.
