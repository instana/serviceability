#!/bin/bash

# Removes Instana instrumentation injected by the autotrace mutating webhook
# from Deployment, DeploymentConfig, DaemonSet, ReplicaSet and StatefulSet objects.
#
# Use --cli oc  for OpenShift clusters (supports DeploymentConfig, default)
# Use --cli kubectl for plain Kubernetes clusters
set -e

DRY_RUN=false
NAMESPACE=""
WORKLOAD_NAME=""
RESOURCE_TYPE="all"  # deployment|deploymentconfig|daemonset|replicaset|statefulset|all
CLI="oc"             # oc | kubectl

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --resource)
            RESOURCE_TYPE="$2"
            shift 2
            ;;
        --cli)
            CLI="$2"
            shift 2
            ;;
        *)
            if [ -z "$NAMESPACE" ]; then
                NAMESPACE="$1"
            elif [ -z "$WORKLOAD_NAME" ]; then
                WORKLOAD_NAME="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$NAMESPACE" ]; then
    echo "Usage: $0 [--dry-run] [--resource TYPE] [--cli oc|kubectl] <namespace> [workload-name]"
    echo ""
    echo "Options:"
    echo "  --dry-run                 Show what would be removed without making changes"
    echo "  --resource TYPE           One of: deployment, deploymentconfig, daemonset,"
    echo "                            replicaset, statefulset, all (default: all)"
    echo "  --cli oc|kubectl          CLI binary to use (default: oc)"
    echo ""
    echo "Examples:"
    echo "  $0 test-apps                                   # All resource types in namespace"
    echo "  $0 test-apps my-app                            # Specific workload (all types)"
    echo "  $0 --resource daemonset test-apps              # Only DaemonSets"
    echo "  $0 --cli kubectl test-apps                     # Use kubectl instead of oc"
    echo "  $0 --dry-run test-apps                         # Preview without applying"
    exit 1
fi

if [[ "$CLI" != "oc" && "$CLI" != "kubectl" ]]; then
    echo "ERROR: --cli must be 'oc' or 'kubectl' (got: '$CLI')"
    exit 1
fi

# DeploymentConfig is an OpenShift-only resource type
if [[ "$RESOURCE_TYPE" == "deploymentconfig" && "$CLI" == "kubectl" ]]; then
    echo "ERROR: DeploymentConfig is an OpenShift resource and requires --cli oc"
    exit 1
fi

# Create backup directory
BACKUP_DIR="./backups-$(date +%Y%m%d-%H%M%S)"
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$BACKUP_DIR"
    echo "Backups will be saved to: $BACKUP_DIR"
else
    echo "[DRY RUN MODE - No changes will be made]"
fi
echo ""

