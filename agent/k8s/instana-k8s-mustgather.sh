#!/bin/sh
###############################################################################
#
# Copyright IBM Corp. 2024, 2025
#
# This script collects data for the Instana Host Agent on Kubernetes / OpenShift
#
# Usage:
#   ./instana-k8s-mustgather.sh [-n NAMESPACE]
#
# Options:
#   -n NAMESPACE  Specify the Instana agent namespace (default: instana-agent)
#   -h            Display this help message
#
###############################################################################

# command_exists checks if command is available for us or not
command_exists() {
    if type "$1" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# exit_with_missing_tool_error is a utility function to exit with missing tool
exit_with_missing_tool_error() {
    echo "ERROR: '$1' is not installed or not in PATH." >&2
    exit 2
}

# determine_cli checks what CLI-tools are available and default to the first one
determine_cli() {
    if command_exists "oc"; then
        echo "oc"
    elif command_exists "kubectl"; then
        echo "kubectl"
    else
        exit_with_missing_tool_error "'oc' nor 'kubectl'"
    fi
}


# determine_platform checks whether we're running on OpenShift or standard Kubernetes using CLI-tool such as 'oc' or 'kubectl'
determine_platform() {
    if $1 get clusterversion > /dev/null 2>&1 || \
       $1 get crd routes.route.openshift.io > /dev/null 2>&1; then
        echo "OpenShift"
    else
        echo "Kubernetes"
    fi
}

# run_cmd helper function to run commands, but log to stderr so it doesn't pollute stdout
run_cmd() {
    >&2 echo "Running: $*"   # Print debug info to stderr
    "$@"                     # Run the command, leaving stdout clean for capturing
}

# Display usage information
show_usage() {
    echo "Usage: $0 [-n NAMESPACE]"
    echo ""
    echo "Options:"
    echo "  -n NAMESPACE  Specify the Instana agent namespace (default: instana-agent)"
    echo "  -h            Display this help message"
}

# Parse command-line arguments
while getopts "n:h" opt; do
    case ${opt} in
        n)
            INSTANA_AGENT_NAMESPACE="${OPTARG}"
            ;;
        h)
            show_usage
            exit 0
            ;;
        \?)
            echo "Invalid option: -${OPTARG}" >&2
            show_usage
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Safer scripting:
# -e  : exit on any command failing
# -u  : treat unset variables as errors
# -o pipefail : fail if any command in a pipeline fails (not supported by dash)
SHELL_EXECUTABLE="/bin/sh"
while IT=$(readlink "${SHELL_EXECUTABLE}"); do SHELL_EXECUTABLE="${IT}"; done
if [ "${SHELL_EXECUTABLE##*/}" = 'dash' ]; then
   set -eu
else
   set -euo pipefail
fi

VERSION="1.1.10"
echo "Version: ${VERSION}" >&2

###############################################################################
# Configuration
###############################################################################
: "${INSTANA_AGENT_NAMESPACE:=instana-agent}"


###############################################################################
# Determine which tool to use (oc or kubectl)
###############################################################################
CLI=$(determine_cli)
PLATFORM=$(determine_platform "$CLI")

###############################################################################
# Verify required utilities are available
###############################################################################
UTILITIES="awk sed tar"

for UTILITY in ${UTILITIES}; do
    if ! command_exists "$UTILITY"; then
        exit_with_missing_tool_error "$UTILITY"
    fi
done

###############################################################################
# Make a dump directory once we've succeeded in all checks above
###############################################################################
CURRENT_TIME=$(date "+%Y%m%d-%H%M%S")
MUSTGATHER_DIR="instana-agent-k8s-mustgather-${VERSION}-${CURRENT_TIME}"
mkdir -p "${MUSTGATHER_DIR}"

###############################################################################
# Collect cluster-level info
###############################################################################
run_cmd "${CLI}" get nodes > "${MUSTGATHER_DIR}/node-list.txt"
run_cmd "${CLI}" describe nodes > "${MUSTGATHER_DIR}/node-describe.txt"
run_cmd "${CLI}" get namespaces > "${MUSTGATHER_DIR}/namespaces.txt"

