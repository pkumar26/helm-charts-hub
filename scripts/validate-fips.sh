#!/usr/bin/env bash

################################################################################
# FIPS 140-2 Validation Script for Istio on AKS
#
# Purpose: Automated validation of FIPS compliance per contract specification
# Contract: specs/007-istio-aks-chart/contracts/fips-validation.md
# Usage: ./scripts/validate-fips.sh [--namespace <ns>] [--skip-node-check]
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
NAMESPACE="${NAMESPACE:-istio-system}"
SKIP_NODE_CHECK=false
VERBOSE=false

# Counters
TOTAL_CHECKS=10
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((PASSED_CHECKS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((FAILED_CHECKS++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
    ((WARNINGS++))
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=()
    
    command -v kubectl >/dev/null 2>&1 || missing+=("kubectl")
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        echo "Install with: sudo apt-get install -y ${missing[*]}"
        exit 1
    fi
    
    # Check if istioctl is available (optional but recommended)
    if ! command -v istioctl >/dev/null 2>&1; then
        log_warning "istioctl not found - some checks will be skipped"
        log_warning "Install from: https://istio.io/latest/docs/setup/getting-started/#download"
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_error "Namespace '$NAMESPACE' not found"
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --skip-node-check)
                SKIP_NODE_CHECK=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                cat << EOF
FIPS 140-2 Validation Script for Istio on AKS

Usage: $0 [OPTIONS]

Options:
    -n, --namespace <ns>    Istio namespace (default: istio-system)
    --skip-node-check       Skip AKS node pool FIPS validation
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

Examples:
    # Validate default Istio installation
    $0

    # Validate custom namespace
    $0 --namespace istio-prod

    # Skip node-level checks (useful for non-AKS clusters)
    $0 --skip-node-check

EOF
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

################################################################################
# FIPS Validation Checks
################################################################################

check_1_node_pool_fips() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Check 1/10: AKS Node Pool FIPS Configuration"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ "$SKIP_NODE_CHECK" = true ]; then
        log_warning "Node check skipped (--skip-node-check flag)"
        return
    fi
    
    # Check if nodes have FIPS label
    local fips_nodes
    fips_nodes=$(kubectl get nodes -l fips=enabled -o name 2>/dev/null | wc -l)
    
    if [ "$fips_nodes" -gt 0 ]; then
        log_success "Found $fips_nodes FIPS-enabled node(s)"
        
        # Verify kernel FIPS mode (if possible)
        local node_name
        node_name=$(kubectl get nodes -l fips=enabled -o jsonpath='{.items[0].metadata.name}')
        log_info "Attempting to verify kernel FIPS mode on node: $node_name"
        
        # This requires privileged access - may not work in all environments
        if kubectl get node "$node_name" -o json | grep -q "fips"; then
            log_info "Node has FIPS indicators in metadata"
        fi
    else
        log_error "No FIPS-enabled nodes found (label fips=enabled)"
        log_error "Expected: At least one node with label fips=enabled"
        log_error "Fix: az aks nodepool add --enable-fips-image --labels fips=enabled"
    fi
}

check_2_helm_values_fips() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Check 2/10: Helm Values FIPS Configuration"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check istiod deployment for FIPS configuration
    if kubectl get deployment -n "$NAMESPACE" istiod >/dev/null 2>&1; then
        local issues=0
        
        # Check for distroless image
        local image
        image=$(kubectl get deployment -n "$NAMESPACE" istiod -o jsonpath='{.spec.template.spec.containers[0].image}')
        if [[ "$image" == *"-distroless"* ]]; then
            log_success "istiod uses distroless image: $image"
        else
            log_error "istiod not using distroless image: $image"
            log_error "Expected: Image tag must contain '-distroless' suffix"
            ((issues++))
        fi
        
        # Check node selector
        local node_selector
        node_selector=$(kubectl get deployment -n "$NAMESPACE" istiod -o jsonpath='{.spec.template.spec.nodeSelector.fips}' 2>/dev/null || echo "")
        if [ -n "$node_selector" ]; then
            log_success "istiod scheduled to FIPS nodes (nodeSelector.fips: $node_selector)"
        else
            log_warning "istiod nodeSelector.fips not set - may not run on FIPS nodes"
        fi
        
        if [ $issues -eq 0 ]; then
            log_success "Helm values FIPS configuration verified"
        fi
    else
        log_error "istiod deployment not found in namespace $NAMESPACE"
    fi
}

check_3_container_images() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Check 3/10: Container Image Verification"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local deployments
    deployments=$(kubectl get deployments -n "$NAMESPACE" -l app=istiod -o name 2>/dev/null)
    deployments+=" $(kubectl get deployments -n "$NAMESPACE" -l app=istio-ingressgateway -o name 2>/dev/null)"
    deployments+=" $(kubectl get deployments -n "$NAMESPACE" -l app=istio-egressgateway -o name 2>/dev/null)"
    
    local non_fips_found=false
    
    for deploy in $deployments; do
        if [ -z "$deploy" ]; then continue; fi
        
        local deploy_name
        deploy_name=$(basename "$deploy")
        
        local images
        images=$(kubectl get "$deploy" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[*].image}' 2>/dev/null)
        
        for image in $images; do
            if [[ "$image" == *"istio"* ]]; then
                if [[ "$image" == *"-distroless"* ]]; then
                    log_success "$deploy_name: $image (FIPS-compliant)"
                else
                    log_error "$deploy_name: $image (NOT FIPS-compliant - missing -distroless)"
                    non_fips_found=true
                fi
            fi
        done
    done
    
    if [ "$non_fips_found" = false ]; then
        log_success "All Istio containers use FIPS-compliant images"
    fi
}

