#!/bin/bash

# Collects libinstana_init (LII) debug logs from a running, webhook-instrumented pod
# WITHOUT modifying the workload, restarting the pod or creating any Kubernetes object.
#
# How it works: LII is injected via LD_PRELOAD, so every new process started in the
# container loads it. The script runs a short-lived process (default: 'java -version')
# inside the existing container with LII debug logging enabled for that process only.
# INSTANA_LII_INIT is unset for that process because the webhook sets it to 1 in the
# container, which makes LII skip initialization (and logging).
#
# NOTE: this replays LII initialization in a new process. It is not the log of the
# original container start (e.g. files LII created on first start already exist, so
# messages differ).
set -e

CLI=""
CONTAINER=""
OUTPUT=""
NAMESPACE=""
POD=""
CMD=()

usage() {
    echo "Usage: $0 [--cli oc|kubectl] [--container NAME] [--output FILE] <namespace> <pod> [-- command [args...]]"
    echo ""
    echo "Options:"
    echo "  --cli oc|kubectl     CLI binary to use (auto-detected: oc if present, else kubectl)"
    echo "  --container NAME     Container to run in (default: the pod's default container)"
    echo "  --output FILE        File for the full output (default: ./lii-<pod>-<timestamp>.log)"
    echo "  -- command [args]    Process to run in the container (default: java -version)"
    echo ""
    echo "Examples:"
    echo "  $0 test-apps my-app-5d8f7c-abcde"
    echo "  $0 --container app test-apps my-app-5d8f7c-abcde"
    echo "  $0 test-apps my-app-5d8f7c-abcde -- java -version"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --cli)
            CLI="$2"
            shift 2
            ;;
        --container)
            CONTAINER="$2"
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        --)
            shift
            CMD=("$@")
            break
            ;;
        *)
            if [ -z "$NAMESPACE" ]; then
                NAMESPACE="$1"
            elif [ -z "$POD" ]; then
                POD="$1"
            else
                echo "ERROR: unexpected argument: $1"
                usage
            fi
            shift
            ;;
    esac
done

if [ -z "$NAMESPACE" ] || [ -z "$POD" ]; then
    usage
fi

if [ ${#CMD[@]} -eq 0 ]; then
    CMD=(java -version)
fi

# Auto-detect CLI if not explicitly set
if [ -z "$CLI" ]; then
    if command -v oc &>/dev/null; then
        CLI="oc"
    elif command -v kubectl &>/dev/null; then
        CLI="kubectl"
    else
        echo "ERROR: neither 'oc' nor 'kubectl' found in PATH"
        exit 1
    fi
    echo "Using CLI: $CLI (auto-detected)"
fi

if [[ "$CLI" != "oc" && "$CLI" != "kubectl" ]]; then
    echo "ERROR: --cli must be 'oc' or 'kubectl' (got: '$CLI')"
    exit 1
fi

# Verify the pod exists and was mutated by the webhook
APPLIED=$($CLI get pod "$POD" -n "$NAMESPACE" \
    -o jsonpath='{.metadata.labels.instana-autotrace-applied}')
if [ "$APPLIED" != "true" ]; then
    echo "ERROR: pod $NAMESPACE/$POD does not have label instana-autotrace-applied=true;"
    echo "       it was not instrumented by the webhook."
    exit 1
fi

if [ -z "$OUTPUT" ]; then
    OUTPUT="./lii-${POD}-$(date +%Y%m%d-%H%M%S).log"
fi

EXEC_ARGS=(exec "$POD" -n "$NAMESPACE")
if [ -n "$CONTAINER" ]; then
    EXEC_ARGS+=(-c "$CONTAINER")
fi

echo "Running '${CMD[*]}' in $NAMESPACE/$POD with LII debug logging (no workload changes)..."

# The command itself may exit non-zero; we only care about the LII output.
set +e
$CLI "${EXEC_ARGS[@]}" -- \
    env -u INSTANA_LII_INIT INSTANA_LII_LOG_LEVEL=debug INSTANA_LII_LOG_STDERR=1 \
    "${CMD[@]}" > "$OUTPUT" 2>&1
EXEC_RC=$?
set -e

LII_LINES=$(grep -c '\[lii ' "$OUTPUT" || true)

if [ "$LII_LINES" -eq 0 ]; then
    echo "ERROR: no LII log lines captured (exec exit code: $EXEC_RC). Full output in $OUTPUT"
    echo "Possible causes: 'env' or the command is missing in the image, wrong container,"
    echo "or LD_PRELOAD does not point to libinstana_init.so in this container."
    exit 1
fi

echo "Captured $LII_LINES LII log lines. Full output saved to: $OUTPUT"
echo "----------------------------------------"
grep '\[lii ' "$OUTPUT"
