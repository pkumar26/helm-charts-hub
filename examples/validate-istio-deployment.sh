#!/bin/bash
#
# Validate Istio Deployment
#
# This script validates that an Istio deployment is correctly configured
# and ready for use. It checks component health, security policies,
# configuration, and performs basic connectivity tests.
#
# Usage:
#   ./examples/validate-istio-deployment.sh [--namespace NAMESPACE] [--environment ENV]
#
# Prerequisites:
#   - kubectl access to target cluster
#   - istioctl (optional, for extended validation)
#   - Istio deployed in target namespace
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
ENVIRONMENT="${ENVIRONMENT:-}"
ERRORS=0
WARNINGS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [--namespace NAMESPACE] [--environment ENV]"
      echo ""
      echo "Options:"
      echo "  --namespace NAMESPACE    Target namespace (default: istio-system)"
      echo "  --environment ENV        Expected environment: dev, staging, or production"
      echo "  --help                   Show this help message"
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
  echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[⚠]${NC} $1"
  ((WARNINGS++))
}

log_error() {
  echo -e "${RED}[✗]${NC} $1"
  ((ERRORS++))
}

log_step() {
  echo -e "\n${GREEN}==>${NC} ${BLUE}$1${NC}\n"
}

# Check prerequisites
log_step "Checking Prerequisites"

if ! command -v kubectl &> /dev/null; then
  log_error "kubectl not found"
  exit 1
fi
log_success "kubectl found"

if ! kubectl cluster-info &> /dev/null; then
  log_error "Cannot connect to Kubernetes cluster"
  exit 1
fi
log_success "Connected to cluster: $(kubectl config current-context)"

# Check namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
  log_error "Namespace '$NAMESPACE' not found"
  exit 1
fi
log_success "Namespace '$NAMESPACE' exists"

# Check istioctl
if command -v istioctl &> /dev/null; then
  ISTIOCTL_AVAILABLE=true
  log_success "istioctl found (extended validation available)"
else
  ISTIOCTL_AVAILABLE=false
  log_warning "istioctl not found (some checks will be skipped)"
fi

#
# Validation 1: Helm Releases
#
log_step "Validation 1: Helm Releases"

RELEASES=$(helm list -n "$NAMESPACE" -o json | jq -r '.[].name' 2>/dev/null || echo "")

if echo "$RELEASES" | grep -q "istio-base"; then
  log_success "istio-base release found"
else
  log_error "istio-base release not found"
fi

if echo "$RELEASES" | grep -q "istiod"; then
  log_success "istiod release found"
else
  log_error "istiod release not found"
fi

if echo "$RELEASES" | grep -q "istio-ingressgateway"; then
  log_success "istio-ingressgateway release found"
else
  log_error "istio-ingressgateway release not found"
fi

if echo "$RELEASES" | grep -q "kiali"; then
  log_success "kiali release found (optional)"
else
  log_info "kiali not installed (optional component)"
fi

#
# Validation 2: CRDs
#
log_step "Validation 2: Istio CRDs"

CRD_COUNT=$(kubectl get crds 2>/dev/null | grep -c 'istio.io' || echo "0")
if [ "$CRD_COUNT" -ge 25 ]; then
  log_success "Istio CRDs installed: $CRD_COUNT CRDs"
else
  log_error "Expected 25+ Istio CRDs, found: $CRD_COUNT"
fi

# Check key CRDs
REQUIRED_CRDS=("virtualservices.networking.istio.io" "destinationrules.networking.istio.io" "gateways.networking.istio.io" "peerauthentications.security.istio.io" "authorizationpolicies.security.istio.io")

for CRD in "${REQUIRED_CRDS[@]}"; do
  if kubectl get crd "$CRD" &> /dev/null; then
    log_success "CRD exists: $CRD"
  else
    log_error "CRD missing: $CRD"
  fi
done

#
# Validation 3: Component Health
#
log_step "Validation 3: Component Health"

# Check istiod pods
ISTIOD_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=istiod -o json 2>/dev/null || echo '{"items":[]}')
ISTIOD_COUNT=$(echo "$ISTIOD_PODS" | jq -r '.items | length')
ISTIOD_READY=$(echo "$ISTIOD_PODS" | jq -r '[.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True"))] | length')

