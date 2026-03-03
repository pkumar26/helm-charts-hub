# Badge Template

Reusable shields.io badge markdown for any public GitHub repository. Copy the badge row below, replace the placeholders, and paste after the H1 title in your README.

## Placeholder Reference

| Placeholder | Description | Example |
|---|---|---|
| `{OWNER}` | GitHub username or org | `pkumar26` |
| `{REPO}` | Repository name | `helm-charts-hub` |
| `{BRANCH}` | Default branch | `master` or `main` |
| `{WORKFLOW}` | CI workflow filename | `chart-lint-test.yaml` |
| `{WORKFLOW_NAME}` | Human-readable workflow name | `Lint and Test Charts` |
| `{CHART}` | Chart directory name (chart-specific only) | `web-app` |
| `{AH_REPO_NAME}` | Artifact Hub repository name (opt-in) | `helm-charts-hub` |

## Standard Badge Row

Copy the following four-badge markdown row and replace the placeholders:

```markdown
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/{OWNER}/{REPO}/blob/{BRANCH}/LICENSE)
[![{WORKFLOW_NAME}](https://img.shields.io/github/actions/workflow/status/{OWNER}/{REPO}/{WORKFLOW})](https://github.com/{OWNER}/{REPO}/actions/workflows/{WORKFLOW})
[![Last Commit](https://img.shields.io/github/last-commit/{OWNER}/{REPO})](https://github.com/{OWNER}/{REPO}/commits)
[![Contributors](https://img.shields.io/github/contributors/{OWNER}/{REPO})](https://github.com/{OWNER}/{REPO}/graphs/contributors)
```

## How to Apply

1. **Copy** the badge row above
2. **Find-and-replace** each `{PLACEHOLDER}` with your repo values
3. **Paste** the result immediately after the `# Title` line in your target README
4. **Push** to GitHub and verify badges render correctly

## Example: comparison-aks-aca-appservice

Substitution: `{OWNER}` → `pkumar26`, `{REPO}` → `comparison-aks-aca-appservice`, `{BRANCH}` → `main`, `{WORKFLOW}` → `generate-diagrams.yml`, `{WORKFLOW_NAME}` → `Generate Diagrams`

```markdown
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/pkumar26/comparison-aks-aca-appservice/blob/main/LICENSE)
[![Generate Diagrams](https://img.shields.io/github/actions/workflow/status/pkumar26/comparison-aks-aca-appservice/generate-diagrams.yml)](https://github.com/pkumar26/comparison-aks-aca-appservice/actions/workflows/generate-diagrams.yml)
[![Last Commit](https://img.shields.io/github/last-commit/pkumar26/comparison-aks-aca-appservice)](https://github.com/pkumar26/comparison-aks-aca-appservice/commits)
[![Contributors](https://img.shields.io/github/contributors/pkumar26/comparison-aks-aca-appservice)](https://github.com/pkumar26/comparison-aks-aca-appservice/graphs/contributors)
```

## Optional Badges

Additional badges you can add after the standard four:

```markdown
[![Stars](https://img.shields.io/github/stars/{OWNER}/{REPO})](https://github.com/{OWNER}/{REPO}/stargazers)
[![Open Issues](https://img.shields.io/github/issues/{OWNER}/{REPO})](https://github.com/{OWNER}/{REPO}/issues)
[![Forks](https://img.shields.io/github/forks/{OWNER}/{REPO})](https://github.com/{OWNER}/{REPO}/network/members)
```

## Private Repositories

Shields.io dynamic badges **do not work** for private repos — the GitHub API returns 404 for private repo metadata.

**Fallback: static-only badges** for private repos:

```markdown
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/{OWNER}/{REPO}/blob/{BRANCH}/LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/{OWNER}/{REPO}/actions)
```

For CI status in private repos, use the GitHub native workflow badge instead (renders only for authenticated users):

```markdown
![CI](https://github.com/{OWNER}/{REPO}/actions/workflows/{WORKFLOW}/badge.svg)
```

## Helm-Specific Badges (Optional — Chart READMEs)

For Helm chart READMEs, add these badges in addition to or instead of the standard set:

```markdown
[![Helm 3](https://img.shields.io/badge/Helm-3-blue?logo=helm&logoColor=white)](https://helm.sh)
[![Chart Version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2F{OWNER}%2F{REPO}%2F{BRANCH}%2Fcharts%2F{CHART}%2FChart.yaml&query=%24.version&label=chart%20version&color=blue&logo=helm)](https://github.com/{OWNER}/{REPO}/tree/{BRANCH}/charts/{CHART})
[![Kubernetes >= 1.26](https://img.shields.io/badge/Kubernetes-%E2%89%A5%201.26-blue?logo=kubernetes&logoColor=white)](https://kubernetes.io)
```

**Artifact Hub** (opt-in — requires chart registration):

```markdown
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/{AH_REPO_NAME})](https://artifacthub.io/packages/search?repo={AH_REPO_NAME})
```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Badge shows "not found" | Wrong owner, repo, or workflow filename | Double-check placeholder values |
| CI badge shows "no status" | Workflow exists but hasn't run yet | Trigger the workflow (push or manual) |
| Badge image broken | Private repository | Use static badges only (see Private Repositories section) |
| License badge shows wrong type | Dynamic license badge API misdetection | Use the static `license-MIT-blue` badge pattern |
| Dynamic chart version badge fails | Raw GitHub URL inaccessible | Check branch name and chart path; use static fallback |
