#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# LogCollector.sh
#
# Must-gather script for .NET Framework / Instana on EKS Windows pods.
# Collects all diagnostic logs needed to troubleshoot Instana tracing
# for IIS-hosted .NET Full Framework applications running on EKS Windows nodes.
#
# The running pod is resolved automatically from the deployment.
# All output is written to ./must-gather-<timestamp>/
#
# Usage:
#   ./LogCollector.sh \
#       -n <app-namespace> \
#       -d <dotnet-app-deployment> \
#       [-c <container-name>]
#
# Examples:
#   Single-container pod:
#     ./LogCollector.sh -n production -d my-dotnet-app
#
#   Multi-container pod (specify the app container explicitly):
#     ./LogCollector.sh -n production -d my-dotnet-app -c app
#
# ---------------------------------------------------------------------------

set -euo pipefail

# helpers
usage() {
  sed -n '2,/^# ---/p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

# argument parsing
NAMESPACE=""
DEPLOYMENT=""
CONTAINER=""

while getopts ":n:d:c:h" opt; do
  case $opt in
    n) NAMESPACE="$OPTARG" ;;
    d) DEPLOYMENT="$OPTARG" ;;
    c) CONTAINER="$OPTARG" ;;
    h) usage ;;
    :) die "Option -$OPTARG requires an argument." ;;
    \?) die "Unknown option: -$OPTARG" ;;
  esac
done

[[ -z "$NAMESPACE"  ]] && die "Missing required flag: -n <app-namespace>"
[[ -z "$DEPLOYMENT" ]] && die "Missing required flag: -d <dotnet-app-deployment>"

# Store the optional container flag as an array to handle spaces safely
CONTAINER_FLAG=()
[[ -n "$CONTAINER" ]] && CONTAINER_FLAG=(-c "$CONTAINER")

# resolve pod name from deployment
log "Resolving pod name for deployment/$DEPLOYMENT ..."

# Step 1: read the deployment's label selector. kubectl errors (not found, RBAC) are shown.
SELECTOR=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
             -o go-template='{{range $k,$v := .spec.selector.matchLabels}}{{$k}}={{$v}},{{end}}') \
  || die "Could not read deployment/$DEPLOYMENT in namespace $NAMESPACE (see kubectl error above)."
SELECTOR="${SELECTOR%,}"   # drop the trailing comma
[[ -z "$SELECTOR" ]] && die "deployment/$DEPLOYMENT has no spec.selector.matchLabels."

# Step 2: find a running pod matching that selector.
PODS=$(kubectl get pods -n "$NAMESPACE" -l "$SELECTOR" \
         --field-selector=status.phase=Running \
         -o jsonpath='{.items[*].metadata.name}') \
  || die "Could not list pods for selector '$SELECTOR' in namespace $NAMESPACE (see kubectl error above)."
POD="${PODS%% *}"   # first pod name

[[ -z "$POD" ]] && die "No running pod found for deployment/$DEPLOYMENT in namespace $NAMESPACE."
log "Using pod: $POD"
echo ""

# output directory
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUT_DIR="must-gather-${TIMESTAMP}"
mkdir -p "$OUT_DIR"
log "Output directory: $OUT_DIR"
echo ""

# identify the active w3wp.exe PID
log "Identifying active w3wp.exe PID ..."

# Only the first w3wp PID is selected: several worker processes would otherwise be
# returned on separate lines and be concatenated into one invalid number.
# Get-Process -ErrorAction SilentlyContinue exits 0 with no output when no w3wp is running,
# so a non-zero exit here means kubectl exec itself failed (RBAC, pod not ready, ...).
# kubectl's stderr is left visible so the cause is shown.
if ! PID=$(kubectl exec "$POD" -n "$NAMESPACE" "${CONTAINER_FLAG[@]}" \
        -- powershell -Command \
        "Get-Process w3wp -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id -First 1" \
      | tr -d '[:space:]'); then
  warn "kubectl exec failed while detecting the w3wp.exe PID (see error above)."
  PID=""
fi

# Confirm the returned value is a valid number before using it in log filenames
if [[ -z "$PID" ]] || ! [[ "$PID" =~ ^[0-9]+$ ]]; then
  [[ -n "$PID" ]] && warn "Unexpected PID value '$PID' — ignoring."
  warn "Could not detect w3wp.exe PID automatically."
  read -rp "        Enter the w3wp.exe PID manually (or press Enter to skip PID-based logs): " PID
fi

if [[ -z "$PID" ]]; then
  warn "No PID provided — CLR and managed tracer logs will be skipped."
else
  log "Using w3wp.exe PID: $PID"
fi
echo ""

# collect diagnostic logs
log "Collecting diagnostic logs ..."
echo ""

# 1. List all log files in the instana-shared directory for reference
log "  [1/9] Listing C:\\instana-shared ..."
if ! kubectl exec "$POD" -n "$NAMESPACE" "${CONTAINER_FLAG[@]}" \
  -- cmd /c "dir C:\instana-shared\*.log" \
  > "$OUT_DIR/instana-shared-dir-listing.txt" 2>/dev/null; then
  rm -f "$OUT_DIR/instana-shared-dir-listing.txt"
  warn "Could not list instana-shared."
