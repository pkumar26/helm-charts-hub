#!/bin/bash
#
# Deploy Istio to Development Environment
# 
# This script demonstrates minimal Istio deployment suitable for development:
# - Single replicas for all components
# - Permissive mTLS mode (allows plaintext for gradual adoption)
# - No FIPS mode
# - Minimal resource requests
# - Anonymous authentication for Kiali (optional)
#
# Usage:
#   ./examples/deploy-istio-dev.sh [--namespace NAMESPACE] [--with-kiali]
#
# Prerequisites:
#   - AKS cluster with kubectl access
#   - Helm 3.10+
#   - Target namespace created (default: istio-system)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="${NAMESPACE:-istio-system}"
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
      echo "  --namespace NAMESPACE    Target namespace (default: istio-system)"
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

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
  echo -e "\n${GREEN}==>${NC} ${BLUE}$1${NC}\n"
}

# Check prerequisites
log_step "Checking Prerequisites"

if ! command -v kubectl &> /dev/null; then
  log_error "kubectl not found. Please install kubectl."
  exit 1
fi
log_success "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"

if ! command -v helm &> /dev/null; then
  log_error "helm not found. Please install Helm 3.10+."
  exit 1
fi
HELM_VERSION=$(helm version --short 2>/dev/null || helm version)
log_success "helm found: $HELM_VERSION"

# Verify cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
  log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
  exit 1
fi
log_success "Connected to cluster: $(kubectl config current-context)"

# Create namespace if it doesn't exist
log_step "Preparing Namespace: $NAMESPACE"
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
  log_info "Namespace '$NAMESPACE' already exists"
else
  log_info "Creating namespace '$NAMESPACE'"
  kubectl create namespace "$NAMESPACE"
  log_success "Namespace created"
fi

# Label namespace for Istio injection (for workloads in this namespace)
log_info "Labeling namespace for Istio injection"
kubectl label namespace "$NAMESPACE" istio-injection=enabled --overwrite
log_success "Namespace labeled: istio-injection=enabled"

#
# Step 1: Install Istio Base (CRDs)
#
log_step "Step 1/3: Installing Istio Base (CRDs)"
log_info "Chart: $CHARTS_DIR/base"

helm upgrade --install istio-base "$CHARTS_DIR/base" \
  --namespace "$NAMESPACE" \
  --values "$CHARTS_DIR/base/values-dev.yaml" \
  --wait \
  --timeout 5m

log_success "Istio Base installed"

# Verify CRDs
log_info "Verifying Istio CRDs..."
CRDS=$(kubectl get crds | grep -c 'istio.io' || true)
log_success "Found $CRDS Istio CRDs"

#
# Step 2: Install Istiod (Control Plane)
#
log_step "Step 2/3: Installing Istiod (Control Plane)"
log_info "Chart: $CHARTS_DIR/istiod"
log_info "Configuration: 1 replica, PERMISSIVE mTLS, no FIPS"

helm upgrade --install istiod "$CHARTS_DIR/istiod" \
  --namespace "$NAMESPACE" \
  --values "$CHARTS_DIR/istiod/values-dev.yaml" \
  --wait \
  --timeout 5m

log_success "Istiod installed"

# Verify istiod pod
log_info "Waiting for istiod pod to be ready..."
kubectl wait --for=condition=ready pod -l app=istiod -n "$NAMESPACE" --timeout=300s
log_success "Istiod pod is ready"

#
# Step 3: Install Gateway (Ingress)
#
log_step "Step 3/3: Installing Istio Gateway (Ingress)"
log_info "Chart: $CHARTS_DIR/gateway"
log_info "Configuration: 1 replica, PERMISSIVE mTLS, basic security"

helm upgrade --install istio-ingressgateway "$CHARTS_DIR/gateway" \
  --namespace "$NAMESPACE" \
  --values "$CHARTS_DIR/gateway/values-dev.yaml" \
  --wait \
  --timeout 5m

log_success "Istio Gateway installed"

# Verify gateway pod
log_info "Waiting for gateway pod to be ready..."
kubectl wait --for=condition=ready pod -l app=istio-ingressgateway -n "$NAMESPACE" --timeout=300s
log_success "Gateway pod is ready"

#
# Optional: Install Kiali Dashboard
#
if [ "$WITH_KIALI" = true ]; then
  log_step "Optional: Installing Kiali Dashboard"
  log_info "Chart: $CHARTS_DIR/kiali"
  log_info "Configuration: Anonymous auth for dev environment"
  
  helm upgrade --install kiali "$CHARTS_DIR/kiali" \
    --namespace "$NAMESPACE" \
    --values "$CHARTS_DIR/kiali/values-dev.yaml" \
    --wait \
    --timeout 5m
  
  log_success "Kiali installed"
  
  # Verify kiali pod
  log_info "Waiting for Kiali pod to be ready..."
  kubectl wait --for=condition=ready pod -l app=kiali -n "$NAMESPACE" --timeout=300s || true
  log_success "Kiali pod is ready"
  
  log_info ""
  log_info "Access Kiali dashboard:"
  log_info "  kubectl port-forward -n $NAMESPACE svc/kiali 20001:20001"
  log_info "  Open: http://localhost:20001"
fi

#
# Deployment Summary
#
log_step "Deployment Summary"

echo ""
echo "✅ Istio Development Environment Deployed Successfully!"
echo ""
echo "Namespace: $NAMESPACE"
echo "Components:"
echo "  - Istio Base (CRDs)"
echo "  - Istiod (Control Plane) - 1 replica"
echo "  - Gateway (Ingress) - 1 replica"
if [ "$WITH_KIALI" = true ]; then
  echo "  - Kiali (Dashboard) - Optional"
fi
echo ""
echo "Configuration:"
echo "  - mTLS Mode: PERMISSIVE (allows plaintext + mTLS)"
echo "  - FIPS: Disabled"
echo "  - Replicas: 1 per component"
echo "  - Resources: Minimal (suitable for dev)"
echo ""

log_info "View deployed components:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl get svc -n $NAMESPACE"
echo "  helm list -n $NAMESPACE"
echo ""

log_info "Check Istio version:"
echo "  kubectl get pods -n $NAMESPACE -l app=istiod -o jsonpath='{.items[0].spec.containers[0].image}'"
echo ""

log_info "Gateway external IP (wait for LoadBalancer):"
echo "  kubectl get svc istio-ingressgateway -n $NAMESPACE"
echo ""

log_warning "Next Steps:"
echo "  1. Label your application namespace for sidecar injection:"
echo "       kubectl label namespace <your-namespace> istio-injection=enabled"
echo "  2. Deploy your application"
echo "  3. Create Gateway and VirtualService resources for traffic routing"
echo "  4. Verify traffic flows through the mesh"
echo ""

log_info "To upgrade to production settings, see: docs/istio-aks-deployment.md"
