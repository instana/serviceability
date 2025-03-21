#!/bin/bash

# Function to check if the directory for a PID exists under /tmp/.com_ibm_tools_attach
check_pid_folder() {
    pid=$1
    directory="/tmp/.com_ibm_tools_attach/$pid"

    if [ -d "$directory" ]; then
        echo "PID $pid: Folder exists, available to Trace"
    else
        echo "PID $pid: Folder does NOT exist, NOT available to Trace."
    fi
}

# Function to collect PIDs based on specific criteria and check if their directories exist
collect_and_check_pids() {
    # Get the list of processes containing "lib/s390-common" and ending with "bboosrmr"
    ps -ef | grep 'lib/s390-common' | grep -v 'grep' | grep 'bboosrmr' | while read -r line; do
        # Extract the PID (second column of ps output)
        pid=$(echo "$line" | awk '{print $2}')

        # Check if the directory exists for this PID
        check_pid_folder "$pid"
    done
}

# Function to check User Privilege
check_user_privilege() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "You are root!"
  else
    echo "You are not root Aborting Agent Installation. Switch to the user which has root privilege and retry"
    exit 1
  fi
}


# Run the function to collect PIDs and check their availability after checking user privilege
check_user_privilege
collect_and_check_pids
