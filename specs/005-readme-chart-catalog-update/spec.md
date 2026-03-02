# Feature Specification: README Chart Catalog Update

**Feature Branch**: `005-readme-chart-catalog-update`  
**Created**: 2026-03-01  
**Status**: Draft  
**Input**: User description: "I noticed that there is no reference for kgateway and envoy on readme under chart catalog section"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Complete Chart Catalog in README (Priority: P1)

A new user visits the repository and reads the root README.md to discover available charts. They expect the Chart Catalog table to list **all** charts in the repository, including envoy-controller and kgateway-controller, so they can evaluate and install the right chart for their needs.

**Why this priority**: The README is the first document most users see. Missing chart entries means users may never discover kgateway-controller or envoy-controller, making those charts effectively invisible.

**Independent Test**: Open README.md and verify the Chart Catalog table lists all 6 charts matching CHARTS.md.

**Acceptance Scenarios**:

1. **Given** the README.md Chart Catalog table, **When** a user reads it, **Then** they see entries for all 6 charts: common-lib, web-app, traefik-controller, nginx-controller, envoy-controller, and kgateway-controller.
2. **Given** the README.md Chart Catalog, **When** compared to CHARTS.md, **Then** every chart in CHARTS.md has a corresponding entry in the README table.

---

### User Story 2 - Accurate Project Overview (Priority: P2)

A user reads the Project Overview section and the architecture text block in the README.md. They expect the overview to accurately reflect the full set of charts, including Gateway API-native controllers (envoy-controller, kgateway-controller), not just Traefik and NGINX.

**Why this priority**: The overview text and architecture text block shape the user's first understanding of the project's scope. Omitting two controllers gives an incomplete picture.

**Independent Test**: Read the Project Overview section and verify it mentions all controller charts and accurately describes Gateway API support.

**Acceptance Scenarios**:

1. **Given** the Project Overview section, **When** a user reads it, **Then** they see envoy-controller and kgateway-controller listed alongside traefik-controller and nginx-controller.
2. **Given** the architecture text block, **When** a user reads it, **Then** it includes envoy-controller and kgateway-controller in the chart tree.
3. **Given** the "Ingress and Gateway API" subsection, **When** a user reads it, **Then** it accurately describes that Gateway API is supported by envoy-controller and kgateway-controller (Gateway API-native) and optionally by Traefik.

---

### User Story 3 - Consistent Prerequisites Note (Priority: P3)

A user reads the Prerequisites section and the note about Gateway API CRDs. They expect it to reference all controllers that support Gateway API, not just Traefik.

**Why this priority**: If the prerequisites note only mentions Traefik for Gateway API, users trying envoy-controller or kgateway-controller may miss the CRD installation step.

**Independent Test**: Read the Prerequisites note and verify it mentions all Gateway API-capable controllers.

**Acceptance Scenarios**:

1. **Given** the Prerequisites note, **When** a user reads it, **Then** it mentions Traefik, Envoy Gateway, and kgateway as controllers that support Gateway API.

---

### Edge Cases

- What happens if a new chart is added in the future? The same pattern should be followed — update both CHARTS.md and README.md.
- What if CHARTS.md and README.md diverge again? A CI check or review checklist item should catch this. *(Future work — not in scope for this feature; consider adding a CI validation step that compares chart entries across both files.)*

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: README.md Chart Catalog table MUST include entries for envoy-controller and kgateway-controller with descriptions, types, and links consistent with CHARTS.md.
- **FR-002**: README.md Project Overview text block MUST list all controller charts (traefik, nginx, envoy, kgateway).
- **FR-003**: README.md "Ingress and Gateway API" subsection MUST accurately describe Gateway API support across all capable controllers.
- **FR-004**: README.md Prerequisites note MUST reference all Gateway API-capable controllers.
- **FR-005**: All changes MUST be consistent with existing entries in CHARTS.md.

### Key Entities

- **README.md**: Root repository documentation — the primary entry point for new users.
- **CHARTS.md**: Authoritative chart catalog with full details.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: README.md Chart Catalog table lists exactly 6 charts, matching CHARTS.md.
- **SC-002**: Project Overview text block and architecture text block include all 4 controller charts.
- **SC-003**: Prerequisites note references all 3 Gateway API-capable controllers (Traefik, Envoy Gateway, kgateway).
- **SC-004**: Zero discrepancies between README.md chart references and CHARTS.md.
