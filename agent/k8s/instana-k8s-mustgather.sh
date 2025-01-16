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
# -o pipefail : fail if any command in a pipeline fails (may not be supported on all sh variants)
set -euo pipefail

VERSION="250114"
CURRENT_TIME=$(date "+%Y.%m.%d-%H.%M.%S")
MGDIR="instana-mustgather-${CURRENT_TIME}"

mkdir -p "${MGDIR}"
echo "${VERSION}" > "${MGDIR}/version.txt"

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
# Check for awk
if ! command -v awk >/dev/null 2>&1; then
    echo "ERROR: 'awk' is not installed or not in PATH." >&2
    exit 1
fi

# Check for jq (required to extract instana-agent-config)
if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: 'jq' is not installed or not in PATH." >&2
    exit 1
fi

###############################################################################
# Helper function to run commands, echoing them first
###############################################################################
run_cmd() {
    echo "Running: $*"
    "$@"
}

###############################################################################
# Collect cluster-level info
###############################################################################
# Node info
run_cmd "${CMD}" get nodes > "${MGDIR}/node-list.txt"
run_cmd "${CMD}" describe nodes > "${MGDIR}/node-describe.txt"

# Namespaces info
run_cmd "${CMD}" get namespaces > "${MGDIR}/namespaces.txt"

# OpenShift cluster operators (if oc)
if [ "${CMD}" = "oc" ]; then
    run_cmd "${CMD}" get clusteroperators > "${MGDIR}/cluster-operators.txt"
fi

###############################################################################
# Gather instana-agent-config secret contents (new approach)
#
# If you’re on OpenShift, use 'oc' instead of 'kubectl'
# This extracts 'configuration.yaml' from the base64-encoded secret
###############################################################################
if "${CMD}" get secret instana-agent-config -n instana-agent >/dev/null 2>&1; then
    echo "Collecting Instana Agent configuration from secret..."
    "${CMD}" get secret instana-agent-config -n instana-agent -o json \
      | jq -r '.data["configuration.yaml"]' \
      | base64 -d \
      > "${MGDIR}/configuration.yaml" \
      || echo "WARN: Could not extract Instana Agent configuration."
else
    echo "No secret named 'instana-agent-config' in 'instana-agent' namespace." \
        > "${MGDIR}/configuration.yaml"
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

    echo "Copying logs from pod '${POD_NAME}'..."
    run_cmd "${CMD}" -n instana-agent cp \
        "${POD_NAME}:/opt/instana/agent/data/log/" \
        "${DEST_DIR}" || echo "WARN: Could not copy logs for pod ${POD_NAME}"

done < "${MGDIR}/instana-agent-pod-names.txt"

###############################################################################
# If on OpenShift, gather pods in the openshift-controller-manager namespace
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

    # Describe each pod in that namespace
    #   We parse only real pod names using -o name, then strip 'pod/'
    run_cmd "${CMD}" get pods -n "${ns}" -o name \
        | sed 's#^pod/##' \
        | awk -v cmd="${CMD}" -v ns="${ns}" -v outdir="${ns_dir}" '
            {
                pod=$1
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
            print cmd " -n " ns " logs " pod " -c " container " --tail=10000 > \"" log_file "\" && echo gathered logs of " pod "_" container
        }
    ' "${ns_dir}/container-list.txt" | sh

    # Gather previous logs for each container (may not exist if container never restarted)
    awk -v cmd="${CMD}" -v ns="${ns}" -v outdir="${ns_dir}" '
        {
            pod=$1
            container=$2
            prev_log_file=outdir "/" pod "_" container "_previous.log"
            print cmd " -n " ns " logs " pod " -c " container " --tail=10000 -p > \"" prev_log_file "\" && echo gathered previous logs of " pod "_" container
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
echo "Must-gather completed. Archive created: ${MGDIR}.tgz"
