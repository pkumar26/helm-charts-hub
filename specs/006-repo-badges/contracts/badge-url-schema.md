# Badge URL Contracts

**Feature**: 006-repo-badges | **Date**: 2026-03-01

This document defines the exact URL contracts for every badge type used in the
project. All URLs are shields.io endpoints.

---

## Root README Badge Set

### 1. License Badge (Static)

```
Image: https://img.shields.io/badge/license-MIT-blue.svg
Link:  https://github.com/{OWNER}/{REPO}/blob/{BRANCH}/LICENSE
Alt:   License: MIT
```

**helm-charts-hub concrete**:
```markdown
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/pkumar26/helm-charts-hub/blob/master/LICENSE)
```

---

### 2. CI Status Badge (Dynamic — GitHub Actions)

```
Image: https://img.shields.io/github/actions/workflow/status/{OWNER}/{REPO}/{WORKFLOW}
Link:  https://github.com/{OWNER}/{REPO}/actions/workflows/{WORKFLOW}
Alt:   {WORKFLOW_NAME}
```

**helm-charts-hub concrete** (Lint & Test):
```markdown
[![Lint and Test Charts](https://img.shields.io/github/actions/workflow/status/pkumar26/helm-charts-hub/chart-lint-test.yaml)](https://github.com/pkumar26/helm-charts-hub/actions/workflows/chart-lint-test.yaml)
```

**Fallback (GitHub native, not recommended for consistency)**:
```
Image: https://github.com/{OWNER}/{REPO}/actions/workflows/{WORKFLOW}/badge.svg
```

---

### 3. Last Commit Badge (Dynamic)

```
Image: https://img.shields.io/github/last-commit/{OWNER}/{REPO}
Link:  https://github.com/{OWNER}/{REPO}/commits
Alt:   Last Commit
```

**helm-charts-hub concrete**:
```markdown
[![Last Commit](https://img.shields.io/github/last-commit/pkumar26/helm-charts-hub)](https://github.com/pkumar26/helm-charts-hub/commits)
```

---

### 4. Contributors Badge (Dynamic)

```
Image: https://img.shields.io/github/contributors/{OWNER}/{REPO}
Link:  https://github.com/{OWNER}/{REPO}/graphs/contributors
Alt:   Contributors
```

**helm-charts-hub concrete**:
```markdown
[![Contributors](https://img.shields.io/github/contributors/pkumar26/helm-charts-hub)](https://github.com/pkumar26/helm-charts-hub/graphs/contributors)
```

---

## Chart README Badge Set (P3 — Optional)

### 5. Helm 3 Badge (Static)

```
Image: https://img.shields.io/badge/Helm-3-blue?logo=helm&logoColor=white
Link:  https://helm.sh
Alt:   Helm 3
```

**Concrete**:
```markdown
[![Helm 3](https://img.shields.io/badge/Helm-3-blue?logo=helm&logoColor=white)](https://helm.sh)
```

---

### 6. Chart Version Badge (Dynamic YAML)

```
Image: https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2F{OWNER}%2F{REPO}%2F{BRANCH}%2Fcharts%2F{CHART}%2FChart.yaml&query=%24.version&label=chart%20version&color=blue&logo=helm
Link:  https://github.com/{OWNER}/{REPO}/tree/{BRANCH}/charts/{CHART}
Alt:   Chart Version
```

**helm-charts-hub/web-app concrete**:
```markdown
[![Chart Version](https://img.shields.io/badge/dynamic/yaml?url=https%3A%2F%2Fraw.githubusercontent.com%2Fpkumar26%2Fhelm-charts-hub%2Fmaster%2Fcharts%2Fweb-app%2FChart.yaml&query=%24.version&label=chart%20version&color=blue&logo=helm)](https://github.com/pkumar26/helm-charts-hub/tree/master/charts/web-app)
```

---

### 6b. Chart Version Badge — Static Fallback

For library charts (e.g., `common-lib`) or private repos where dynamic YAML
badges cannot resolve, use a static badge with the version hardcoded:

```
Image: https://img.shields.io/badge/chart%20version-{VERSION}-blue?logo=helm
Link:  https://github.com/{OWNER}/{REPO}/tree/{BRANCH}/charts/{CHART}
Alt:   Chart Version
```

**helm-charts-hub/common-lib concrete** (version read manually from Chart.yaml):
```markdown
[![Chart Version](https://img.shields.io/badge/chart%20version-0.1.0-blue?logo=helm)](https://github.com/pkumar26/helm-charts-hub/tree/master/charts/common-lib)
```

**Note**: The `{VERSION}` value must be updated manually when the chart version
changes. This is the trade-off for library charts where the dynamic YAML badge
may not be desirable.

---

### 7. Kubernetes Version Badge (Static)

```
Image: https://img.shields.io/badge/Kubernetes-%E2%89%A5%201.26-blue?logo=kubernetes&logoColor=white
Link:  https://kubernetes.io
Alt:   Kubernetes >= 1.26
```

**Concrete**:
```markdown
[![Kubernetes >= 1.26](https://img.shields.io/badge/Kubernetes-%E2%89%A5%201.26-blue?logo=kubernetes&logoColor=white)](https://kubernetes.io)
```

---

### 8. Artifact Hub Badge (Endpoint — Future/Opt-in)

```
Image: https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/{AH_REPO_NAME}
Link:  https://artifacthub.io/packages/search?repo={AH_REPO_NAME}
Alt:   Artifact Hub
```

**Prerequisite**: Charts must be registered on Artifact Hub.

---

## Placeholder Reference

| Placeholder | Description | Example |
|---|---|---|
| `{OWNER}` | GitHub username or org | `pkumar26` |
| `{REPO}` | Repository name | `helm-charts-hub` |
| `{BRANCH}` | Default branch | `master` or `main` |
| `{WORKFLOW}` | Workflow filename | `chart-lint-test.yaml` |
| `{WORKFLOW_NAME}` | Human-readable workflow name | `Lint and Test Charts` |
| `{CHART}` | Chart directory name | `web-app` |
| `{AH_REPO_NAME}` | Artifact Hub repository name | `helm-charts-hub` |
