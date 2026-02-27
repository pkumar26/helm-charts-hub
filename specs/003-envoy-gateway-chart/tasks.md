# Tasks: Envoy Gateway Controller Chart

**Input**: Design documents from `/specs/003-envoy-gateway-chart/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/chart-resources.md, quickstart.md

**Tests**: Not requested — no test tasks included.

**Organization**: Tasks are grouped by functional area (mapped from spec.md functional requirements) to enable independent implementation and validation of each area.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Chart Scaffolding)

**Purpose**: Create chart directory structure and initialize Helm chart metadata

- [ ] T001 Create chart directory structure at charts/envoy-gateway/templates/ and charts/envoy-gateway/ci/
- [ ] T002 Create Chart.yaml with common-lib dependency in charts/envoy-gateway/Chart.yaml
- [ ] T003 Run `helm dependency build` for charts/envoy-gateway to fetch common-lib

---

## Phase 2: Foundational (Values & Helpers)

**Purpose**: Core configuration and naming helpers that ALL templates depend on

**⚠️ CRITICAL**: No template work can begin until this phase is complete

- [ ] T004 Create values.yaml with full schema and sensible defaults in charts/envoy-gateway/values.yaml
- [ ] T005 Create local chart helpers (_helpers.tpl) with name/fullname overrides in charts/envoy-gateway/templates/_helpers.tpl

**Checkpoint**: Chart scaffolding ready — template implementation can now begin

---

## Phase 3: User Story 1 — Controller Deployment & Service (Priority: P1) 🎯 MVP

**Goal**: Deploy the Envoy Gateway controller as a Kubernetes Deployment with a ClusterIP Service exposing the xDS gRPC port. This is the core deliverable — without the controller running, nothing else matters.

**Independent Test**: `helm template` renders a valid Deployment with correct container args, ports, health probes, volume mounts, and env vars; renders a Service with grpc port 18000.

### Implementation for User Story 1

- [ ] T006 [P] [US1] Create ConfigMap template with EnvoyGateway configuration in charts/envoy-gateway/templates/configmap.yaml
- [ ] T007 [P] [US1] Create ServiceAccount template using common-lib helper in charts/envoy-gateway/templates/serviceaccount.yaml
- [ ] T008 [US1] Create Deployment template with multi-port, xDS args, health probes, ConfigMap volume mount in charts/envoy-gateway/templates/deployment.yaml
- [ ] T009 [US1] Create Service template with ClusterIP, gRPC port 18000, conditional metrics port in charts/envoy-gateway/templates/service.yaml

**Checkpoint**: Controller Deployment + Service render correctly via `helm template`. Core MVP is functional.

---

## Phase 4: User Story 2 — RBAC (Priority: P2)

**Goal**: Provide least-privilege RBAC so the controller can watch Gateway API resources and manage the Envoy Proxy data plane.

**Independent Test**: `helm template` renders ClusterRole with correct rules and ClusterRoleBinding linking to ServiceAccount. Resources gated behind `rbac.create`.

### Implementation for User Story 2

- [ ] T010 [P] [US2] Create ClusterRole template with Gateway API, core, apps, autoscaling, and coordination permissions in charts/envoy-gateway/templates/clusterrole.yaml
- [ ] T011 [P] [US2] Create ClusterRoleBinding template binding ClusterRole to ServiceAccount in charts/envoy-gateway/templates/clusterrolebinding.yaml

**Checkpoint**: RBAC resources render and are properly gated behind `rbac.create`.

---

## Phase 5: User Story 3 — Gateway API Resources (Priority: P3)

**Goal**: Register Envoy Gateway as a Gateway API implementation via GatewayClass, and optionally create a default Gateway with configurable listeners.

**Independent Test**: `helm template` renders GatewayClass with correct controllerName when `gatewayClass.create: true`. Gateway only rendered when `gateway.enabled: true`. Gateway references the correct GatewayClass name.

### Implementation for User Story 3

- [ ] T012 [P] [US3] Create GatewayClass template gated on gatewayClass.create in charts/envoy-gateway/templates/gateway-class.yaml
- [ ] T013 [P] [US3] Create Gateway template with configurable listeners gated on gateway.enabled in charts/envoy-gateway/templates/gateway.yaml

**Checkpoint**: Gateway API resources render correctly with proper feature flags.

---

## Phase 6: User Story 4 — Documentation & CI (Priority: P4)

**Goal**: Provide complete documentation, CI test values, environment overlays, and post-install notes so the chart meets all constitution requirements and is ready for use.

**Independent Test**: README includes all §9.2 sections. CI values pass `helm lint`. Environment overlays exist for dev/staging/production. NOTES.txt renders with correct Gateway info.

### Implementation for User Story 4

- [ ] T014 [P] [US4] Create NOTES.txt with post-install instructions in charts/envoy-gateway/templates/NOTES.txt
- [ ] T015 [P] [US4] Create CI test-values.yaml (basic mode, no Gateway) in charts/envoy-gateway/ci/test-values.yaml
- [ ] T016 [P] [US4] Create CI test-gateway-values.yaml (Gateway enabled) in charts/envoy-gateway/ci/test-gateway-values.yaml
- [ ] T017 [P] [US4] Create README.md with all required sections per constitution §9.2 in charts/envoy-gateway/README.md
- [ ] T018 [P] [US4] Create dev environment overlay in environments/dev/envoy-gateway.values.yaml
- [ ] T019 [P] [US4] Create staging environment overlay in environments/staging/envoy-gateway.values.yaml
- [ ] T020 [P] [US4] Create production environment overlay in environments/production/envoy-gateway.values.yaml
- [ ] T021 [P] [US4] Create production example values in examples/envoy-gateway-production.yaml

**Checkpoint**: All documentation, CI values, and environment overlays are complete.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Validation, integration with the broader repository, and final quality checks

- [ ] T022 Update root CHARTS.md with envoy-gateway chart entry
- [ ] T023 Run `helm dependency build` for charts/envoy-gateway
- [ ] T024 Run `helm lint charts/envoy-gateway` — zero errors
- [ ] T025 Run `helm lint charts/envoy-gateway -f charts/envoy-gateway/ci/test-values.yaml` — zero errors
- [ ] T026 Run `helm lint charts/envoy-gateway -f charts/envoy-gateway/ci/test-gateway-values.yaml` — zero errors
- [ ] T027 Run `helm template charts/envoy-gateway` — validate all resources render
- [ ] T028 Run `helm template charts/envoy-gateway -f charts/envoy-gateway/ci/test-gateway-values.yaml` — validate Gateway resources render
- [ ] T029 Validate all resources carry 6 base labels + 2 base annotations from common-lib
- [ ] T030 Run quickstart.md validation — verify documented commands work

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (Chart.yaml + dependency build) — BLOCKS all templates
- **US1: Deployment & Service (Phase 3)**: Depends on Phase 2 (values.yaml + helpers)
- **US2: RBAC (Phase 4)**: Depends on Phase 2 — can run in PARALLEL with Phase 3
- **US3: Gateway API (Phase 5)**: Depends on Phase 2 — can run in PARALLEL with Phases 3 and 4
- **US4: Docs & CI (Phase 6)**: Depends on Phase 2 (needs values.yaml for CI values) — can run in PARALLEL with Phases 3-5
- **Polish (Phase 7)**: Depends on ALL previous phases being complete

### User Story Dependencies

- **US1 (Controller Deployment & Service)**: Can start after Phase 2 — no dependencies on other stories
- **US2 (RBAC)**: Can start after Phase 2 — independent of US1
- **US3 (Gateway API)**: Can start after Phase 2 — independent of US1 and US2
- **US4 (Docs & CI)**: Can start after Phase 2 — independent of US1-US3 (templates not needed for docs)

### Within Each User Story

- ConfigMap and ServiceAccount before Deployment (US1: T006, T007 before T008)
- Deployment before Service (US1: T008 before T009)
- ClusterRole and ClusterRoleBinding are independent (US2: T010, T011 parallel)
- GatewayClass and Gateway are independent (US3: T012, T013 parallel)
- All US4 tasks are independent (different files, no dependencies)

### Parallel Opportunities

```text
Phase 2 complete
    ├── US1: T006 + T007 (parallel) → T008 → T009
    ├── US2: T010 + T011 (parallel)
    ├── US3: T012 + T013 (parallel)
    └── US4: T014 + T015 + T016 + T017 + T018 + T019 + T020 + T021 (all parallel)
