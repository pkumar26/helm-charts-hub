# Research: Istio AKS Helm Chart with FIPS and Security Baseline

**Feature**: 007-istio-aks-chart  
**Phase**: 0 (Research & Architecture Decisions)  
**Date**: 2026-05-20

## Overview

This document captures research findings, architectural decisions, and best practices for implementing Istio service mesh on Azure Kubernetes Service (AKS) using Helm charts with FIPS 140-2 compliance and security baseline configurations.

---

## Decision 1: Installation Method - Helm vs istioctl vs Operator

### Decision
Use **Helm 3 with Istio's official Helm charts** as the installation method for all three components (base, istiod, gateway).

### Rationale
1. **Declarative GitOps Compatibility**: Helm charts are version-controlled YAML files that integrate seamlessly with GitOps tools (ArgoCD, Flux). Changes are auditable in Git history.

2. **Repeatable Deployments**: `helm install` with values files ensures identical deployments across environments (dev/staging/prod) without manual command-line flag memorization.

3. **Upgrade Path**: `helm upgrade` provides built-in rollback capabilities and diff previewing. Istio's official upgrade guides document Helm-based upgrade sequences.

4. **Classified Environment Requirements**: Classified AKS environments require audit trails for all infrastructure changes. Helm values files in Git provide this automatically.

5. **No Deprecated Tooling**: Istio Operator is deprecated as of Istio 1.23 and not recommended for new deployments.

### Alternatives Considered

| Method | Pros | Cons | Why Rejected |
|--------|------|------|--------------|
| `istioctl install` | Simple for quick demos | Not declarative, no Git audit trail, hard to reproduce exact config | No repeatable process; unsuitable for production |
| Istio Operator | CRD-based, declarative | **Deprecated in Istio 1.23**, complex upgrade path | Official deprecation; would require migration later |
| Manual `kubectl apply` | Full control | No upgrade management, no rollback, high operational burden | No built-in upgrade/rollback; reinvents Helm |

