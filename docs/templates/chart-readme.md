# <Chart Name>

<!-- Brief description of what this chart deploys -->

## Overview

<!-- What the chart does, what resources it creates, and how it integrates with common-lib -->

## Prerequisites

- Helm ≥ 3.12
- Kubernetes ≥ 1.26
<!-- Add any additional prerequisites (e.g., Ingress controller, CRDs) -->

## Installation

### From OCI Registry

```bash
helm install <release-name> oci://ghcr.io/<org>/charts/<chart-name> --version <version> \
  --set image.repository=<your-image> \
  --set image.tag=<your-tag>
```

### From Source

```bash
helm dependency build charts/<chart-name>
helm install <release-name> charts/<chart-name> \
  --set image.repository=<your-image> \
  --set image.tag=<your-tag>
```

### Uninstall

```bash
helm uninstall <release-name>
```

## Configuration

<!-- Configuration table — generate with helm-docs or fill manually -->

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `image.repository` | string | `""` | Container image repository (**required**) |
| `image.tag` | string | `""` | Container image tag (**required**) |
| `replicaCount` | int | `1` | Number of replicas |
<!-- Add all values keys here -->

## Examples

### Minimal

```bash
helm install my-release charts/<chart-name> \
  --set image.repository=nginx \
  --set image.tag=1.27-alpine
```

### Production

```bash
helm install my-release charts/<chart-name> -f examples/<chart-name>-production.yaml
```

## Upgrade Notes

### 0.1.0

Initial release — no prior versions.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `image.repository is required` | Provide `--set image.repository=<image>` |
| `image.tag must not be empty` | Provide `--set image.tag=<tag>` |
<!-- Add chart-specific troubleshooting -->