```

---

## Parallel Example: After Phase 2 Completes

```bash
# Launch all user stories in parallel:

# US1 — ConfigMap + ServiceAccount first (parallel):
Task: "Create ConfigMap template in charts/envoy-gateway/templates/configmap.yaml"
Task: "Create ServiceAccount template in charts/envoy-gateway/templates/serviceaccount.yaml"

# US2 — Both RBAC templates (parallel):
Task: "Create ClusterRole template in charts/envoy-gateway/templates/clusterrole.yaml"
Task: "Create ClusterRoleBinding template in charts/envoy-gateway/templates/clusterrolebinding.yaml"

# US3 — Both Gateway API templates (parallel):
Task: "Create GatewayClass template in charts/envoy-gateway/templates/gateway-class.yaml"
Task: "Create Gateway template in charts/envoy-gateway/templates/gateway.yaml"

# US4 — All documentation (parallel):
Task: "Create NOTES.txt in charts/envoy-gateway/templates/NOTES.txt"
Task: "Create CI test-values.yaml in charts/envoy-gateway/ci/test-values.yaml"
Task: "Create CI test-gateway-values.yaml in charts/envoy-gateway/ci/test-gateway-values.yaml"
Task: "Create README.md in charts/envoy-gateway/README.md"
Task: "Create dev overlay in environments/dev/envoy-gateway.values.yaml"
Task: "Create staging overlay in environments/staging/envoy-gateway.values.yaml"
Task: "Create production overlay in environments/production/envoy-gateway.values.yaml"
Task: "Create production example in examples/envoy-gateway-production.yaml"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T003)
2. Complete Phase 2: Foundational (T004–T005)
3. Complete Phase 3: User Story 1 — Controller Deployment & Service (T006–T009)
4. **STOP and VALIDATE**: `helm template` renders Deployment + Service correctly
5. This is a deployable MVP — the controller can run

### Incremental Delivery

1. Complete Setup + Foundational → Chart scaffolding ready
2. Add US1 (Deployment + Service) → Test with `helm template` → MVP!
3. Add US2 (RBAC) → Test RBAC renders → Controller can operate with proper permissions
4. Add US3 (Gateway API) → Test GatewayClass/Gateway → Full functionality
5. Add US4 (Docs & CI) → Full documentation → Ready for review
6. Polish → Lint, validate, integrate → Ready for merge

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Phase 2 is done:
   - Developer A: US1 (Deployment, Service, ConfigMap, ServiceAccount)
   - Developer B: US2 (RBAC) + US3 (Gateway API)
   - Developer C: US4 (Docs, CI, Environment overlays)
3. All stories complete independently and integrate without conflicts

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story operates on entirely different template files — zero conflict risk
- Commit after each task or logical group
- Stop at any checkpoint to validate independently
- No IngressClass resource — Envoy Gateway is Gateway API-native (unlike traefik/nginx controllers)
- Chart only deploys control plane — data plane (Envoy Proxy) is auto-managed by the controller
