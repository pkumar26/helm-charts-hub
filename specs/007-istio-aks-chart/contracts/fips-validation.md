# Contract: FIPS 140-2 Validation Checklist

**Feature**: 007-istio-aks-chart  
**Contract Type**: FIPS Compliance Verification  
**Date**: 2026-05-20

## Purpose

This contract defines the validation steps and acceptance criteria for FIPS 140-2 compliance in Istio deployments on AKS.

---

## FIPS 140-2 Overview

### What is FIPS 140-2?

**FIPS 140-2** (Federal Information Processing Standard 140-2) is a U.S. government security standard that specifies requirements for cryptographic modules. It is mandatory for classified and regulated workloads on Azure Government and DoD clouds.

### Why FIPS for Istio?

Istio service mesh performs cryptographic operations:
- **mTLS certificate generation** (istiod acts as Certificate Authority)
- **TLS handshakes** (Envoy proxy in sidecars and gateways)
- **JWT token validation** (authorization policies)

All cryptographic operations must use **FIPS 140-2 validated cryptographic modules** to comply with federal requirements.

---

## FIPS Implementation in Istio

### BoringSSL/BoringCrypto

Istio uses **BoringSSL** (Google's fork of OpenSSL) in Envoy proxy. The FIPS-validated variant is called **BoringCrypto**.

- **FIPS Certificate**: #4407
- **Validation Date**: 2020-09-02
- **Modules**: BoringCrypto for Android, BoringCrypto for Linux
- **Certificate Link**: https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4407

### FIPS-Enabled Istio Images

Istio provides **distroless** images with BoringCrypto compiled in:
- `istio/pilot:1.23.0-distroless` (for istiod)
- `istio/proxyv2:1.23.0-distroless` (for Envoy proxies)

**Standard images** (without `-distroless` suffix) use OpenSSL and are **NOT FIPS-compliant**.

---

## Pre-Deployment Validation

### 1. AKS Cluster FIPS Configuration

#### Verify FIPS-Enabled Node Pools

```bash
# List node pools with FIPS status
az aks nodepool list \
  --cluster-name <cluster-name> \
  --resource-group <resource-group> \
  --query "[].{name:name, fipsEnabled:enableFips}" \
  -o table
```

**Expected Output:**
```
name          fipsEnabled
------------  ------------
istiosystem   true
```

#### Check Node OS FIPS Status

```bash
# SSH into a node and check FIPS kernel mode
kubectl debug node/<node-name> -it --image=ubuntu -- chroot /host

# Inside the node shell
cat /proc/sys/crypto/fips_enabled
# Output: 1 (FIPS enabled)
```

**Acceptance Criteria:**
- ✅ At least one node pool has `enableFips: true`
- ✅ Nodes report `/proc/sys/crypto/fips_enabled = 1`
- ❌ If FIPS not enabled at node level → Reconfigure AKS node pool

---

### 2. Helm Values Validation

#### Verify FIPS Configuration in values-prod.yaml

**istiod values-prod.yaml:**
```yaml
global:
  fips:
    enabled: true
  hub: docker.io/istio
  tag: 1.23.0-distroless  # Must contain "-distroless"

pilot:
  image: pilot
  tag: 1.23.0-distroless
  env:
    GOFIPS: "1"  # Enable Go FIPS runtime checks

# Pod scheduled to FIPS node pool
nodeSelector:
  fips: "true"  # Match FIPS node pool label
```

**gateway values-prod.yaml:**
```yaml
global:
  fips:
    enabled: true
  hub: docker.io/istio
  tag: 1.23.0-distroless

proxy:
  image: proxyv2
  tag: 1.23.0-distroless
  env:
    GOFIPS: "1"

nodeSelector:
  fips: "true"
```

**Acceptance Criteria:**
- ✅ `global.fips.enabled: true` is set
- ✅ All image tags contain `-distroless` suffix
- ✅ `GOFIPS: "1"` environment variable is set
- ✅ `nodeSelector` targets FIPS node pool
- ❌ If using standard images → Update to `-distroless`

---

## Post-Deployment Validation

### 3. Container Image Verification

#### Check Deployed Images

```bash
# istiod image
kubectl get deployment -n istio-system istiod -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: docker.io/istio/pilot:1.23.0-distroless

# Gateway image
kubectl get deployment -n istio-system istio-ingressgateway -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: docker.io/istio/proxyv2:1.23.0-distroless
```

**Acceptance Criteria:**
- ✅ All images contain `-distroless` in the tag
- ❌ If standard image found → Redeploy with correct values

---

### 4. GOFIPS Environment Variable Check

```bash
# Check istiod environment
kubectl exec -n istio-system deploy/istiod -- env | grep GOFIPS
# Expected: GOFIPS=1

# Check gateway environment
kubectl exec -n istio-system deploy/istio-ingressgateway -- env | grep GOFIPS
# Expected: GOFIPS=1
```

**Acceptance Criteria:**
- ✅ `GOFIPS=1` is present in all control plane and gateway pods
- ❌ If missing → Update values files and redeploy

---

### 5. BoringSSL Validation in Envoy

#### Check Envoy Bootstrap Configuration

```bash
# Get istiod pod name
ISTIOD_POD=$(kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].metadata.name}')

# Extract Envoy bootstrap config
istioctl proxy-config bootstrap -n istio-system $ISTIOD_POD | grep -i boring
```

**Expected Output:**
```json
"tls_certificates": {
  "private_key_provider": {
    "provider_name": "cryptomb",
    "typed_config": {
      "@type": "type.googleapis.com/envoy.extensions.private_key_providers.cryptomb.v3alpha.CryptoMbPrivateKeyMethodConfig"
    }
  }
}
```

**Acceptance Criteria:**
- ✅ Bootstrap config references BoringSSL/CryptoMb provider
- ✅ No references to OpenSSL
- ❌ If OpenSSL detected → Image is not FIPS-compliant

---

### 6. TLS Certificate Validation

#### Verify Certificate Authority

```bash
# Check istiod CA certificate
kubectl get secret -n istio-system istio-ca-secret -o jsonpath='{.data.ca-cert\.pem}' | base64 -d | openssl x509 -noout -text

# Verify signature algorithm uses FIPS-approved algorithms
# Allowed: RSA 2048/3072/4096, ECDSA P-256/P-384
# Not allowed: RSA 1024, MD5, SHA1
```

**Expected Output:**
```
Signature Algorithm: sha256WithRSAEncryption
Public Key Algorithm: rsaEncryption
    RSA Public-Key: (2048 bit)
```

**Acceptance Criteria:**
- ✅ Signature algorithm is SHA-256 or stronger
- ✅ RSA key size >= 2048 bits
- ❌ If weak crypto detected → Regenerate CA certificate

---

### 7. mTLS Connection Validation

#### Test mTLS Between Workloads

```bash
# Deploy test workloads
kubectl create ns test-mesh
kubectl label ns test-mesh istio-injection=enabled

kubectl run client -n test-mesh --image=curlimages/curl:latest -- sleep infinity
kubectl run server -n test-mesh --image=hashicorp/http-echo:latest -- -text="hello"

# Check mTLS status
istioctl authn tls-check client.test-mesh.svc.cluster.local server.test-mesh.svc.cluster.local
```

**Expected Output:**
```
HOST:PORT                                     STATUS       SERVER        CLIENT     AUTHN POLICY     DESTINATION RULE
server.test-mesh.svc.cluster.local:80        OK           mTLS          mTLS       default/istio-system     -
```

**Acceptance Criteria:**
- ✅ Status shows `mTLS` for both SERVER and CLIENT
- ✅ Connection succeeds (HTTP 200)
- ❌ If plaintext detected → PeerAuthentication policy not enforced

---

### 8. Cipher Suite Validation

#### Check Allowed TLS Ciphers

```bash
# Get gateway pod
GW_POD=$(kubectl get pod -n istio-system -l app=istio-ingressgateway -o jsonpath='{.items[0].metadata.name}')

# Check listener config
istioctl proxy-config listener $GW_POD -n istio-system -o json | jq '.[].filterChains[].tlsContext.commonTlsContext.tlsParams'
```

**Expected FIPS-Compliant Cipher Suites:**
```json
{
  "tlsMinimumProtocolVersion": "TLSv1_2",
  "tlsMaximumProtocolVersion": "TLSv1_3",
  "cipherSuites": [
    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
  ]
}
```

**Acceptance Criteria:**
- ✅ TLS 1.2 or 1.3 minimum
- ✅ Only FIPS-approved ciphers (AES-GCM, RSA/ECDSA)
- ❌ If weak ciphers detected (RC4, DES, 3DES) → Reconfigure

---

### 9. Runtime Crypto Library Check

#### Verify BoringSSL Library in Container

```bash
# Enter istiod container
kubectl exec -n istio-system deploy/istiod -c discovery -- sh

# Check linked libraries
ldd /usr/local/bin/pilot-discovery | grep -i boring
# Expected: libcrypto.so -> /usr/local/lib/libcrypto.so (BoringSSL)

# Check for OpenSSL (should NOT be present)
ldd /usr/local/bin/pilot-discovery | grep -i openssl
# Expected: (no output)
```

**Acceptance Criteria:**
- ✅ BoringSSL library is loaded
- ✅ OpenSSL is NOT present
- ❌ If OpenSSL detected → Wrong image variant

---

### 10. Audit Log Verification

#### Check AKS Audit Logs for FIPS Violations

```bash
# Query Azure Log Analytics
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query '
    AzureDiagnostics
    | where Category == "kube-audit"
    | where log_s contains "crypto" or log_s contains "fips"
    | where log_s contains "violation" or log_s contains "non-compliant"
    | project TimeGenerated, log_s
  '
```

**Acceptance Criteria:**
- ✅ No FIPS violation audit logs
- ❌ If violations found → Investigate and remediate

---

## Continuous Monitoring

### Automated FIPS Validation (Recommended)

Deploy a **CronJob** to periodically validate FIPS compliance:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: fips-validation
  namespace: istio-system
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: validator
            image: istio/istioctl:1.23.0
            command:
            - /bin/sh
            - -c
            - |
              # Run validation checks
              kubectl get deploy -n istio-system -o yaml | grep 'distroless' || exit 1
              istioctl verify-install || exit 1
              echo "FIPS validation passed"
          restartPolicy: OnFailure
```

---

## Troubleshooting Guide

### Issue: Pods not using FIPS images

**Symptom:**
```bash
kubectl get deploy -n istio-system istiod -o yaml | grep image:
# Shows: istio/pilot:1.23.0 (missing -distroless)
```

**Resolution:**
1. Update `values-prod.yaml` to use `-distroless` images
2. Run `helm upgrade` to apply changes
3. Delete pods to force recreation with new images

---

### Issue: GOFIPS not set

**Symptom:**
```bash
kubectl exec -n istio-system deploy/istiod -- env | grep GOFIPS
# (no output)
```

**Resolution:**
1. Add `GOFIPS: "1"` to `pilot.env` in values
2. Run `helm upgrade`
3. Restart istiod deployment

---

### Issue: mTLS not enforcing FIPS crypto

**Symptom:**
Connections succeed but TLS inspection shows non-FIPS ciphers.

**Resolution:**
1. Verify PeerAuthentication policy is set to STRICT
2. Check that workload sidecars are using distroless images
3. Recreate pods to inject new sidecar configuration

---

## Compliance Reporting

### Generate FIPS Compliance Report

```bash
#!/bin/bash
# fips-compliance-report.sh

echo "=== FIPS 140-2 Compliance Report ==="
echo "Date: $(date)"
echo "Cluster: $(kubectl config current-context)"
echo ""

echo "1. AKS Node Pool FIPS Status:"
az aks nodepool list \
  --cluster-name <cluster> \
  --resource-group <rg> \
  --query "[].{name:name, fips:enableFips}" \
  -o table

echo ""
echo "2. Istio Image Versions:"
kubectl get deploy -n istio-system -o json | \
  jq -r '.items[] | .metadata.name + ": " + .spec.template.spec.containers[0].image'

echo ""
echo "3. GOFIPS Environment:"
for pod in $(kubectl get pod -n istio-system -l app=istiod -o name); do
  echo "$pod:"
  kubectl exec -n istio-system $pod -- env | grep GOFIPS
done

echo ""
echo "4. mTLS Status:"
istioctl proxy-status

echo ""
echo "=== Report Complete ==="
```

**Save report to Git:**
```bash
./fips-compliance-report.sh > reports/fips-compliance-$(date +%Y%m%d).txt
git add reports/
git commit -m "FIPS compliance report $(date +%Y-%m-%d)"
```

---

## Summary

This FIPS validation checklist ensures:
- ✅ AKS nodes have FIPS-enabled kernel
- ✅ Istio uses distroless images with BoringCrypto
- ✅ GOFIPS environment variable is set
- ✅ mTLS uses FIPS-approved ciphers
- ✅ No OpenSSL libraries present in containers
- ✅ Continuous monitoring via CronJob

**Acceptance Gate:**
All validation steps must PASS before deploying to classified production environments (IL4/IL5/FedRAMP High).