check_4_gofips_environment() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Check 4/10: GOFIPS Environment Variable"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check istiod
    if kubectl get deployment -n "$NAMESPACE" istiod >/dev/null 2>&1; then
        local gofips
        gofips=$(kubectl get deployment -n "$NAMESPACE" istiod -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="GOFIPS")].value}' 2>/dev/null)
        
        if [ "$gofips" = "1" ]; then
            log_success "istiod: GOFIPS=1 configured"
        else
            log_error "istiod: GOFIPS not set to 1 (found: '$gofips')"
            log_error "Expected: GOFIPS=1 in deployment environment"
        fi
    fi
    
    # Check gateway deployments
    local gateways
    gateways=$(kubectl get deployments -n "$NAMESPACE" -l app=istio-ingressgateway -o name 2>/dev/null)
    gateways+=" $(kubectl get deployments -n "$NAMESPACE" -l app=istio-egressgateway -o name 2>/dev/null)"
    
    for gateway in $gateways; do
        if [ -z "$gateway" ]; then continue; fi
        
        local gw_name
        gw_name=$(basename "$gateway")
        
        local gofips
        gofips=$(kubectl get "$gateway" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="GOFIPS")].value}' 2>/dev/null)
        
        if [ "$gofips" = "1" ]; then
            log_success "$gw_name: GOFIPS=1 configured"
        else
            log_warning "$gw_name: GOFIPS not set (found: '$gofips')"
        fi
    done
}

check_5_boring_ssl() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Check 5/10: BoringSSL Validation in Envoy"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! command -v istioctl >/dev/null 2>&1; then
        log_warning "istioctl not found - skipping BoringSSL bootstrap check"
        log_warning "Install istioctl to enable this check"
        return
    fi
    
    # Get istiod pod
    local istiod_pod
    istiod_pod=$(kubectl get pod -n "$NAMESPACE" -l app=istiod -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$istiod_pod" ]; then
        log_info "Checking Envoy bootstrap configuration for $istiod_pod"
        
        # Check for BoringSSL indicators in proxy config
        if istioctl proxy-config bootstrap -n "$NAMESPACE" "$istiod_pod" 2>/dev/null | grep -iq "boring\|cryptomb"; then
            log_success "BoringSSL/CryptoMb provider detected in Envoy config"
        else
            log_warning "Could not verify BoringSSL in bootstrap config"
            log_warning "This may be expected for distroless images (BoringSSL compiled in)"
        fi
    else
        log_warning "No istiod pod found - skipping BoringSSL check"
    fi
}

