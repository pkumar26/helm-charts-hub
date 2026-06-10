# Data Model: Istio AKS Helm Chart

**Feature**: 007-istio-aks-chart  
**Phase**: 1 (Design & Contracts)  
**Date**: 2026-05-20

## Overview

This data model describes the key configuration entities and relationships in the Istio AKS Helm chart implementation. Since this is infrastructure-as-code (Helm charts), the "data model" represents the structure of configuration objects, Helm values, and Kubernetes resources rather than traditional database schemas.

---

## Entity 1: IstioBaseChart

### Description
Helm chart containing Istio's Custom Resource Definitions (CRDs) and cluster-wide resources. Must be installed first in the sequence.

### Attributes

| Attribute | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `istioVersion` | string | Yes | `1.23.0` | Istio version to install (must match istiod/gateway) |
| `createNamespace` | boolean | Yes | `true` | Whether to create istio-system namespace |
| `validationWebhook` | boolean | Yes | `true` | Enable CRD schema validation |

### Relationships
- **PREREQUISITE_FOR**: `IstioControlPlane` (istiod), `IstioGateway`
- **CREATES**: Kubernetes CRDs (Gateway, VirtualService, DestinationRule, etc.)

### State Transitions
```
NOT_INSTALLED → INSTALLING → INSTALLED → (optional) UPGRADING → INSTALLED
```

### Validation Rules
- Version string must match semver format (e.g., `1.23.0`)
- Must be installed before istiod or gateway charts
- CRD updates are additive only (no field removals)

---

## Entity 2: IstioControlPlane (istiod)

### Description
Helm chart for the Istio control plane deployment. Manages service mesh configuration distribution, certificate authority, and sidecar injection.

### Attributes

| Attribute | Type | Required | Default (dev) | Default (prod) | Description |
|-----------|------|----------|---------------|----------------|-------------|
| `replicaCount` | integer | Yes | `1` | `3` | Number of control plane replicas |
| `image.repository` | string | Yes | `istio/pilot` | `istio/pilot` | Container image repository |
| `image.tag` | string | Yes | `1.23.0` | `1.23.0-distroless` | Image tag (distroless for FIPS) |
| `resources.requests.cpu` | string | Yes | `100m` | `500m` | CPU request |
| `resources.requests.memory` | string | Yes | `512Mi` | `2Gi` | Memory request |
| `resources.limits.cpu` | string | Yes | `1000m` | `2000m` | CPU limit |
| `resources.limits.memory` | string | Yes | `1Gi` | `4Gi` | Memory limit |
| `fips.enabled` | boolean | Yes | `false` | `true` | Enable FIPS 140-2 mode |
| `mtls.mode` | enum | Yes | `PERMISSIVE` | `STRICT` | mTLS enforcement mode |
| `autoscaling.enabled` | boolean | Yes | `false` | `true` | Enable HPA |
| `autoscaling.minReplicas` | integer | No | - | `3` | Minimum replicas (if HPA enabled) |
| `autoscaling.maxReplicas` | integer | No | - | `5` | Maximum replicas (if HPA enabled) |
| `autoscaling.targetCPUUtilizationPercentage` | integer | No | - | `80` | Target CPU utilization for HPA scaling |
| `podSecurityContext.runAsNonRoot` | boolean | Yes | `true` | `true` | Run as non-root user |
| `podSecurityContext.runAsUser` | integer | Yes | `1337` | `1337` | User ID (Istio default) |
| `securityContext.readOnlyRootFilesystem` | boolean | Yes | `false` | `true` | Read-only root filesystem |
| `securityContext.allowPrivilegeEscalation` | boolean | Yes | `false` | `false` | Allow privilege escalation |

### Relationships
- **DEPENDS_ON**: `IstioBaseChart` (must be installed first)
- **CONFIGURES**: `IstioGateway`, application sidecars
- **PROVIDES**: Certificate Authority, xDS API, sidecar injection

