# Tasks: README Chart Catalog Update

**Feature**: 005-readme-chart-catalog-update  
**Generated**: 2026-03-01  
**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Research**: [research.md](research.md)

**Total Tasks**: 8  
**User Stories**: 3 (P1: 2 tasks, P2: 3 tasks, P3: 1 task)  
**Parallel Opportunities**: 0 (single-file edit — all tasks are sequential)  
**Tests**: Not requested — verification via quickstart.md validation commands

---

## Phase 1: Setup

**Purpose**: No project setup needed — this is a documentation-only change to an existing file (README.md).

*Phase skipped — no scaffolding, dependencies, or configuration required.*

---

## Phase 2: Foundational

**Purpose**: Validate the authoritative source and current README state before making changes.

- [X] T001 Verify CHARTS.md lists all 6 charts and extract descriptions for use in README.md updates (CHARTS.md)

---

## Phase 3: User Story 1 — Complete Chart Catalog in README (Priority: P1 — MVP)

**Goal**: The Chart Catalog table in README.md lists all 6 charts, matching CHARTS.md.

**Independent Test**: Count table rows with `grep -c '^\| \[' README.md` — expect 6. Verify envoy-controller and kgateway-controller rows are present with accurate descriptions and types.

### Implementation for User Story 1

- [X] T002 [US1] Add envoy-controller row to the Chart Catalog table in README.md (line ~92)
- [X] T003 [US1] Add kgateway-controller row to the Chart Catalog table in README.md (line ~93)

**Checkpoint**: Chart Catalog table now lists all 6 charts. Verify with `grep -c '^\| \[' README.md` (expect 6) and cross-check against CHARTS.md.

---

## Phase 4: User Story 2 — Accurate Project Overview (Priority: P2)

**Goal**: The Project Overview section accurately reflects all controller charts, including Gateway API-native controllers.

**Independent Test**: Read the Project Overview, architecture text block, and "Ingress and Gateway API" subsection — verify envoy-controller and kgateway-controller are mentioned alongside traefik-controller and nginx-controller.

### Implementation for User Story 2

- [X] T004 [US2] Update the Application tier description text to mention envoy-controller and kgateway-controller in README.md (line ~12)
- [X] T005 [US2] Add envoy-controller and kgateway-controller to the architecture text block in README.md (lines ~15-19)
- [X] T006 [US2] Update the "Ingress and Gateway API" subsection to describe Gateway API-native controllers (envoy-controller, kgateway-controller) and dual-mode support (Traefik) in README.md (lines ~25-31)

**Checkpoint**: Project Overview now describes all 4 controller charts. Architecture text block shows 5 child charts under common-lib. "Ingress and Gateway API" subsection accurately lists Ingress, Gateway API-native, and dual-mode controllers.

---

## Phase 5: User Story 3 — Consistent Prerequisites Note (Priority: P3)

**Goal**: The Prerequisites note references all Gateway API-capable controllers, not just Traefik.

**Independent Test**: Read the Prerequisites note (line ~43) and verify it mentions Traefik, Envoy Gateway, and kgateway as Gateway API-capable controllers.

### Implementation for User Story 3

- [X] T007 [US3] Update the Prerequisites note to mention all Gateway API-capable controllers (Traefik, Envoy Gateway, kgateway) in README.md (line ~43)

**Checkpoint**: Prerequisites note now references all 3 Gateway API-capable controllers.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across all user stories.

- [X] T008 Run quickstart.md verification commands to validate all README.md sections are consistent with CHARTS.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Skipped — no setup needed
- **Foundational (Phase 2)**: No dependencies — verifies source data
- **User Stories (Phase 3-5)**: All depend on T001 (Foundational) for verified chart descriptions
  - User stories edit different sections of README.md — can proceed sequentially (single file)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after T001 — Chart Catalog table (lines ~86-92)
- **User Story 2 (P2)**: Can start after T001 — Project Overview section (lines ~8-31)
- **User Story 3 (P3)**: Can start after T001 — Prerequisites note (line ~43)

### Within Each User Story

- All tasks within a story edit the same file (README.md) but different sections — sequential within story
- No test tasks (tests not requested)

### Parallel Opportunities

- US1, US2, and US3 edit distinct non-overlapping sections of README.md — conceptually independent
- Since all changes are in a single file, parallelism is limited to planning; execution is sequential
- T002 and T003 (both US1) must be sequential (adjacent table rows)

---

## Parallel Example: User Story 2

```bash
# These tasks edit different sections but same file — plan in parallel, execute sequentially:
Task T004: "Update Application tier description text (line ~12)"
Task T005: "Add charts to architecture text block (lines ~15-19)"  
Task T006: "Update Ingress and Gateway API subsection (lines ~25-31)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (verify CHARTS.md) 
2. Complete Phase 3: User Story 1 (add 2 rows to Chart Catalog table)
3. **STOP and VALIDATE**: `grep -c '^\| \[' README.md` → expect 6
4. This alone fixes the primary gap — users can now discover all charts

### Incremental Delivery

1. T001 → Verify source data (CHARTS.md)
2. T002-T003 → Chart Catalog table complete → **MVP!**
3. T004-T006 → Project Overview accurate → Full picture
4. T007 → Prerequisites consistent → All stories done
5. T008 → Final validation → Ready to merge

---

## Notes

- All changes are in a single file: README.md
- CHARTS.md is the authoritative reference — all descriptions must match
- No code, template, or values changes — documentation only
- Quickstart.md contains verification commands for final validation
- Commit after each user story phase for clean history
