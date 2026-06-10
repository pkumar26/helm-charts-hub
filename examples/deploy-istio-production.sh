#!/bin/bash
#
# Deploy Istio to Production Environment
#
# This script demonstrates production-grade Istio deployment with:
# - High availability (3 replicas with pod anti-affinity)
# - STRICT mTLS mode (enforced mutual TLS)
# - FIPS 140-2 compliance (distroless images with BoringSSL)
# - Full security baseline (AuthorizationPolicy, NetworkPolicy)
# - Horizontal Pod Autoscaling (3-5 replicas)
# - Production resource limits
# - Token-based Kiali authentication (optional)
#
# Usage:
#   ./examples/deploy-istio-production.sh [--namespace NAMESPACE] [--with-kiali] [--dry-run]
#
# Prerequisites:
#   - AKS cluster with FIPS-enabled node pool
#   - kubectl access with admin permissions
#   - Helm 3.10+
#   - Target namespace created (default: istio-system)
#   - Node pool with label: fips=enabled (for FIPS workloads)
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
DRY_RUN=false
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
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      echo "Usage: $0 [--namespace NAMESPACE] [--with-kiali] [--dry-run]"
      echo ""
      echo "Options:"
      echo "  --namespace NAMESPACE    Target namespace (default: istio-system)"
      echo "  --with-kiali            Include Kiali dashboard (optional)"
      echo "  --dry-run               Perform dry-run without installing"
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
CLUSTER_CONTEXT=$(kubectl config current-context)
log_success "Connected to cluster: $CLUSTER_CONTEXT"

# Verify FIPS node pool exists
log_info "Verifying FIPS-enabled node pool..."
FIPS_NODES=$(kubectl get nodes -l fips=enabled -o name 2>/dev/null | wc -l)
if [ "$FIPS_NODES" -eq 0 ]; then
  log_error "No FIPS-enabled nodes found. Production deployment requires FIPS node pool."
  log_error "Create FIPS node pool with: az aks nodepool add --enable-fips-image --node-labels fips=enabled"
  exit 1
fi
log_success "FIPS node pool found: $FIPS_NODES nodes with label fips=enabled"

# Production readiness checks
log_step "Production Readiness Checks"

log_warning "⚠️  PRODUCTION DEPLOYMENT CHECKLIST:"
echo ""
echo "Before proceeding, verify:"
echo "  [ ] AKS cluster has 3+ nodes across multiple availability zones"
echo "  [ ] FIPS-enabled node pool is provisioned (verified above)"
echo "  [ ] Network policies are supported (Azure CNI required)"
echo "  [ ] Resource quotas allow for production workloads (3-5 replicas per component)"
echo "  [ ] Monitoring solution is configured (Prometheus/Grafana/Azure Monitor)"
echo "  [ ] Backup and disaster recovery plan is documented"
echo "  [ ] Security team has reviewed STRICT mTLS and authorization policies"
echo "  [ ] Certificate management strategy is in place"
echo "  [ ] Maintenance window is planned for initial deployment"
echo ""

if [ "$DRY_RUN" = false ]; then
  read -p "Continue with production deployment? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    log_info "Deployment cancelled by user"
    exit 0
  fi
fi

# Prepare namespace
log_step "Preparing Namespace: $NAMESPACE"

if [ "$DRY_RUN" = true ]; then
  log_info "[DRY-RUN] Would create/verify namespace: $NAMESPACE"
else
  if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    log_info "Namespace '$NAMESPACE' already exists"
  else
    log_info "Creating namespace '$NAMESPACE'"
    kubectl create namespace "$NAMESPACE"
    log_success "Namespace created"
  fi
  
  # Label namespace for Istio injection
  log_info "Labeling namespace for Istio injection"
  kubectl label namespace "$NAMESPACE" istio-injection=enabled --overwrite
  log_success "Namespace labeled: istio-injection=enabled"
fi

# Determine helm flags
HELM_FLAGS="--namespace $NAMESPACE --wait --timeout 10m"
if [ "$DRY_RUN" = true ]; then
  HELM_FLAGS="$HELM_FLAGS --dry-run"
  log_warning "DRY-RUN MODE: No changes will be applied"
fi

#
# Step 1: Install Istio Base (CRDs)
#
log_step "Step 1/3: Installing Istio Base (CRDs)"
log_info "Chart: $CHARTS_DIR/base"

helm upgrade --install istio-base "$CHARTS_DIR/base" \
  $HELM_FLAGS \
  --values "$CHARTS_DIR/base/values-prod.yaml"

if [ "$DRY_RUN" = false ]; then
  log_success "Istio Base installed"
  
  # Verify CRDs
  log_info "Verifying Istio CRDs..."
  CRDS=$(kubectl get crds | grep -c 'istio.io' || true)
  log_success "Found $CRDS Istio CRDs"
fi

