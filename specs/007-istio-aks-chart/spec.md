# Feature Specification: Istio AKS Helm Chart with FIPS and Security Baseline

**Feature Branch**: `007-istio-aks-chart`  
**Created**: 2026-05-20  
**Status**: Draft  
**Input**: User description: "Add Helm chart for Istio install on AKS with FIPS mode and the baseline Gateway + security policy configuration. Plan to produce the full values.yaml files for base, istiod, and gateway with FIPS mode and classified security baseline already configured."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy Istio Base (CRDs) to AKS (Priority: P1)

As a platform engineer deploying to a classified AKS cluster, I need to install Istio's custom resource definitions (CRDs) and cluster-wide resources using a Helm chart with FIPS-compliant configuration so that my service mesh foundation meets federal compliance requirements.

**Why this priority**: Without the base CRDs, no other Istio components can be installed. This is the foundational dependency for all Istio functionality and must work in FIPS-enforced environments.

**Independent Test**: Run `helm install istio-base charts/istio/base --values charts/istio/base/values-dev.yaml` and verify all CRDs are created without errors. Confirm FIPS mode is not applicable at this layer (CRDs only).

**Acceptance Scenarios**:

1. **Given** an empty AKS cluster with FIPS enforcement, **When** I install the istio-base chart, **Then** all required Istio CRDs are created (Gateway, VirtualService, DestinationRule, etc.).
2. **Given** istio-base is installed, **When** I run `kubectl get crds | grep istio.io`, **Then** all Istio CRDs are listed.
3. **Given** the base chart is installed, **When** I check the namespace labels, **Then** istio-system namespace is properly labeled for mesh operation.

---

### User Story 2 - Deploy Istio Control Plane (istiod) with FIPS Mode (Priority: P1)

As a platform engineer, I need to deploy the Istio control plane (istiod) with FIPS 140-2 validated cryptographic modules enabled so that all certificate management and mTLS operations comply with classified environment security policies.

**Why this priority**: The control plane is the second mandatory component. Without istiod, there is no service mesh functionality, certificate authority, or sidecar injection. FIPS mode is a hard requirement for classified workloads.

**Independent Test**: Run `helm install istiod charts/istio/istiod --values charts/istio/istiod/values-prod.yaml` and verify the istiod pod starts with FIPS mode enabled. Confirm BoringCrypto is in use for all TLS operations.

**Acceptance Scenarios**:

1. **Given** istio-base is installed, **When** I install istiod with FIPS values, **Then** the istiod deployment uses the FIPS-compliant container image (distroless with BoringSSL).
2. **Given** istiod is running, **When** I check the pod environment, **Then** `GOFIPS=1` is set and TLS libraries report FIPS mode.
3. **Given** istiod is deployed, **When** I inject a sidecar into a test pod, **Then** the sidecar uses FIPS-validated crypto for all mTLS handshakes.
4. **Given** classified security baseline is applied, **When** I inspect the deployment, **Then** pod security context enforces `runAsNonRoot`, read-only root filesystem, and drops all capabilities.

---

### User Story 3 - Deploy Istio Ingress Gateway with Security Policies (Priority: P1)

As a platform engineer, I need to deploy an Istio ingress gateway with pre-configured security policies (strict mTLS, authorized traffic only, baseline NetworkPolicies) so that external traffic entering the mesh is properly validated and controlled.

**Why this priority**: The gateway is the entry point for all external traffic. Without proper security baseline configuration, the mesh is exposed to unauthorized access. This completes the minimum viable Istio installation.

**Independent Test**: Run `helm install istio-ingressgateway charts/istio/gateway --values charts/istio/gateway/values-prod.yaml` and verify the gateway pod enforces strict mTLS and only accepts traffic matching defined authorization policies.

**Acceptance Scenarios**:

1. **Given** istiod is running, **When** I install the ingress gateway with security baseline values, **Then** the gateway deployment uses FIPS images and enforces PeerAuthentication STRICT mode.
2. **Given** the gateway is deployed, **When** an unauthenticated client attempts a connection, **Then** the connection is rejected with mTLS required error.
3. **Given** the security baseline is applied, **When** I check AuthorizationPolicy resources, **Then** default-deny policies are in place with explicit allowlists.
4. **Given** gateway is running, **When** I check NetworkPolicy resources, **Then** ingress controller can only communicate with istiod and mesh workloads, not arbitrary pods.

