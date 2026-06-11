#!/bin/bash
set -e

echo "======================================"
echo "Istio Cleanup Script"
echo "======================================"
echo ""

NAMESPACE="istio-system"

# Backup existing resources
echo "Step 1: Backing up Istio resources..."
mkdir -p /tmp/istio-backup-$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/tmp/istio-backup-$(date +%Y%m%d-%H%M%S)"

kubectl get virtualservices,destinationrules,gateways,httproutes -A -o yaml > "$BACKUP_DIR/istio-configs.yaml" 2>/dev/null || true
kubectl get gateway -A -o yaml > "$BACKUP_DIR/gateway-api-resources.yaml" 2>/dev/null || true
helm list -n $NAMESPACE > "$BACKUP_DIR/helm-releases.txt" 2>/dev/null || true
echo "✓ Backups saved to $BACKUP_DIR"
echo ""

# Uninstall Helm releases
echo "Step 2: Uninstalling Helm releases..."
helm uninstall gateway-api -n $NAMESPACE 2>/dev/null || echo "  gateway-api not found"
helm uninstall kiali -n $NAMESPACE 2>/dev/null || echo "  kiali not found"
helm uninstall istio-ingressgateway -n $NAMESPACE 2>/dev/null || echo "  istio-ingressgateway not found"
helm uninstall istiod -n $NAMESPACE 2>/dev/null || echo "  istiod not found"
helm uninstall ztunnel -n $NAMESPACE 2>/dev/null || echo "  ztunnel not found"
helm uninstall istio-cni -n $NAMESPACE 2>/dev/null || echo "  istio-cni not found"
helm uninstall istio-base -n $NAMESPACE 2>/dev/null || echo "  istio-base not found"
echo "✓ Helm releases uninstalled"
echo ""

# Delete cluster-wide resources
echo "Step 3: Deleting cluster-wide Istio resources..."

# ClusterRoles
kubectl delete clusterrole \
  istiod-clusterrole-istio-system \
  istiod-gateway-controller-istio-system \
  istio-reader-clusterrole-istio-system \
  istio-cni \
  istio-cni-ambient \
  istio-cni-repair-role \
  ztunnel \
  --ignore-not-found=true

# ClusterRoleBindings
kubectl delete clusterrolebinding \
  istiod-clusterrole-istio-system \
  istiod-gateway-controller-istio-system \
  istio-reader-clusterrole-istio-system \
  istio-cni \
  istio-cni-ambient \
  istio-cni-repair-rolebinding \
  ztunnel \
  --ignore-not-found=true

# Webhooks
kubectl delete mutatingwebhookconfiguration \
  istio-sidecar-injector \
  istio-revision-tag-default \
  --ignore-not-found=true

kubectl delete validatingwebhookconfiguration \
  istio-validator-istio-system \
  istiod-default-validator \
  --ignore-not-found=true

echo "✓ Cluster resources deleted"
echo ""

# Delete namespace
echo "Step 4: Deleting istio-system namespace..."
kubectl delete namespace $NAMESPACE --ignore-not-found=true

# Wait for namespace deletion
echo "Waiting for namespace deletion to complete..."
kubectl wait --for=delete namespace/$NAMESPACE --timeout=60s 2>/dev/null || true
echo "✓ Namespace deleted"
echo ""

# Verify cleanup
echo "Step 5: Verifying cleanup..."
CRD_COUNT=$(kubectl get crds | grep istio.io | wc -l || echo 0)
if [ "$CRD_COUNT" -eq 0 ]; then
  echo "✓ All Istio CRDs removed"
else
  echo "⚠️  Warning: $CRD_COUNT Istio CRDs still present"
  kubectl get crds | grep istio.io
fi

NS_EXISTS=$(kubectl get namespace $NAMESPACE 2>/dev/null | wc -l || echo 0)
if [ "$NS_EXISTS" -eq 0 ]; then
  echo "✓ Namespace fully removed"
else
  echo "⚠️  Warning: Namespace still exists (may be terminating)"
fi

HELM_COUNT=$(helm list -n $NAMESPACE 2>/dev/null | tail -n +2 | wc -l || echo 0)
if [ "$HELM_COUNT" -eq 0 ]; then
  echo "✓ All Helm releases removed"
else
  echo "⚠️  Warning: $HELM_COUNT Helm releases still present"
  helm list -n $NAMESPACE
fi

echo ""
echo "======================================"
echo "Cleanup Complete!"
echo "======================================"
echo ""
echo "Backups saved to: $BACKUP_DIR"
echo ""
echo "To reinstall Istio, run:"
echo "  ./examples/install-istio-ambient.sh"
echo ""
echo "Or for sidecar mode, follow the documentation:"
echo "  docs/istio-aks-deployment.md"
