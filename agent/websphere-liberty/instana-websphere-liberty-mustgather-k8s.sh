#!/bin/bash

###############################################################################
#
# Copyright IBM Corp. 2024, 2025
# This script collects data for the Instana WebSphere Liberty Sensor in Kubernetes
#
# Usage:
# ./instana-websphere-liberty-mustgather-k8s.sh
#
###############################################################################

set -e
set -o pipefail

VERSION="1.0.0"
echo "Instana WebSphere Liberty Sensor MustGather Tool for Kubernetes - Version: ${VERSION}" >&2
CURRENT_TIME=$(date "+%Y%m%d-%H%M%S")
MGDIR="instana-websphere-liberty-mustgather-k8s-${VERSION}-${CURRENT_TIME}"
mkdir -p "${MGDIR}"

# Helper function to run commands
run_cmd() {
>&2 echo "Running: $*"
"$@"
}

# Check prerequisites
check_prerequisites() {
echo "Checking prerequisites..."
if ! command -v kubectl > /dev/null; then
echo "Error: kubectl is not available. Please install kubectl or ensure it's in your PATH."
exit 1
fi
if ! command -v tar > /dev/null; then
echo "Error: tar is not available. Please install tar or ensure it's in your PATH."
exit 1
fi
echo "Prerequisites check completed."
}

# Collect Liberty information from Kubernetes pods
collect_liberty_k8s_info() {
echo "Enter the namespace where WebSphere Liberty is deployed:"
read -r liberty_namespace
echo "Enter the label selector for WebSphere Liberty pods (e.g., app=my-liberty-app):"
read -r liberty_selector

# Get list of pods
echo "Retrieving Liberty pods..."
kubectl get pods -n "${liberty_namespace}" -l "${liberty_selector}" -o name > "${MGDIR}/liberty_pods.txt"
if [ ! -s "${MGDIR}/liberty_pods.txt" ]; then
echo "No Liberty pods found with selector '${liberty_selector}' in namespace '${liberty_namespace}'"
return 1
fi

mkdir -p "${MGDIR}/liberty_info"

# Process each pod
while IFS= read -r pod; do
pod_name=$(echo "${pod}" | cut -d'/' -f2)
echo "Processing pod: ${pod_name}"
mkdir -p "${MGDIR}/liberty_info/${pod_name}"

# Get pod details
kubectl describe pod -n "${liberty_namespace}" "${pod_name}" > "${MGDIR}/liberty_info/${pod_name}/pod_details.txt"

# Get container names in the pod
kubectl get pod -n "${liberty_namespace}" "${pod_name}" -o jsonpath='{.spec.containers[*].name}' > "${MGDIR}/liberty_info/${pod_name}/containers.txt"

# Ask which container has Liberty
echo "Container(s) in pod ${pod_name}: $(cat "${MGDIR}/liberty_info/${pod_name}/containers.txt")"
echo "Enter the container name running WebSphere Liberty:"
read -r liberty_container

# Get logs
kubectl logs -n "${liberty_namespace}" "${pod_name}" -c "${liberty_container}" > "${MGDIR}/liberty_info/${pod_name}/container_logs.txt"

# Try to get Liberty version
echo "Attempting to get Liberty version..."
kubectl exec -n "${liberty_namespace}" "${pod_name}" -c "${liberty_container}" -- bash -c "if [ -f /opt/ibm/wlp/bin/productInfo ]; then /opt/ibm/wlp/bin/productInfo version; fi" > "${MGDIR}/liberty_info/${pod_name}/liberty_version.txt" 2>/dev/null || echo "Could not get Liberty version"

# Common Liberty paths to check
liberty_paths=("/opt/ibm/wlp" "/liberty" "/opt/liberty" "/opt/ol/wlp")
for liberty_path in "${liberty_paths[@]}"; do
# Try to find server.xml
echo "Checking for server.xml in ${liberty_path}..."
kubectl exec -n "${liberty_namespace}" "${pod_name}" -c "${liberty_container}" -- bash -c "find ${liberty_path} -name server.xml 2>/dev/null" > "${MGDIR}/liberty_info/${pod_name}/server_xml_paths.txt" 2>/dev/null || true

if [ -s "${MGDIR}/liberty_info/${pod_name}/server_xml_paths.txt" ]; then
server_xml_path=$(head -1 "${MGDIR}/liberty_info/${pod_name}/server_xml_paths.txt")
echo "Found server.xml at ${server_xml_path}"

# Get server.xml content
kubectl exec -n "${liberty_namespace}" "${pod_name}" -c "${liberty_container}" -- cat "${server_xml_path}" > "${MGDIR}/liberty_info/${pod_name}/server.xml" 2>/dev/null || echo "Could not get server.xml content"

# Check for monitor-1.0 feature
grep "monitor-1.0" "${MGDIR}/liberty_info/${pod_name}/server.xml" > "${MGDIR}/liberty_info/${pod_name}/monitor_feature.txt" 2>/dev/null || echo "monitor-1.0 feature not found in server.xml" > "${MGDIR}/liberty_info/${pod_name}/monitor_feature.txt"

# Check for JMX configuration
grep -A 10 "monitor-1.0" "${MGDIR}/liberty_info/${pod_name}/server.xml" > "${MGDIR}/liberty_info/${pod_name}/jmx_config.txt" 2>/dev/null || echo "JMX configuration not found in server.xml" > "${MGDIR}/liberty_info/${pod_name}/jmx_config.txt"

# Try to find jvm.options in the same directory
server_dir=$(dirname "${server_xml_path}")
kubectl exec -n "${liberty_namespace}" "${pod_name}" -c "${liberty_container}" -- bash -c "if [ -f ${server_dir}/jvm.options ]; then cat ${server_dir}/jvm.options; fi" > "${MGDIR}/liberty_info/${pod_name}/jvm.options" 2>/dev/null || echo "Could not get jvm.options content"

# Check for javaagent configuration
grep "javaagent" "${MGDIR}/liberty_info/${pod_name}/jvm.options" > "${MGDIR}/liberty_info/${pod_name}/javaagent_config.txt" 2>/dev/null || echo "javaagent configuration not found in jvm.options" > "${MGDIR}/liberty_info/${pod_name}/javaagent_config.txt"

break
fi
done

# Get Java version
kubectl exec -n "${liberty_namespace}" "${pod_name}" -c "${liberty_container}" -- java -version > "${MGDIR}/liberty_info/${pod_name}/java_version.txt" 2>&1 || echo "Could not get Java version"
done < "${MGDIR}/liberty_pods.txt"

echo "Liberty information collection from Kubernetes completed."
}

# Main function
instana_websphere_liberty_mustgather() {
check_prerequisites

# Collect Kubernetes cluster info
echo "Collecting Kubernetes cluster information..."
kubectl cluster-info > "${MGDIR}/cluster_info.txt" 2>&1 || echo "Could not get cluster info"
kubectl version --short > "${MGDIR}/kubectl_version.txt" 2>&1 || echo "Could not get kubectl version"

# Collect Liberty information from Kubernetes
collect_liberty_k8s_info

# Create the final archive
run_cmd tar czf "${MGDIR}.tgz" "${MGDIR}"
echo "Must-gather completed. Archive created: ${MGDIR}.tgz"
echo "Please provide this file to IBM Support for analysis."
}

# Execute the main function
instana_websphere_liberty_mustgather