---

### User Story 4 - Upgrade Istio Versions Declaratively (Priority: P2)

As a platform operator, I need to upgrade Istio from one version to another using `helm upgrade` with a clear upgrade path (base → istiod → gateway) so that I have a reproducible, auditable process for version management in production.

**Why this priority**: Upgrades are critical for security patching and feature adoption but are not required for initial deployment. This story ensures long-term operability.

**Independent Test**: Install Istio 1.22, then upgrade to 1.23 using `helm upgrade` on each chart in sequence. Verify zero downtime and successful version transition.

**Acceptance Scenarios**:

1. **Given** Istio 1.22 is running, **When** I upgrade base chart to 1.23, **Then** CRDs are updated without disrupting running workloads.
2. **Given** base is upgraded, **When** I upgrade istiod with canary settings, **Then** new control plane pods join the cluster and old pods drain gracefully.
3. **Given** istiod is upgraded, **When** I upgrade the gateway, **Then** traffic continues flowing with zero dropped connections.

---

### User Story 5 - Deploy Istio to Multiple Environments (dev, staging, prod) (Priority: P2)

As a platform team, I need to deploy the same Istio Helm charts with environment-specific values files (values-dev.yaml, values-staging.yaml, values-prod.yaml) so that I can maintain consistent mesh architecture while tuning resource limits, replica counts, and security settings per environment.

**Why this priority**: Multi-environment support is essential for GitOps workflows but not required for a single-cluster POC. This enables production-grade adoption.

**Independent Test**: Deploy to three namespaces (istio-dev, istio-staging, istio-prod) using different values files. Verify dev uses minimal replicas and relaxed policies, while prod enforces high availability and strict FIPS.

**Acceptance Scenarios**:

1. **Given** dev values set `replicaCount: 1`, **When** installed, **Then** istiod runs a single replica for cost savings.
2. **Given** prod values set `replicaCount: 3` and pod anti-affinity, **When** installed, **Then** istiod pods spread across availability zones.
3. **Given** dev values disable FIPS, **When** installed, **Then** standard Istio images are used instead of FIPS builds.

---

### Edge Cases