### References
- [Istio Helm Installation Guide](https://istio.io/latest/docs/setup/install/helm/)
- [Istio Operator Deprecation Notice](https://istio.io/latest/blog/2023/operator-deprecation/)
- [NIST SP 800-53 Configuration Management Requirements](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)

---

## Decision 2: Chart Structure - Three Separate Charts

### Decision
Implement **three independent Helm charts** under `charts/istio/`:
1. `base` - CRDs and cluster-wide resources
2. `istiod` - Control plane (Pilot, CA, sidecar injector)
3. `gateway` - Ingress gateway deployment

### Rationale
1. **Istio Architecture Alignment**: Istio's official Helm repository (`istio.io/charts`) separates these components to ensure correct installation order and independent lifecycle management.

2. **Upgrade Safety**: CRD updates (base chart) must be applied before control plane upgrades (istiod). Separating charts enforces this sequence and prevents accidental out-of-order upgrades.

3. **Independent Rollback**: If a gateway configuration breaks, operators can `helm rollback istio-gateway` without affecting the control plane.

4. **Component-Specific Configuration**: Each component has different resource requirements, scaling policies, and security contexts. Separate charts avoid massive conditional logic in templates.

5. **Helm Release Isolation**: Each chart becomes a separate Helm release with independent status tracking, making troubleshooting easier.

### Alternatives Considered

| Approach | Pros | Cons | Why Rejected |
|----------|------|------|--------------|
| Single monolithic chart | One install command | Complex conditionals, violates Istio upgrade order, no independent rollback | Unsafe for production upgrades |
| Helm subchart dependencies | Grouped under parent chart | Helm dependencies don't enforce install order, complicates versioning | Doesn't solve upgrade sequencing |

### Implementation Pattern
```bash
# Installation sequence
helm install istio-base charts/istio/base -n istio-system --create-namespace
helm install istiod charts/istio/istiod -n istio-system --wait
helm install istio-ingressgateway charts/istio/gateway -n istio-system --wait

# Upgrade sequence (same order)
helm upgrade istio-base charts/istio/base -n istio-system
helm upgrade istiod charts/istio/istiod -n istio-system --wait
helm upgrade istio-ingressgateway charts/istio/gateway -n istio-system --wait
```

### References
- [Istio Helm Chart Repository Structure](https://github.com/istio/istio/tree/master/manifests/charts)
- [Istio Upgrade Best Practices](https://istio.io/latest/docs/setup/upgrade/)

---

## Decision 3: FIPS 140-2 Compliance Implementation

### Decision
Enable FIPS mode in production by:
1. Using Istio's **distroless container images with BoringSSL** (FIPS 140-2 validated)
2. Setting `global.fips.enabled: true` in values-prod.yaml
3. Deploying to **AKS FIPS-enabled node pools**
4. Validating BoringCrypto usage in runtime via `istioctl proxy-config bootstrap`

### Rationale
1. **Federal Compliance**: Classified workloads on Azure Government require FIPS 140-2 validated cryptographic modules for all TLS operations.

2. **BoringSSL/BoringCrypto**: Google's BoringSSL fork (used by Istio Envoy) has FIPS 140-2 validation (Certificate #4407). Standard OpenSSL in Istio images is NOT FIPS-validated.

3. **AKS FIPS Node Pools**: Azure provides FIPS 140-2 enabled Ubuntu node images. These must be used in conjunction with FIPS container images.

4. **End-to-End Crypto Validation**: mTLS between workloads, certificate signing by istiod CA, and external TLS termination at gateway all use FIPS-validated crypto when properly configured.

### FIPS Configuration Details

**values-prod.yaml for istiod and gateway:**
```yaml
global:
  fips:
    enabled: true
  
  # Use distroless images with BoringCrypto
  hub: docker.io/istio
  tag: 1.23.0-distroless
  
  # Ensure FIPS environment variable is set
  podDNSSearchNamespaces:
  - istio-system
  
pilot:
  env:
    GOFIPS: "1"  # Enable Go FIPS runtime checks

proxy:
  env:
    GOFIPS: "1"
```

**AKS Node Pool Configuration (Azure CLI):**
```bash
az aks nodepool add \
  --cluster-name <cluster-name> \
  --name fips140 \
  --resource-group <rg> \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --os-sku AzureLinux \
  --enable-fips-image
```

### Validation Steps
1. Check container image: `kubectl describe pod -n istio-system <istiod-pod> | grep Image:`
2. Verify FIPS env: `kubectl exec -n istio-system <istiod-pod> -- env | grep GOFIPS`
3. Validate BoringSSL: `istioctl proxy-config bootstrap -n istio-system <pod> | grep -i boring`
4. Test mTLS crypto: `istioctl authn tls-check <pod> <pod> | grep "STRICT"`

### Alternatives Considered

| Approach | Pros | Cons | Why Rejected |
|----------|------|------|--------------|
| Standard Istio images | Smaller image size | NOT FIPS-compliant, uses OpenSSL | Fails federal compliance requirements |
| Custom FIPS-patched Envoy | Full control | Maintenance burden, no official support, recertification required | Istio's official FIPS images are already validated |
| Software-only FIPS (no FIPS nodes) | Simpler AKS setup | Incomplete compliance (kernel crypto not FIPS) | IL4/IL5 workloads require FIPS at all layers |

### References
- [FIPS 140-2 Certificate #4407 (BoringCrypto)](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4407)
- [Istio FIPS Compliance Documentation](https://istio.io/latest/docs/ops/configuration/security/fips-compliance/)
- [AKS FIPS 140-2 Enabled Nodes](https://learn.microsoft.com/en-us/azure/aks/fips-compliant-node-pools)

---

## Decision 4: Security Baseline Configuration

### Decision
Implement a **classified security baseline** in production values files with:
1. **Strict mTLS** via PeerAuthentication STRICT mode
2. **Default-deny AuthorizationPolicy** with explicit allowlists
3. **Kubernetes NetworkPolicy** for control plane isolation
4. **Pod Security Standards** (runAsNonRoot, readOnlyRootFilesystem, drop all capabilities)
5. **Resource limits** to prevent resource exhaustion attacks

### Rationale
1. **Zero Trust Architecture**: Classified environments assume breach. Strict mTLS ensures all service-to-service traffic is authenticated and encrypted.

2. **Defense in Depth**: Combining Istio AuthorizationPolicy (L7) with NetworkPolicy (L3/L4) provides multiple enforcement layers.

3. **Principle of Least Privilege**: Default-deny AuthorizationPolicy forces explicit declaration of allowed traffic patterns, reducing attack surface.

4. **Container Escape Prevention**: Pod security context settings (non-root, read-only FS) mitigate container breakout vulnerabilities.

5. **DoS Prevention**: CPU/memory limits prevent single compromised workload from consuming cluster resources.

### Security Baseline Components

#### 1. Strict mTLS (PeerAuthentication)
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT  # Reject plaintext traffic
```

#### 2. Default-Deny Authorization (AuthorizationPolicy)
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: istio-system
spec:
  {}  # Empty spec = deny all
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-istiod-webhook
  namespace: istio-system
spec:
  selector:
    matchLabels:
      app: istiod
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces: ["kube-system"]  # Allow API server to webhook
    to:
    - operation:
        ports: ["15017"]
```

#### 3. Network Policy (L3/L4 Isolation)
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
  ingress:
  - from:
    - namespaceSelector: {}  # Allow mesh workloads
    ports:
    - protocol: TCP
      port: 15012  # xDS config distribution
  - from:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: TCP
      port: 15017  # Webhook
```

#### 4. Pod Security Context
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1337  # Istio's default user ID
  fsGroup: 1337
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
```

#### 5. Resource Limits (Production)
```yaml
resources:
  requests:
    cpu: 500m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi
```

### Dev vs Production Security Posture

| Setting | Dev Values | Production Values | Rationale |
|---------|-----------|-------------------|-----------|
| mTLS Mode | PERMISSIVE | STRICT | Dev allows plaintext for debugging |
| AuthorizationPolicy | None | Default-deny + allowlists | Dev prioritizes iteration speed |
| NetworkPolicy | None | Strict ingress/egress | Dev allows unrestricted networking |
| FIPS Mode | Disabled | Enabled | Dev uses standard images for faster pulls |
| Pod Security | Relaxed | Strict (non-root, RO FS) | Dev may need writable FS for debugging |
| Resource Limits | Minimal (100m/512Mi) | Production (500m/2Gi) | Dev conserves cluster resources |

### Alternatives Considered

| Approach | Pros | Cons | Why Rejected |
|----------|------|------|--------------|
| PERMISSIVE mTLS in prod | Gradual migration path | Allows plaintext traffic, fails compliance | Classified environments require encryption always |
| ALLOW-based AuthorizationPolicy only | Simpler policies | Fails-open on policy errors | Default-deny is security best practice |
| No NetworkPolicy | Simpler Kubernetes config | No L3/L4 defense layer | Defense in depth requires multiple layers |
| Privileged pods for control plane | Avoid file permission issues | Massive security risk | Istio runs fine as non-root |

### References
- [Istio Security Best Practices](https://istio.io/latest/docs/ops/best-practices/security/)
- [NSA/CISA Kubernetes Hardening Guide](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

---

## Decision 5: Environment-Specific Values Strategy

### Decision
Provide **three values files per chart** (dev, staging, prod) with progressive security and resource settings:
- `values-dev.yaml`: Minimal resources, permissive security, fast iteration
- `values-staging.yaml`: Moderate resources, semi-strict security, pre-prod testing
- `values-prod.yaml`: HA resources, FIPS + strict security, classified-ready

### Rationale
1. **Cost Optimization**: Dev environments don't need 3-replica HA control planes with 2Gi memory per pod.

2. **Development Velocity**: Developers need PERMISSIVE mTLS and no AuthorizationPolicy to quickly test services.

3. **Staging Parity**: Staging should mirror production topology (replica counts, anti-affinity) but may skip FIPS for cost savings.

4. **GitOps Workflow**: Each environment has a dedicated values file committed to Git. Deployments reference the appropriate file.

### Values File Hierarchy

**Installation Pattern:**
```bash
# Dev
helm install istiod charts/istio/istiod \
  -n istio-system \
  -f charts/istio/istiod/values-dev.yaml

# Staging
helm install istiod charts/istio/istiod \
  -n istio-system \
  -f charts/istio/istiod/values-staging.yaml

# Production
helm install istiod charts/istio/istiod \
  -n istio-system \
  -f charts/istio/istiod/values-prod.yaml
```

### Key Differences by Environment

| Configuration | Dev | Staging | Production |
|---------------|-----|---------|------------|
| Replicas (istiod) | 1 | 2 | 3 |
| Replicas (gateway) | 1 | 2 | 3 |
| Resource Requests | 100m/512Mi | 250m/1Gi | 500m/2Gi |
| FIPS Enabled | false | false | true |
| mTLS Mode | PERMISSIVE | STRICT | STRICT |
| AuthorizationPolicy | None | Baseline | Full baseline + custom |
| NetworkPolicy | None | Basic | Strict |
| HPA Enabled | false | true | true |
| Pod Anti-Affinity | None | Soft | Hard |
| Node Selector | None | None | FIPS node pool |

### Alternatives Considered

| Approach | Pros | Cons | Why Rejected |
|----------|------|------|--------------|
| Single values.yaml with conditionals | One file to maintain | Massive conditionals, hard to audit per-env | Violates simplicity principle |
| Environment-specific charts | Complete isolation | 3x duplication, impossible to keep in sync | Maintainability nightmare |
| Helm values layering (`-f base.yaml -f prod.yaml`) | DRY principle | Harder to audit final merged config | GitOps tools prefer single-file references |

### References
- [Helm Best Practices - Values Files](https://helm.sh/docs/chart_best_practices/values/)
- [GitOps with ArgoCD and Helm](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)

---

## Decision 6: Chart Dependency Strategy

### Decision
Use **Helm chart dependencies** in Chart.yaml to reference Istio's **official upstream charts**, then override with our security baseline values:

```yaml
# charts/istio/istiod/Chart.yaml
dependencies:
- name: istiod
  version: "1.23.0"
  repository: "https://istio-release.storage.googleapis.com/charts"
```

### Rationale
1. **Leverage Upstream Expertise**: Istio's official charts are tested by the Istio community and include all necessary resources.

2. **Automatic Updates**: Bumping Istio version is a single Chart.yaml change, not template rewrites.

3. **Avoid Duplication**: We don't want to copy/paste Istio's 1000+ lines of templates. Dependency management keeps our charts thin.

4. **Override Pattern**: Our charts provide **values overlays** (FIPS settings, security policies) that merge with upstream defaults.

### Implementation Pattern

**Our Chart Structure:**
```
charts/istio/istiod/
├── Chart.yaml              # Declares dependency on upstream istiod
├── values.yaml             # Base overrides (common across envs)
├── values-prod.yaml        # Production overrides (FIPS + security)
└── templates/
    ├── peerauthentication.yaml    # Our custom security resource
    ├── authorizationpolicy.yaml   # Our custom security resource
    └── networkpolicy.yaml         # Our custom security resource
```

**Values Merging:**
- Upstream `istiod` chart provides defaults (image, replicas, service)
- Our `values.yaml` overrides critical settings (e.g., resource requests)
- Our `values-prod.yaml` adds FIPS and security baseline
- Our templates/ add **supplemental** resources (security policies, network policies)

### Alternatives Considered

| Approach | Pros | Cons | Why Rejected |
|----------|------|------|--------------|
| Copy upstream templates | Full control | 1000+ lines to maintain, breaks upgrades | Unmaintainable, loses upstream fixes |
| Fork Istio repo | Can modify anything | Permanent maintenance burden, can't merge upstream | We're not modifying Istio itself |
| No dependencies (minimal wrapper) | Simplest | User must manually install Istio first | Loses Helm dependency management benefits |

### Upgrade Workflow
```bash
# Update Istio version
# 1. Edit charts/istio/istiod/Chart.yaml
dependencies:
- name: istiod
  version: "1.24.0"  # Bump version

# 2. Update dependencies
helm dependency update charts/istio/istiod

# 3. Test locally
helm template istiod charts/istio/istiod \
  -f charts/istio/istiod/values-prod.yaml \
  | kubectl apply --dry-run=server -f -

# 4. Deploy upgrade
helm upgrade istiod charts/istio/istiod \
  -n istio-system \
  -f charts/istio/istiod/values-prod.yaml
```

### References
- [Helm Chart Dependencies](https://helm.sh/docs/helm/helm_dependency/)
- [Istio Official Helm Repository](https://istio-release.storage.googleapis.com/charts)

---

## AKS-Specific Best Practices

### 1. Node Pool Configuration
- **FIPS Node Pools**: Use `--enable-fips-image` for production
- **VM SKU**: Minimum Standard_D4s_v3 (4 vCPU, 16GB RAM) for istiod nodes
- **Availability Zones**: Spread nodes across 3 AZs for HA
- **Node Taints**: Taint control plane nodes to dedicate them to Istio

```bash
az aks nodepool add \
  --cluster-name <cluster> \
  --name istiosystem \
  --resource-group <rg> \
  --node-count 3 \
  --zones 1 2 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-fips-image \
  --node-taints dedicated=istio-system:NoSchedule
```

### 2. Load Balancer Configuration
- Use **Azure LoadBalancer** (not NodePort) for ingress gateway
- Enable **HTTP/2** and **TLS passthrough** at load balancer
- Configure **health probes** on gateway status port (15021)

```yaml
# values-prod.yaml for gateway
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz/ready
    service.beta.kubernetes.io/azure-load-balancer-health-probe-interval: "5"
  externalTrafficPolicy: Local  # Preserve client IP
```

### 3. Azure CNI Considerations
- **CNI Plugin**: Use Azure CNI (not kubenet) for better pod networking
- **Network Policies**: Istio NetworkPolicy requires Azure CNI with Calico or Cilium
- **IP Addressing**: Reserve sufficient IP space (Istio adds sidecar containers to every pod)

### 4. Managed Identity Integration
- Use **AKS Managed Identity** for control plane access to Azure resources
- Configure **Workload Identity** for Istio to access Azure Key Vault (if using external CA)

---

## Decision 7: Observability Add-Ons (Kiali, Prometheus, Grafana)

### Decision
Implement observability add-ons as **optional fourth chart** (`kiali`) that can be installed independently:
- **Core MVP**: base + istiod + gateway (required components)
- **Optional Add-On**: kiali (mesh visualization and troubleshooting)
- **Feature Flag**: `kiali.enabled` controls installation via Helm values

### Rationale
1. **Separation of Concerns**: Kiali is a separate application with its own lifecycle, not part of Istio's core data/control plane.

2. **Optional Nature**: Not all environments need mesh visualization:
   - Dev: Often disabled to conserve resources
   - Staging: Useful for testing
   - Production: May be disabled in air-gapped classified environments
   - Air-gapped: May not have access to Kiali container images

3. **Independent Upgrades**: Kiali versions don't align 1:1 with Istio versions. Operators should upgrade independently.

4. **Resource Overhead**: Kiali adds ~200-500MB memory footprint. Small dev clusters may skip it.

5. **Security Considerations**: Kiali requires read access to Istio configs and Kubernetes resources, which may require additional RBAC auditing in classified environments.

### Implementation Pattern

**Fourth Optional Chart:**
```
charts/istio/
├── base/            # Chart 1: CRDs (required)
├── istiod/          # Chart 2: Control plane (required)
├── gateway/         # Chart 3: Ingress (required)
└── kiali/           # Chart 4: Observability (optional)
    ├── Chart.yaml   # Depends on istiod
    ├── README.md
    ├── values.yaml  # Base configuration
    ├── values-dev.yaml    # Minimal resources, PERMISSIVE mTLS
    ├── values-staging.yaml
    ├── values-prod.yaml   # Production resources, authentication
    └── templates/
        ├── deployment.yaml    # Kiali server
        ├── service.yaml       # Kiali web UI (ClusterIP or LoadBalancer)
        ├── configmap.yaml     # Kiali configuration
        ├── serviceaccount.yaml
        ├── clusterrole.yaml   # Read access to Istio configs
        └── clusterrolebinding.yaml
```

**Installation Sequence:**
```bash
# Core Istio installation (required)
helm install istio-base charts/istio/base -n istio-system --create-namespace
helm install istiod charts/istio/istiod -n istio-system --wait
helm install istio-ingressgateway charts/istio/gateway -n istio-system --wait

# Optional: Install Kiali for mesh observability
helm install kiali charts/istio/kiali -n istio-system --wait
```

**Conditional Installation (values-based):**
```yaml
# environments/production/istio-kiali.values.yaml
enabled: true  # Set to false to skip Kiali

kiali:
  image:
    repository: quay.io/kiali/kiali
    tag: v1.86.0
  
  # Production: Require authentication
  auth:
    strategy: token  # or openid, oauth, anonymous (dev only)
  
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi
  
  # Istio configuration
  externalServices:
    istio:
      rootNamespace: istio-system
      configMapName: istio
      istioApiEnabled: true
  
  # Optional: Integrate with Prometheus/Grafana
  externalServices:
    prometheus:
      url: "http://prometheus:9090"
    grafana:
      enabled: false  # Set true if Grafana is deployed
```

### Alternatives Considered

| Approach | Pros | Cons | Why Rejected |
|----------|------|------|--------------|
| Embed Kiali in istiod chart | One install command | Bloats control plane chart, couples lifecycles | Violates single responsibility principle |
| Require manual Kiali install | Simpler chart structure | No version management, inconsistent configs | Loses Helm benefits |
| Include all observability (Prometheus, Grafana, Jaeger) | Complete observability stack | Massive complexity, most users have existing monitoring | Out of scope; users have varied observability preferences |
| Make Kiali mandatory | Guaranteed observability | Forces overhead on all environments | Dev/air-gapped environments don't need it |

### Kiali Features Enabled by Chart

1. **Mesh Topology Visualization**: Graph view of services, workloads, and traffic flows
2. **Traffic Metrics**: Request rates, latency, error rates per service
3. **Configuration Validation**: Detect misconfigured VirtualServices, DestinationRules
4. **mTLS Status**: Visual indicators showing which services have mTLS enabled
5. **Distributed Tracing** (if Jaeger configured): End-to-end request tracing
6. **Istio Config Browser**: View all Istio CRDs (Gateway, AuthorizationPolicy, etc.)

### When to Skip Kiali

- **Dev Environments**: Developers using `kubectl` and `istioctl` directly
- **CI/CD Pipelines**: Automated testing doesn't need UI visualization
- **Air-Gapped Clusters**: May not have access to Kiali container registry
- **Cost-Constrained Environments**: Small clusters (< 3 nodes) need to conserve resources
- **Classified Environments**: RBAC auditing overhead may delay approval

### Integration with Existing Monitoring

If users already have Prometheus/Grafana:
```yaml
# charts/istio/kiali/values-prod.yaml
kiali:
  externalServices:
    prometheus:
      url: "http://prometheus-k8s.monitoring:9090"  # Existing Prometheus
    grafana:
      enabled: true
      url: "http://grafana.monitoring:3000"
      auth:
        type: bearer
        token: "secret://grafana-token"
```

### Security Considerations for Kiali

**RBAC Requirements:**
- ClusterRole with `get`, `list`, `watch` on all Istio CRDs
- ClusterRole with `get`, `list` on pods, services, deployments (for topology)
- ServiceAccount bound to ClusterRole

**Authentication (Production):**
- **Token Strategy**: Kubernetes ServiceAccount tokens (recommended)
- **OpenID Connect**: Integration with Azure AD or corporate IdP
- **OAuth**: GitHub, Google, or custom OAuth provider
- **Anonymous**: **Never use in production** (dev only)

**Network Policy (Production):**
```yaml
# Allow Kiali to access istiod for config
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: kiali
  namespace: istio-system
spec:
  podSelector:
    matchLabels:
      app: kiali
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: istiod
    ports:
    - protocol: TCP
      port: 15012  # xDS
  - to:
    - namespaceSelector: {}  # Prometheus if in different namespace
```

### References
- [Kiali Documentation](https://kiali.io/docs/)
- [Kiali Installation with Helm](https://kiali.io/docs/installation/installation-guide/helm/)
- [Istio Observability Best Practices](https://istio.io/latest/docs/ops/best-practices/observability/)

---

```bash
az aks update \
  --resource-group <rg> \
  --name <cluster> \
  --enable-oidc-issuer \
  --enable-workload-identity
```

### 5. Monitoring and Logging
- **Azure Monitor**: Enable Container Insights for Istio control plane metrics
- **Log Analytics**: Stream istiod and gateway logs to Log Analytics workspace
- **Prometheus**: Deploy Prometheus Operator for detailed Istio metrics (separate from this chart)

---

## Testing and Validation Strategy

### 1. Chart Validation
```bash
helm lint charts/istio/base
helm lint charts/istio/istiod
helm lint charts/istio/gateway

helm template charts/istio/istiod \
  -f charts/istio/istiod/values-prod.yaml \
  | kubectl apply --dry-run=server -f -
```

### 2. FIPS Validation
```bash
# Check FIPS image
kubectl get deploy -n istio-system istiod -o yaml | grep image:

# Verify GOFIPS environment
kubectl exec -n istio-system deploy/istiod -- env | grep GOFIPS

# Validate BoringSSL in Envoy
istioctl proxy-config bootstrap -n istio-system deploy/istiod | grep -i boring
```

### 3. Security Validation
```bash
# Check mTLS mode
istioctl x authz check <pod>

# Verify strict mTLS enforcement
kubectl get peerauthentication -A

# Test authorization policies
kubectl get authorizationpolicy -A

# Validate network policies
kubectl get networkpolicy -n istio-system
```

### 4. Integration Testing
```bash
# Deploy test workload with sidecar
kubectl create ns test-mesh
kubectl label ns test-mesh istio-injection=enabled
kubectl run test-client --image=curlimages/curl:latest -n test-mesh -- sleep infinity

# Test mTLS connectivity
kubectl exec -n test-mesh test-client -- curl http://httpbin.test-mesh:8000/get
```

---

## Summary of Key Research Outcomes

| Research Area | Decision | Key Rationale |
|---------------|----------|---------------|
| Installation Method | Helm charts | GitOps-ready, auditable, repeatable deployments |
| Chart Structure | 3 separate charts (base/istiod/gateway) | Matches Istio architecture, enables independent lifecycle |
| FIPS Compliance | distroless + BoringSSL images on FIPS node pools | FIPS 140-2 Certificate #4407, required for classified workloads |
| Security Baseline | Strict mTLS + default-deny AuthZ + NetworkPolicy | Zero trust, defense in depth, least privilege |
| Environment Strategy | 3 values files (dev/staging/prod) | Cost optimization + security progression + GitOps |
| Chart Dependencies | Upstream Istio charts + our security overlays | Leverage upstream expertise, avoid duplication |

All NEEDS CLARIFICATION items resolved. Ready to proceed to Phase 1 (Design & Contracts).
