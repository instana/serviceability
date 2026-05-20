#!/bin/sh

# Kubernetes OpenTelemetry Collector Must-Gather Script
# Collects diagnostic information from OTel Collector deployed via Helm
# Usage: ./must-gather-k8s-collector.sh [-n namespace] [release-name]
#        ./must-gather-k8s-collector.sh [release-name] [-n namespace]

set -e

# Default values
DEFAULT_NAMESPACE="instana-otel-collector"
DEFAULT_RELEASE_NAME="instana-otel-collector"

# Initialize variables
NAMESPACE="$DEFAULT_NAMESPACE"
RELEASE_NAME="$DEFAULT_RELEASE_NAME"

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -n)
            if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then
                NAMESPACE="$2"
                shift 2
            else
                echo "Error: -n requires a namespace argument"
                exit 1
            fi
            ;;
        -*)
            echo "Error: Unknown option $1"
            exit 1
            ;;
        *)
            # Positional argument - treat as release name
            RELEASE_NAME="$1"
            shift
            ;;
    esac
done

# Output directory setup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="k8s-otel-must-gather-${TIMESTAMP}"

# Banner
print_banner() {
    echo "========================================================"
    echo "  Kubernetes OpenTelemetry Collector Must-Gather Tool"
    echo "========================================================"
    echo ""
}

# Print section header
print_section() {
    echo ""
    echo ">>> $1"
}

# Print success message
print_success() {
    echo "[SUCCESS] $1"
}

# Print error message
print_error() {
    echo "[ERROR] $1" >&2
}

# Print info message
print_info() {
    echo "[INFO] $1"
}

# Check required tools
check_dependencies() {
    print_section "Checking dependencies"
    
    missing_tools=""
    
    # Check for required commands
    for cmd in kubectl tar date du wc tr; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            if [ -n "$missing_tools" ]; then
                missing_tools="$missing_tools $cmd"
            else
                missing_tools="$cmd"
            fi
        fi
    done
    
    # Check for helm (optional but recommended)
    if ! command -v helm > /dev/null 2>&1; then
        print_info "helm not found - some features may be limited"
    fi
    
    if [ -n "$missing_tools" ]; then
        print_error "Missing required tools: $missing_tools"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    print_success "All required tools are available"
}

# Create output directory structure
setup_output_directory() {
    print_section "Setting up output directory"
    
    mkdir -p "$OUTPUT_DIR/pods" "$OUTPUT_DIR/configmaps" "$OUTPUT_DIR/logs" "$OUTPUT_DIR/otelcr"
    
    print_success "Created output directory: $OUTPUT_DIR"
}

# Collect pod information
collect_pod_info() {
    print_section "Collecting pod information"
    
    pods_dir="$OUTPUT_DIR/pods"
    
    # Collect pods matching any of the label selectors
    all_pods=""
    for label_selector in "app.kubernetes.io/instance=${RELEASE_NAME}" "app.kubernetes.io/name=opentelemetry-operator" "app.kubernetes.io/managed-by=opentelemetry-operator"
    do
        pods=""
        if pods=$(kubectl get pods -n "$NAMESPACE" -l "$label_selector" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); then
            if [ -n "$pods" ]; then
                if [ -z "$all_pods" ]; then
                    all_pods="$pods"
                else
                    all_pods="$all_pods $pods"
                fi
            fi
        fi
    done
    
    # Remove duplicates and sort
    all_pods=$(printf '%s\n' "$all_pods" | sort -u | tr '\n' ' ')
    
    if [ -z "$all_pods" ]; then
        print_error "No pods found matching any of the label selectors"
        print_info "Verify the namespace ($NAMESPACE) and release name ($RELEASE_NAME) are correct"
        return 1
    fi
    
    pod_count=$(printf '%s\n' "$all_pods" | wc -w | tr -d ' ')
    print_success "Found $pod_count unique pod(s)"
    
    # List pods - use the collected pod names
    for pod in $all_pods
    do
        kubectl get pod "$pod" -n "$NAMESPACE" -o wide 2>&1
    done > "$pods_dir/pods-list.txt"
    
    # Describe pods
    for pod in $all_pods
    do
        kubectl describe pod "$pod" -n "$NAMESPACE" 2>&1
    done > "$pods_dir/pods-describe.txt"
    print_success "Collected pod descriptions"
    
    # Get pod resource usage (optional - metrics server may not be available)
    {
        for pod in $all_pods
        do
            kubectl top pod "$pod" -n "$NAMESPACE" 2>&1 || true
        done
    } > "$pods_dir/pods-top.txt"
    
    if grep -q "error" "$pods_dir/pods-top.txt" 2>/dev/null; then
        print_info "Could not collect pod resource usage (metrics server may not be available)"
    else
        print_success "Collected pod resource usage"
    fi
}