### State Transitions
```
NOT_DEPLOYED → DEPLOYING → HEALTHY → (optional) DEGRADED → HEALTHY
                                   ↓
                              UPGRADING → HEALTHY
                                   ↓
                              ROLLING_BACK → HEALTHY
```

### Validation Rules
- Replica count must be odd (1, 3, 5) for leader election
- FIPS mode requires `-distroless` image tag
- STRICT mTLS requires all workloads to have sidecars
- Memory request must be at least 512Mi for production workloads

---

## Entity 3: IstioGateway

### Description
Helm chart for Istio ingress gateway deployment. Handles external traffic entry into the service mesh.

### Attributes

| Attribute | Type | Required | Default (dev) | Default (prod) | Description |
|-----------|------|----------|---------------|----------------|-------------|
| `replicaCount` | integer | Yes | `1` | `3` | Number of gateway replicas |
| `image.repository` | string | Yes | `istio/proxyv2` | `istio/proxyv2` | Container image repository |
| `image.tag` | string | Yes | `1.23.0` | `1.23.0-distroless` | Image tag (distroless for FIPS) |
| `service.type` | enum | Yes | `LoadBalancer` | `LoadBalancer` | Kubernetes service type |
| `service.ports` | array | Yes | `[80, 443]` | `[443]` | Exposed ports |
| `service.annotations` | object | No | `{}` | Azure LB annotations | Service annotations |
| `resources.requests.cpu` | string | Yes | `100m` | `500m` | CPU request |
| `resources.requests.memory` | string | Yes | `512Mi` | `2Gi` | Memory request |
| `fips.enabled` | boolean | Yes | `false` | `true` | Enable FIPS 140-2 mode |
| `mtls.mode` | enum | Yes | `PERMISSIVE` | `STRICT` | mTLS enforcement mode |
| `autoscaling.enabled` | boolean | Yes | `false` | `true` | Enable HPA |
| `autoscaling.minReplicas` | integer | No | - | `3` | Minimum replicas (if HPA enabled) |
| `autoscaling.maxReplicas` | integer | No | - | `10` | Maximum replicas (if HPA enabled) |
| `autoscaling.targetCPUUtilizationPercentage` | integer | No | - | `80` | Target CPU utilization for HPA scaling |
| `podSecurityContext.runAsNonRoot` | boolean | Yes | `true` | `true` | Run as non-root user |
| `podSecurityContext.runAsUser` | integer | Yes | `1337` | `1337` | User ID (Istio default) |

### Relationships
- **DEPENDS_ON**: `IstioControlPlane` (must be healthy before gateway starts)
- **EXPOSES**: Service mesh to external traffic
- **CONSUMES**: Configuration from istiod via xDS protocol

### State Transitions
```
NOT_DEPLOYED → DEPLOYING → HEALTHY → (optional) DEGRADED → HEALTHY
                                   ↓
                              SCALING → HEALTHY (HPA-driven)
```

### Validation Rules
- Service type must be `LoadBalancer` or `NodePort` (not `ClusterIP`)
- At least one port must be exposed
- FIPS mode requires `-distroless` image tag
- Replica count >= 2 for production high availability

---

## Entity 4: EnvironmentValues

### Description
Environment-specific configuration overlays for dev, staging, and production deployments.

### Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `environment` | enum | Yes | One of: `dev`, `staging`, `production` |
| `securityPosture` | enum | Yes | One of: `relaxed`, `moderate`, `strict` |
| `fipsRequired` | boolean | Yes | Whether FIPS 140-2 compliance is mandatory |
| `resourceTier` | enum | Yes | One of: `minimal`, `moderate`, `production` |
| `highAvailability` | boolean | Yes | Whether HA configuration is enabled |

### Relationships
- **APPLIED_TO**: `IstioControlPlane`, `IstioGateway`
- **OVERRIDES**: Base `values.yaml` in each chart

### Configuration Matrix

