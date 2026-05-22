#!/bin/sh

# OpenTelemetry Collector Must-Gather Script
# Collects system information, configuration and logs
# Usage: ./must-gather-host-collector.sh [collector_install_path]

set -e

# Initialize variables
DEFAULT_OTELCOL_INSTALL_PATH="/opt/instana/collector"
OTELCOL_INSTALL_PATH="$DEFAULT_OTELCOL_INSTALL_PATH"

# Parse arguments
if [ $# -gt 0 ]; then
    OTELCOL_INSTALL_PATH="$1"
fi    

# Check if default collector directory exists
if [ ! -d "$OTELCOL_INSTALL_PATH" ]; then
    echo "================================================"
    echo "  OpenTelemetry Collector Must-Gather Tool"
    echo "================================================"
    echo ""
    if [ "$OTELCOL_INSTALL_PATH" != "$DEFAULT_OTELCOL_INSTALL_PATH" ]; then
        echo "Error: The path $OTELCOL_INSTALL_PATH does not exist"
    else
        echo "[ERROR] Default path $OTELCOL_INSTALL_PATH does not exist"
        echo "[ERROR] Please provide the collector installation path as parameter"
    fi
    echo ""
    echo "Usage: $0 [collector_install_path]"
    echo "Example: $0 /custom/path/to/collector"
    echo ""
    exit 1
fi

# Set derived paths
OTELCOL_CONFIG_PATH="${OTELCOL_INSTALL_PATH}/config"
OTELCOL_LOGS_PATH="${OTELCOL_INSTALL_PATH}/logs"

# Output directory setup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="host-otel-must-gather-${TIMESTAMP}"

# Banner
print_banner() {
    echo "================================================"
    echo "  OpenTelemetry Collector Must-Gather Tool"
    echo "================================================"
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
    for cmd in tar date find du uname hostname df wc cut; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            if [ -n "$missing_tools" ]; then
                missing_tools="$missing_tools $cmd"
            else
                missing_tools="$cmd"
            fi
        fi
    done
    
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
    
    mkdir -p "$OUTPUT_DIR/system" "$OUTPUT_DIR/logs" "$OUTPUT_DIR/config"
    
    print_success "Created output directory: $OUTPUT_DIR"
}

# Collect system information
collect_system_info() {
    print_section "Collecting system information"
    
    sys_dir="$OUTPUT_DIR/system"
    
    # Kernel version
    uname -a > "$sys_dir/kernel-version.txt"
    print_success "Collected kernel version"
    
    # Hostname
    hostname > "$sys_dir/hostname.txt"
    print_success "Collected hostname"
    
    free -h > "$sys_dir/memory-usage.txt" 2>/dev/null || true
    
    # Disk space
    df -h > "$sys_dir/disk-space.txt"
    print_success "Collected disk space information"
}

# Collect OpenTelemetry Collector logs
collect_collector_logs() {
    print_section "Collecting OpenTelemetry Collector logs"
    
    logs_path="$OTELCOL_LOGS_PATH"
    logs_dir="$OUTPUT_DIR/logs"
    
    if [ -d "$logs_path" ]; then
        cp -r "$logs_path"/* "$logs_dir/" 2>/dev/null || true
        
        # Count collected log files
        log_count=$(find "$logs_dir" -type f | wc -l)
        print_success "Collected $log_count log file(s)"
        
        # Create log file inventory
        find "$logs_dir" -type f -exec ls -lh {} \; > "$logs_dir/log-inventory.txt"
    else
        print_error "Logs directory not found: $logs_path"
    fi
}

# Collect collector configuration
collect_collector_config() {
    print_section "Collecting OpenTelemetry Collector configuration"
    
    config_dir="$OUTPUT_DIR/config"
    
    if [ -d "$OTELCOL_CONFIG_PATH" ]; then
        cp "$OTELCOL_CONFIG_PATH"/*.env  "$config_dir/" > /dev/null 2>&1
        cp "$OTELCOL_CONFIG_PATH"/*.yaml "$config_dir/" > /dev/null 2>&1
        print_success "Collected config.yaml and config.env from $config_dir"
    else
        print_error "Configuration directory not found: $OTELCOL_CONFIG_PATH"
        printf "Please enter the directory path containing config.yaml (or press Enter to skip): "
        read -r enter_path
        
        if [ -n "$enter_path" ] && [ -d "$enter_path" ]; then
            cp "$enter_path/"*.env  "$config_dir/" > /dev/null 2>&1
            cp "$enter_path/"*.yaml "$config_dir/" > /dev/null 2>&1
            print_success "Collected config.yaml and config.env from $enter_path"
        else
            print_info "Skipping configuration collection"
        fi
    fi
}

# Create summary report
create_summary() {
    print_section "Creating summary report"
    
    summary_file="$OUTPUT_DIR/SUMMARY.txt"
    
    cat > "$summary_file" << EOF
OpenTelemetry Collector Must-Gather Report
==========================================
Collection Date: $(date)
Output Directory: $OUTPUT_DIR

Contents:
---------
- system/         : System information (OS, memory, disk)
- logs/           : OpenTelemetry Collector logs
- config/         : Collector configuration files

Notes:
------
EOF

    if [ ! -f "$OUTPUT_DIR/config/config.yaml" ]; then
        echo "- Configuration file was not found or collected" >> "$summary_file"
    fi
    
    if [ ! -d "$OUTPUT_DIR/logs" ] || [ -z "$(ls -A "$OUTPUT_DIR/logs")" ]; then
        echo "- Collector logs were not found or collected" >> "$summary_file"
    fi
    
    print_success "Summary report created: $summary_file"
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
        print_success "Archive created: $archive_name (Size: $size)"
        
        echo ""
        print_info "To extract: tar -xzf $archive_name"
    else
        print_error "Failed to create archive (exit code: $tar_exit_code)"
        if [ -n "$tar_error" ]; then
            echo "tar error output: $tar_error" >&2
        fi
    fi
}

# Main execution
main() {
    print_banner
    
    print_info "Starting must-gather collection..."
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Setup
    setup_output_directory
    
    # Collect information
    collect_system_info
    collect_collector_logs
    collect_collector_config
    
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
