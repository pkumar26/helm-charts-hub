# Contract: Chart.yaml Schemas

**Date**: 2026-02-19

---

## common-lib Chart.yaml

```yaml
apiVersion: v2
name: common-lib
description: Reusable Helm library chart for helm-charts-hub — provides standard helpers for Deployments, Services, Ingress, HPA, labels, annotations, and security contexts.
type: library
version: 0.1.0
# No appVersion — library charts don't deploy an application
```

## web-app Chart.yaml

```yaml
apiVersion: v2
name: web-app
description: General-purpose application chart for deploying services on Kubernetes. Supports Deployment and CronJob workload types.
type: application
version: 0.1.0
appVersion: "1.0.0"
dependencies:
  - name: common-lib
    version: ">=0.1.0 <1.0.0"
    repository: "file://../common-lib"
```

## Dependency Resolution

- **Local development**: `repository: "file://../common-lib"` resolves the sibling directory.
- **CI publishing**: `helm package charts/web-app` embeds the resolved dependency. The published `.tgz` is self-contained.
- **Version constraint**: `>=0.1.0 <1.0.0` accepts any 0.x minor/patch release. Pins to major 0 during initial development per SemVer conventions.

## Version Bump Rules

| Change Type | common-lib | web-app |
|-------------|-----------|---------|
| New helper added (backwards-compatible) | Minor bump | No bump (unless adopting the new helper) |
| Helper signature changed (breaking) | Major bump | Major bump (if consuming the changed helper) |
| Bug fix in helper | Patch bump | No bump |
| New values key added (optional, default preserves behavior) | — | Minor bump |
| Values key removed or renamed | — | Major bump |
| Bug fix in template | — | Patch bump |