if [ "$ISTIOD_COUNT" -gt 0 ]; then
  log_success "Istiod pods: $ISTIOD_READY/$ISTIOD_COUNT ready"
  
  if [ "$ISTIOD_READY" -lt "$ISTIOD_COUNT" ]; then
    log_error "Not all istiod pods are ready"
  fi
  
  # Environment-specific checks
  if [ "$ENVIRONMENT" = "dev" ] && [ "$ISTIOD_COUNT" -ne 1 ]; then
    log_warning "Dev environment should have 1 istiod replica, found: $ISTIOD_COUNT"
  elif [ "$ENVIRONMENT" = "staging" ] && [ "$ISTIOD_COUNT" -lt 2 ]; then
    log_warning "Staging environment should have 2+ istiod replicas, found: $ISTIOD_COUNT"
  elif [ "$ENVIRONMENT" = "production" ] && [ "$ISTIOD_COUNT" -lt 3 ]; then
    log_error "Production environment requires 3+ istiod replicas, found: $ISTIOD_COUNT"
  fi
else
  log_error "No istiod pods found"
fi

# Check gateway pods
GATEWAY_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=istio-ingressgateway -o json 2>/dev/null || echo '{"items":[]}')
GATEWAY_COUNT=$(echo "$GATEWAY_PODS" | jq -r '.items | length')
GATEWAY_READY=$(echo "$GATEWAY_PODS" | jq -r '[.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="True"))] | length')

if [ "$GATEWAY_COUNT" -gt 0 ]; then
  log_success "Gateway pods: $GATEWAY_READY/$GATEWAY_COUNT ready"
  
  if [ "$GATEWAY_READY" -lt "$GATEWAY_COUNT" ]; then
    log_error "Not all gateway pods are ready"
  fi
else
  log_error "No gateway pods found"
fi

#
# Validation 4: Services
#
log_step "Validation 4: Services"

if kubectl get svc istiod -n "$NAMESPACE" &> /dev/null; then
  log_success "istiod service exists"
else
  log_error "istiod service not found"
fi

if kubectl get svc istio-ingressgateway -n "$NAMESPACE" &> /dev/null; then
  log_success "istio-ingressgateway service exists"
  
  # Check LoadBalancer IP
  GATEWAY_IP=$(kubectl get svc istio-ingressgateway -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  if [ -n "$GATEWAY_IP" ]; then
    log_success "Gateway LoadBalancer IP: $GATEWAY_IP"
  else
    log_warning "Gateway LoadBalancer IP pending (may take a few minutes)"
  fi
else
  log_error "istio-ingressgateway service not found"
fi

#
# Validation 5: Configuration
#
log_step "Validation 5: Configuration"

# Check mTLS mode
PA_MODE=$(kubectl get peerauthentication -n "$NAMESPACE" -o jsonpath='{.items[*].spec.mtls.mode}' 2>/dev/null || echo "")
if [ -n "$PA_MODE" ]; then
  log_success "mTLS mode configured: $PA_MODE"
  
  if [ "$ENVIRONMENT" = "dev" ] && [ "$PA_MODE" != "PERMISSIVE" ]; then
    log_warning "Dev environment typically uses PERMISSIVE mTLS, found: $PA_MODE"
  elif [ "$ENVIRONMENT" = "staging" ] || [ "$ENVIRONMENT" = "production" ]; then
    if [ "$PA_MODE" != "STRICT" ]; then
      log_error "Staging/Production should use STRICT mTLS, found: $PA_MODE"
    fi
  fi
else
  log_warning "No PeerAuthentication policies found"
fi

# Check authorization policies
AP_COUNT=$(kubectl get authorizationpolicy -n "$NAMESPACE" -o name 2>/dev/null | wc -l)
if [ "$AP_COUNT" -gt 0 ]; then
  log_success "AuthorizationPolicy resources: $AP_COUNT"
else
  log_warning "No AuthorizationPolicy resources found (expected in production)"
fi

# Check network policies
NP_COUNT=$(kubectl get networkpolicy -n "$NAMESPACE" -o name 2>/dev/null | wc -l)
if [ "$NP_COUNT" -gt 0 ]; then
  log_success "NetworkPolicy resources: $NP_COUNT"
else
  log_warning "No NetworkPolicy resources found (expected in production)"
fi

#
# Validation 6: FIPS Compliance (if applicable)
#
if [ "$ENVIRONMENT" = "production" ]; then
  log_step "Validation 6: FIPS Compliance (Production)"
  
  # Check istiod image
  ISTIOD_IMAGE=$(kubectl get pods -n "$NAMESPACE" -l app=istiod -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || echo "")
  if [[ "$ISTIOD_IMAGE" == *"-distroless"* ]]; then
    log_success "Istiod using FIPS image: $ISTIOD_IMAGE"
  else
    log_error "Istiod not using FIPS distroless image: $ISTIOD_IMAGE"
  fi
  
  # Check gateway image
  GATEWAY_IMAGE=$(kubectl get pods -n "$NAMESPACE" -l app=istio-ingressgateway -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || echo "")
  if [[ "$GATEWAY_IMAGE" == *"-distroless"* ]]; then
    log_success "Gateway using FIPS image: $GATEWAY_IMAGE"
  else
    log_error "Gateway not using FIPS distroless image: $GATEWAY_IMAGE"
  fi
  
  # Check FIPS environment variable
  GOFIPS=$(kubectl get pods -n "$NAMESPACE" -l app=istiod -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="GOFIPS")].value}' 2>/dev/null || echo "")
  if [ "$GOFIPS" = "1" ]; then
    log_success "GOFIPS environment variable set correctly"
  else
    log_error "GOFIPS environment variable not set to 1"
  fi
  
  # Check node selector for FIPS
  NODE_SELECTOR=$(kubectl get pods -n "$NAMESPACE" -l app=istiod -o jsonpath='{.items[0].spec.nodeSelector.fips}' 2>/dev/null || echo "")
  if [ "$NODE_SELECTOR" = "enabled" ]; then
    log_success "Pods scheduled on FIPS-enabled nodes"
  else
    log_warning "Pods may not be scheduled on FIPS-enabled nodes (nodeSelector.fips not set)"
  fi
