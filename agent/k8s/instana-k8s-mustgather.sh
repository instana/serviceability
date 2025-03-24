#!/bin/sh
###############################################################################
#
# This script collects data for the Instana Host Agent on Kubernetes / OpenShift
#
# Usage:
#   ./instana-k8s-mustgather.sh
#
###############################################################################

# Safer scripting:
# -e  : exit on any command failing
# -u  : treat unset variables as errors
# -o pipefail : fail if any command in a pipeline fails (may not be supported on older sh)
set -euo pipefail

VERSION="1.1.6"
CURRENT_TIME=$(date "+%Y.%m.%d-%H.%M.%S")
MGDIR="instana-k8s-mustgather-${CURRENT_TIME}"

mkdir -p "${MGDIR}"
echo "Version: ${VERSION}" >&2
echo "${VERSION}" > "${MGDIR}/instana-k8s-mustgather-version.txt"

###############################################################################
# Determine if we're on OpenShift (oc) or vanilla K8s (kubectl)
###############################################################################
if command -v oc >/dev/null 2>&1; then
    CMD="oc"
    LIST_NS="instana-agent openshift-controller-manager"
elif command -v kubectl >/dev/null 2>&1; then
    CMD="kubectl"
    LIST_NS="instana-agent"
else
    echo "ERROR: Neither 'oc' nor 'kubectl' is installed or in PATH." >&2
    exit 1
fi

###############################################################################
# Verify required utilities
###############################################################################
if ! command -v awk >/dev/null 2>&1; then
    echo "ERROR: 'awk' is not installed or not in PATH." >&2
    exit 1
fi

if ! command -v sed >/dev/null 2>&1; then
    echo "ERROR: 'sed' is not installed or not in PATH." >&2
    exit 1
fi

###############################################################################
# Helper function to run commands, but log to stderr so it doesn't pollute stdout
###############################################################################
run_cmd() {
    >&2 echo "Running: $*"   # Print debug info to stderr
    "$@"                     # Run the command, leaving stdout clean for capturing
}

###############################################################################
# Collect cluster-level info
###############################################################################
run_cmd "${CMD}" get nodes > "${MGDIR}/node-list.txt"
run_cmd "${CMD}" describe nodes > "${MGDIR}/node-describe.txt"
run_cmd "${CMD}" get namespaces > "${MGDIR}/namespaces.txt"

# If on OpenShift, gather clusteroperators
if [ "${CMD}" = "oc" ]; then
    run_cmd "${CMD}" get clusteroperators > "${MGDIR}/cluster-operators.txt"
fi

###############################################################################
# Gather the instana-agent-config secret data (if it exists)
###############################################################################
echo "Collecting Instana Agent configuration from secret..." >&2
if "${CMD}" get secret instana-agent-config -n instana-agent >/dev/null 2>&1; then
    # Use jsonpath to extract .data
    if ! run_cmd "${CMD}" get secret instana-agent-config -n instana-agent \
        -o jsonpath='{.data}' \
        > "${MGDIR}/instana-agent-config.json"
    then
        echo "WARN: Could not extract Instana Agent configuration from secret." >&2
    fi
else
    echo "(HELM 1.x) Collecting Instana Agent configuration from configMap..." >&2
    if "${CMD}" get cm instana-agent -n instana-agent >/dev/null 2>&1; then
        run_cmd "${CMD}" describe cm instana-agent -n instana-agent \
            > "${MGDIR}/configMap.txt"
    else
        echo "WARN: No configMap named 'instana-agent' in 'instana-agent' namespace." \
            >> "${MGDIR}/configMap.txt"
    fi
fi

###############################################################################
# Collect pod info for the instana-agent namespace
###############################################################################
# 1) Wide output for reference
run_cmd "${CMD}" get pods -n instana-agent -o wide \
    > "${MGDIR}/instana-agent-pod-list.txt"

# 2) Retrieve only the pod names using -o name, then strip the 'pod/' prefix
run_cmd "${CMD}" get pods -n instana-agent -o name \
    | sed 's#^pod/##' \
    > "${MGDIR}/instana-agent-pod-names.txt"

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

    DEST_DIR="${MGDIR}/instana-agent/${POD_NAME}_logs"
    mkdir -p "$(dirname "${DEST_DIR}")"

    echo "Copying logs from pod '${POD_NAME}'..." >&2
    # oc/kubectl cp <pod>:/path <localPath>
    if ! run_cmd "${CMD}" -n instana-agent cp \
        "${POD_NAME}:/opt/instana/agent/data/log/" \
        "${DEST_DIR}"
    then
        echo "WARN: Could not copy logs for pod '${POD_NAME}'" >&2
    fi

done < "${MGDIR}/instana-agent-pod-names.txt"

###############################################################################
# If on OpenShift, gather pods in openshift-controller-manager namespace
###############################################################################
if [ "${CMD}" = "oc" ]; then
    run_cmd "${CMD}" get pods -n openshift-controller-manager -o wide \
        > "${MGDIR}/openshift-controller-manager-pod-list.txt"
fi

###############################################################################
# Function to gather data from a single namespace
###############################################################################
gather_ns_data() {
    ns="$1"
    ns_dir="${MGDIR}/${ns}"
    mkdir -p "${ns_dir}"

    # Collect all resources and events
    run_cmd "${CMD}" get all,events -n "${ns}" -o wide \
        > "${ns_dir}/all-list.txt" 2>&1

    # Describe each pod in that namespace using -o name for real pod names
    run_cmd "${CMD}" get pods -n "${ns}" -o name \
        | sed 's#^pod/##' \
        | awk -v cmd="${CMD}" -v ns="${ns}" -v outdir="${ns_dir}" '
            {
                pod=$1
                # "describe pod" command
                print cmd " -n " ns " describe pod " pod " > " outdir "/" pod "-describe.txt && echo described " pod
            }
        ' | sh

    # Build container list using go-template
    run_cmd "${CMD}" get pods -n "${ns}" \
        -o go-template='{{range $i := .items}}{{range $c := $i.spec.containers}}{{println $i.metadata.name $c.name}}{{end}}{{end}}' \
        > "${ns_dir}/container-list.txt"

    # Gather current logs for each container
    awk -v cmd="${CMD}" -v ns="${ns}" -v outdir="${ns_dir}" '
    {
        pod=$1
        container=$2
        log_file=outdir "/" pod "_" container ".log"
        # Build the command to get logs and redirect
        print cmd " -n " ns " logs " pod " -c " container " --tail=10000 > \"" log_file "\" && echo gathered logs of " pod "_" container
    }
    ' "${ns_dir}/container-list.txt" | sh

    # Gather previous logs for each container (friendly message if none exist)
    awk -v cmd="${CMD}" -v ns="${ns}" -v outdir="${ns_dir}" '
    {
        pod=$1
        container=$2
        prev_log_file=outdir "/" pod "_" container "_previous.log"
        print cmd " -n " ns " logs " pod " -c " container " --tail=10000 -p > \"" prev_log_file "\" 2>&1 && echo gathered previous logs of " pod "_" container " || echo No previous logs available for " pod "_" container
    }
    ' "${ns_dir}/container-list.txt" | sh || true
}

###############################################################################
# Gather data from each namespace in LIST_NS
###############################################################################
for namespace in ${LIST_NS}; do
    gather_ns_data "${namespace}"
done

###############################################################################
# Create a compressed tarball of the must-gather directory
###############################################################################
run_cmd tar czf "${MGDIR}.tgz" "${MGDIR}"
>&2 echo "Must-gather completed. Archive created: ${MGDIR}.tgz"