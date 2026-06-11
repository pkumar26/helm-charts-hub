#!/bin/bash
set -e

echo "======================================"
echo "Istio Cleanup and Helm Reinstall Script"
echo "======================================"
echo

# Backup current Istio Gateway if it exists
echo "Step 1: Checking for existing Istio resources to backup..."
kubectl get gateway.networking.istio.io -A -o yaml > /tmp/istio-gateways-backup.yaml 2>/dev/null || true
kubectl get virtualservice.networking.istio.io -A -o yaml > /tmp/istio-virtualservices-backup.yaml 2>/dev/null || true
echo "✓ Backups saved to /tmp/istio-*-backup.yaml"
echo

# Delete old Istio cluster-wide resources
echo "Step 2: Cleaning up old Istio cluster resources..."
kubectl delete clusterrole,clusterrolebinding -l app.kubernetes.io/part-of=istio --ignore-not-found=true
kubectl delete mutatingwebhookconfiguration,validatingwebhookconfiguration -l app.kubernetes.io/part-of=istio --ignore-not-found=true
echo "✓ Cluster resources cleaned"
echo

# Fresh install with Helm
echo "Step 3: Installing Istio base (CRDs)..."
helm uninstall istio-base -n istio-system --wait 2>/dev/null || true
sleep 2
helm install istio-base charts/istio/base -n istio-system --create-namespace --wait
echo "✓ Istio base installed"
echo

echo "Step 4: Installing Istio control plane (istiod)..."
helm install istiod charts/istio/istiod -n istio-system -f environments/dev/istio-istiod.values.yaml --wait --timeout 5m
echo "✓ Istiod installed"
echo

echo "Step 5: Installing Istio gateway..."
helm install istio-gateway charts/istio/gateway -n istio-system -f environments/dev/istio-gateway.values.yaml --wait --timeout 5m
echo "✓ Gateway installed"
echo

echo "Step 6: Installing Kiali (optional)..."
helm install kiali charts/istio/kiali -n istio-system -f environments/dev/kiali.values.yaml --wait --timeout 5m || echo "⚠ Kiali install failed or skipped"
echo

echo "======================================"
echo "Installation Complete!"
echo "======================================"
echo
echo "Verify the installation:"
echo "  kubectl get pods -n istio-system"
echo "  helm list -n istio-system"
echo
echo "Restore your backed up resources if needed:"
echo "  kubectl apply -f /tmp/istio-gateways-backup.yaml"
echo "  kubectl apply -f /tmp/istio-virtualservices-backup.yaml"
echo