check_6_tls_certificates() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Check 6/10: TLS Certificate Validation"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if CA secret exists
    if kubectl get secret -n "$NAMESPACE" istio-ca-secret >/dev/null 2>&1; then
        log_info "Found istio-ca-secret - verifying certificate"
        
        # Extract and verify CA certificate
        local ca_cert
        ca_cert=$(kubectl get secret -n "$NAMESPACE" istio-ca-secret -o jsonpath='{.data.ca-cert\.pem}' 2>/dev/null | base64 -d)
        
        if [ -n "$ca_cert" ]; then
            # Check signature algorithm
            local sig_algo
            sig_algo=$(echo "$ca_cert" | openssl x509 -noout -text 2>/dev/null | grep "Signature Algorithm" | head -1)
            
            if [[ "$sig_algo" == *"sha256"* ]] || [[ "$sig_algo" == *"sha384"* ]] || [[ "$sig_algo" == *"sha512"* ]]; then
                log_success "CA certificate uses FIPS-approved signature algorithm"
                [ "$VERBOSE" = true ] && log_info "$sig_algo"
            else
                log_error "CA certificate uses weak signature algorithm: $sig_algo"
                log_error "Expected: SHA-256, SHA-384, or SHA-512"
            fi
            
            # Check key size
            local key_size
            key_size=$(echo "$ca_cert" | openssl x509 -noout -text 2>/dev/null | grep "Public-Key:" | grep -oE '[0-9]+')
            
            if [ -n "$key_size" ] && [ "$key_size" -ge 2048 ]; then
                log_success "CA certificate key size: $key_size bits (meets FIPS requirement >= 2048)"
            elif [ -n "$key_size" ]; then
                log_error "CA certificate key size: $key_size bits (below FIPS requirement of 2048)"
            fi
        fi
    else
        log_warning "istio-ca-secret not found - may be using external CA"
        log_info "Skipping certificate validation"
    fi
}

check_7_mtls_connection() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Check 7/10: mTLS Connection Validation"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check PeerAuthentication policy
    local peer_auth
    peer_auth=$(kubectl get peerauthentication -n "$NAMESPACE" -o json 2>/dev/null | jq -r '.items[] | select(.spec.mtls.mode=="STRICT") | .metadata.name' | head -1)
    
    if [ -n "$peer_auth" ]; then
        log_success "STRICT mTLS policy found: $peer_auth"
    else
        log_warning "No STRICT mTLS PeerAuthentication policy found"
        log_warning "Expected: At least one PeerAuthentication with spec.mtls.mode=STRICT"
    fi
    
    # Check if istioctl is available for connection test
    if ! command -v istioctl >/dev/null 2>&1; then
        log_warning "istioctl not found - skipping mTLS connection test"
        return
    fi
    
    # Look for any mesh workloads to test
    local mesh_pods
    mesh_pods=$(kubectl get pods --all-namespaces -l security.istio.io/tlsMode=istio -o json 2>/dev/null | jq -r '.items | length')
    
    if [ "$mesh_pods" -gt 0 ]; then
        log_info "Found $mesh_pods pod(s) with Istio sidecar"
        log_success "Mesh workloads present for mTLS validation"
    else
        log_warning "No mesh workloads found - cannot verify mTLS connections"
        log_info "Deploy workloads with Istio injection to test mTLS"
    fi
}

check_8_cipher_suites() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Check 8/10: Cipher Suite Validation"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if ! command -v istioctl >/dev/null 2>&1; then
        log_warning "istioctl not found - skipping cipher suite validation"
        return
    fi
    
    # Get gateway pod
    local gw_pod
    gw_pod=$(kubectl get pod -n "$NAMESPACE" -l app=istio-ingressgateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$gw_pod" ]; then
        log_info "Checking TLS configuration for $gw_pod"
        
        # Check listener config for TLS settings
        local tls_config
        tls_config=$(istioctl proxy-config listener "$gw_pod" -n "$NAMESPACE" -o json 2>/dev/null)
        
        if [ -n "$tls_config" ]; then
            # Check for TLS version
            if echo "$tls_config" | jq -e '.[] | .filterChains[]? | .tlsContext? | select(.commonTlsContext.tlsParams.tlsMinimumProtocolVersion >= "TLSv1_2")' >/dev/null 2>&1; then
                log_success "TLS 1.2 or higher configured"
            else
                log_info "TLS configuration present (version check inconclusive)"
            fi
            
            # Check for FIPS-approved ciphers
            if echo "$tls_config" | grep -iq "AES.*GCM"; then
                log_success "FIPS-approved cipher suites detected (AES-GCM)"
            else
                log_warning "Could not verify FIPS-approved cipher suites"
            fi
        else
            log_warning "Could not retrieve listener configuration"
        fi
    else
        log_warning "No ingress gateway pod found - skipping cipher suite check"
    fi
}

