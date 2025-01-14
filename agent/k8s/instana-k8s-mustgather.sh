#!/bin/sh
set -euo pipefail

VERSION="1.1.0"
CURRENT_TIME=$(date "+%Y.%m.%d-%H.%M.%S")
MGDIR="instana-mustgather-${CURRENT_TIME}"

mkdir -p "${MGDIR}"
echo "${VERSION}" > "${MGDIR}/version.txt"

if command -v oc >/dev/null 2>&1; then
    CMD="oc"
    LIST_NS="instana-agent openshift-controller-manager"
elif command -v kubectl >/dev/null 2>&1; then
    CMD="kubectl"
    LIST_NS="instana-agent"
else
    echo "ERROR: Neither 'oc' nor 'kubectl' is in PATH." >&2
    exit 1
fi

###############################################################################
# Helper function to run commands
###############################################################################
run_cmd() {
    echo "Running: $*"
    "$@"
}

###############################################################################
# Gather instana-agent pods, but parse only the NAME column
###############################################################################
# 1) We collect the full list with wide formatting for reference
run_cmd "${CMD}" get pods -n instana-agent -o wide \
    > "${MGDIR}/instana-agent-pod-list.txt"

# 2) We collect just the NAME column for script logic
run_cmd "${CMD}" get pods -n instana-agent \
    | awk 'NR>1 {print $1}' \
    > "${MGDIR}/instana-agent-pod-names.txt"

# Copy logs from instana-agent pods, excluding any with "k8sensor" in the name
while read -r POD_NAME; do
    # Skip any pods that match 'k8sensor'
    case "${POD_NAME}" in
        *k8sensor*) continue ;;
        *controller-manager*) continue ;;
        *NAME*) continue ;;
    esac

    # We assume /opt/instana/agent/data/log/ exists in the container
    # If it doesn't, oc/kubectl cp will complain
    DEST_DIR="${MGDIR}/instana-agent/${POD_NAME}_logs"
    mkdir -p "$(dirname "${DEST_DIR}")"

    echo "Copying logs from pod '${POD_NAME}'..."
    run_cmd "${CMD}" -n instana-agent cp \
        "${POD_NAME}:/opt/instana/agent/data/log/" \
        "${DEST_DIR}" || echo "WARN: Could not copy logs for pod ${POD_NAME}"

done < "${MGDIR}/instana-agent-pod-names.txt"

###############################################################################
# Gathering Container Logs for Each Namespace
###############################################################################
gather_ns_data() {
    ns="$1"
    ns_dir="${MGDIR}/${ns}"
    mkdir -p "${ns_dir}"

    # Collect all resources in the namespace
    run_cmd "${CMD}" get all,events -n "${ns}" -o wide \
        > "${ns_dir}/all-list.txt" 2>&1

    # Describe each pod
    run_cmd "${CMD}" get pods -n "${ns}" \
        | awk -v cmd="${CMD}" -v ns="${ns}" -v outdir="${ns_dir}" 'NR>1 {
            pod=$1
            # Make a describe command
            print cmd " -n " ns " describe pod " pod " > " outdir "/" pod "-describe.txt && echo described " pod
        }' | sh

    # Build container list
    run_cmd "${CMD}" get pods -n "${ns}" \
        -o go-template='{{range $i := .items}}{{range $c := $i.spec.containers}}{{println $i.metadata.name $c.name}}{{end}}{{end}}' \
        > "${ns_dir}/container-list.txt"

    # Gather current logs
    awk -v cmd="${CMD}" -v ns="${ns}" -v outdir="${ns_dir}" '
        {
            pod=$1
            container=$2
            log_file=outdir "/" pod "_" container ".log"
            print cmd " -n " ns " logs " pod " -c " container " --tail=10000 > \"" log_file "\" && echo gathered logs of " pod "_" container
        }
    ' "${ns_dir}/container-list.txt" | sh

    # Gather previous logs (may fail if no previous logs exist)
    awk -v cmd="${CMD}" -v ns="${ns}" -v outdir="${ns_dir}" '
        {
            pod=$1
            container=$2
            prev_log_file=outdir "/" pod "_" container "_previous.log"
            print cmd " -n " ns " logs " pod " -c " container " --tail=10000 -p > \"" prev_log_file "\" && echo gathered previous logs of " pod "_" container
        }
    ' "${ns_dir}/container-list.txt" | sh || true
    # ^ we can append "|| true" here if we want to ignore errors for previous logs
}

for namespace in ${LIST_NS}; do
    gather_ns_data "${namespace}"
done

###############################################################################
# Create a compressed tarball
###############################################################################
run_cmd tar czf "${MGDIR}.tgz" "${MGDIR}"
echo "Must-gather completed. Archive: ${MGDIR}.tgz"