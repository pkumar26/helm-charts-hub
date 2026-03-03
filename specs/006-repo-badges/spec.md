# Feature Specification: Repository Badges

**Feature Branch**: `006-repo-badges`  
**Created**: 2026-03-01  
**Status**: Draft  
**Input**: User description: "I like badges used in repo e.g. https://github.com/pkumar26/comparison-aks-aca-appservice.git — How can we implement same in all my repos?"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Add Shields.io Badges to helm-charts-hub README (Priority: P1)

As a repository visitor, I see a row of status badges at the top of the
helm-charts-hub README so that I can immediately assess license, build health,
last activity, and contributor count without navigating away.

**Why this priority**: Badges provide instant project credibility and health
signals. This repo is the current workspace and the first target.

**Independent Test**: Verify that the README renders four badges (License, Lint &
Test, Last Commit, Contributors) on GitHub; each badge image loads and links to
the relevant GitHub page.

**Acceptance Scenarios**:

1. **Given** a visitor opens the helm-charts-hub GitHub page, **When** the README
   renders, **Then** four shields.io badges appear below the title (License, Lint
   & Test, Last Commit, Contributors).
2. **Given** the Lint and Test workflow passes on `main`, **When** the badge is
   loaded, **Then** it shows a green "passing" state.
3. **Given** a contributor clicks the License badge, **When** the link resolves,
   **Then** the browser navigates to the LICENSE file.

---

### User Story 2 - Create a Reusable Badge Template for All Repos (Priority: P2)

As a repository owner with multiple repos, I want a documented, copy-paste-ready
badge template so that I can add consistent badges to any repo with minimal
effort.

**Why this priority**: The user explicitly wants this across *all* repos, so a
reusable template multiplies value beyond this single repo.

**Independent Test**: Copy the template, replace the required placeholders
(`OWNER`, `REPO`, `BRANCH`, `WORKFLOW`, `WORKFLOW_NAME`), paste into a new repo
README, and confirm badges render correctly.

**Acceptance Scenarios**:

1. **Given** the badge template exists in docs/, **When** a user substitutes
   `OWNER`, `REPO`, `BRANCH`, `WORKFLOW`, and `WORKFLOW_NAME` placeholders,
   **Then** valid badge markdown is produced for any public GitHub repo.
2. **Given** a repo has no GitHub Actions workflow, **When** the template is
   applied, **Then** the build-status badge gracefully shows "no status" or can
   be omitted.

---

### User Story 3 - Add Chart-Specific Badges to Sub-Chart READMEs (Priority: P3)

As a chart consumer, I see a Helm version badge and chart version badge on each
chart's README so that I can quickly identify compatibility.

**Why this priority**: Nice-to-have enhancement for individual chart discovery;
lower priority than P1/P2 but technically independent (modifies different files).

**Independent Test**: Open any chart README (e.g., charts/web-app/README.md) and
confirm a "Helm 3" badge and chart version badge render correctly.

**Acceptance Scenarios**:

1. **Given** a visitor opens the web-app chart README, **When** it renders,
   **Then** a "Helm 3" badge and a chart version badge are visible.

---

### Edge Cases

- What happens when a workflow file is renamed? Build badge URL breaks —
  template should document the workflow file name dependency.
- How does a badge render for a private repository? Shields.io cannot access
  private repo metadata — document this limitation.
- What if the repo has no LICENSE file? The license badge should use a static
  "MIT" badge that doesn't depend on GitHub API detection.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The helm-charts-hub root README MUST display shields.io badges for
  License, CI status (Lint & Test), Last Commit, and Contributors.
- **FR-002**: Badge markdown MUST use shields.io URLs with the `pkumar26` owner
  and correct repository name.
- **FR-003**: Each badge MUST link to the relevant GitHub resource (LICENSE file,
  Actions tab, commit history, contributors page).
- **FR-004**: A reusable badge template MUST be created in
  `docs/templates/badge-template.md` with the following placeholders: `OWNER`,
  `REPO`, `BRANCH`, `WORKFLOW`, `WORKFLOW_NAME`, `CHART` (chart-specific), and
  `AH_REPO_NAME` (opt-in). The canonical placeholder set is defined in
  `contracts/badge-url-schema.md` Placeholder Reference.
- **FR-005**: The template MUST include instructions for customizing the workflow
  file name for the build-status badge.
- **FR-006**: Chart-specific READMEs MAY include Helm version and chart version
  badges (P3, optional).

### Key Entities

- **Badge**: A shields.io image URL + link URL pair rendered as markdown.
- **Badge Set**: The standard collection of badges applied to a repo (License,
  CI, Last Commit, Contributors).
- **Badge Template**: A parameterized markdown snippet for reuse across repos.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All four badges render correctly on the helm-charts-hub GitHub
  README page.
- **SC-002**: The badge template can be applied to the comparison-aks-aca-appservice
  repo with only variable substitution (owner/repo) — no structural changes.
- **SC-003**: Badge URLs resolve and return valid SVG images (HTTP 200).
- **SC-004**: Applying badges to a new repo takes under 2 minutes using the
  template.
