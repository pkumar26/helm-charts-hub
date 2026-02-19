# Changelog — common-lib

All notable changes to this chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] — 2026-02-19

### Added

- Ingress helper (networking.k8s.io/v1) with ingress.enabled guard, className, hosts, TLS support
- HPA helper (autoscaling/v2) with autoscaling.enabled guard, CPU/memory targets
- ConfigMap helper accepting data dict argument
- Secret helper with base64 encoding accepting data dict argument

## [0.1.0] — 2026-02-19

### Added

- Metadata helpers: `common-lib.fullname`, `common-lib.chart`
- Label helpers: `common-lib.labels` (6 base labels + extraLabels), `common-lib.selectorLabels`
- Annotation helpers: `common-lib.annotations` (2 base annotations + extraAnnotations)
- Deployment helper with workloadType guard, image validation, probes, security context, resource limits
- Service helper with workloadType guard and selectorLabels
- ServiceAccount helper with create guard and name default
- Pod security context helper (runAsNonRoot, readOnlyRootFilesystem, allowPrivilegeEscalation)
- Canonical values.yaml with sensible defaults
