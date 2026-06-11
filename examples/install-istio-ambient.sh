#!/bin/bash
#
# Istio Ambient Mode Installation Script
# 
# Installs Istio in ambient mode with environment-specific configuration:
# - Base chart (CRDs)
# - CNI plugin (from official Istio repo)
# - Ztunnel DaemonSet (L4 proxy)
# - Istiod control plane
# - Gateway API CRDs and resources
#
# Usage:
#   ./examples/install-istio-ambient.sh [--environment ENV] [--namespace NAMESPACE] [--with-kiali]
#
# Prerequisites:
#   - AKS cluster with kubectl access
#   - Helm 3.10+
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${ENVIRONMENT:-dev}"
NAMESPACE="${NAMESPACE:-istio-system}"
WITH_KIALI=true
ISTIO_VERSION="1.30.0"
GATEWAY_API_VERSION="v1.2.0"
CHARTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/charts/istio"
ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/environments"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --with-kiali)
      WITH_KIALI=true
      shift
      ;;
    --help)
      echo "Usage: $0 [--environment ENV] [--namespace NAMESPACE] [--with-kiali]"
      echo ""
      echo "Options:"
      echo "  --environment ENV        Environment: dev, staging, or production (default: dev)"
      echo "  --namespace NAMESPACE    Target namespace (default: istio-system)"
      echo "  --with-kiali            Install Kiali observability dashboard"
      echo "  --help                  Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                                           # Install dev environment"
      echo "  $0 --environment production --with-kiali    # Install production with Kiali"
      exit 0
      ;;
    *)
      echo -e "${RED}❌ Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|production)$ ]]; then
  echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
  echo "Must be one of: dev, staging, production"
  exit 1
fi

# Validate environment files exist
for component in base istiod gateway-api; do
  VALUES_FILE="$ENV_DIR/$ENVIRONMENT/istio-${component}.values.yaml"
  if [[ ! -f "$VALUES_FILE" ]]; then
    echo -e "${YELLOW}⚠️  Warning: $VALUES_FILE not found, using chart defaults${NC}"
  fi
done

echo "======================================"
echo "Istio Ambient Mode Installation"
echo "======================================"
echo -e "${BLUE}Environment:${NC} $ENVIRONMENT"
echo -e "${BLUE}Namespace:${NC} $NAMESPACE"
echo -e "${BLUE}Istio Version:${NC} $ISTIO_VERSION"
echo -e "${BLUE}Gateway API:${NC} $GATEWAY_API_VERSION"
echo ""

