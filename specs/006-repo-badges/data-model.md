# Data Model: Repository Badges

**Feature**: 006-repo-badges | **Date**: 2026-03-01

## Entities

This feature is documentation-only — no databases, APIs, or runtime entities.
The "data model" describes the structural elements that make up the badge system.

---

### Entity: Badge

A single shields.io badge rendered as a markdown image-link.

| Field | Type | Description | Example |
|---|---|---|---|
| `label` | string | Display text on the left side of the badge | `license`, `build`, `last commit` |
| `message` | string | Display text on the right side (for static badges) | `MIT`, `passing` |
| `color` | string | Right-side color (shields.io color name or hex) | `blue`, `green`, `brightgreen` |
| `imageUrl` | URL | Full shields.io image URL | `https://img.shields.io/badge/license-MIT-blue.svg` |
| `linkUrl` | URL | Target URL when badge is clicked | `https://github.com/pkumar26/helm-charts-hub/blob/master/LICENSE` |
| `altText` | string | Markdown alt-text for accessibility | `License` |
| `type` | enum | `static` or `dynamic` | `static` |
| `logo` | string? | Optional shields.io logo parameter | `helm`, `kubernetes` |

**Markdown rendering**:
```markdown
[![{altText}]({imageUrl})]({linkUrl})
```

---

### Entity: BadgeSet

An ordered collection of Badge entities for a specific README.

| Field | Type | Description |
|---|---|---|
| `target` | enum | `root` (repo README) or `chart` (chart-level README) |
| `badges` | Badge[] | Ordered list of badges to render |
| `placement` | string | Where in the README badges appear (after H1 title) |

**Root BadgeSet** (4 badges):
1. License (static)
2. CI Status (dynamic — `chart-lint-test.yaml`)
3. Last Commit (dynamic)
4. Contributors (dynamic)

**Chart BadgeSet** (2–4 badges, P3):
1. Helm 3 (static)
2. Chart Version (dynamic YAML, or static fallback for library charts — see §6b)
3. Kubernetes version (static, optional)
4. Artifact Hub (endpoint, optional)

---

### Entity: BadgeTemplate

A parameterized markdown snippet with placeholders for repo-specific values.

| Field | Type | Description |
|---|---|---|
| `owner` | placeholder | GitHub username/org (`OWNER`) |
| `repo` | placeholder | Repository name (`REPO`) |
| `branch` | placeholder | Default branch, defaults to `main` (`BRANCH`) |
| `workflow` | placeholder | CI workflow filename (`WORKFLOW`) |
| `workflowName` | placeholder | Human-readable workflow name (`WORKFLOW_NAME`) |
| `chart` | placeholder | Chart directory name, chart-specific only (`CHART`) |
| `artifactHubRepoName` | placeholder | Artifact Hub repo name, opt-in (`AH_REPO_NAME`) |

**Substitution rule**: Replace all occurrences of `OWNER`, `REPO`, `BRANCH`,
`WORKFLOW`, `WORKFLOW_NAME` (and `CHART` / `AH_REPO_NAME` for chart badges) in
the template to produce repo-specific badge markdown. The canonical placeholder
set is defined in `contracts/badge-url-schema.md` Placeholder Reference.

---

## Relationships

```text
BadgeTemplate
    │
    ├── produces → BadgeSet (root)
    │                 ├── Badge: License
    │                 ├── Badge: CI Status
    │                 ├── Badge: Last Commit
    │                 └── Badge: Contributors
    │
    └── produces → BadgeSet (chart)  ← P3, optional
                      ├── Badge: Helm 3
                      ├── Badge: Chart Version
                      └── Badge: Artifact Hub (opt-in)
```

## Validation Rules

- `imageUrl` MUST start with `https://img.shields.io/`
- `linkUrl` MUST be a valid GitHub URL for the target repo
- `altText` MUST be non-empty and describe the badge meaning
- `type=static` badges MUST NOT contain `:user/:repo` API patterns
- `type=dynamic` badges MUST contain the correct `owner/repo` in the URL
- Badge order within a BadgeSet MUST follow: identity → health → activity → community

## State Transitions

N/A — badges are stateless markdown. Shields.io handles caching and state
internally (default 300s cache per badge).
