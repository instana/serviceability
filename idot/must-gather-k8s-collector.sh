#!/bin/sh

# Kubernetes OpenTelemetry Collector Must-Gather Script
# Collects diagnostic information from OTel Collector deployed via Helm
# Usage: ./must-gather-k8s-collector.sh [namespace] [release-name]

set -e

# Default values
DEFAULT_NAMESPACE="default"
DEFAULT_RELEASE_NAME="opentelemetry-collector"

# Parse arguments
NAMESPACE="${1:-$DEFAULT_NAMESPACE}"
RELEASE_NAME="${2:-$DEFAULT_RELEASE_NAME}"

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
    
    mkdir -p "$OUTPUT_DIR"/{pods,configmaps,logs}
    
    print_success "Created output directory: $OUTPUT_DIR"
}

# Collect pod information
collect_pod_info() {
    print_section "Collecting pod information"
    
    local pods_dir="$OUTPUT_DIR/pods"
    
    # Get pods with label selector for OTel Collector
    local label_selector="app.kubernetes.io/instance=${RELEASE_NAME}"
    
    # List pods - capture both stdout and stderr
    if ! kubectl get pods -n "$NAMESPACE" -l "$label_selector" -o wide > "$pods_dir/pods-list.txt" 2>&1; then
        print_error "Failed to list pods. Check kubectl connectivity and permissions."
        cat "$pods_dir/pods-list.txt" >&2
        return 1
    fi
    
    # Count pods - check for kubectl errors
    local pod_count_output
    if ! pod_count_output=$(kubectl get pods -n "$NAMESPACE" -l "$label_selector" --no-headers 2>&1); then
        print_error "Failed to query pods: $pod_count_output"
        return 1
    fi
    
    local pod_count=$(echo "$pod_count_output" | wc -l | tr -d ' ')
    
    # Check if we actually got any pods (empty output means 0 pods)
    if [ -z "$pod_count_output" ] || [ "$pod_count" -eq 0 ]; then
        print_error "No pods found with label: $label_selector"
        print_info "Verify the namespace ($NAMESPACE) and release name ($RELEASE_NAME) are correct"
        return 1
    fi
    
    print_success "Found $pod_count pod(s)"
    
    # Describe pods
    if ! kubectl describe pods -n "$NAMESPACE" -l "$label_selector" > "$pods_dir/pods-describe.txt" 2>&1; then
        print_error "Failed to describe pods"
        return 1
    fi
    print_success "Collected pod descriptions"
    
    # Get pod resource usage (optional - metrics server may not be available)
    if ! kubectl top pods -n "$NAMESPACE" -l "$label_selector" > "$pods_dir/pods-top.txt" 2>&1; then
        echo "Metrics server not available or insufficient permissions" > "$pods_dir/pods-top.txt"
        print_info "Could not collect pod resource usage (metrics server may not be available)"
    else
        print_success "Collected pod resource usage"
    fi
}

# Collect pod logs
collect_pod_logs() {
    print_section "Collecting pod logs"
    
    local logs_dir="$OUTPUT_DIR/logs"
    local label_selector="app.kubernetes.io/instance=${RELEASE_NAME}"
    
    # Get all pods - check for kubectl errors
    local pods
    if ! pods=$(kubectl get pods -n "$NAMESPACE" -l "$label_selector" -o jsonpath='{.items[*].metadata.name}' 2>&1); then
        print_error "Failed to query pods for log collection: $pods"
        return 1
    fi
    
    if [ -z "$pods" ]; then
        print_error "No pods found to collect logs"
        return 1
    fi
    
    for pod in $pods; do
        print_info "Collecting logs from pod: $pod"
        
        # Get container names
        local containers=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)
        
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
    
    local cm_dir="$OUTPUT_DIR/configmaps"
    local label_selector="app.kubernetes.io/instance=${RELEASE_NAME}"
    
    # List ConfigMaps
    if ! kubectl get configmaps -n "$NAMESPACE" -l "$label_selector" > "$cm_dir/configmaps-list.txt" 2>&1; then
        print_error "Failed to list ConfigMaps"
        return 1
    fi
    
    # Get ConfigMaps YAML
    if ! kubectl get configmaps -n "$NAMESPACE" -l "$label_selector" -o yaml > "$cm_dir/configmaps.yaml" 2>&1; then
        print_error "Failed to get ConfigMaps YAML"
        return 1
    fi
    print_success "Collected ConfigMaps"
    
    # Extract config.yaml from ConfigMap
    local configmaps
    if ! configmaps=$(kubectl get configmaps -n "$NAMESPACE" -l "$label_selector" -o jsonpath='{.items[*].metadata.name}' 2>&1); then
        print_error "Failed to query ConfigMaps: $configmaps"
        return 1
    fi
    
    if [ -z "$configmaps" ]; then
        print_info "No ConfigMaps found with label: $label_selector"
        return 0
    fi
    
    for cm in $configmaps; do
        # Try to extract config.yaml or relay.yaml (common keys)
        kubectl get configmap "$cm" -n "$NAMESPACE" -o jsonpath='{.data.relay}' > "$cm_dir/${cm}-config.yaml" 2>/dev/null || \
        kubectl get configmap "$cm" -n "$NAMESPACE" -o jsonpath='{.data.config\.yaml}' > "$cm_dir/${cm}-config.yaml" 2>/dev/null || \
        kubectl get configmap "$cm" -n "$NAMESPACE" -o yaml > "$cm_dir/${cm}-full.yaml" 2>/dev/null
        
        if [ -s "$cm_dir/${cm}-config.yaml" ]; then
            print_success "Extracted config from ConfigMap: $cm"
        fi
    done
}

# Create summary report
create_summary() {
    print_section "Creating summary report"
    
    local summary_file="$OUTPUT_DIR/SUMMARY.txt"
    
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

Pod Summary:
-----------
EOF

    local label_selector="app.kubernetes.io/instance=${RELEASE_NAME}"
    kubectl get pods -n "$NAMESPACE" -l "$label_selector" --no-headers 2>/dev/null >> "$summary_file" || echo "No pods found" >> "$summary_file"
    
    echo "" >> "$summary_file"
    echo "Service Summary:" >> "$summary_file"
    echo "---------------" >> "$summary_file"
    kubectl get services -n "$NAMESPACE" -l "$label_selector" --no-headers 2>/dev/null >> "$summary_file" || echo "No services found" >> "$summary_file"
    
    print_success "Summary report created"
}

# Create archive
create_archive() {
    print_section "Creating archive"
    
    local archive_name="${OUTPUT_DIR}.tar.gz"
    
    tar -czf "$archive_name" "$OUTPUT_DIR" 2>/dev/null
    
    if [ -f "$archive_name" ]; then
        local size=$(du -h "$archive_name" | cut -f1)
        print_success "Archive created: $archive_name (Size: $size)"
        
        echo ""
        print_info "To extract: tar -xzf $archive_name"
    else
        print_error "Failed to create archive"
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
main
