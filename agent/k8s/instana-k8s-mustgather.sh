#!/bin/sh
###############################################################################
#
# Copyright IBM Corp. 2024, 2026
#
# Instana Kubernetes Must-Gather Script
# Collects diagnostic data for Instana agents using label-based discovery
#
# Usage:
#   ./instana-k8s-mustgather.sh [-t TAIL_LINES] [-d]
#
# Options:
#   -t TAIL_LINES  Number of log lines to collect (default: 10000)
#   -d             Enable debug mode
#   -h             Display help
#
###############################################################################

set -eu

VERSION="2.0.0"
LOG_TAIL_LINES=10000
DEBUG_MODE=false

# Discovery labels (tried in order)
DISCOVERY_LABELS="
app.kubernetes.io/name=instana-agent
app.kubernetes.io/component=instana-agent
app.kubernetes.io/part-of=instana
app.kubernetes.io/name=instana-agent-operator
app=instana-agent
"

INSTANA_K8S_SENSOR="k8sensor"
INSTANA_AGENT_OPERATOR="controller_manager"
INSTANA_AGENT="agent"

# =============================================================================
# Logging
# =============================================================================

log() { printf "[INFO] %b\n" "$*" >&2; }
log_debug() { 
    if [ "${DEBUG_MODE}" = true ]; then 
        printf "[DEBUG] %b\n" "$*" >&2
    fi
}
log_warn() { printf "[WARN] %b\n" "$*" >&2; }
log_error() { printf "[ERROR] %b\n" "$*" >&2; exit 1; }

# =============================================================================
# Utilities
# =============================================================================

command_exists() { command -v "$1" >/dev/null 2>&1; }

identify_pod() {
    pod_name="$1"
    case "${pod_name}" in
        *k8sensor*)
            echo "${INSTANA_K8S_SENSOR}"
            ;;
        *controller-manager*)
            echo "${INSTANA_AGENT_OPERATOR}"
            ;;
        instana-agent*)
            echo "${INSTANA_AGENT}"
            ;;
        *)
            log_warn "Unrecognized pod: ${pod_name}"
            echo "unknown"
            ;;
    esac
}

make_directories() {
    for dir in "$@"; do
        log "Creating directory at ${dir}..."
        if [ ! -d "${dir}" ]; then
            mkdir -p "${dir}"
        fi
    done
}

# =============================================================================
# CLI and Platform Detection
# =============================================================================

detect_cli_and_platform() {
    has_oc=false
    has_kubectl=false
    
    command_exists oc && has_oc=true
    command_exists kubectl && has_kubectl=true
    
    if [ "${has_oc}" = false ] && [ "${has_kubectl}" = false ]; then
        log_error "Neither 'oc' nor 'kubectl' detected"
    fi
    
    # Use kubectl for platform detection (more universal)
    test_cli="kubectl"
    [ "${has_kubectl}" = false ] && test_cli="oc"
    
    # Detect platform
    if ${test_cli} get clusterversion >/dev/null 2>&1 || \
       ${test_cli} get crd routes.route.openshift.io >/dev/null 2>&1; then
        PLATFORM="OpenShift"
        CLI="${has_oc:+oc}"
        CLI="${CLI:-kubectl}"
        log "Detected OpenShift platform, using CLI: ${CLI}"
    else
        PLATFORM="Kubernetes"
        CLI="${has_kubectl:+kubectl}"
        CLI="${CLI:-oc}"
        log "Detected Kubernetes platform, using CLI: ${CLI}"
    fi
}

# =============================================================================
# Discovery
# =============================================================================

