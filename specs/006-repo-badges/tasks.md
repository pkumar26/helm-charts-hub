# Tasks: Repository Badges

**Input**: Design documents from `/specs/006-repo-badges/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/badge-url-schema.md, quickstart.md

**Tests**: Not requested in the feature specification. No test tasks included.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: No project initialization needed — this is a documentation-only feature modifying existing files. Phase 1 is empty.

*(No tasks — proceed to Phase 2)*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Verify badge URLs resolve correctly before modifying any files

**⚠️ CRITICAL**: Validate badge image URLs load valid SVGs before embedding them in READMEs

- [X] T001 Verify all four badge image URLs return HTTP 200 and valid SVG by running `curl -sI` against each shields.io URL documented in contracts/badge-url-schema.md (License, CI Status, Last Commit, Contributors for pkumar26/helm-charts-hub)
- [X] T002 Verify all four badge link URLs resolve to valid GitHub pages (LICENSE file, Actions workflows page, commits page, contributors page) for pkumar26/helm-charts-hub

**Checkpoint**: All badge URLs verified — README modifications can begin

---

## Phase 3: User Story 1 — Add Badges to helm-charts-hub README (Priority: P1) 🎯 MVP

**Goal**: Display four shields.io badges (License, CI Status, Last Commit, Contributors) at the top of the root README

**Independent Test**: Open https://github.com/pkumar26/helm-charts-hub after push and confirm four badges render below the title, each linking to the correct page

### Implementation for User Story 1

- [X] T003 [US1] Add badge row to root README.md — insert the four-badge markdown line immediately after the `# Helm Charts Hub` H1 title (before the blank line and "A Helm chart monorepo..." paragraph). Use exact badge markdown from contracts/badge-url-schema.md sections 1–4 (License static, CI dynamic for chart-lint-test.yaml, Last Commit dynamic, Contributors dynamic) in file README.md
- [X] T004 [US1] Verify rendered markdown locally — run `cat README.md | head -5` to confirm badge line is on line 3 (after title and blank line), and all four `[![` badge patterns are present in README.md

**Checkpoint**: User Story 1 complete — helm-charts-hub README displays 4 badges. This is the MVP.

---

## Phase 4: User Story 2 — Create Reusable Badge Template (Priority: P2)

**Goal**: Create a documented, copy-paste-ready badge template with OWNER/REPO/WORKFLOW placeholders so badges can be applied to any repo

**Independent Test**: Copy the template, substitute `pkumar26` and `comparison-aks-aca-appservice`, and verify the resulting markdown produces valid badge URLs

### Implementation for User Story 2

- [X] T005 [US2] Create reusable badge template file at docs/templates/badge-template.md with:
  1. A title and purpose section explaining what the template does
  2. A placeholder reference table (OWNER, REPO, WORKFLOW, WORKFLOW_NAME, BRANCH, CHART, AH_REPO_NAME) matching contracts/badge-url-schema.md Placeholder Reference
  3. The standard four-badge markdown row using `{OWNER}`, `{REPO}`, `{WORKFLOW}`, `{WORKFLOW_NAME}`, `{BRANCH}` placeholders (matching contracts/badge-url-schema.md patterns)
  4. Step-by-step instructions: (a) copy badge row, (b) find-and-replace placeholders, (c) paste after H1 title in target README
  5. A working example showing substitution for `pkumar26/comparison-aks-aca-appservice` with `generate-diagrams.yml` workflow
  6. An optional badges section listing Stars, Open Issues, Forks badge patterns with placeholders
  7. A private repo section explaining shields.io limitations and providing static-only fallback badges
  8. A Helm-specific badges section (Helm 3, Chart Version dynamic YAML, Kubernetes version, Artifact Hub) with placeholders, marked as optional/chart-specific
  9. A troubleshooting table covering: "not found", "no status", broken image, wrong license type (matching quickstart.md §4)

- [X] T006 [US2] Validate template by performing a dry-run substitution — mentally or via sed replace OWNER→pkumar26, REPO→comparison-aks-aca-appservice, WORKFLOW→generate-diagrams.yml, BRANCH→main in docs/templates/badge-template.md and confirm URLs match the example in quickstart.md §3

**Checkpoint**: User Story 2 complete — template exists and produces valid badge markdown for any public repo

---

## Phase 5: User Story 3 — Add Chart-Specific Badges to Sub-Chart READMEs (Priority: P3)

**Goal**: Add Helm 3 and dynamic chart version badges to each chart's README for quick compatibility identification

**Independent Test**: Open any chart README (e.g., charts/web-app/README.md) on GitHub and confirm a Helm 3 badge and a chart version badge render correctly

### Implementation for User Story 3