- What happens when FIPS mode is enabled but the AKS node OS doesn't support FIPS kernel modules? Installation succeeds but runtime crypto validation may fail — document prerequisite AKS configuration.
- How does the system handle upgrades if CRD changes introduce breaking schema changes? Manual intervention required — document upgrade runbook with CRD validation steps.
- What if the istio-system namespace already exists with conflicting resources? Helm install fails with conflict error — provide cleanup script or pre-install validation.
- How do we handle air-gapped environments where pulling Istio images from DockerHub is blocked? Document local registry mirroring and override `global.hub` values.
- What happens when multiple ingress gateways are needed (public + private)? Chart should support multiple gateway installations with unique release names.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide three separate Helm charts under `charts/istio/`: `base`, `istiod`, and `gateway`.
- **FR-002**: Each chart MUST have `values-dev.yaml`, `values-staging.yaml`, and `values-prod.yaml` environment-specific configurations.
- **FR-003**: Production values files MUST enable FIPS mode by setting `global.fips.enabled: true` and using FIPS-validated container images (e.g., `istio/pilot:1.23.0-distroless` with BoringCrypto).
- **FR-004**: Production values MUST configure strict mTLS by setting `spec.mtls.mode: STRICT` in PeerAuthentication resources.
- **FR-005**: Production values MUST include baseline AuthorizationPolicy resources enforcing default-deny with explicit allowlists for known services.
- **FR-006**: istiod chart MUST configure pod security context with `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, and `allowPrivilegeEscalation: false`.
- **FR-007**: istiod chart MUST set resource requests and limits suitable for production workloads (e.g., 500m CPU, 2Gi memory for control plane).
- **FR-008**: gateway chart MUST support configurable HorizontalPodAutoscaler with min/max replicas and target CPU utilization (default: 80% CPU).
- **FR-009**: All charts MUST follow the repository's Helm chart conventions from `common-lib` for labels, annotations, and resource naming.
- **FR-010**: Charts MUST support Kubernetes NetworkPolicy resources to restrict control plane and gateway network access.
- **FR-011**: Charts MUST include inline documentation in values.yaml explaining each configuration parameter.
- **FR-012**: Charts MUST be installable using standard `helm install` commands without requiring external scripts or operators.
- **FR-013**: System MUST provide a quickstart guide documenting the installation order (base → istiod → gateway) and verification steps.
- **FR-014**: Charts MUST be upgradable using `helm upgrade` following Istio's official upgrade sequence.
- **FR-015**: Dev values MUST use relaxed security settings (permissive mTLS, no FIPS) for faster iteration cycles.

### Key Entities *(include if feature involves data)*

- **IstioBase Chart**: Helm chart containing Istio CRDs and cluster-wide resources. Minimal configuration, no runtime components.
  - Key attributes: Istio version, CRD definitions, namespace creation.

- **Istiod Chart**: Helm chart for the Istio control plane deployment.
  - Key attributes: Replica count, FIPS mode toggle, resource limits, pod security context, HPA settings, certificate provider (Kubernetes CA vs. external).

- **Gateway Chart**: Helm chart for Istio ingress gateway deployment.
  - Key attributes: Gateway service type (LoadBalancer/NodePort), replica count, autoscaling config, mTLS enforcement, authorization policies, network policies, FIPS mode.

- **Environment Values Files**: YAML files defining environment-specific overrides.
  - Key attributes: dev (minimal resources, permissive policies), staging (moderate resources, semi-strict policies), prod (HA resources, FIPS enabled, strict security).

- **Security Baseline Configuration**: Pre-configured AuthorizationPolicy and PeerAuthentication resources.
  - Key attributes: Default-deny rules, mTLS enforcement level, allowed service principals, ingress allowlists.

## Non-Functional Requirements

- **NFR-001**: Charts MUST pass `helm lint` and `helm template` validation without errors.
- **NFR-002**: FIPS-enabled deployments MUST use only FIPS 140-2 validated cryptographic modules for all TLS operations.
- **NFR-003**: Production configurations MUST support high availability with minimum 3 replicas for istiod and gateway.
- **NFR-004**: Installation and upgrade operations MUST complete within 10 minutes on a standard AKS cluster (defined as: 3 nodes, Standard_D4s_v3 VM size, single availability zone, no GPU).
- **NFR-005**: Documentation MUST include troubleshooting steps for common issues (FIPS validation failures, certificate bootstrapping, upgrade conflicts).
- **NFR-006**: Charts MUST be compatible with Istio versions 1.21+ and Kubernetes 1.26+.
- **NFR-007**: All chart changes MUST be version-controlled in Git with semantic versioning.

## Out of Scope

- Automated Istio version upgrades (user must manually trigger helm upgrade).
- Multi-cluster mesh configuration (single-cluster only).
- Integration with external certificate authorities (uses Kubernetes CA by default).
- Istio Operator-based deployments (deprecated, not used).
- Custom Envoy filter configurations beyond baseline security policies.
- Observability stack deployment (Prometheus, Grafana, Jaeger) — users must deploy separately.
- Service mesh application onboarding automation (sidecar injection is manual per namespace).

## Dependencies

- AKS cluster with Kubernetes 1.26 or later.
- FIPS-enabled AKS node pools (for production environments).
- Helm 3.10 or later.
- kubectl CLI configured with cluster access.
- Access to Istio container images (either DockerHub or local registry mirror).
- Existing `common-lib` chart for shared Helm helpers (from this repository).

## Success Criteria

- All three Istio charts deploy successfully to an AKS cluster using `helm install`.
- FIPS mode is verifiable in production deployments (BoringSSL in use).
- Strict mTLS is enforced for all mesh traffic in production.
- Upgrade from Istio 1.22 to 1.23 succeeds with zero downtime.
- Documentation allows a new engineer to deploy Istio from scratch in under 30 minutes.
- All charts pass CI/CD validation (lint, template, schema validation).
