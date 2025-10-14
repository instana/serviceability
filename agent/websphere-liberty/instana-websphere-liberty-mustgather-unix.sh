#!/bin/bash

###############################################################################
#
# Copyright IBM Corp. 2024, 2025
# This script collects data for the Instana WebSphere Liberty Sensor on Unix/Linux
#
# Usage:
# ./instana-websphere-liberty-mustgather-unix.sh
#
###############################################################################

set -e
set -o pipefail

VERSION="1.0.0"
echo "Instana WebSphere Liberty Sensor MustGather Tool - Version: ${VERSION}" >&2
CURRENT_TIME=$(date "+%Y%m%d-%H%M%S")
MGDIR="instana-websphere-liberty-mustgather-${VERSION}-${CURRENT_TIME}"
mkdir -p "${MGDIR}"

# Helper function to run commands
run_cmd() {
>&2 echo "Running: $*"
"$@"
}

# Check prerequisites
check_prerequisites() {
if ! command -v java > /dev/null || ! command -v tar > /dev/null; then
echo "Error: This script requires Java and tar to be installed."
exit 1
fi
}

# Collect Liberty information
collect_liberty_info() {
echo "Enter the path to the WebSphere Liberty installation directory:"
read -r liberty_path
if [ ! -d "$liberty_path" ]; then
echo "Error: Liberty directory not found at $liberty_path"
return 1
fi

mkdir -p "${MGDIR}/liberty_info/"

# Collect Liberty version
if [ -f "${liberty_path}/bin/productInfo" ]; then
run_cmd "${liberty_path}/bin/productInfo" version > "${MGDIR}/liberty_info/liberty_version.txt"
echo "Liberty version information collected."
else
echo "Warning: productInfo not found at ${liberty_path}/bin/productInfo"
fi

# Ask for server name
echo "Enter the WebSphere Liberty server name:"
read -r server_name

server_dir="${liberty_path}/usr/servers/${server_name}"
if [ ! -d "$server_dir" ]; then
echo "Error: Server directory not found at $server_dir"
return 1
fi

# Collect server.xml
if [ -f "${server_dir}/server.xml" ]; then
cp "${server_dir}/server.xml" "${MGDIR}/liberty_info/"
echo "Server configuration (server.xml) collected."
# Check for monitor-1.0 feature
run_cmd grep "monitor-1.0" "${server_dir}/server.xml" > "${MGDIR}/liberty_info/monitor_feature.txt" 2>/dev/null || echo "monitor-1.0 feature not found in server.xml" > "${MGDIR}/liberty_info/monitor_feature.txt"
# Check for JMX configuration
run_cmd grep -A 10 "monitor-1.0" "${server_dir}/server.xml" > "${MGDIR}/liberty_info/jmx_config.txt" 2>/dev/null || echo "JMX configuration not found in server.xml" > "${MGDIR}/liberty_info/jmx_config.txt"
else
echo "Warning: server.xml not found at ${server_dir}/server.xml"
fi

# Collect jvm.options
if [ -f "${server_dir}/jvm.options" ]; then
cp "${server_dir}/jvm.options" "${MGDIR}/liberty_info/"
echo "JVM options (jvm.options) collected."
# Check for javaagent configuration
run_cmd grep "javaagent" "${server_dir}/jvm.options" > "${MGDIR}/liberty_info/javaagent_config.txt" 2>/dev/null || echo "javaagent configuration not found in jvm.options" > "${MGDIR}/liberty_info/javaagent_config.txt"
else
echo "Warning: jvm.options not found at ${server_dir}/jvm.options"
fi

# Collect server logs
if [ -d "${server_dir}/logs" ]; then
mkdir -p "${MGDIR}/liberty_info/logs/"
cp "${server_dir}/logs/console.log" "${MGDIR}/liberty_info/logs/" 2>/dev/null || echo "console.log not found"
cp "${server_dir}/logs/messages.log" "${MGDIR}/liberty_info/logs/" 2>/dev/null || echo "messages.log not found"
echo "Server logs collected."
else
echo "Warning: Server logs directory not found at ${server_dir}/logs"
fi

# Check server status
if [ -f "${liberty_path}/bin/server" ]; then
run_cmd "${liberty_path}/bin/server" status "${server_name}" > "${MGDIR}/liberty_info/server_status.txt" 2>&1
echo "Server status collected."
else
echo "Warning: server script not found at ${liberty_path}/bin/server"
fi
}

# Main function
instana_websphere_liberty_mustgather() {
check_prerequisites
# Collect system and Java info
run_cmd java -version > "${MGDIR}/java_version.txt" 2>&1
run_cmd uname -a > "${MGDIR}/system_info.txt"
# Collect Liberty information
collect_liberty_info

# Create the final archive
run_cmd tar czf "${MGDIR}.tgz" "${MGDIR}"
echo "Must-gather completed. Archive created: ${MGDIR}.tgz"
echo "Please provide this file to IBM Support for analysis."
}

# Execute the main function
instana_websphere_liberty_mustgather