- [X] T007 [P] [US3] Add Helm 3 badge and dynamic chart version badge to charts/web-app/README.md — insert badge row after the H1 title using patterns from contracts/badge-url-schema.md sections 5–6 with CHART=web-app
- [X] T008 [P] [US3] Add Helm 3 badge and static chart version badge to charts/common-lib/README.md — insert badge row after the H1 title using patterns from contracts/badge-url-schema.md section 5 (Helm 3 static) and section 6b (static chart version fallback). common-lib is a library chart; read version from Chart.yaml and use the static badge pattern instead of dynamic YAML
- [X] T009 [P] [US3] Add Helm 3 badge and dynamic chart version badge to charts/envoy-controller/README.md — insert badge row after the H1 title using patterns from contracts/badge-url-schema.md sections 5–6 with CHART=envoy-controller
- [X] T010 [P] [US3] Add Helm 3 badge and dynamic chart version badge to charts/nginx-controller/README.md — insert badge row after the H1 title using patterns from contracts/badge-url-schema.md sections 5–6 with CHART=nginx-controller
- [X] T011 [P] [US3] Add Helm 3 badge and dynamic chart version badge to charts/traefik-controller/README.md — insert badge row after the H1 title using patterns from contracts/badge-url-schema.md sections 5–6 with CHART=traefik-controller
- [X] T012 [P] [US3] Add Helm 3 badge and dynamic chart version badge to charts/kgateway-controller/README.md — insert badge row after the H1 title using patterns from contracts/badge-url-schema.md sections 5–6 with CHART=kgateway-controller

**Checkpoint**: All 6 chart READMEs display Helm 3 and chart version badges

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation updates

- [X] T013 Run quickstart.md validation — follow quickstart.md §1 steps to confirm the root README badge row matches the documented format
- [X] T014 [P] Update CONTRIBUTING.md to mention the badge template location (docs/templates/badge-template.md) in the documentation or contribution guidelines section
- [X] T015 Commit all changes with message "feat: add shields.io badges to READMEs and create reusable badge template"

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Empty — no setup needed
- **Foundational (Phase 2)**: No dependencies — can start immediately
- **User Story 1 (Phase 3)**: Depends on Phase 2 (badge URL validation)
- **User Story 2 (Phase 4)**: Depends on Phase 2 (badge URL validation). Independent of US1.
- **User Story 3 (Phase 5)**: Depends on Phase 2 (badge URL validation). Independent of US1 and US2.
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Phase 2. No dependencies on other stories.
- **User Story 2 (P2)**: Can start after Phase 2. No dependencies on other stories. Can run in parallel with US1.
- **User Story 3 (P3)**: Can start after Phase 2. No dependencies on other stories. Can run in parallel with US1 and US2. All 6 chart tasks (T007–T012) are parallel — different files with no cross-dependencies.

### Within Each User Story

- US1: T003 (edit README) → T004 (verify)
- US2: T005 (create template) → T006 (validate)
- US3: T007–T012 are all parallel (different chart READMEs)

### Parallel Opportunities

- T001 and T002 (Phase 2) can run in parallel
- US1 and US2 can run in parallel after Phase 2
- T007, T008, T009, T010, T011, T012 (US3) can all run in parallel

---

## Parallel Example: User Story 3

```bash
# All chart README edits can run in parallel (different files):
Task T007: "Add badges to charts/web-app/README.md"
Task T008: "Add badges to charts/common-lib/README.md"
Task T009: "Add badges to charts/envoy-controller/README.md"
Task T010: "Add badges to charts/nginx-controller/README.md"
Task T011: "Add badges to charts/traefik-controller/README.md"
Task T012: "Add badges to charts/kgateway-controller/README.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (validate badge URLs)
2. Complete Phase 3: User Story 1 (add badges to root README)
3. **STOP and VALIDATE**: Push to GitHub, confirm 4 badges render
4. Deploy/demo if ready — this is the MVP

### Incremental Delivery

1. Complete Phase 2 → Badge URLs verified
2. Add User Story 1 → Root README has 4 badges (MVP!)
3. Add User Story 2 → Reusable template ready for all repos
4. Add User Story 3 → All 6 chart READMEs have Helm badges
5. Phase 6 → Polish, final validation, commit

### Parallel Strategy

With multiple developers:

1. Both complete Phase 2 together (quick validation)
2. Once Phase 2 done:
   - Developer A: User Story 1 (root README) + User Story 3 (chart READMEs)
   - Developer B: User Story 2 (badge template)
3. Converge at Phase 6 for polish

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- This entire feature is documentation-only — no Helm template, chart version, or code changes
- All badge URLs use shields.io flat style (default) per research.md §5
- Badge order is always: License → CI → Last Commit → Contributors per research.md §4
- Commit after each user story checkpoint for incremental delivery