| Environment | Security | FIPS | Resource Tier | HA | Replicas (istiod) | Replicas (gateway) |
|-------------|----------|------|---------------|----|--------------------|---------------------|
| dev | relaxed | false | minimal | false | 1 | 1 |
| staging | moderate | false | moderate | true | 2 | 2 |
| production | strict | true | production | true | 3 | 3 |

### Validation Rules
- Production environment MUST have `securityPosture: strict`
- Production environment MUST have `highAvailability: true`
- FIPS requirement MUST match AKS node pool configuration

---

## Entity 5: SecurityBaseline

### Description
Pre-configured security policies applied to Istio control plane and gateway in production.

### Components

#### 5.1 PeerAuthentication
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT  # or PERMISSIVE for dev
```

**Attributes:**
- `mtls.mode`: `STRICT` (prod) or `PERMISSIVE` (dev)

**Validation:**
- STRICT mode requires all workloads to have Istio sidecars
- Cannot downgrade from STRICT to PERMISSIVE without rolling restart

#### 5.2 AuthorizationPolicy
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: istio-system
spec:
  {}  # Empty spec = default deny
```

**Attributes:**
- `action`: `ALLOW`, `DENY`, or `CUSTOM`
- `rules`: Array of allow/deny rules
- `selector`: Pod label selector

**Validation:**
- Default-deny policy must exist in production
- ALLOW policies must have explicit source principals

#### 5.3 NetworkPolicy
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: istiod-ingress
  namespace: istio-system
spec:
  podSelector:
    matchLabels:
      app: istiod
  policyTypes:
  - Ingress
  - Egress
  ingress: [...]
  egress: [...]
```

**Attributes:**
- `podSelector`: Label selector for target pods
- `ingress`: Array of allowed ingress rules
- `egress`: Array of allowed egress rules

**Validation:**
- Control plane must allow ingress from API server webhook
- Gateway must allow egress to control plane xDS port (15012)

### Relationships
- **APPLIES_TO**: `IstioControlPlane`, `IstioGateway`
- **ENFORCED_BY**: Istio Envoy proxies (L7), Kubernetes (L3/L4)

### State Transitions
```
NOT_APPLIED → APPLYING → ENFORCED → (optional) UPDATING → ENFORCED
```

---

## Entity 6: FIPSConfiguration

### Description
Configuration entity for FIPS 140-2 compliance settings.

### Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `enabled` | boolean | Yes | Whether FIPS mode is enabled |
| `imageTag` | string | Yes | Image tag with FIPS support (must contain `-distroless`) |
| `boringCryptoValidation` | boolean | Yes | Whether to validate BoringSSL at runtime |
| `nodePoolFips` | boolean | Yes | Whether AKS node pool has FIPS enabled |

### Relationships
- **CONFIGURED_IN**: `IstioControlPlane`, `IstioGateway`
- **REQUIRES**: FIPS-enabled AKS node pool

### Validation Rules
- If `enabled: true`, `imageTag` must contain `-distroless`
- If `enabled: true`, `nodePoolFips` must be `true`
- BoringCrypto validation must pass at deployment time (checked by init container or admission webhook)

### Runtime Validation Commands
```bash
# Verify FIPS image
kubectl describe pod -n istio-system istiod-xxx | grep Image:

# Check GOFIPS environment variable
kubectl exec -n istio-system istiod-xxx -- env | grep GOFIPS

# Validate BoringSSL in Envoy bootstrap
istioctl proxy-config bootstrap -n istio-system istiod-xxx | grep -i boring
```

---

## Entity 7: HelmRelease

### Description
Helm release metadata for installed charts.

### Attributes

| Attribute | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | Yes | Release name (e.g., `istio-base`, `istiod`) |
| `namespace` | string | Yes | Installation namespace (typically `istio-system`) |
| `chart` | string | Yes | Chart name and version |
| `status` | enum | Yes | `deployed`, `failed`, `pending-install`, `pending-upgrade` |
| `revision` | integer | Yes | Release revision number (incremented on upgrade) |
| `values` | object | Yes | Merged values from all sources |

### Relationships
- **MANAGES**: Kubernetes resources (Deployment, Service, ConfigMap, etc.)
- **TRACKS**: Installation and upgrade history

### State Transitions
```
NOT_INSTALLED → INSTALLING → DEPLOYED → UPGRADING → DEPLOYED
                     ↓                         ↓
                   FAILED                ROLLING_BACK → DEPLOYED
                     ↓                         ↓
                ROLLING_BACK → DEPLOYED      FAILED