# If on OpenShift, gather clusteroperators
if [ "${PLATFORM}" = "OpenShift" ]; then
    run_cmd "${CLI}" get clusteroperators > "${MUSTGATHER_DIR}/cluster-operators.txt"
fi

###############################################################################
# Gather the instana-agent-config secret data (if it exists)
###############################################################################
echo "Collecting Instana Agent configuration from secret..." >&2
if "${CLI}" get secret instana-agent-config -n "${INSTANA_AGENT_NAMESPACE}" >/dev/null 2>&1; then
    # Use jsonpath to extract .data
    if ! run_cmd "${CLI}" get secret instana-agent-config -n "${INSTANA_AGENT_NAMESPACE}" \
        -o jsonpath='{.data}' \
        > "${MUSTGATHER_DIR}/instana-agent-config.json"
    then
        echo "WARN: Could not extract Instana Agent configuration from secret." >&2
    fi
else
    echo "(HELM 1.x) Collecting Instana Agent configuration from configMap..." >&2
    if "${CLI}" get cm instana-agent -n "${INSTANA_AGENT_NAMESPACE}" >/dev/null 2>&1; then
        run_cmd "${CLI}" describe cm instana-agent -n "${INSTANA_AGENT_NAMESPACE}" \
            > "${MUSTGATHER_DIR}/configMap.txt"
    else
        echo "WARN: No configMap named 'instana-agent' in 'instana-agent' namespace." \
            >> "${MUSTGATHER_DIR}/configMap.txt"
    fi
fi

###############################################################################
# Collect pod info for the instana-agent namespace
###############################################################################
# 1) Wide output for reference
run_cmd "${CLI}" get pods -n "${INSTANA_AGENT_NAMESPACE}" -o wide \
    > "${MUSTGATHER_DIR}/instana-agent-pod-list.txt"

# 2) Retrieve only the pod names using -o name, then strip the 'pod/' prefix
run_cmd "${CLI}" get pods -n "${INSTANA_AGENT_NAMESPACE}" -o name \
    | sed 's#^pod/##' \
    > "${MUSTGATHER_DIR}/instana-agent-pod-names.txt"

# Copy logs from instana-agent pods, excluding those with 'k8sensor' in their name
while read -r POD_NAME; do
    case "${POD_NAME}" in
        *k8sensor*)
            echo "Skipping k8sensor pod: ${POD_NAME}"
            continue
            ;;
        *controller-manager*)
            echo "Skipping controller-manager pod: ${POD_NAME}"
            continue
            ;;
        *NAME*)
            echo "Skipping line containing: ${POD_NAME}"
            continue
            ;;
    esac

    DEST_DIR="${MUSTGATHER_DIR}/${INSTANA_AGENT_NAMESPACE}/${POD_NAME}"
    mkdir -p "$(dirname "${DEST_DIR}")"

    echo "Copying logs from pod '${POD_NAME}'..." >&2
    # oc/kubectl cp <pod>:/path <localPath>
    if ! run_cmd "${CLI}" -n "${INSTANA_AGENT_NAMESPACE}" cp \
        "${POD_NAME}:/opt/instana/agent/data/log/" \
        "${DEST_DIR}_logs"
    then
        echo "WARN: Could not copy logs for pod '${POD_NAME}'" >&2
    fi

    echo "Executing Agent Diagnostics collection on pod '${POD_NAME}'...">&2
    run_cmd "${CLI}" exec -i "$POD_NAME" -n "$INSTANA_AGENT_NAMESPACE" -- /opt/instana/agent/jvm/bin/java -jar /opt/instana/agent/bin/agent-diagnostic.jar version > "${DEST_DIR}_diagnostics_version"
    run_cmd "${CLI}" exec -i "$POD_NAME" -n "$INSTANA_AGENT_NAMESPACE" -- /opt/instana/agent/jvm/bin/java -jar /opt/instana/agent/bin/agent-diagnostic.jar check-ports > "${DEST_DIR}_diagnostics_check-ports"
    run_cmd "${CLI}" exec -i "$POD_NAME" -n "$INSTANA_AGENT_NAMESPACE" -- /opt/instana/agent/jvm/bin/java -jar /opt/instana/agent/bin/agent-diagnostic.jar check-configuration > "${DEST_DIR}_diagnostics_check-configuration"
    echo "Execution on pod '${POD_NAME} complete'...">&2

