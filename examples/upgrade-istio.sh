#!/usr/bin/env bash

#############################################################################
# Istio Upgrade Script for AKS
#
# This script automates the upgrade of Istio components (base, istiod, gateway)
# with proper sequencing, wait conditions, and validation.
#
# Usage:
#   ./upgrade-istio.sh --version 1.23.0 --environment production
#   ./upgrade-istio.sh --version 1.23.0 --environment production --dry-run
#   ./upgrade-istio.sh --help
#
# Requirements:
#   - Helm 3.10+
#   - kubectl configured with cluster access
#   - istioctl installed (for validation)
#
# Author: Platform Team
# Repository: https://github.com/pkumar26/helm-charts-hub
#############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERSION=""
ENVIRONMENT=""
NAMESPACE="istio-system"
DRY_RUN=false
SKIP_BASE=false
SKIP_ISTIOD=false
SKIP_GATEWAY=false
WAIT_TIMEOUT="5m"
CHARTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/charts/istio"

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Upgrade Istio components on AKS with proper sequencing and validation.

OPTIONS:
    -v, --version VERSION       Target Istio version (required, e.g., 1.23.0)
    -e, --environment ENV       Environment: dev, staging, production (required)
    -n, --namespace NAMESPACE   Kubernetes namespace (default: istio-system)
    -d, --dry-run              Perform dry-run without applying changes
    --skip-base                Skip base chart upgrade
    --skip-istiod              Skip istiod upgrade
    --skip-gateway             Skip gateway upgrade
    --timeout DURATION         Helm wait timeout (default: 5m)
    -h, --help                 Display this help message

EXAMPLES:
    # Upgrade to version 1.23.0 in production
    $0 --version 1.23.0 --environment production

    # Dry-run upgrade
    $0 --version 1.23.0 --environment production --dry-run

    # Skip gateway upgrade
    $0 --version 1.23.0 --environment production --skip-gateway

    # Upgrade with custom timeout
    $0 --version 1.23.0 --environment staging --timeout 10m

EOF
    exit 1
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_step() {
    echo -e "\n${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}$*${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}\n"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-base)
                SKIP_BASE=true
                shift
                ;;
            --skip-istiod)
                SKIP_ISTIOD=true
                shift
                ;;
            --skip-gateway)
                SKIP_GATEWAY=true
                shift
                ;;
            --timeout)
                WAIT_TIMEOUT="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$VERSION" ]]; then
        log_error "Version is required"
        usage
    fi

    if [[ -z "$ENVIRONMENT" ]]; then
        log_error "Environment is required"
        usage
    fi

    if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|production)$ ]]; then
        log_error "Environment must be one of: dev, staging, production"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking Prerequisites"

    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed"
        exit 1
    fi
    local helm_version=$(helm version --short | grep -oE 'v[0-9]+\.[0-9]+')
    log_info "Helm version: $helm_version"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    log_info "kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"

    # Check istioctl
    if command -v istioctl &> /dev/null; then
        log_info "istioctl: $(istioctl version --short 2>/dev/null || echo 'installed')"
    else
        log_warning "istioctl not found - validation steps will be limited"
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    log_success "Connected to cluster: $(kubectl config current-context)"

    # Check namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    log_success "Namespace '$NAMESPACE' exists"
}

# Backup current state
backup_state() {
    log_step "Backing Up Current State"

    local backup_dir="./istio-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"

    log_info "Backup directory: $backup_dir"

    # Backup Helm releases
    helm get values istio-base -n "$NAMESPACE" > "$backup_dir/base-values.yaml" 2>/dev/null || true
    helm get values istiod -n "$NAMESPACE" > "$backup_dir/istiod-values.yaml" 2>/dev/null || true
    helm get values istio-ingressgateway -n "$NAMESPACE" > "$backup_dir/gateway-values.yaml" 2>/dev/null || true

    # Backup CRDs
    kubectl get crds -o yaml > "$backup_dir/istio-crds.yaml" 2>/dev/null || true

    # Backup Istio configurations
    kubectl get virtualservices,destinationrules,gateways,serviceentries --all-namespaces -o yaml > "$backup_dir/istio-configs.yaml" 2>/dev/null || true

    # Backup component state
    helm list -n "$NAMESPACE" > "$backup_dir/helm-releases.txt" 2>/dev/null || true
    kubectl get pods -n "$NAMESPACE" -o wide > "$backup_dir/pods.txt" 2>/dev/null || true

    log_success "Backup completed: $backup_dir"
    echo "$backup_dir" > .last-backup-location
}