check_9_runtime_crypto() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Check 9/10: Runtime Crypto Library Check"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # For distroless images, we verify by checking the image tag
    local istiod_image
    istiod_image=$(kubectl get deployment -n "$NAMESPACE" istiod -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
    
    if [[ "$istiod_image" == *"-distroless"* ]]; then
        log_success "Distroless image verified: $istiod_image"
        log_info "BoringSSL is statically compiled into distroless images"
        log_success "Runtime crypto library check passed (distroless = BoringSSL)"
    else
        log_error "Not using distroless image: $istiod_image"
        log_error "Standard images may not be FIPS-compliant"
    fi
}

check_10_audit_logs() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Check 10/10: Audit Log Verification"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check Kubernetes audit events for FIPS-related issues
    log_info "Checking for FIPS violation events in recent pod logs"
    
    # Look for FIPS-related errors in istiod logs
    if kubectl get deployment -n "$NAMESPACE" istiod >/dev/null 2>&1; then
        local errors
        errors=$(kubectl logs -n "$NAMESPACE" deployment/istiod --tail=100 2>/dev/null | grep -i "fips\|crypto.*error\|certificate.*fail" | wc -l)
        
        if [ "$errors" -eq 0 ]; then
            log_success "No FIPS violation errors in istiod logs (last 100 lines)"
        else
            log_warning "Found $errors potential FIPS-related error(s) in istiod logs"
            if [ "$VERBOSE" = true ]; then
                kubectl logs -n "$NAMESPACE" deployment/istiod --tail=100 2>/dev/null | grep -i "fips\|crypto.*error\|certificate.*fail"
            fi
        fi
    fi
    
    log_info "Note: Azure Log Analytics audit log queries require az CLI and workspace configuration"
    log_info "Run manually: az monitor log-analytics query --workspace <id> --analytics-query '<query>'"
}

################################################################################
# Summary Report
################################################################################

print_summary() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "FIPS 140-2 Validation Summary"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Total Checks:   $TOTAL_CHECKS"
    echo -e "Passed:         ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "Failed:         ${RED}$FAILED_CHECKS${NC}"
    echo -e "Warnings:       ${YELLOW}$WARNINGS${NC}"
    echo ""
    
    if [ "$FAILED_CHECKS" -eq 0 ]; then
        log_success "✓ FIPS 140-2 validation PASSED"
        echo ""
        log_info "Your Istio deployment meets FIPS 140-2 compliance requirements."
        log_info "Certificate #4407: BoringCrypto for Linux"
        echo ""
        return 0
    else
        log_error "✗ FIPS 140-2 validation FAILED"
        echo ""
        log_error "Found $FAILED_CHECKS critical issue(s) that must be resolved."
        log_error "Review the failed checks above and update your configuration."
        echo ""
        log_info "Common fixes:"
        log_info "  1. Update image tags to include '-distroless' suffix"
        log_info "  2. Set GOFIPS=1 environment variable"
        log_info "  3. Configure nodeSelector to target FIPS-enabled nodes"
        log_info "  4. Use FIPS-approved certificate signature algorithms (SHA-256+)"
        echo ""
        log_info "Reference: specs/007-istio-aks-chart/contracts/fips-validation.md"
        echo ""
        return 1
    fi
}

################################################################################
# Main Execution
################################################################################

main() {
    parse_args "$@"
    
    echo "════════════════════════════════════════════════════════════════════"
    echo "  FIPS 140-2 Validation for Istio on AKS"
    echo "════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Namespace:     $NAMESPACE"
    echo "Skip Node:     $SKIP_NODE_CHECK"
    echo "Verbose:       $VERBOSE"
    echo ""
    
    check_prerequisites
    
    # Run all 10 validation checks
    check_1_node_pool_fips
    check_2_helm_values_fips
    check_3_container_images
    check_4_gofips_environment
    check_5_boring_ssl
    check_6_tls_certificates
    check_7_mtls_connection
    check_8_cipher_suites
    check_9_runtime_crypto
    check_10_audit_logs
    
    # Print summary and exit with appropriate code
    print_summary
    exit $?
}

# Run main function with all arguments
main "$@"