done < "${MUSTGATHER_DIR}/instana-agent-pod-names.txt"

###############################################################################
# If on OpenShift, gather pods in openshift-controller-manager namespace
###############################################################################
if [ "${PLATFORM}" = "OpenShift" ]; then
    run_cmd "${CLI}" get pods -n openshift-controller-manager -o wide \
        > "${MUSTGATHER_DIR}/openshift-controller-manager-pod-list.txt"
fi

###############################################################################
# Function to gather data from a single namespace
###############################################################################
gather_namesace_data() {
    ns="$1"
    ns_dir="${MUSTGATHER_DIR}/${ns}"
    mkdir -p "${ns_dir}"

    # Collect all resources and events
    run_cmd "${CLI}" get all,events -n "${ns}" -o wide \
        > "${ns_dir}/all-list.txt" 2>&1

    # Describe each pod in that namespace using -o name for real pod names
    run_cmd "${CLI}" get pods -n "${ns}" -o name \
        | sed 's#^pod/##' \
        | awk -v cmd="${CLI}" -v ns="${ns}" -v outdir="${ns_dir}" '
            {
                pod=$1
                # "describe pod" command
                print cmd " -n " ns " describe pod " pod " > " outdir "/" pod "-describe.txt && echo described " pod
            }
        ' | sh

    # Build container list using go-template
    run_cmd "${CLI}" get pods -n "${ns}" \
        -o go-template='{{range $i := .items}}{{range $c := $i.spec.containers}}{{println $i.metadata.name $c.name}}{{end}}{{end}}' \
        > "${ns_dir}/container-list.txt"

    # Gather current logs for each container
    awk -v cmd="${CLI}" -v ns="${ns}" -v outdir="${ns_dir}" '
    {
        pod=$1
        container=$2
        log_file=outdir "/" pod "_" container ".log"
        # Build the command to get logs and redirect
        print cmd " -n " ns " logs " pod " -c " container " --tail=10000 > \"" log_file "\" && echo gathered logs of " pod "_" container
    }
    ' "${ns_dir}/container-list.txt" | sh

    # Gather previous logs for each container (friendly message if none exist)
    awk -v cmd="${CLI}" -v ns="${ns}" -v outdir="${ns_dir}" '
    {
        pod=$1
        container=$2
        prev_log_file=outdir "/" pod "_" container "_previous.log"
        print cmd " -n " ns " logs " pod " -c " container " --tail=10000 -p > \"" prev_log_file "\" 2>&1 && echo gathered previous logs of " pod "_" container " || echo No previous logs available for " pod "_" container
    }
    ' "${ns_dir}/container-list.txt" | sh || true
}

###############################################################################
# Gather data from each namespace in NAMESPACES
###############################################################################
NAMESPACES=$INSTANA_AGENT_NAMESPACE

if [ "$PLATFORM" = "OpenShift" ]; then
    NAMESPACES="${NAMESPACES} openshift-controller-manager"
fi

for namespace in ${NAMESPACES}; do
    gather_namesace_data "${namespace}"
done

###############################################################################
# Create a compressed tarball of the must-gather directory
###############################################################################
run_cmd tar czf "${MUSTGATHER_DIR}.tgz" "${MUSTGATHER_DIR}"
>&2 echo "Must-gather completed. Archive created: ${MUSTGATHER_DIR}.tgz"