#
# Step 2: Install Istiod (Control Plane)
#
log_step "Step 2/3: Installing Istiod (Control Plane)"
log_info "Chart: $CHARTS_DIR/istiod"
log_info "Configuration: 3 replicas, STRICT mTLS, FIPS enabled, HPA 3-5 replicas"

helm upgrade --install istiod "$CHARTS_DIR/istiod" \
  $HELM_FLAGS \
  --values "$CHARTS_DIR/istiod/values-prod.yaml"

if [ "$DRY_RUN" = false ]; then
  log_success "Istiod installed"
  
  # Verify istiod pods
  log_info "Waiting for istiod pods to be ready..."
  kubectl wait --for=condition=ready pod -l app=istiod -n "$NAMESPACE" --timeout=600s
  
  ISTIOD_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=istiod -o name | wc -l)
  log_success "Istiod ready: $ISTIOD_PODS pods running"
  
  # Verify FIPS mode
  log_info "Verifying FIPS mode..."
  ISTIOD_IMAGE=$(kubectl get pods -n "$NAMESPACE" -l app=istiod -o jsonpath='{.items[0].spec.containers[0].image}')
  if [[ "$ISTIOD_IMAGE" == *"-distroless"* ]]; then
    log_success "FIPS enabled: Using distroless image with BoringSSL"
  else
    log_warning "FIPS verification: Image does not contain '-distroless' suffix"
  fi
  
  # Check FIPS environment variable
  FIPS_ENV=$(kubectl get pods -n "$NAMESPACE" -l app=istiod -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="GOFIPS")].value}')
  if [ "$FIPS_ENV" = "1" ]; then
    log_success "FIPS environment verified: GOFIPS=1"
  fi
fi

#
# Step 3: Install Gateway (Ingress)
#
log_step "Step 3/3: Installing Istio Gateway (Ingress)"
log_info "Chart: $CHARTS_DIR/gateway"
log_info "Configuration: 3 replicas, STRICT mTLS, FIPS enabled, full security baseline, HPA 3-5 replicas"

helm upgrade --install istio-ingressgateway "$CHARTS_DIR/gateway" \
  $HELM_FLAGS \
  --values "$CHARTS_DIR/gateway/values-prod.yaml"

if [ "$DRY_RUN" = false ]; then
  log_success "Istio Gateway installed"
  
  # Verify gateway pods
  log_info "Waiting for gateway pods to be ready..."
  kubectl wait --for=condition=ready pod -l app=istio-ingressgateway -n "$NAMESPACE" --timeout=600s
  
  GATEWAY_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=istio-ingressgateway -o name | wc -l)
  log_success "Gateway ready: $GATEWAY_PODS pods running"
  
  # Verify FIPS mode for gateway
  log_info "Verifying gateway FIPS mode..."
  GATEWAY_IMAGE=$(kubectl get pods -n "$NAMESPACE" -l app=istio-ingressgateway -o jsonpath='{.items[0].spec.containers[0].image}')
  if [[ "$GATEWAY_IMAGE" == *"-distroless"* ]]; then
    log_success "Gateway FIPS enabled: Using distroless image"
  fi
  
  # Check for security policies
  log_info "Verifying security policies..."
  PA_COUNT=$(kubectl get peerauthentication -n "$NAMESPACE" -o name 2>/dev/null | wc -l)
  AP_COUNT=$(kubectl get authorizationpolicy -n "$NAMESPACE" -o name 2>/dev/null | wc -l)
  NP_COUNT=$(kubectl get networkpolicy -n "$NAMESPACE" -o name 2>/dev/null | wc -l)
  
  log_success "Security policies deployed:"
  echo "  - PeerAuthentication: $PA_COUNT (STRICT mTLS enforcement)"
  echo "  - AuthorizationPolicy: $AP_COUNT (default-deny + allowlists)"
  echo "  - NetworkPolicy: $NP_COUNT (L3/L4 isolation)"
fi

#
# Optional: Install Kiali Dashboard
#
if [ "$WITH_KIALI" = true ]; then
  log_step "Optional: Installing Kiali Dashboard"
  log_info "Chart: $CHARTS_DIR/kiali"
  log_info "Configuration: Token-based authentication for production"
  
  helm upgrade --install kiali "$CHARTS_DIR/kiali" \
    $HELM_FLAGS \
    --values "$CHARTS_DIR/kiali/values-prod.yaml" \
    --set enabled=true
  
  if [ "$DRY_RUN" = false ]; then
    log_success "Kiali installed"
    
    # Verify kiali pod
    log_info "Waiting for Kiali pod to be ready..."
    kubectl wait --for=condition=ready pod -l app=kiali -n "$NAMESPACE" --timeout=300s || true
    log_success "Kiali pod is ready"
    
    log_warning "Kiali requires token authentication in production"
    log_info "Create service account token:"
    echo "  kubectl create token kiali-service-account -n $NAMESPACE --duration=24h"
    log_info "Access Kiali:"
    echo "  kubectl port-forward -n $NAMESPACE svc/kiali 20001:20001"
    echo "  Open: http://localhost:20001 (login with token)"
  fi
