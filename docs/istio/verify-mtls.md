# How to Verify mTLS Encryption in Istio Ambient Mode

## Current State Check

### 1. Check PeerAuthentication Policy
```bash
kubectl get peerauthentication -A
```

### 2. View ztunnel Logs (Shows Encrypted Connections)
```bash
kubectl logs -n istio-system -l app=ztunnel --tail=20 | grep "identity"
```

Look for lines with:
- `src.identity="spiffe://..."` = Source has mesh identity
- `dst.identity="spiffe://..."` = Destination has mesh identity
- `dst.hbone_addr` = Using HBONE (encrypted tunnel)

**If you see both identities → mTLS is active ✅**

### 3. Check in Kiali
Open Kiali → Graph view → Display Settings → Enable "Security" badge
- 🔒 Lock icon = mTLS encrypted
- ⚠️ Warning = Plaintext allowed (PERMISSIVE mode)

---

## Enable Strict mTLS (Enforce Encryption)

### Option 1: Namespace-level (default namespace only)
```bash
kubectl apply -f mtls-strict-mode.yaml
```

### Option 2: Global (all namespaces)
Edit `mtls-strict-mode.yaml`, uncomment the global section, then:
```bash
kubectl apply -f mtls-strict-mode.yaml
```

### Option 3: Quick command (namespace-level)
```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default-strict-mtls
  namespace: default
spec:
  mtls:
    mode: STRICT
EOF
```

---

## Test mTLS is Working

### Test 1: Check ztunnel logs after enabling STRICT
```bash
# Enable strict mode
kubectl apply -f mtls-strict-mode.yaml

# Generate some traffic
curl http://20.252.30.248/

# Check logs - should see only encrypted connections
kubectl logs -n istio-system -l app=ztunnel --tail=20 --since=1m | grep "identity"
```

### Test 2: Verify in Kiali
1. Open Kiali Graph view
2. Enable "Security" display option
3. Generate traffic
4. All connections should show 🔒 lock icon

### Test 3: Try plaintext connection (should fail with STRICT mode)
```bash
# From outside the mesh, try to connect without mTLS
kubectl run test-client --rm -it --image=curlimages/curl -- sh
# Inside the pod:
curl http://sampleapp.default.svc.cluster.local/
# Should fail or timeout if STRICT mode is enforced
```

---

## mTLS Modes Explained

### PERMISSIVE (Current Default)
- ✅ Accepts both mTLS and plaintext
- ✅ Good for gradual migration
- ⚠️ Less secure - plaintext is allowed
- **Use when**: Adding services to mesh incrementally

### STRICT (Recommended for Production)
- 🔒 Only accepts mTLS connections
- ❌ Rejects plaintext traffic
- ✅ Maximum security
- **Use when**: All services are in the mesh

### DISABLE (Not Recommended)
- ❌ No mTLS encryption
- ⚠️ All traffic is plaintext
- **Use when**: Troubleshooting or legacy apps

---

## Troubleshooting

### Issue: No mTLS connections after labeling namespace
**Solution**: Restart pods to pick up mesh settings
```bash
kubectl rollout restart deployment -n default
```

### Issue: Services can't communicate after enabling STRICT
**Cause**: Some pods/services are not in the mesh yet
**Solution**: 
1. Check namespace label: `kubectl get ns default --show-labels`
2. Verify ztunnel is running: `kubectl get pods -n istio-system -l app=ztunnel`
3. Check if pod has identity: `kubectl logs -n istio-system -l app=ztunnel | grep "podname"`

### Issue: Want to temporarily disable mTLS for a specific service
```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: disable-mtls-for-myapp
  namespace: default
spec:
  selector:
    matchLabels:
      app: myapp
  mtls:
    mode: PERMISSIVE  # or DISABLE
EOF
```

---

## Summary

**Current Setup:**
- ✅ Ambient mode enabled on `default` namespace
- ✅ Ztunnel capturing traffic
- ✅ mTLS encryption active (PERMISSIVE mode)
- ⚠️ Plaintext still accepted

**To lock down (STRICT mode):**
```bash
kubectl apply -f mtls-strict-mode.yaml
```

**Verify it's working:**
```bash
kubectl logs -n istio-system -l app=ztunnel --tail=50 | grep identity
```
