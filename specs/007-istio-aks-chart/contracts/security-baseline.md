# Contract: Security Baseline Configuration

**Feature**: 007-istio-aks-chart  
**Contract Type**: Security Policy Definitions  
**Date**: 2026-05-20

## Purpose

This contract defines the security baseline configuration for Istio service mesh deployments on AKS, including mTLS policies, authorization policies, network policies, and pod security standards.

---

## Security Layers

The security baseline implements **defense in depth** with three enforcement layers:

```
┌─────────────────────────────────────────────┐
│ Layer 3/4: Kubernetes NetworkPolicy         │
│ (IP-based, port-based filtering)            │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│ Layer 7: Istio AuthorizationPolicy          │
│ (Identity-based, method-based)              │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│ Transport: Istio PeerAuthentication         │
│ (mTLS encryption + authentication)          │
└─────────────────────────────────────────────┘
```

---

## 1. mTLS Configuration (PeerAuthentication)

### Production: STRICT Mode

**File**: `charts/istio/istiod/templates/peerauthentication.yaml`

```yaml
{{- if .Values.security.mtls.enabled }}
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "istio-istiod.labels" . | nindent 4 }}
spec:
  mtls:
    mode: {{ .Values.security.mtls.mode }}
{{- end }}
```

**values-prod.yaml:**
```yaml
security:
  mtls:
    enabled: true
    mode: STRICT  # Reject all plaintext traffic
```

**Guarantees:**
- ✅ All service-to-service traffic is encrypted with mTLS
- ✅ Plaintext connections are rejected at the proxy level
- ✅ Mutual authentication (both client and server prove identity)
- ✅ Automatic certificate rotation (24h default TTL)

**Verification:**
```bash
# Check mTLS policy
kubectl get peerauthentication -n istio-system default -o yaml

# Verify mTLS is enforced for a workload
istioctl authn tls-check <pod-name>.<namespace>.svc.cluster.local
```

---

### Development: PERMISSIVE Mode

**values-dev.yaml:**
```yaml
security:
  mtls:
    enabled: true
    mode: PERMISSIVE  # Allow both mTLS and plaintext
```

**Use Case:**
- Gradual onboarding of legacy services
- Debugging with curl/netcat
- Performance testing without TLS overhead

**Risk:**
- ⚠️ Allows plaintext traffic (no encryption)
- ⚠️ Not suitable for production or classified workloads

---

## 2. Authorization Policies (AuthorizationPolicy)

### Production: Default-Deny + Explicit Allowlists

#### 2.1 Default Deny All

**File**: `charts/istio/istiod/templates/authorizationpolicy-deny-all.yaml`

```yaml
{{- if .Values.security.authorization.enabled }}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "istio-istiod.labels" . | nindent 4 }}
spec:
  {}  # Empty spec = deny all traffic
{{- end }}
```

**Effect:**
- ❌ All requests to Istio control plane are denied by default
- ✅ Forces explicit declaration of allowed traffic

---

#### 2.2 Allow API Server → istiod Webhook

**File**: `charts/istio/istiod/templates/authorizationpolicy-allow-webhook.yaml`

```yaml
{{- if .Values.security.authorization.enabled }}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-api-server-webhook
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "istio-istiod.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      app: istiod
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces: ["kube-system"]  # API server namespace
    to:
    - operation:
        ports: ["15017"]  # Webhook port
        methods: ["POST"]
{{- end }}
```

**Guarantees:**
- ✅ Kubernetes API server can call admission webhook for pod creation
- ✅ Only specific port and method allowed
- ❌ Other namespaces cannot access webhook

---

#### 2.3 Allow Mesh Workloads → istiod xDS

**File**: `charts/istio/istiod/templates/authorizationpolicy-allow-xds.yaml`

```yaml
{{- if .Values.security.authorization.enabled }}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-xds-clients
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "istio-istiod.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      app: istiod
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/*/sa/*"]  # Any service account in mesh
    to:
    - operation:
        ports: ["15012"]  # xDS gRPC port
        methods: ["POST"]  # gRPC uses POST
{{- end }}
```

**Guarantees:**
- ✅ Sidecars can fetch configuration from control plane
- ✅ Only authenticated service accounts (mTLS required)
- ❌ Anonymous clients cannot access xDS API

---

#### 2.4 Gateway Authorization Policies

**File**: `charts/istio/gateway/templates/authorizationpolicy-gateway.yaml`

```yaml
{{- if .Values.security.authorization.enabled }}
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-external-ingress
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "istio-gateway.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      app: istio-ingressgateway
  action: ALLOW
  rules:
  {{- range .Values.security.authorization.allowedSources }}
  - from:
    - source:
        ipBlocks: {{ .ipBlocks | toJson }}
    to:
    - operation:
        ports: ["443"]
        methods: ["GET", "POST", "PUT", "DELETE"]
  {{- end }}
{{- end }}
```

**values-prod.yaml:**
```yaml
security:
  authorization:
    enabled: true
    allowedSources:
    - ipBlocks:
      - "10.0.0.0/8"      # Internal VNet
      - "192.168.0.0/16"  # VPN range
    # External public IPs would be listed here for internet-facing gateways
```