# ---------------------------------------------------------------------------
# JQ filter — identical for all pod-spec-bearing resource types.
# Strips every artifact injected by the autotrace webhook.
# ---------------------------------------------------------------------------
readonly JQ_FILTER='
    del(.metadata.annotations."kubectl.kubernetes.io/last-applied-configuration") |
    del(.metadata.annotations."deployment.kubernetes.io/revision") |
    if .spec.template.spec.initContainers then
        .spec.template.spec.initContainers = [.spec.template.spec.initContainers[] | select(.name != "instana-instrumentation-init")] |
        if (.spec.template.spec.initContainers | length) == 0 then del(.spec.template.spec.initContainers) else . end
    else . end |
    if .spec.template.spec.volumes then
        .spec.template.spec.volumes = [.spec.template.spec.volumes[] |
            select(
                .name != "instana-instrumentation-volume" and
                .name != "instana-autotrace-ace-config-volume" and
                .name != "instana-autotrace-ibmmq-config-volume"
            )] |
        if (.spec.template.spec.volumes | length) == 0 then del(.spec.template.spec.volumes) else . end
    else . end |
    .spec.template.spec.containers = [.spec.template.spec.containers[] |
        if .volumeMounts then
            .volumeMounts = [.volumeMounts[] |
                select(
                    .name != "instana-instrumentation-volume" and
                    .name != "instana-autotrace-ace-config-volume" and
                    .name != "instana-autotrace-ibmmq-config-volume"
                )] |
            if (.volumeMounts | length) == 0 then del(.volumeMounts) else . end
        else . end |
        if .env then
            .env = [.env[] |
                if .name == "NODE_OPTIONS" and (.value // "") != "" then
                    .value = (.value |
                        gsub("--require /opt/instana/instrumentation/nodejs/node_modules/@instana/collector/src/immediate\\s*"; "") |
                        gsub("--import /opt/instana/instrumentation/nodejs/node_modules/@instana/collector/esm-register.mjs\\s*"; "") |
                        gsub("--experimental-loader /opt/instana/instrumentation/nodejs/node_modules/@instana/collector/esm-loader.mjs\\s*"; "") |
                        gsub("^\\s+|\\s+$"; ""))
                elif .name == "PYTHONPATH" and (.value // "") != "" then
                    .value = (.value |
                        gsub(":/opt/instana/instrumentation/python/custom-site"; "") |
                        gsub("/opt/instana/instrumentation/python/custom-site:?"; "") |
                        gsub("^\\s+|\\s+$"; ""))
                else . end |
                select(
                    .name != "LD_PRELOAD" and
                    .name != "INSTANA_AGENT_HOST" and
                    .name != "INSTANA_SERVICE_NAME" and
                    .name != "ACE_ENABLE_OPEN_TRACING" and
                    .name != "OTEL_TRACING_ENABLED" and
                    .name != "OTEL_TRACING_PROTOCOL" and
                    .name != "MQ_ENABLE_OPEN_TRACING" and
                    .name != "AUTOTRACE_RUBY_HOME" and
                    .name != "RUBYOPT" and
                    .name != "INSTANA_TRACER_ENVIRONMENT" and
                    .name != "INSTANA_ENDPOINT_URL" and
                    .name != "INSTANA_AGENT_KEY" and
                    .name != "HOST_ALIAS" and
                    .name != "HOST_IP"
                ) |
                select((.value // "") != "" or .valueFrom != null)
            ] |
            if (. | length) == 0 then . = null else . end
        else . end |
        if .env == null then del(.env) else . end
    ] |
    if .metadata.labels then
        del(.metadata.labels."instana-autotrace-applied") |
        del(.metadata.labels."instana-autotrace-version") |
        del(.metadata.labels."instana-autotrace-transformation")
    else . end |
    if .spec.template.metadata.labels then
        del(.spec.template.metadata.labels."instana-autotrace-applied") |
        del(.spec.template.metadata.labels."instana-autotrace-version") |
        del(.spec.template.metadata.labels."instana-autotrace-transformation")
    else . end |
    if .spec.template.spec.imagePullSecrets then
        .spec.template.spec.imagePullSecrets = [.spec.template.spec.imagePullSecrets[] |
            select((.name | contains("instana")) | not)] |
        if (.spec.template.spec.imagePullSecrets | length) == 0 then del(.spec.template.spec.imagePullSecrets) else . end
    else . end |
    del(.status)
'

# ---------------------------------------------------------------------------
# process_workload <kind> <name>
# ---------------------------------------------------------------------------
process_workload() {
    local KIND="$1"
    local NAME="$2"

    echo "Processing $KIND: $NAME"

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would backup $KIND"
        echo "  [DRY RUN] Would remove:"
        $CLI get "$KIND" "$NAME" -n "$NAMESPACE" -o yaml \
            | grep -E "(initContainers:|LD_PRELOAD|MQ_ENABLE_OPEN_TRACING|NODE_OPTIONS.*instana|instana-autotrace-applied|instana-autotrace-version)" \
            | sed 's/^/    /'
        echo ""
        return
    fi

    # Backup
    $CLI get "$KIND" "$NAME" -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/${NAMESPACE}-${KIND}-${NAME}.yaml"
    echo "  ✓ Backed up"

    # Fetch, strip instrumentation, replace
    $CLI get "$KIND" "$NAME" -n "$NAMESPACE" -o json \
        | jq "$JQ_FILTER" \
        | $CLI replace -f - > /dev/null

    echo "  ✓ Removed instrumentation"
    echo ""
}

# ---------------------------------------------------------------------------
# process_kind <kind>
#   Discovers all instrumented workloads of the given kind (or uses the
#   explicitly named workload if provided) and calls process_workload.
# ---------------------------------------------------------------------------
FOUND_ANY=false

process_kind() {
    local KIND="$1"
    local NAMES=""

    # DeploymentConfig is OpenShift-only — skip silently when using kubectl
    if [[ "$KIND" == "deploymentconfig" && "$CLI" == "kubectl" ]]; then
        return
    fi

    if [ -n "$WORKLOAD_NAME" ]; then
        if $CLI get "$KIND" "$WORKLOAD_NAME" -n "$NAMESPACE" &>/dev/null; then
            NAMES="$WORKLOAD_NAME"
        fi
    else
        NAMES=$($CLI get "${KIND}s" -n "$NAMESPACE" \
            -l instana-autotrace-applied=true \
            -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
    fi

    if [ -n "$NAMES" ]; then
        FOUND_ANY=true
        for NAME in $NAMES; do
            process_workload "$KIND" "$NAME"
        done
    fi
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
case "$RESOURCE_TYPE" in
    all)
        process_kind deployment
        process_kind deploymentconfig
        process_kind daemonset
        process_kind replicaset
        process_kind statefulset
        ;;
    deployment|deploymentconfig|daemonset|replicaset|statefulset)
        process_kind "$RESOURCE_TYPE"
        ;;
    *)
        echo "ERROR: unknown --resource type '$RESOURCE_TYPE'"
        echo "       Valid values: deployment, deploymentconfig, daemonset, replicaset, statefulset, all"
        exit 1
        ;;
esac

if [ "$FOUND_ANY" = false ]; then
    echo "No instrumented workloads found in namespace: $NAMESPACE"
    exit 0
fi

echo "=========================================="
echo "Complete!"
echo "=========================================="
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "This was a dry run. No changes were made."
    echo ""
    echo "To apply these changes, run without --dry-run:"
    echo "  $0 $NAMESPACE${WORKLOAD_NAME:+ $WORKLOAD_NAME}"
else
    echo "Backups saved to: $BACKUP_DIR"
    echo ""
    echo "Verify workloads are clean:"
    echo "  $CLI get deployment,daemonset,replicaset,statefulset -n $NAMESPACE -o yaml | grep -E '(LD_PRELOAD|NODE_OPTIONS.*instana|instana-autotrace-applied)'"
    echo ""
    echo "To rollback a specific workload:"
    echo "  $CLI apply -f $BACKUP_DIR/${NAMESPACE}-<kind>-<name>.yaml"
fi
