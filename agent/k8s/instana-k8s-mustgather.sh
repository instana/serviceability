#!/bin/sh
###############################################################################
#
# This script is used to collect data for
# the Instana Host Agent on Kubernetes / OpenShift
#
# Usage:
#   ./instana-k8s-mustgather.sh
#
###############################################################################

# Safer scripting: stop on errors (-e), fail on unset vars (-u), fail on pipeline errors (pipefail).
# Note: some older sh variants may not support pipefail; if that’s the case, remove `-o pipefail`.
set -euo pipefail

VERSION="1.1.1"
CURRENT_TIME=$(date "+%Y.%m.%d-%H.%M.%S")
MGDIR="instana-mustgather-${CURRENT_TIME}"

mkdir -p "${MGDIR}"
echo "${VERSION}" > "${MGDIR}/version.txt"

# Determine if we're on OpenShift (oc) or vanilla K8s (kubectl)
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

# Ensure awk is available
if ! command -v awk >/dev/null 2>&1; then
    echo "ERROR: 'awk' is not installed or not in PATH." >&2
    exit 1
fi

###############################################################################
# Helper function to run commands, echoing them first
###############################################################################
run_cmd() {
    echo "Running: $*"
    # Execute the command with all arguments properly expanded
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

# If on OpenShift, gather clusteroperators
if [ "${CMD}" = "oc" ]; then
    run_cmd "${CMD}" get clusteroperators > "${MGDIR}/cluster-operators.txt"
fi

###############################################################################
# Check if instana-agent config map exists and collect it
###############################################################################
if "${CMD}" get cm instana-agent -n instana-agent >/dev/null 2>&1; then
    run_cmd "${CMD}" describe cm instana-agent -n instana-agent \
        > "${MGDIR}/configMap.txt"
else
    echo "No configMap named 'instana-agent' in 'instana-agent' namespace." \
        >> "${MGDIR}/configMap.txt"
fi

###############################################################################
# Collect pod info for the instana-agent namespace
###############################################################################
# 1) Wide output for reference
run_cmd "${CMD}" get pods -n instana-agent -o wide \
    > "${MGDIR}/instana-agent-pod-list.txt"

# 2) Parse only the NAME column for actual script logic (skips header with NR>1)
run_cmd "${CMD}" get pods -n instana-agent \
    | awk 'NR>1 {print $1}' \
    > "${MGDIR}/instana-agent-pod-names.txt"

# Copy logs from instana-agent pods (excluding pods containing "k8sensor")
while read -r POD_NAME; do
    # Skip pods that match 'k8sensor'
    case "${POD_NAME}" in
        *k8sensor*)
            echo "Skipping k8sensor pod: ${POD_NAME}"
            continue
            ;;
        *controller-manager*) continue ;;
        *NAME*) continue ;;
    esac

    DEST_DIR="${MGDIR}/instana-agent/${POD_NAME}_logs"
    mkdir -p "$(dirname "${DEST_DIR}")"

    echo "Copying logs from pod '${POD_NAME}'..."
    run_cmd "${CMD}" -n instana-agent cp \
        "${POD_NAME}:/opt/instana/agent/data/log/" \
        "${DEST_DIR}" || echo "WARN: Could not copy logs for pod ${POD_NAME}"

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

    # Describe each pod in that namespace
    run_cmd "${CMD}" get pods -n "${ns}" \
        | awk -v cmd="${CMD}" -v ns="${ns}" -v outdir="${ns_dir}" '
        NR>1 {
            pod=$1
            print cmd " -n " ns " describe pod " pod " > " outdir "/" pod "-describe.txt && echo described " pod
        }' | sh

    # Build container list
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

    # Gather previous logs for each container (may not exist if no restarts)
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