discover_instana_pods() {
    log "Discovering Instana related pods and containers cluster-wide..."
    
    all_pod_containers=""
    found_any=false
    
    for label in ${DISCOVERY_LABELS}; do
        log "Searching with label: ${label}"
        
        # Discover pods with their containers in one query
        discoveries=$(${CLI} get pods --all-namespaces \
            -l "${label}" \
            -o go-template='{{range .items}}{{$ns:=.metadata.namespace}}{{$pod:=.metadata.name}}{{range .spec.containers}}{{println $ns $pod .name}}{{end}}{{end}}' \
            --no-headers 2>/dev/null || true)
        
        if [ -n "${discoveries}" ]; then
            COUNT=$(echo "${discoveries}" | wc -l | tr -d ' ')
            log "Found ${COUNT} containers using label: ${label}"
            
            # Accumulate all discovered pod-container combinations
            if [ -z "${all_pod_containers}" ]; then
                all_pod_containers="${discoveries}"
            else
                all_pod_containers="${all_pod_containers}
${discoveries}"
            fi
            found_any=true
        fi
    done
    
    if [ "${found_any}" = false ]; then
        log_warn "No Instana pods discovered via labels"
        return 1
    fi
    
    # Deduplicate and save results
    discovered_containers=$(echo "${all_pod_containers}" | sort -u)
    container_count=$(echo "${discovered_containers}" | wc -l | tr -d ' ')
    
    # Extract unique pods and namespaces
    discovered_pods=$(echo "${discovered_containers}" | awk '{print $1, $2}' | sort -u)
    pod_count=$(echo "${discovered_pods}" | wc -l | tr -d ' ')
    discovered_namespaces=$(echo "${discovered_pods}" | awk '{print $1}' | sort -u)
    namespace_count=$(echo "${discovered_namespaces}" | wc -l | tr -d ' ')
    
    log "Total: ${pod_count} unique pods with ${container_count} containers in ${namespace_count} namespace(s)"
    
    # Save all three formats for different use cases
    echo "${discovered_containers}" > "${TMP_DIR}/discovered-pods-containers.txt"
    echo "${discovered_namespaces}" > "${TMP_DIR}/discovered-namespaces.txt"
    
    return 0
}

# =============================================================================
# Data Collection
# =============================================================================

collect_cluster_info() {
    log "Collecting cluster info..."
    ${CLI} get nodes > "${MUSTGATHER_DIR}/cluster-info_nodes.txt"
    ${CLI} describe nodes > "${MUSTGATHER_DIR}/cluster-info_nodes-describe.txt"
    ${CLI} get namespaces > "${MUSTGATHER_DIR}/cluster-info_namespaces.txt"
    
    if [ "${PLATFORM}" = "OpenShift" ]; then
        ${CLI} get clusteroperators > "${MUSTGATHER_DIR}/cluster-info_openshift_clusteroperators.txt" 2>&1 || true
    fi
}

collect_agent_config() {
    log "Collecting agent configuration..."
    
    while IFS= read -r ns; do
        ns_dir="${MUSTGATHER_DIR}/namespaces/${ns}"
        make_directories "${ns_dir}"

        if ${CLI} get secret instana-agent-config -n "${ns}" >/dev/null 2>&1; then
            ${CLI} get secret instana-agent-config -n "${ns}" -o jsonpath='{.data}' \
                > "${ns_dir}/agent-config.json" 2>&1 || true
        fi
        
        # Instana agent ConfigMap on Helm 1.x
        if ${CLI} get cm instana-agent -n "${ns}" >/dev/null 2>&1; then
            ${CLI} describe cm instana-agent -n "${ns}" \
                > "${ns_dir}/agent-configmap.txt" 2>&1 || true
        fi
    done < "${TMP_DIR}/discovered-namespaces.txt"
}

collect_namespace_data() {
    ns="$1"
    ns_dir="${MUSTGATHER_DIR}/namespaces/${ns}"
    make_directories "${ns_dir}"
    file_path="${ns_dir}/resources-and-events.txt"
    
    log "Collecting ${ns}-namespace resources and events to ${file_path}"
    
    # Resources and events
    ${CLI} get all,events -n "${ns}" -o wide > "${file_path}" 2>&1 || true
}

