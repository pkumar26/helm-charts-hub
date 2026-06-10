#!/bin/bash
#
# Deploy Istio to Staging Environment
#
# This script demonstrates staging Istio deployment with:
# - Moderate replicas (2 replicas, HPA 2-4)
# - STRICT mTLS mode (enforced mutual TLS)
# - FIPS disabled (for cost optimization in pre-prod)
# - Moderate security baseline
# - Suitable for pre-production testing
#
# Usage:
#   ./examples/deploy-istio-staging.sh [--namespace NAMESPACE] [--with-kiali]
#
# Prerequisites:
#   - AKS cluster with kubectl access
#   - Helm 3.10+
#   - Target namespace created (default: istio-staging)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="${NAMESPACE:-istio-staging}"
WITH_KIALI=false
CHARTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/charts/istio"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --with-kiali)
      WITH_KIALI=true
      shift
      ;;
    --help)
      echo "Usage: $0 [--namespace NAMESPACE] [--with-kiali]"
      echo ""
      echo "Options:"
      echo "  --namespace NAMESPACE    Target namespace (default: istio-staging)"
      echo "  --with-kiali            Include Kiali dashboard (optional)"
      echo "  --help                  Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_step() {
  echo -e "\n${GREEN}==>${NC} ${BLUE}$1${NC}\n"
}

# Check prerequisites
log_step "Checking Prerequisites"

if ! command -v kubectl &> /dev/null || ! command -v helm &> /dev/null; then
  echo "Error: kubectl and helm are required"
  exit 1
fi

log_success "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
log_success "helm found: $(helm version --short 2>/dev/null || helm version)"

# Verify cluster connectivity
kubectl cluster-info &> /dev/null || { echo "Error: Cannot connect to cluster"; exit 1; }
log_success "Connected to cluster: $(kubectl config current-context)"

# Prepare namespace
log_step "Preparing Namespace: $NAMESPACE"

if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
  kubectl create namespace "$NAMESPACE"
  log_success "Namespace created"
else
  log_info "Namespace already exists"
fi

kubectl label namespace "$NAMESPACE" istio-injection=enabled --overwrite
log_success "Namespace labeled for Istio injection"

#
# Step 1: Install Istio Base
#
log_step "Step 1/3: Installing Istio Base (CRDs)"

helm upgrade --install istio-base "$CHARTS_DIR/base" \
  --namespace "$NAMESPACE" \
  --values "$CHARTS_DIR/base/values-staging.yaml" \
  --wait \
  --timeout 5m

log_success "Istio Base installed"

#
# Step 2: Install Istiod
#
log_step "Step 2/3: Installing Istiod (Control Plane)"
log_info "Configuration: 2 replicas, STRICT mTLS, no FIPS, HPA 2-4"

helm upgrade --install istiod "$CHARTS_DIR/istiod" \
  --namespace "$NAMESPACE" \
  --values "$CHARTS_DIR/istiod/values-staging.yaml" \
  --wait \
  --timeout 5m

log_success "Istiod installed"

kubectl wait --for=condition=ready pod -l app=istiod -n "$NAMESPACE" --timeout=300s
log_success "Istiod pods ready"

#
# Step 3: Install Gateway
#
log_step "Step 3/3: Installing Istio Gateway (Ingress)"
log_info "Configuration: 2 replicas, STRICT mTLS, security baseline, HPA 2-4"

helm upgrade --install istio-ingressgateway "$CHARTS_DIR/gateway" \
  --namespace "$NAMESPACE" \
  --values "$CHARTS_DIR/gateway/values-staging.yaml" \
  --wait \
  --timeout 5m

log_success "Gateway installed"

kubectl wait --for=condition=ready pod -l app=istio-ingressgateway -n "$NAMESPACE" --timeout=300s
log_success "Gateway pods ready"

#
# Optional: Kiali
#
if [ "$WITH_KIALI" = true ]; then
  log_step "Optional: Installing Kiali"
  
  helm upgrade --install kiali "$CHARTS_DIR/kiali" \
    --namespace "$NAMESPACE" \
    --values "$CHARTS_DIR/kiali/values-staging.yaml" \
    --wait \
    --timeout 5m
  
  log_success "Kiali installed (token auth)"
  log_info "Access Kiali: kubectl port-forward -n $NAMESPACE svc/kiali 20001:20001"
fi

#
# Summary
#
log_step "Deployment Summary"

echo ""
echo "✅ Istio Staging Environment Deployed!"
echo ""
echo "Namespace: $NAMESPACE"
echo "Configuration:"
echo "  - mTLS Mode: STRICT"
echo "  - FIPS: Disabled"
echo "  - Replicas: 2 per component, HPA 2-4"
echo "  - Security: Moderate baseline"
echo ""

log_info "View components:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  helm list -n $NAMESPACE"
echo ""

log_info "Gateway IP:"
echo "  kubectl get svc istio-ingressgateway -n $NAMESPACE"
echo ""

log_warning "This is a staging environment - not suitable for production traffic"