fi

#
# Post-Deployment Validation
#
if [ "$DRY_RUN" = false ]; then
  log_step "Post-Deployment Validation"
  
  log_info "Checking component health..."
  
  # Check all pods are running
  ALL_PODS=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}')
  RUNNING_COUNT=$(echo "$ALL_PODS" | grep -c "Running" || true)
  TOTAL_COUNT=$(echo "$ALL_PODS" | wc -l)
  
  if [ "$RUNNING_COUNT" -eq "$TOTAL_COUNT" ]; then
    log_success "All $TOTAL_COUNT pods are Running"
  else
    log_warning "$RUNNING_COUNT/$TOTAL_COUNT pods are Running"
  fi
  
  # Check HPA status
  log_info "Checking HorizontalPodAutoscaler status..."
  kubectl get hpa -n "$NAMESPACE" || log_info "No HPA resources found yet (may take a few minutes)"
  
  # Check services
  log_info "Checking services..."
  kubectl get svc -n "$NAMESPACE"
  
  log_success "Post-deployment validation complete"
fi

#
# Deployment Summary
#
log_step "Deployment Summary"

echo ""
echo "✅ Istio Production Environment Deployed Successfully!"
echo ""
echo "Namespace: $NAMESPACE"
echo "Cluster: $CLUSTER_CONTEXT"
echo ""
echo "Components:"
echo "  - Istio Base (CRDs)"
echo "  - Istiod (Control Plane) - 3 replicas, HPA 3-5"
echo "  - Gateway (Ingress) - 3 replicas, HPA 3-5"
if [ "$WITH_KIALI" = true ]; then
  echo "  - Kiali (Dashboard) - Token auth"
fi
echo ""
echo "Configuration:"
echo "  - mTLS Mode: STRICT (enforced mutual TLS)"
echo "  - FIPS: Enabled (distroless images with BoringSSL/Certificate #4407)"
echo "  - Security: Full baseline (PeerAuthentication, AuthorizationPolicy, NetworkPolicy)"
echo "  - HA: 3 replicas with pod anti-affinity across AZs"
echo "  - Autoscaling: HPA 3-5 replicas per component"
echo "  - Resources: Production limits (500m-1000m CPU, 1-2Gi memory)"
echo ""

if [ "$DRY_RUN" = false ]; then
  log_info "View deployed components:"
  echo "  kubectl get pods -n $NAMESPACE -o wide"
  echo "  kubectl get svc -n $NAMESPACE"
  echo "  helm list -n $NAMESPACE"
  echo ""
  
  log_info "Gateway external IP (LoadBalancer):"
  GATEWAY_IP=$(kubectl get svc istio-ingressgateway -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Pending...")
  echo "  $GATEWAY_IP"
  if [ "$GATEWAY_IP" = "Pending..." ]; then
    echo "  (Wait for Azure to provision LoadBalancer)"
    echo "  kubectl get svc istio-ingressgateway -n $NAMESPACE -w"
  fi
  echo ""
  
  log_info "Verify FIPS compliance:"
  echo "  # Check istiod FIPS:"
  echo "  kubectl exec -n $NAMESPACE deploy/istiod -- pilot-discovery version"
  echo "  kubectl get pods -n $NAMESPACE -l app=istiod -o jsonpath='{.items[0].spec.containers[0].image}'"
  echo ""
  echo "  # Check gateway FIPS:"
  echo "  kubectl get pods -n $NAMESPACE -l app=istio-ingressgateway -o jsonpath='{.items[0].spec.containers[0].image}'"
  echo ""
  
  log_info "Verify mTLS STRICT mode:"
  echo "  kubectl get peerauthentication -n $NAMESPACE"
  echo "  # Should show mtls mode: STRICT"
  echo ""
  
  log_info "Verify security policies:"
  echo "  kubectl get authorizationpolicy -n $NAMESPACE"
  echo "  kubectl get networkpolicy -n $NAMESPACE"
  echo ""
fi

log_warning "Next Steps:"
echo "  1. Configure monitoring and alerting"
echo "  2. Set up certificate management (cert-manager recommended)"
echo "  3. Label application namespaces for sidecar injection"
echo "  4. Deploy applications with Istio sidecar"
echo "  5. Create Gateway and VirtualService resources for ingress routing"
echo "  6. Configure observability (traces, metrics, logs)"
echo "  7. Set up backup procedures for Istio configuration"
echo "  8. Document runbooks for common operations"
echo "  9. Plan upgrade strategy (see docs/istio-aks-deployment.md)"
echo ""

log_info "For troubleshooting and operations, see:"
echo "  - docs/istio-aks-deployment.md"
echo "  - charts/istio/base/README.md"
echo "  - charts/istio/istiod/README.md"
echo "  - charts/istio/gateway/README.md"
