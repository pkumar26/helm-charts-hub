# Research: Repository Badges

**Feature**: 006-repo-badges | **Date**: 2026-03-01

## 1. Badge Service Selection

**Decision**: Use [shields.io](https://shields.io) for all badges.

**Rationale**: Shields.io is the de facto standard for GitHub repo badges, used
by >1M repositories. Stable URL patterns, global CDN (Cloudflare), graceful
degradation for missing data.

**Alternatives Considered**:
- **Badgen.net** — slightly faster CDN, but smaller ecosystem and fewer badge
  variants. Rejected for ecosystem breadth.
- **GitHub native workflow badges** — only cover CI status; different visual
  style breaks consistency when mixed with shields.io. Documented as fallback.

---

## 2. Badge Types and URL Patterns

### Standard Badge Set (root README)

| Badge | URL Pattern | Links To |
|---|---|---|
| License (static) | `img.shields.io/badge/license-MIT-blue.svg` | LICENSE file |
| CI Status (dynamic) | `img.shields.io/github/actions/workflow/status/:user/:repo/:workflow` | Actions tab |
| Last Commit (dynamic) | `img.shields.io/github/last-commit/:user/:repo` | Commit history |
| Contributors (dynamic) | `img.shields.io/github/contributors/:user/:repo` | Contributors page |

### Optional Badges (documented in template)

| Badge | URL Pattern | Use Case |
|---|---|---|
| Stars | `img.shields.io/github/stars/:user/:repo` | Community signal |
| Open Issues | `img.shields.io/github/issues/:user/:repo` | Issue triage signal |
| Forks | `img.shields.io/github/forks/:user/:repo` | Fork network signal |

### Helm-Specific Badges (chart READMEs)

| Badge | URL Pattern | Notes |
|---|---|---|
| Helm 3 (static) | `img.shields.io/badge/Helm-3-blue?logo=helm` | Compatibility signal |
| Chart Version (dynamic) | `img.shields.io/badge/dynamic/yaml?url=RAW_CHART_YAML&query=$.version&label=chart` | Auto-reads Chart.yaml |
| Kubernetes ≥ 1.26 (static) | `img.shields.io/badge/Kubernetes-≥ 1.26-blue?logo=kubernetes&logoColor=white` | Compatibility signal |
| Artifact Hub (endpoint) | `img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/REPO` | If published on AH |

---

## 3. Static vs Dynamic Badges

**Decision**: Use static badge for License (avoids GitHub API license-detection
failures); dynamic for all other badges.

**Rationale**: The GitHub API occasionally misidentifies LICENSE file formats.
A static `license-MIT-blue` badge is reliable and the license type rarely
changes. All other metrics benefit from live updates.

**Alternatives Considered**:
- All dynamic — rejected because the dynamic license badge (`/github/license/`)
  sometimes returns "not identifiable by GitHub" for valid LICENSE files.
- All static — rejected because it requires manual updates for live metrics.

---

## 4. Badge Ordering Convention

**Decision**: License → CI Status → Last Commit → Contributors

**Rationale**: Identity → Health → Activity → Community — this ordering follows
the convention used by major open-source projects (Kubernetes, Helm, CNCF
projects).

---

## 5. Visual Style

**Decision**: Use shields.io default `flat` style. No custom colors beyond the
standard shields.io palette.

**Rationale**: `flat` is most readable at GitHub's default rendering size, is the
shields.io default, and matches the reference repo (`comparison-aks-aca-appservice`).

**Alternatives Considered**:
- `for-the-badge` — larger/bolder, looks oversized in technical READMEs.
- `flat-square` — acceptable but less common in the ecosystem.

---

## 6. Build Status Badge Specifics

**Decision**: Use shields.io GitHub Actions workflow status endpoint. Badge the
primary CI workflow (`chart-lint-test.yaml`) in the root README.

**Rationale**: Shields.io degrades gracefully (shows "no status" instead of broken
image). Visual style is consistent with other badges on the same line.

### This Repo's Workflows

| Workflow Name | File | Badge in Root README? |
|---|---|---|
| Lint and Test Charts | `chart-lint-test.yaml` | Yes (primary CI) |
| Release Charts | `chart-release.yaml` | No (secondary) |
| Documentation Check | `docs-check.yaml` | No (secondary) |

### Workflow Rename Risk

If a workflow file is renamed, the badge URL breaks. The badge template
must document this dependency explicitly. No automated solution exists
short of a CI step that validates badge URLs.

---

## 7. Private Repo Limitations

**Decision**: Document limitations in the badge template. Provide static badge
fallbacks for private repos.

**Key Finding**: Shields.io dynamic badges **do not work** for private repos.
The GitHub API returns 404 for private repo metadata. Even shields.io's
GitHub App authorization (for rate limiting) does not unlock private repo data.

### Private Repo Alternatives

| Approach | Coverage | Limitation |
|---|---|---|
| GitHub native workflow badges | CI status only | Only renders for authenticated GitHub users |
| Static shields.io badges | Any fixed value | No live data; manual updates |
| Self-hosted Shields instance | All badges | Operational overhead |

**For helm-charts-hub**: This is a public repo, so shields.io dynamic badges
work fully.

---

## 8. Helm/Kubernetes Specific Badges

**Decision**: Prepare Helm 3 and chart version badges for chart READMEs. Prepare
Artifact Hub badge as opt-in for when charts are published there.

### Dynamic Chart Version Badge

For this repo, a dynamic chart version badge reads from Chart.yaml via raw
GitHub URL:

```
https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fpkumar26%2Fhelm-charts-hub%2Fmaster%2Fcharts%2Fweb-app%2FChart.yaml&query=%24.version&label=chart%20version&color=blue&logo=helm
```

**Trade-off**: Depends on shields.io → GitHub raw file availability. Acceptable
for public repos. Falls back to static badge for private repos.

### Artifact Hub

Charts are **not yet published** on Artifact Hub. The badge template includes the
pattern as a documented opt-in for future use.

---

## Summary of All Decisions

| # | Decision | Confidence |
|---|---|---|
| 1 | Use shields.io `flat` style for all badges | High |
| 2 | Static badge for License, dynamic for everything else | High |
| 3 | Shields.io (not GitHub native) for CI status badge | High |
| 4 | Badge primary CI workflow only (`chart-lint-test.yaml`) in root README | High |
| 5 | Badge order: License → CI → Last Commit → Contributors | High |
| 6 | Document private repo limitations with static fallbacks | High |
| 7 | Helm 3 + dynamic chart version badges for chart READMEs | Medium |
| 8 | Artifact Hub badge prepared as opt-in/future | Medium |