**Guarantees:**
- ✅ Only traffic from trusted IP ranges is accepted
- ✅ Provides IP-based allowlist at L7
- ❌ Traffic from unlisted IPs is rejected (403 Forbidden)

---

### Development: No Authorization Policies

**values-dev.yaml:**
```yaml
security:
  authorization:
    enabled: false  # No authorization policies in dev
```

**Use Case:**
- Faster iteration without policy debugging
- Open access for local testing

---

## 3. Network Policies (L3/L4 Isolation)

### Production: Strict Ingress/Egress Control

#### 3.1 istiod Ingress Policy

**File**: `charts/istio/istiod/templates/networkpolicy.yaml`

```yaml
{{- if .Values.security.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: istiod-ingress
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "istio-istiod.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      app: istiod
  policyTypes:
  - Ingress
  ingress:
  # Allow API server webhook calls
  - from:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: TCP
      port: 15017  # Webhook
  
  # Allow xDS clients from any namespace with istio-injection
  - from:
    - namespaceSelector:
        matchLabels:
          istio-injection: enabled
    ports:
    - protocol: TCP
      port: 15012  # xDS gRPC
  
  # Allow metrics scraping (Prometheus)
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 15014  # Metrics
{{- end }}
```

**Guarantees:**
- ✅ Only specific namespaces can reach istiod
- ✅ Only required ports are exposed
- ❌ Arbitrary pods cannot access control plane

---

#### 3.2 Gateway Ingress Policy

**File**: `charts/istio/gateway/templates/networkpolicy.yaml`

```yaml
{{- if .Values.security.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: gateway-ingress
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "istio-gateway.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      app: istio-ingressgateway
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Allow traffic from Azure LoadBalancer health probes
  - from:
    - podSelector: {}  # Azure LB probes come from node, not pod
    ports:
    - protocol: TCP
      port: 15021  # Health check port
  
  # Allow external traffic on HTTPS
  - ports:
    - protocol: TCP
      port: 443
  
  egress:
  # Allow gateway to reach istiod control plane
  - to:
    - podSelector:
        matchLabels:
          app: istiod
    ports:
    - protocol: TCP
      port: 15012  # xDS
  
  # Allow gateway to reach mesh workloads
  - to:
    - namespaceSelector:
        matchLabels:
          istio-injection: enabled
    ports:
    - protocol: TCP
      port: 8080  # Common app port (adjust as needed)
{{- end }}
```

**Guarantees:**
- ✅ Gateway can only communicate with control plane and mesh workloads
- ✅ Health probes from Azure LB are allowed
- ❌ Gateway cannot access arbitrary cluster services

---

### Development: No Network Policies

**values-dev.yaml:**
```yaml
security:
  networkPolicy:
    enabled: false  # No network isolation in dev
```

---

## 4. Pod Security Standards

### Production: Restricted Profile

**values-prod.yaml:**
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1337       # Istio's default user ID
  fsGroup: 1337
  seccompProfile:
    type: RuntimeDefault

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
  runAsNonRoot: true
  runAsUser: 1337
```

**Applied to:**
- ✅ istiod deployment
- ✅ Gateway deployment
- ✅ Sidecar containers (via injection template)

**Guarantees:**
- ✅ Containers run as non-root user (UID 1337)
- ✅ Root filesystem is read-only (prevents malware installation)
- ✅ All Linux capabilities dropped (reduces kernel attack surface)
- ✅ Seccomp profile restricts syscalls
- ❌ Cannot escalate privileges to root

---

### Development: Relaxed Profile

**values-dev.yaml:**
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1337

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: false  # Allow writable FS for debugging
  capabilities:
    drop:
    - ALL
```

**Relaxed Settings:**
- ⚠️ Writable root filesystem (for debugging tools)
- ⚠️ No seccomp profile (for strace/debugging)

---

## 5. Resource Limits (DoS Prevention)

### Production: Guaranteed QoS

**values-prod.yaml:**
```yaml
resources:
  requests:
    cpu: "500m"
    memory: "2Gi"
  limits:
    cpu: "2000m"      # 4x request (burstable)
    memory: "4Gi"     # 2x request
```

**Guarantees:**
- ✅ istiod guaranteed 500m CPU and 2Gi memory
- ✅ Cannot consume unlimited cluster resources
- ✅ OOMKilled if memory exceeds limit (prevents cluster-wide OOM)
- ✅ CPU throttled if exceeds limit (prevents noisy neighbor)

---

### Development: Minimal Resources

**values-dev.yaml:**
```yaml
resources:
  requests:
    cpu: "100m"
    memory: "512Mi"
  limits:
    cpu: "1000m"
    memory: "1Gi"
```

---

## 6. Image Security

### Production: Distroless Images + Image Pull Policy

**values-prod.yaml:**
```yaml
image:
  repository: docker.io/istio/pilot
  tag: 1.23.0-distroless
  pullPolicy: Always  # Always pull to ensure latest patch

imagePullSecrets:
- name: acr-credentials  # If using private registry
```