# Collect pod logs
collect_pod_logs() {
    print_section "Collecting pod logs"
    
    logs_dir="$OUTPUT_DIR/logs"
    
    # Collect pods matching any of the label selectors
    all_pods=""
    for label_selector in "app.kubernetes.io/instance=${RELEASE_NAME}" "app.kubernetes.io/name=opentelemetry-operator" "app.kubernetes.io/managed-by=opentelemetry-operator"
    do
        pods=""
        if pods=$(kubectl get pods -n "$NAMESPACE" -l "$label_selector" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); then
            if [ -n "$pods" ]; then
                if [ -z "$all_pods" ]; then
                    all_pods="$pods"
                else
                    all_pods="$all_pods $pods"
                fi
            fi
        fi
    done
    
    # Remove duplicates and sort
    all_pods=$(printf '%s\n' "$all_pods" | sort -u | tr '\n' ' ')
    
    if [ -z "$all_pods" ]; then
        print_error "No pods found matching any of the label selectors"
        return 1
    fi
    
    print_info "Found $(printf '%s\n' "$all_pods" | wc -w | tr -d ' ') unique pod(s)"
    
    for pod in $all_pods; do
        print_info "Collecting logs from pod: $pod"
        
        # Get container names
        containers=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
        
        for container in $containers; do
            # Current logs
            kubectl logs "$pod" -n "$NAMESPACE" -c "$container" > "$logs_dir/${pod}-${container}.log" 2>&1
            print_success "  Collected current logs: $container"
            
            # Previous logs (if pod restarted)
            if kubectl logs "$pod" -n "$NAMESPACE" -c "$container" --previous > /dev/null 2>&1; then
                kubectl logs "$pod" -n "$NAMESPACE" -c "$container" --previous > "$logs_dir/${pod}-${container}-previous.log" 2>&1
                print_success "  Collected previous logs: $container"
            fi
        done
    done
}

# Collect ConfigMap information
collect_configmap_info() {
    print_section "Collecting ConfigMap information"
    
    cm_dir="$OUTPUT_DIR/configmaps"
    
    # List ConfigMaps
    kubectl get configmap -n "$NAMESPACE" > "$cm_dir/configmaps-list.txt" 2>&1
    # Get ConfigMaps YAML
    kubectl get configmap -n "$NAMESPACE" -o yaml > "$cm_dir/configmaps.yaml" 2>&1
}

# Collect Custom Resource information
collect_cr_info() {
    print_section "Collecting Custom Resource information"
    
    cr_dir="$OUTPUT_DIR/otelcr"
    
    # List OpentelemetryCollector
    kubectl get opentelemetrycollector -n "$NAMESPACE" > "$cr_dir/opentelemetrycollector-list.txt" 2>&1
    # Get OpentelemetryCollector YAML
    kubectl get opentelemetrycollector -n "$NAMESPACE" -o yaml > "$cr_dir/opentelemetrycollectors.yaml" 2>&1

    print_success "Collected OpentelemetryCollector"
}

# Create summary report
create_summary() {
    print_section "Creating summary report"
    
    summary_file="$OUTPUT_DIR/SUMMARY.txt"
    
    cat > "$summary_file" << EOF
Kubernetes OpenTelemetry Collector Must-Gather Report
=====================================================
Collection Date: $(date)
Output Directory: $OUTPUT_DIR

Cluster Information:
-------------------
Namespace: $NAMESPACE
Release Name: $RELEASE_NAME
Kubectl Context: $(kubectl config current-context)

Contents:
---------
- pods/            : Pod information (list, describe, YAML)
- logs/            : OpenTelemetry Collector pod logs
- configmaps/      : ConfigMaps and extracted config.yaml
- otelcr/          : Custom Resource Information
-----------
EOF
    print_success "Summary report created"
}

# Create archive
create_archive() {
    print_section "Creating archive"
    
    archive_name="${OUTPUT_DIR}.tar.gz"
    
    # Capture tar errors
    tar_error=$(tar -czf "$archive_name" "$OUTPUT_DIR" 2>&1)
    tar_exit_code=$?
    
    if [ $tar_exit_code -eq 0 ]; then
        size=$(du -h "$archive_name" | cut -f1)
        print_success "Archive created: $archive_name - size: $size"       
        echo ""
        print_info "To extract: tar -xzf $archive_name"
    else
        print_error "Failed to create archive - exit code: $tar_exit_code"
        if [ -n "$tar_error" ]; then
            echo "tar error output: $tar_error" >&2
        fi
    fi
}

# Main execution
main() {
    print_banner
    
    print_info "Namespace: $NAMESPACE"
    print_info "Release Name: $RELEASE_NAME"
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Setup
    setup_output_directory
    
    # Collect information
    collect_pod_info
    collect_pod_logs
    collect_configmap_info
    collect_cr_info
    
    # Finalize
    create_summary
    create_archive
    
    # Final message
    echo ""
    print_banner
    print_success "Must-gather collection completed successfully!"
    echo ""
    print_info "Output directory: $OUTPUT_DIR"
    print_info "Archive file: ${OUTPUT_DIR}.tar.gz"
    echo ""
    print_info "Please share the archive file for analysis"
}

# Run main function
main "$@"
