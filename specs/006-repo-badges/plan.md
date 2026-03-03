# Implementation Plan: Repository Badges

**Branch**: `006-repo-badges` | **Date**: 2026-03-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-repo-badges/spec.md`

## Summary

Add shields.io status badges (License, CI Status, Last Commit, Contributors) to
the helm-charts-hub root README, matching the pattern used in the
`comparison-aks-aca-appservice` repository. Create a reusable badge template in
`docs/templates/badge-template.md` so the same badges can be applied to any repo
with simple variable substitution.

## Technical Context

**Language/Version**: Markdown (GitHub Flavored Markdown)
**Primary Dependencies**: shields.io (external badge service), GitHub API (badge data source)
**Storage**: N/A (documentation-only change)
**Testing**: Visual verification on GitHub; optional CI link-check
**Target Platform**: GitHub.com rendered markdown
**Project Type**: Documentation / cross-repo template
**Performance Goals**: N/A
**Constraints**: Badges must work for public repos; private repos require shields.io token or alternative
**Scale/Scope**: 1 repo immediate (helm-charts-hub), template reusable across all pkumar26 repos

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| § | Rule | Status | Notes |
|---|------|--------|-------|
| §9.1 | Every chart MUST include README.md | ✅ PASS | Not adding new charts; modifying existing READMEs |
| §9.2 | Required README sections | ✅ PASS | Badges are additive; no required sections removed |
| §9.3 | Breaking change docs | ✅ N/A | No breaking changes |
| §2.2 | Consistency | ✅ PASS | Badge set is standardized via template |
| §2.1 | Simplicity | ✅ PASS | Copy-paste template, minimal complexity |
| §11.1 | SemVer | ✅ N/A | No chart version changes required |

**Gate result**: ✅ PASS — no violations.

## Project Structure

### Documentation (this feature)

```text
specs/006-repo-badges/
├── plan.md              # This file
├── research.md          # Phase 0 output — badge service research
├── data-model.md        # Phase 1 output — badge entity model
├── quickstart.md        # Phase 1 output — how to apply badges
├── contracts/           # Phase 1 output — badge URL schema
└── tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
README.md                          # Modified: add badge row below title
CONTRIBUTING.md                    # Modified: mention badge template location
docs/
└── templates/
    └── badge-template.md          # NEW: reusable badge template for all repos
```

**Structure Decision**: Documentation-only feature. Changes are limited to
markdown files in the repo root and `docs/templates/`. No source code, no new
charts, no Helm template changes. Chart-level READMEs (6 charts) are also
modified to add Helm-specific badges (P3).

## Complexity Tracking

> No violations — section intentionally left empty.