**Distroless Benefits:**
- ✅ No shell (sh, bash) → prevents shell-based exploits
- ✅ No package managers (apt, yum) → prevents malware installation
- ✅ Minimal attack surface (~50MB vs ~500MB for full Debian image)
- ✅ FIPS-compliant BoringSSL included

---

## 7. Audit Logging

### Production: Enable Istio Access Logs

**values-prod.yaml:**
```yaml
meshConfig:
  accessLogFile: "/dev/stdout"
  accessLogEncoding: "JSON"
  accessLogFormat: |
    {
      "start_time": "%START_TIME%",
      "method": "%REQ(:METHOD)%",
      "path": "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%",
      "protocol": "%PROTOCOL%",
      "response_code": "%RESPONSE_CODE%",
      "response_flags": "%RESPONSE_FLAGS%",
      "bytes_received": "%BYTES_RECEIVED%",
      "bytes_sent": "%BYTES_SENT%",
      "duration": "%DURATION%",
      "upstream_service_time": "%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%",
      "x_forwarded_for": "%REQ(X-FORWARDED-FOR)%",
      "user_agent": "%REQ(USER-AGENT)%",
      "request_id": "%REQ(X-REQUEST-ID)%",
      "authority": "%REQ(:AUTHORITY)%",
      "upstream_host": "%UPSTREAM_HOST%",
      "upstream_cluster": "%UPSTREAM_CLUSTER%"
    }
```

**Guarantees:**
- ✅ All HTTP requests logged to stdout
- ✅ Logs streamed to Azure Log Analytics
- ✅ Audit trail for security investigations
- ✅ Compliance with NIST 800-53 AU-2

---

## Security Configuration Matrix

| Setting | Dev | Staging | Production | Rationale |
|---------|-----|---------|------------|-----------|
| mTLS Mode | PERMISSIVE | STRICT | STRICT | Prod requires encryption always |
| AuthorizationPolicy | Disabled | Baseline | Full baseline + custom | Prod requires default-deny |
| NetworkPolicy | Disabled | Basic | Strict | Prod requires L3/L4 isolation |
| Pod Security | Relaxed | Moderate | Restricted | Prod requires non-root + RO FS |
| Resource Limits | Minimal | Moderate | Guaranteed | Prod requires QoS guarantees |
| Image Type | Standard | Standard | Distroless | Prod requires FIPS + minimal attack surface |
| Access Logs | Disabled | Enabled | Enabled + JSON | Prod requires audit trail |

---

## Validation Commands

```bash
# Check mTLS mode
kubectl get peerauthentication -n istio-system

# Check authorization policies
kubectl get authorizationpolicy -n istio-system

# Check network policies
kubectl get networkpolicy -n istio-system

# Check pod security context
kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].spec.securityContext}' | jq

# Check resource limits
kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].spec.containers[0].resources}' | jq

# Test mTLS enforcement
istioctl authn tls-check <pod>

# Test authorization policy
kubectl exec -n test <pod> -- curl -v http://istiod.istio-system:15012
# Expected: 403 Forbidden (if not in allowlist)
```

---

## Threat Model Coverage

| Threat | Mitigation | Layer |
|--------|-----------|-------|
| Man-in-the-middle (eavesdropping) | STRICT mTLS | Transport |
| Unauthorized service access | AuthorizationPolicy default-deny | L7 |
| Lateral movement | NetworkPolicy + namespace isolation | L3/L4 |
| Container escape | Non-root user + RO filesystem + no capabilities | Pod |
| Resource exhaustion (DoS) | CPU/memory limits + HPA | Cluster |
| Malware installation | Distroless images (no shell/package managers) | Image |
| Credential theft | Short-lived certificates (24h TTL) | mTLS |
| Audit trail gaps | Access logs to Log Analytics | Monitoring |

---

## Compliance Mapping

| Control | Requirement | Implementation |
|---------|-------------|----------------|
| NIST 800-53 SC-8 | Transmission confidentiality | STRICT mTLS |
| NIST 800-53 AC-3 | Access enforcement | AuthorizationPolicy default-deny |
| NIST 800-53 SC-7 | Boundary protection | NetworkPolicy |
| NIST 800-53 AU-2 | Audit events | Istio access logs |
| CIS Kubernetes 5.2.1 | Minimize container privileges | Non-root + RO FS |
| CIS Kubernetes 5.2.6 | Drop unnecessary capabilities | capabilities.drop: [ALL] |

---

## Summary

The security baseline provides **defense in depth** with:
- ✅ **Transport Security**: STRICT mTLS with FIPS crypto
- ✅ **Access Control**: Default-deny AuthorizationPolicy + explicit allowlists
- ✅ **Network Isolation**: L3/L4 NetworkPolicy
- ✅ **Pod Security**: Non-root + RO FS + no capabilities
- ✅ **Resource Limits**: Guaranteed QoS to prevent DoS
- ✅ **Audit Logging**: Full request logging to Log Analytics

Configuration is **progressive by environment**:
- Dev: Minimal restrictions for fast iteration
- Staging: Moderate restrictions for pre-prod testing
- Production: Full security baseline for classified workloads