fi

# 2 & 3. PID-specific logs are only available when a valid PID was found.
# Filenames include a date/sequence suffix (e.g. clr_9000_2026-10-05.log),
# so we resolve the actual filename using the PID prefix wildcard clr_<PID>_*
# and instana_net_ff_<PID>_* to avoid matching unrelated files.
if [[ -n "$PID" ]]; then
  log "  [2/9] Copying CLR profiler log for PID $PID ..."
  CLR_LOG=$(kubectl exec "$POD" -n "$NAMESPACE" "${CONTAINER_FLAG[@]}" \
    -- powershell -Command \
    "Get-ChildItem 'C:\instana-shared\clr_${PID}_*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name -First 1" \
    2>/dev/null | tr -d '\r') || true
  if [[ -n "$CLR_LOG" ]]; then
    if ! kubectl exec "$POD" -n "$NAMESPACE" "${CONTAINER_FLAG[@]}" \
      -- cmd /c "type C:\instana-shared\\${CLR_LOG}" \
      > "$OUT_DIR/${CLR_LOG}" 2>/dev/null; then
      rm -f "$OUT_DIR/${CLR_LOG}"
      warn "Could not copy CLR log: $CLR_LOG"
    fi
  else
    warn "CLR log not found for PID $PID (clr_${PID}_*)"
  fi

  log "  [3/9] Copying managed tracer log for PID $PID ..."
  FF_LOG=$(kubectl exec "$POD" -n "$NAMESPACE" "${CONTAINER_FLAG[@]}" \
    -- powershell -Command \
    "Get-ChildItem 'C:\instana-shared\instana_net_ff_${PID}_*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name -First 1" \
    2>/dev/null | tr -d '\r') || true
  if [[ -n "$FF_LOG" ]]; then
    if ! kubectl exec "$POD" -n "$NAMESPACE" "${CONTAINER_FLAG[@]}" \
      -- cmd /c "type C:\instana-shared\\${FF_LOG}" \
      > "$OUT_DIR/${FF_LOG}" 2>/dev/null; then
      rm -f "$OUT_DIR/${FF_LOG}"
      warn "Could not copy managed tracer log: $FF_LOG"
    fi
  else
    warn "Managed tracer log not found for PID $PID (instana_net_ff_${PID}_*)"
  fi
else
  warn "  [2/9] Skipping CLR profiler log — no PID available."
  warn "  [3/9] Skipping managed tracer log — no PID available."
fi

# 4. Pod description and events
log "  [4/9] Collecting pod description ..."
if ! kubectl describe pod "$POD" -n "$NAMESPACE" \
  > "$OUT_DIR/pod-describe.txt" 2>/dev/null; then
  rm -f "$OUT_DIR/pod-describe.txt"
  warn "kubectl describe failed."
fi

# 5. Instana init-container logs
log "  [5/9] Collecting init-container logs ..."
if ! kubectl logs "$POD" -c instana-instrumentation-init -n "$NAMESPACE" \
  > "$OUT_DIR/init-container.log" 2>/dev/null; then
  rm -f "$OUT_DIR/init-container.log"
  warn "Init-container logs not available."
fi

# 6. Application container logs
log "  [6/9] Collecting application container logs ..."
if [[ -n "$CONTAINER" ]]; then
  if ! kubectl logs "$POD" -c "$CONTAINER" -n "$NAMESPACE" \
    > "$OUT_DIR/app-container.log" 2>/dev/null; then
    rm -f "$OUT_DIR/app-container.log"
    warn "App container logs not available."
  fi
else
  if ! kubectl logs "$POD" -n "$NAMESPACE" \
    > "$OUT_DIR/app-container.log" 2>/dev/null; then
    rm -f "$OUT_DIR/app-container.log"
    warn "App container logs not available."
  fi
fi

# 7. Instana autotrace webhook logs
log "  [7/9] Collecting autotrace-webhook logs ..."
if ! kubectl logs \
  -l app.kubernetes.io/name=instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  > "$OUT_DIR/webhook.log" 2>/dev/null; then
  rm -f "$OUT_DIR/webhook.log"
  warn "Webhook logs not available."
fi

# 8. Application deployment YAML
log "  [8/9] Exporting deployment YAML ..."
if ! kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o yaml \
  > "$OUT_DIR/deployment.yaml" 2>/dev/null; then
  rm -f "$OUT_DIR/deployment.yaml"
  warn "Could not export deployment YAML."
fi

# 9. Windows Application event log (most recent 30 entries)
log "  [9/9] Collecting Windows Application event log ..."
if ! kubectl exec "$POD" -n "$NAMESPACE" "${CONTAINER_FLAG[@]}" \
  -- powershell -Command "Get-EventLog -LogName Application -Newest 30 | Format-Table -Wrap" \
  > "$OUT_DIR/windows-app-events.txt" 2>/dev/null; then
  rm -f "$OUT_DIR/windows-app-events.txt"
  warn "Windows event log not available."
fi

# summary
echo ""
log "Collection complete. All files have been saved to: $(pwd)/$OUT_DIR/"
