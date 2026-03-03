# Quickstart: Adding Badges to Your Repos

**Feature**: 006-repo-badges | **Date**: 2026-03-01

## 1. Add Badges to helm-charts-hub (This Repo)

Insert the following line immediately after the `# Helm Charts Hub` title in
the root README.md:

```markdown
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/pkumar26/helm-charts-hub/blob/master/LICENSE)
[![Lint and Test Charts](https://img.shields.io/github/actions/workflow/status/pkumar26/helm-charts-hub/chart-lint-test.yaml)](https://github.com/pkumar26/helm-charts-hub/actions/workflows/chart-lint-test.yaml)
[![Last Commit](https://img.shields.io/github/last-commit/pkumar26/helm-charts-hub)](https://github.com/pkumar26/helm-charts-hub/commits)
[![Contributors](https://img.shields.io/github/contributors/pkumar26/helm-charts-hub)](https://github.com/pkumar26/helm-charts-hub/graphs/contributors)
```

**Verification**: Push to GitHub and confirm four badges render below the title.

---

## 2. Add Badges to Any Other Repo (Template)

### Step 1: Copy the template

Copy `/docs/templates/badge-template.md` (once created) into your clipboard.

### Step 2: Replace placeholders

| Placeholder | Replace With | Example |
|---|---|---|
| `OWNER` | Your GitHub username or org | `pkumar26` |
| `REPO` | Your repository name | `comparison-aks-aca-appservice` |
| `WORKFLOW` | Your primary CI workflow filename | `generate-diagrams.yml` |
| `WORKFLOW_NAME` | Human-readable workflow name | `Generate Diagrams` |
| `BRANCH` | Your default branch | `main` |

### Step 3: Paste into your README

Insert the resulting badge line immediately after the H1 title in your
README.md.

### Step 4: Verify

Push to GitHub and confirm badges render correctly.

---

## 3. Example: comparison-aks-aca-appservice

After substitution, the badges for the reference repo would be:

```markdown
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/pkumar26/comparison-aks-aca-appservice/blob/main/LICENSE)
[![Generate Diagrams](https://img.shields.io/github/actions/workflow/status/pkumar26/comparison-aks-aca-appservice/generate-diagrams.yml)](https://github.com/pkumar26/comparison-aks-aca-appservice/actions/workflows/generate-diagrams.yml)
[![Last Commit](https://img.shields.io/github/last-commit/pkumar26/comparison-aks-aca-appservice)](https://github.com/pkumar26/comparison-aks-aca-appservice/commits)
[![Contributors](https://img.shields.io/github/contributors/pkumar26/comparison-aks-aca-appservice)](https://github.com/pkumar26/comparison-aks-aca-appservice/graphs/contributors)
```

---

## 4. Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Badge shows "not found" | Wrong owner, repo, or workflow filename | Double-check placeholder values |
| CI badge shows "no status" | Workflow exists but hasn't run yet | Trigger the workflow (push or manual) |
| Badge image broken | Private repository | Use static badges only (see research.md §7) |
| License badge shows wrong type | Dynamic license badge API misdetection | Use the static badge pattern instead |

---

## 5. Time Estimate

| Task | Time |
|---|---|
| Add badges to this repo | ~2 minutes |
| Apply template to another repo | ~2 minutes |
| Create badge template file | ~10 minutes (one-time) |
