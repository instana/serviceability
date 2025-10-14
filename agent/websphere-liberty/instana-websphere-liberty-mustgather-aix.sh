#!/bin/ksh

###############################################################################
#
# Copyright IBM Corp. 2024, 2025
# This script collects data for the Instana WebSphere Liberty Sensor on AIX
#
# Usage:
# ./instana-websphere-liberty-mustgather-aix.sh
#
###############################################################################

# AIX environments typically use ksh instead of bash
# Using ksh for better compatibility

# Exit on error
set -e

VERSION="1.0.0"
echo "Instana WebSphere Liberty Sensor MustGather Tool for AIX - Version: ${VERSION}" >&2
CURRENT_TIME=$(date "+%Y%m%d-%H%M%S")
MGDIR="instana-websphere-liberty-mustgather-aix-${VERSION}-${CURRENT_TIME}"
mkdir -p "${MGDIR}"

# Helper function to run commands
run_cmd() {
echo "Running: $*" >&2
"$@"
}

# Check prerequisites
check_prerequisites() {
echo "Checking prerequisites..."
# Check for Java
if ! whence java > /dev/null 2>&1; then
echo "Error: Java is not available. Please install Java or ensure it's in your PATH."
exit 1
fi
# Check for tar
if ! whence tar > /dev/null 2>&1; then
echo "Error: tar is not available. Please install tar or ensure it's in your PATH."
exit 1
fi
echo "Prerequisites check completed."
}

# Collect Liberty information
collect_liberty_info() {
echo "Enter the path to the WebSphere Liberty installation directory:"
read liberty_path
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
read server_name

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
grep "monitor-1.0" "${server_dir}/server.xml" > "${MGDIR}/liberty_info/monitor_feature.txt" 2>/dev/null || echo "monitor-1.0 feature not found in server.xml" > "${MGDIR}/liberty_info/monitor_feature.txt"
# Check for JMX configuration
grep -A 10 "monitor-1.0" "${server_dir}/server.xml" > "${MGDIR}/liberty_info/jmx_config.txt" 2>/dev/null || echo "JMX configuration not found in server.xml" > "${MGDIR}/liberty_info/jmx_config.txt"
else
echo "Warning: server.xml not found at ${server_dir}/server.xml"
fi

# Collect jvm.options
if [ -f "${server_dir}/jvm.options" ]; then
cp "${server_dir}/jvm.options" "${MGDIR}/liberty_info/"
echo "JVM options (jvm.options) collected."
# Check for javaagent configuration
grep "javaagent" "${server_dir}/jvm.options" > "${MGDIR}/liberty_info/javaagent_config.txt" 2>/dev/null || echo "javaagent configuration not found in jvm.options" > "${MGDIR}/liberty_info/javaagent_config.txt"
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

# Collect AIX-specific system information
collect_aix_system_info() {
echo "Collecting AIX system information..."
mkdir -p "${MGDIR}/system_info/"
# Basic system information
run_cmd oslevel -s > "${MGDIR}/system_info/os_level.txt"
run_cmd uname -a > "${MGDIR}/system_info/uname.txt"
run_cmd prtconf > "${MGDIR}/system_info/prtconf.txt" 2>/dev/null || echo "Could not run prtconf"
# Memory information
run_cmd svmon -G > "${MGDIR}/system_info/memory_usage.txt" 2>/dev/null || echo "Could not run svmon"
# Disk information
run_cmd df -g > "${MGDIR}/system_info/disk_usage.txt"
# Network information
run_cmd netstat -in > "${MGDIR}/system_info/network_interfaces.txt"
echo "AIX system information collected."
}

# Main function
instana_websphere_liberty_mustgather() {
check_prerequisites
# Collect system and Java info
run_cmd java -version > "${MGDIR}/java_version.txt" 2>&1
collect_aix_system_info
# Collect Liberty information
collect_liberty_info

# Create the final archive
run_cmd tar -cf "${MGDIR}.tar" "${MGDIR}" && run_cmd gzip "${MGDIR}.tar"
echo "Must-gather completed. Archive created: ${MGDIR}.tar.gz"
echo "Please provide this file to IBM Support for analysis."
}

# Execute the main function
instana_websphere_liberty_mustgather