collect_pod_data() {
    log "Collecting pod data..."
    
    processed=0
    skipped=0
    
    while IFS= read -r line; do
        [ -z "${line}" ] && continue
        
        ns=$(echo "${line}" | awk '{print $1}')
        pod=$(echo "${line}" | awk '{print $2}')
        container=$(echo "${line}" | awk '{print $3}')
        
        pod_type=$(identify_pod "${pod}")
        log "Processing ${pod_type} pod: ${ns}/${pod}"

        processed=$((processed + 1))
        dump_dir="${MUSTGATHER_DIR}/namespaces/${ns}/pods/${pod}/containers/${container}"

        # Agent specific collection
        if [ "$pod_type" = "$INSTANA_AGENT" ]; then
            make_directories "${dump_dir}/agent-logs" "${dump_dir}/diagnostics-tool"

            # Copy agent logs
            ${CLI} -n "${ns}" cp "${pod}:/opt/instana/agent/data/log/" "${dump_dir}/agent-logs" 2>&1 || \
                log_warn "Failed to copy logs from ${pod}"
            
            # Run diagnostics
            for command in version check-ports check-configuration; do
                log_debug "Running diagnostic: ${command} on ${pod}"
                ${CLI} exec -i "${pod}" -n "${ns}" -- \
                    /opt/instana/agent/jvm/bin/java -jar /opt/instana/agent/bin/agent-diagnostic.jar "${command}" \
                    > "${dump_dir}/diagnostics-tool/${command}.log" 2>&1 </dev/null || \
                    log_warn "Diagnostic ${command} failed for ${pod}"
            done
        fi
        
        # General kubectl commands
        make_directories "${dump_dir}/kubectl"
        ${CLI} logs "${pod}" -c "${container}" -n "${ns}" --tail="${LOG_TAIL_LINES}" \
            > "${dump_dir}/kubectl/log.log" 2>&1 || true
        
        ${CLI} logs "${pod}" -c "${container}" -n "${ns}" --tail="${LOG_TAIL_LINES}" -p \
            > "${dump_dir}/kubectl/log_previous.log" 2>&1 || true

        ${CLI} describe pod "${pod}" -n "${ns}" \
            > "${dump_dir}/kubectl/describe.txt" 2>&1 || true

    done < "${TMP_DIR}/discovered-pods-containers.txt"
    
    log "Pod data collected (processed: ${processed}, skipped: ${skipped})"
}



show_usage() {
    cat << EOF
Usage: $0 [-t TAIL_LINES] [-d] [-h]

Collects Instana agent diagnostics using label-based discovery.

Options:
  -t TAIL_LINES  Log lines to collect (default: 10000)
  -d             Debug mode
  -h             Show help

Version: ${VERSION}
EOF
}

parse_args() {
    while getopts "t:n:dh" opt; do
        case ${opt} in
            t) LOG_TAIL_LINES="${OPTARG}" ;;
            d) DEBUG_MODE=true ;;
            n) log_warn "Ignoring -n flag as it is no longer supported." ;;
            h) show_usage; exit 0 ;;
            *) show_usage; exit 1 ;;
        esac
    done
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"
    
    log "Instana K8s Must-Gather v${VERSION}"
    
    # Validate
    for util in awk sed tar date sort wc tr; do
        command_exists "${util}" || log_error "Missing utility in your local commandline: ${util}"
    done
    
    # Setup
    detect_cli_and_platform
    
    current_time=$(date "+%Y%m%d-%H%M%S")
    MUSTGATHER_DIR="instana-k8s-mustgather-${VERSION}-${current_time}"
    TMP_DIR="tmp"
    make_directories "${MUSTGATHER_DIR}" "${TMP_DIR}"
    
    # Discover
    if ! discover_instana_pods; then
        log_error "No Instana pods found. Ensure agents are deployed and labeled correctly."
    fi
    
    # Collect
    collect_cluster_info
    collect_agent_config
    
    while IFS= read -r ns; do
        collect_namespace_data "${ns}"
    done < "${TMP_DIR}/discovered-namespaces.txt"
    
    collect_pod_data
    
    # OpenShift extras
    if [ "${PLATFORM}" = "OpenShift" ]; then
        collect_namespace_data "openshift-controller-manager"
    fi
    
    # Create an archive tgz file from the directory
    log "Creating archive..."
    tar czf "${MUSTGATHER_DIR}.tgz" "${MUSTGATHER_DIR}"
    
    log "Archived at: ${MUSTGATHER_DIR}.tgz"

    # Cleanup all temporary files and directories needed to make the archive if not in debug mode
    if [ "${DEBUG_MODE}" = false ]; then 
        log "Removing temporary directories: \n ./${TMP_DIR} \n ./${MUSTGATHER_DIR}"
        rm -rf "./${TMP_DIR}"
        rm -rf "./${MUSTGATHER_DIR}"
    fi

    log "Complete"
}

main "$@"