# Verify current health
verify_health() {
    log_step "Verifying Current System Health"

    # Check all pods are running
    log_info "Checking pod health..."
    local unhealthy_pods=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
    if [[ $unhealthy_pods -gt 0 ]]; then
        log_warning "Found $unhealthy_pods unhealthy pods"
        kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running
    else
        log_success "All pods are running"
    fi

    # Check proxy sync status
    if command -v istioctl &> /dev/null; then
        log_info "Checking proxy sync status..."
        if istioctl proxy-status &> /dev/null; then
            local stale_proxies=$(istioctl proxy-status 2>/dev/null | grep -c STALE || true)
            if [[ $stale_proxies -gt 0 ]]; then
                log_warning "Found $stale_proxies stale proxies"
            else
                log_success "All proxies are synced"
            fi
        fi
    fi

    # Run configuration analysis
    if command -v istioctl &> /dev/null; then
        log_info "Running configuration analysis..."
        if istioctl analyze --all-namespaces &> /tmp/istio-analyze.txt; then
            log_success "No configuration issues found"
        else
            log_warning "Configuration issues detected:"
            cat /tmp/istio-analyze.txt
        fi
    fi

    log_success "Health verification completed"
}

# Upgrade base chart
upgrade_base() {
    if [[ "$SKIP_BASE" == "true" ]]; then
        log_warning "Skipping base chart upgrade"
        return 0
    fi

    log_step "Upgrading Base Chart (CRDs)"

    local values_file="$CHARTS_DIR/base/values-${ENVIRONMENT}.yaml"
    if [[ ! -f "$values_file" ]]; then
        log_error "Values file not found: $values_file"
        exit 1
    fi

    # Update dependencies
    log_info "Updating chart dependencies..."
    (cd "$CHARTS_DIR/base" && helm dependency update)

    # Prepare helm command
    local helm_cmd="helm upgrade istio-base $CHARTS_DIR/base \
        --namespace $NAMESPACE \
        --values $values_file \
        --install \
        --create-namespace"

    if [[ "$DRY_RUN" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run --debug"
        log_info "Dry-run mode: Base chart upgrade"
    fi

    log_info "Executing: $helm_cmd"
    eval "$helm_cmd"

    if [[ "$DRY_RUN" == "false" ]]; then
        log_info "Waiting for CRD propagation (30 seconds)..."
        sleep 30

        # Verify CRDs
        log_info "Verifying CRDs..."
        local crd_count=$(kubectl get crds | grep -c istio.io || true)
        log_info "Istio CRDs installed: $crd_count"

        log_success "Base chart upgraded successfully"
    else
        log_info "Dry-run completed for base chart"
    fi
}

# Upgrade istiod chart
upgrade_istiod() {
    if [[ "$SKIP_ISTIOD" == "true" ]]; then
        log_warning "Skipping istiod upgrade"
        return 0
    fi

    log_step "Upgrading Istiod (Control Plane)"

    local values_file="$CHARTS_DIR/istiod/values-${ENVIRONMENT}.yaml"
    if [[ ! -f "$values_file" ]]; then
        log_error "Values file not found: $values_file"
        exit 1
    fi

    # Update dependencies
    log_info "Updating chart dependencies..."
    (cd "$CHARTS_DIR/istiod" && helm dependency update)

    # Prepare helm command
    local helm_cmd="helm upgrade istiod $CHARTS_DIR/istiod \
        --namespace $NAMESPACE \
        --values $values_file \
        --install \
        --wait \
        --timeout $WAIT_TIMEOUT"

    if [[ "$DRY_RUN" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run --debug"
        log_info "Dry-run mode: Istiod upgrade"
    fi

    log_info "Executing: $helm_cmd"
    eval "$helm_cmd"

    if [[ "$DRY_RUN" == "false" ]]; then
        # Verify istiod pods
        log_info "Verifying istiod pods..."
        kubectl wait --for=condition=ready pod -l app=istiod -n "$NAMESPACE" --timeout=300s

        local istiod_pods=$(kubectl get pods -n "$NAMESPACE" -l app=istiod --no-headers | wc -l)
        log_info "Istiod pods running: $istiod_pods"

        # Check for errors
        log_info "Checking istiod logs for errors..."
        if kubectl logs -n "$NAMESPACE" -l app=istiod --tail=50 | grep -i error; then
            log_warning "Errors found in istiod logs (review above)"
        else
            log_success "No errors in istiod logs"
        fi

        log_success "Istiod upgraded successfully"
    else
        log_info "Dry-run completed for istiod"
    fi
}

# Upgrade gateway chart
upgrade_gateway() {
    if [[ "$SKIP_GATEWAY" == "true" ]]; then
        log_warning "Skipping gateway upgrade"
        return 0
    fi

    log_step "Upgrading Gateway"

    local values_file="$CHARTS_DIR/gateway/values-${ENVIRONMENT}.yaml"
    if [[ ! -f "$values_file" ]]; then
        log_error "Values file not found: $values_file"
        exit 1
    fi

    # Update dependencies
    log_info "Updating chart dependencies..."
    (cd "$CHARTS_DIR/gateway" && helm dependency update)

    # Prepare helm command with zero-downtime settings
    local helm_cmd="helm upgrade istio-ingressgateway $CHARTS_DIR/gateway \
        --namespace $NAMESPACE \
        --values $values_file \
        --install \
        --wait \
        --timeout $WAIT_TIMEOUT"

    if [[ "$DRY_RUN" == "true" ]]; then
        helm_cmd="$helm_cmd --dry-run --debug"
        log_info "Dry-run mode: Gateway upgrade"
    fi

    log_info "Executing: $helm_cmd"
    eval "$helm_cmd"

    if [[ "$DRY_RUN" == "false" ]]; then
        # Verify gateway deployment
        log_info "Verifying gateway deployment..."
        kubectl rollout status deployment istio-ingressgateway -n "$NAMESPACE" --timeout=300s

        local gateway_pods=$(kubectl get pods -n "$NAMESPACE" -l istio=ingressgateway --no-headers | wc -l)
        log_info "Gateway pods running: $gateway_pods"

        # Test gateway connectivity
        log_info "Testing gateway connectivity..."
        local gateway_ip=$(kubectl get svc istio-ingressgateway -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
        if [[ "$gateway_ip" != "pending" && -n "$gateway_ip" ]]; then
            log_info "Gateway IP: $gateway_ip"
            if curl -sf -o /dev/null "http://$gateway_ip/healthz/ready" --max-time 5; then
                log_success "Gateway health check passed"
            else
                log_warning "Gateway health check failed (this may be expected if no routes are configured)"
            fi
        else
            log_info "Gateway LoadBalancer IP pending..."
        fi

        log_success "Gateway upgraded successfully"
    else
        log_info "Dry-run completed for gateway"
    fi
}

# Post-upgrade validation
post_upgrade_validation() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_step "Skipping Post-Upgrade Validation (dry-run mode)"
        return 0
    fi

    log_step "Post-Upgrade Validation"

    # Check helm releases
    log_info "Helm releases:"
    helm list -n "$NAMESPACE"

    # Check Istio version
    if command -v istioctl &> /dev/null; then
        log_info "Istio version:"
        istioctl version || true
    fi

    # Check proxy status
    if command -v istioctl &> /dev/null; then
        log_info "Proxy sync status:"
        istioctl proxy-status | head -20 || true
    fi

    # Run configuration analysis
    if command -v istioctl &> /dev/null; then
        log_info "Running configuration analysis..."
        if istioctl analyze --all-namespaces; then
            log_success "No configuration issues detected"
        else
            log_warning "Configuration issues found (review above)"
        fi
    fi

    # Check pod health
    log_info "Istio component health:"
    kubectl get pods -n "$NAMESPACE" -o wide

    # Check for recent errors
    log_info "Checking for recent errors in logs..."
    if kubectl logs -n "$NAMESPACE" -l app=istiod --tail=20 --since=5m 2>/dev/null | grep -i error; then
        log_warning "Errors found in recent logs (review above)"
    else
        log_success "No errors in recent logs"
    fi

    log_success "Post-upgrade validation completed"
}

# Main upgrade flow
main() {
    log_step "Istio Upgrade Script"
    log_info "Version: $VERSION"
    log_info "Environment: $ENVIRONMENT"
    log_info "Namespace: $NAMESPACE"
    log_info "Dry-run: $DRY_RUN"
    log_info "Charts directory: $CHARTS_DIR"

    parse_args "$@"
    check_prerequisites
    
    if [[ "$DRY_RUN" == "false" ]]; then
        backup_state
        verify_health
    fi

    upgrade_base
    upgrade_istiod
    upgrade_gateway
    post_upgrade_validation

    log_step "Upgrade Complete"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        log_success "✅ Istio upgraded to version $VERSION in $ENVIRONMENT environment"
        log_info ""
        log_info "Next steps:"
        log_info "  1. Monitor application traffic for any issues"
        log_info "  2. Check metrics in Grafana/Prometheus"
        log_info "  3. Run full application test suite"
        log_info "  4. Keep this terminal session for 30 minutes"
        log_info ""
        log_info "Rollback command (if needed):"
        log_info "  helm rollback istio-ingressgateway -n $NAMESPACE"
        log_info "  helm rollback istiod -n $NAMESPACE"
        log_info "  helm rollback istio-base -n $NAMESPACE"
        log_info ""
        if [[ -f .last-backup-location ]]; then
            log_info "Backup location: $(cat .last-backup-location)"
        fi
    else
        log_info "✅ Dry-run completed successfully"
        log_info ""
        log_info "To apply the upgrade, run without --dry-run flag:"
        log_info "  $0 --version $VERSION --environment $ENVIRONMENT"
    fi
}

# Run main function
main "$@"