```

### Operations
- `helm install`: Create new release
- `helm upgrade`: Update existing release (increments revision)
- `helm rollback`: Revert to previous revision
- `helm uninstall`: Delete release and resources

---

## Entity Relationship Diagram

```
┌──────────────────┐
│ IstioBaseChart   │
│ (CRDs)           │
└────────┬─────────┘
         │ PREREQUISITE_FOR
         ↓
┌──────────────────┐     CONFIGURES     ┌──────────────────┐
│ IstioControlPlane│◄──────────────────►│ IstioGateway     │
│ (istiod)         │                     │ (ingressgateway) │
└────────┬─────────┘                     └────────┬─────────┘
         │                                        │
         │ APPLIES_TO                  APPLIES_TO │
         ↓                                        ↓
┌──────────────────────────────────────────────────────────┐
│ SecurityBaseline                                         │
│ ├─ PeerAuthentication (mTLS)                            │
│ ├─ AuthorizationPolicy (default-deny + allowlists)      │
│ └─ NetworkPolicy (L3/L4 isolation)                      │
└──────────────────┬───────────────────────────────────────┘
                   │
                   │ CONFIGURED_BY
                   ↓
┌──────────────────────────────────────────────────────────┐
│ EnvironmentValues                                        │
│ ├─ values-dev.yaml (relaxed security, minimal resources)│
│ ├─ values-staging.yaml (moderate security, HA)          │
│ └─ values-prod.yaml (strict security, FIPS, HA)         │
└──────────────────┬───────────────────────────────────────┘
                   │
                   │ INCLUDES
                   ↓
┌──────────────────────────────────────────────────────────┐
│ FIPSConfiguration                                        │
│ ├─ enabled: true                                         │
│ ├─ imageTag: 1.23.0-distroless                          │
│ └─ nodePoolFips: true                                    │
└──────────────────────────────────────────────────────────┘
```

---

## Configuration Composition Flow

```
Helm Chart (base values.yaml)
         ↓
   + EnvironmentValues (values-{env}.yaml)
         ↓
   = Final Merged Configuration
         ↓
   Helm Install/Upgrade
         ↓
   Kubernetes Resources Created
         ↓
   SecurityBaseline Policies Applied
         ↓
   Istio Control Plane Operational
```

---

## Data Validation Summary

### Pre-Installation Validation
1. AKS cluster version >= 1.26
2. Helm version >= 3.10
3. FIPS node pool exists (if FIPS enabled)
4. Namespace does not have conflicting resources
5. CRDs (base chart) installed before control plane

### Post-Installation Validation
1. All pods in `Running` state
2. istiod proxy-status shows healthy endpoints
3. FIPS validation passes (if enabled)
4. mTLS mode matches expected configuration
5. Authorization policies are enforced
6. Network policies are active

### Upgrade Validation
1. Version compatibility check (can't skip minor versions)
2. CRD schema compatibility
3. Existing workload sidecars compatible with new control plane
4. Canary upgrade success before full rollout

---

## Summary

This data model defines the key configuration entities for the Istio AKS Helm chart implementation. The model emphasizes:
- **Sequential Dependencies**: Base → istiod → gateway
- **Environment Progression**: Dev (relaxed) → Staging (moderate) → Prod (strict)
- **Security Layering**: mTLS (L7) + AuthZ (L7) + NetworkPolicy (L3/L4)
- **FIPS Compliance**: Separate entity ensuring all crypto requirements are met
- **Helm Release Management**: Standard Helm lifecycle operations

All entities are designed to be declarative, version-controlled in Git, and deployed via GitOps workflows.
