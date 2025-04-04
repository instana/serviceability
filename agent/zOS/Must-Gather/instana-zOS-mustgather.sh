#!/bin/sh
###############################################################################
#
# This script collects data for the Instana Host Agent on z/OS
#
# Usage:
#   ./instana-zOS-mustgather.sh
#
###############################################################################

# Safer scripting:

# -o pipefail : fail if any command in a pipeline fails (may not be supported on older sh)
set -o pipefail



CURRENT_TIME=$(date "+%Y%m%d-%H%M%S")
MGDIR="instana-agent-zOS-mustgather-${CURRENT_TIME}"
mkdir -p "${MGDIR}"



###############################################################################
# Helper function to run commands, but log to stderr so it doesn't pollute stdout
###############################################################################
run_cmd() {
    >&2 echo "Running: $*"   # Print debug info to stderr
    "$@"                     # Run the command, leaving stdout clean for capturing
}




function collect_agent_logs() {


log_folder="$instana_agent_path/data/log"
# Check if the log folder exists
if [ ! -d "$log_folder" ]; then
    echo "Error: The log folder '$log_folder' does not exist."
    exit 1
fi

mkdir -p "${MGDIR}/logs/"
for file in "$log_folder"/*; do
    if [ -f "$file" ]; then
        cp "$file" "$destination_folder"
        echo "Copied: $(basename "$file")"
    fi
done

}

function check_user_privilege() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "You are root!"
  else
    echo "You are not root Aborting MUST Gather collection. Switch to the user which has root privilege and retry"
    exit 1
  fi
}
function check_zOS_prerequisites() {
 if command -v bash > /dev/null && command -v tar > /dev/null; then
   log_info 'bash and tar are available on the system'
 else
   log_error 'This script requires bash and tar to be installed on this system. Aborting installation.'
   exit 1
 fi

}

function instana-zOS-mustgather() {
    check_user_privilege
    check_zOS_prerequisites

    run_cmd id > "${MGDIR}/user-privilege.txt"
    run_cmd java -version > "${MGDIR}/java-version.txt"

    read -p "Enter the instana-agent directory path: for example /u/user1/instana-agent " instana_agent_path

    # Check if the instana-agent directory exists
    if [ ! -d "$instana_agent_path" ]; then
        echo "Error: The specified instana-agent directory does not exist."
        exit 1
    fi
    run_cmd ls -lTr "${instana_agent_path}"/bin > "${MGDIR}/tag-for-bin-files.txt"
    run_cmd ls -lTr "${instana_agent_path}"/etc > "${MGDIR}/tag-for-etc-files.txt"
    run_cmd ls -ltr /tmp/.instana > "${MGDIR}/tmp-instana-files.txt"

    collect_agent_logs
    ./${instana_agent_path}/WebSphere-zOS-Prereq.sh > "${MGDIR}/websphere-zOS-Prereq-output.txt"
    run_cmd tar czf "${MGDIR}.tgz" "${MGDIR}"
    >&2 echo "Must-gather completed. Archive created: ${MGDIR}.tgz"

}

if ! instana-zOS-mustgather; then
  exit 1
fi

