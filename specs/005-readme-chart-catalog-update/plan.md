# Implementation Plan: README Chart Catalog Update

**Branch**: `005-readme-chart-catalog-update` | **Date**: 2026-03-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-readme-chart-catalog-update/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

The root README.md is missing envoy-controller and kgateway-controller from the Chart Catalog table, Project Overview text block, architecture text block, and Gateway API references. This plan covers updating all documentation sections to accurately reflect all 6 charts in the repository. This is a documentation-only change — no code, templates, or values are modified.

## Technical Context

**Language/Version**: Markdown (documentation only)  
**Primary Dependencies**: N/A — no code changes  
**Storage**: N/A  
**Testing**: Manual review; `helm lint` unaffected (no chart changes)  
**Target Platform**: GitHub repository README rendering  
**Project Type**: Documentation update  
**Performance Goals**: N/A  
**Constraints**: Must stay consistent with CHARTS.md (authoritative source)  
**Scale/Scope**: Single file (README.md), 4 sections to update

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Constitution Reference | Status |
|------|----------------------|--------|
| §9.1 Chart README Requirement | Every chart must have a README | PASS — all 6 charts already have READMEs |
| §9.2 Required README Sections | Chart READMEs must have standard sections (applied by analogy: root README should also reflect all charts) | PASS (chart READMEs complete) — root README gap addressed by this feature |
| §2.2 Consistency | All charts must follow identical naming and conventions (applied by extension: documentation references should be consistent across README and CHARTS.md) | FAIL → README inconsistent with CHARTS.md |
| §7.1 Criteria for New Charts | Charts must be documented | PASS — envoy/kgateway have READMEs, just missing from root README |
| §9.4 Usage Examples | Charts should include examples | PASS — examples exist in /examples/ |

**Gate Result**: Violations are the reason for this feature — fixing them brings us into compliance.

## Project Structure

### Documentation (this feature)

```text
specs/005-readme-chart-catalog-update/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (document structure mapping)
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
README.md                # Only file requiring changes
CHARTS.md                # Authoritative reference (already complete)
```

**Structure Decision**: Documentation-only change. Single file (README.md) with 4 sections to update. No source code structure changes.

## Complexity Tracking

No constitution violations — this feature resolves existing non-compliance (§9.2, §2.2).