# Check prerequisites
echo "Step 1: Checking prerequisites..."
command -v helm >/dev/null 2>&1 || { echo -e "${RED}❌ helm is required but not installed. Aborting.${NC}"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl is required but not installed. Aborting.${NC}"; exit 1; }
echo -e "${GREEN}✓ Prerequisites met${NC}"
echo ""

# Add official Istio Helm repository
echo "Step 2: Adding official Istio Helm repository..."
helm repo add istio https://istio-release.storage.googleapis.com/charts 2>/dev/null || true
helm repo update istio
echo -e "${GREEN}✓ Istio Helm repo added${NC}"
echo ""

# Install Base Chart (CRDs)
echo "Step 3: Installing Istio base (CRDs)..."
BASE_VALUES="$ENV_DIR/$ENVIRONMENT/istio-base.values.yaml"
if [[ -f "$BASE_VALUES" ]]; then
  helm install istio-base "$CHARTS_DIR/base" \
    --namespace $NAMESPACE \
    --create-namespace \
    --values "$BASE_VALUES" \
    --wait
else
  helm install istio-base "$CHARTS_DIR/base" \
    --namespace $NAMESPACE \
    --create-namespace \
    --wait
fi

# Verify CRDs
CRD_COUNT=$(kubectl get crds | grep istio.io | wc -l)
echo -e "${GREEN}✓ Istio base installed ($CRD_COUNT CRDs created)${NC}"
echo ""

# Install CNI Plugin
echo "Step 4: Installing Istio CNI plugin..."
helm install istio-cni istio/cni \
  --namespace $NAMESPACE \
  --version $ISTIO_VERSION \
  --set profile=ambient \
  --wait \
  --timeout 5m

# Verify CNI
kubectl get daemonset -n $NAMESPACE istio-cni-node
echo -e "${GREEN}✓ Istio CNI installed${NC}"
echo ""

# Install Istiod (Control Plane) - MUST be before ztunnel
# Istiod creates the istio-ca-root-cert ConfigMap that ztunnel needs.
# NOTE: pilot.env.* settings MUST be nested under the `istiod.` subchart key;
# top-level pilot.* values are silently ignored by the upstream subchart.
# PILOT_ENABLE_AMBIENT=true is REQUIRED, otherwise ztunnel refuses to connect.
echo "Step 5: Installing istiod (control plane)..."
ISTIOD_VALUES="$ENV_DIR/$ENVIRONMENT/istio-istiod.values.yaml"
if [[ -f "$ISTIOD_VALUES" ]]; then
  helm install istiod "$CHARTS_DIR/istiod" \
    --namespace $NAMESPACE \
    --values "$ISTIOD_VALUES" \
    --set global.cni.enabled=true \
    --set-string istiod.pilot.env.PILOT_ENABLE_AMBIENT=true \
    --set-string istiod.pilot.env.PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER=true \
    --wait \
    --timeout 5m
else
  helm install istiod "$CHARTS_DIR/istiod" \
    --namespace $NAMESPACE \
    --set global.cni.enabled=true \
    --set-string istiod.pilot.env.PILOT_ENABLE_AMBIENT=true \
    --set-string istiod.pilot.env.PILOT_ENABLE_GATEWAY_API_DEPLOYMENT_CONTROLLER=true \
    --wait \
    --timeout 5m
fi

# Verify istiod
kubectl get pods -n $NAMESPACE -l app=istiod
echo -e "${GREEN}✓ Istiod installed${NC}"
echo ""

# Install Ztunnel (L4 Proxy) - MUST be after istiod
# Ztunnel requires the istio-ca-root-cert ConfigMap created by istiod
echo "Step 6: Installing ztunnel (L4 proxy)..."
helm install ztunnel istio/ztunnel \
  --namespace $NAMESPACE \
  --version $ISTIO_VERSION \
  --wait \
  --timeout 5m

# Verify ztunnel
kubectl get daemonset -n $NAMESPACE ztunnel
echo -e "${GREEN}✓ Ztunnel installed${NC}"
echo ""

# Install Gateway API CRDs
echo "Step 7: Installing Gateway API CRDs..."
if ! kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
  kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml
  echo -e "${GREEN}✓ Gateway API CRDs installed${NC}"
else
  echo -e "${GREEN}✓ Gateway API CRDs already exist${NC}"
fi
echo ""

# Install Gateway API Chart
echo "Step 8: Installing Gateway API chart..."
GATEWAY_VALUES="$ENV_DIR/$ENVIRONMENT/istio-gateway-api.values.yaml"

if [[ -f "$GATEWAY_VALUES" ]]; then
  helm install gateway-api "$CHARTS_DIR/gateway-api" \
    --namespace $NAMESPACE \
    --values "$GATEWAY_VALUES" \
    --wait \
    --timeout 5m
else
  helm install gateway-api "$CHARTS_DIR/gateway-api" \
    --namespace $NAMESPACE \
    --wait \
    --timeout 5m
fi

# Wait for Gateway to be ready
echo "Waiting for Gateway to be programmed..."
kubectl wait --for=condition=Programmed gateway/istio-gateway -n $NAMESPACE --timeout=60s 2>/dev/null || true
echo -e "${GREEN}✓ Gateway API chart installed${NC}"
echo ""

# Install Kiali (optional)
if [ "$WITH_KIALI" = true ]; then
  echo "Step 9: Installing Kiali observability dashboard..."
  KIALI_VALUES="$ENV_DIR/$ENVIRONMENT/kiali.values.yaml"
  if [[ -f "$KIALI_VALUES" ]]; then
    helm install kiali "$CHARTS_DIR/kiali" \
      --namespace $NAMESPACE \
      --values "$KIALI_VALUES" \
      --wait \
      --timeout 5m
  else
    helm install kiali "$CHARTS_DIR/kiali" \
      --namespace $NAMESPACE \
      --wait \
      --timeout 5m
  fi
  echo -e "${GREEN}✓ Kiali installed${NC}"
  echo ""
fi

# Summary
echo "======================================"
echo -e "${GREEN}Installation Complete!${NC}"
echo "======================================"
echo -e "${BLUE}Environment:${NC} $ENVIRONMENT"
echo -e "${BLUE}Namespace:${NC} $NAMESPACE"
echo ""
echo "Installed components:"
helm list -n $NAMESPACE
echo ""
echo "Running pods:"
kubectl get pods -n $NAMESPACE
echo ""
echo "Gateway status:"
kubectl get gateway -n $NAMESPACE
echo ""
echo "Gateway external IP:"
kubectl get svc -n $NAMESPACE -l istio.io/gateway-name=istio-gateway
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Label a namespace for ambient mode:"
echo -e "   ${YELLOW}kubectl label namespace <namespace> istio.io/dataplane-mode=ambient${NC}"
echo ""
echo "2. Deploy your application to the labeled namespace"
echo ""
echo "3. Create HTTPRoute resources to route traffic"
echo ""
if [ "$WITH_KIALI" = false ]; then
  echo "4. (Optional) Install Kiali for observability:"
  echo -e "   ${YELLOW}$0 --environment $ENVIRONMENT --with-kiali${NC}"
  echo "   Or manually:"
  echo -e "   ${YELLOW}helm install kiali $CHARTS_DIR/kiali -n $NAMESPACE --values $ENV_DIR/$ENVIRONMENT/kiali.values.yaml${NC}"
fi