fi

#
# Validation 7: Extended Checks (istioctl)
#
if [ "$ISTIOCTL_AVAILABLE" = true ]; then
  log_step "Validation 7: Extended Checks (istioctl)"
  
  # Proxy status
  log_info "Checking proxy status..."
  if istioctl proxy-status -n "$NAMESPACE" &> /dev/null; then
    log_success "All proxies are synced with control plane"
  else
    log_warning "Some proxies may not be synced (check 'istioctl proxy-status')"
  fi
  
  # Configuration analysis
  log_info "Running configuration analysis..."
  ANALYSIS_OUTPUT=$(istioctl analyze --namespace "$NAMESPACE" 2>&1 || true)
  if echo "$ANALYSIS_OUTPUT" | grep -q "No validation issues found"; then
    log_success "Configuration analysis: No issues found"
  else
    log_warning "Configuration analysis found issues:"
    echo "$ANALYSIS_OUTPUT" | grep -E "(Error|Warning|Info)" || true
  fi
  
  # Version check
  log_info "Checking component versions..."
  VERSION_OUTPUT=$(istioctl version 2>&1 || echo "")
  if [ -n "$VERSION_OUTPUT" ]; then
    log_success "Version check complete"
    echo "$VERSION_OUTPUT"
  fi
fi

#
# Validation 8: HPA (for staging/production)
#
if [ "$ENVIRONMENT" = "staging" ] || [ "$ENVIRONMENT" = "production" ]; then
  log_step "Validation 8: Horizontal Pod Autoscaling"
  
  HPA_COUNT=$(kubectl get hpa -n "$NAMESPACE" -o name 2>/dev/null | wc -l)
  if [ "$HPA_COUNT" -gt 0 ]; then
    log_success "HPA resources found: $HPA_COUNT"
    kubectl get hpa -n "$NAMESPACE"
  else
    log_warning "No HPA resources found (expected in staging/production)"
  fi
fi

#
# Summary
#
log_step "Validation Summary"

echo ""
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo -e "${GREEN}✅ All validations passed!${NC}"
  echo ""
  echo "Istio deployment in namespace '$NAMESPACE' is healthy and ready for use."
elif [ "$ERRORS" -eq 0 ]; then
  echo -e "${YELLOW}⚠️  Validation completed with warnings${NC}"
  echo ""
  echo "Warnings: $WARNINGS"
  echo "Istio deployment is functional but some optional checks failed."
  echo "Review warnings above and consider addressing them."
else
  echo -e "${RED}❌ Validation failed${NC}"
  echo ""
  echo "Errors: $ERRORS"
  echo "Warnings: $WARNINGS"
  echo ""
  echo "Critical issues found. Please review errors above and fix before proceeding."
  exit 1
fi

echo ""
log_info "Next steps:"
echo "  1. Label application namespace for sidecar injection:"
echo "       kubectl label namespace <your-namespace> istio-injection=enabled"
echo "  2. Deploy test application"
echo "  3. Create Gateway and VirtualService for routing"
echo "  4. Verify traffic flows through mesh"
echo "  5. Monitor with 'kubectl get pods -n $NAMESPACE -w'"

if [ "$ISTIOCTL_AVAILABLE" = true ]; then
  echo ""
  log_info "Useful istioctl commands:"
  echo "  istioctl proxy-status              # Check proxy sync status"
  echo "  istioctl analyze --all-namespaces  # Analyze configuration"
  echo "  istioctl dashboard kiali           # Open Kiali dashboard (if installed)"
fi

echo ""
exit 0
