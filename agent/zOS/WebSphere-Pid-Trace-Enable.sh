#!/bin/bash

# Function to check if the directory for a PID exists under /tmp/.com_ibm_tools_attach
check_pid_folder() {
    pid=$1
    directory="/tmp/.com_ibm_tools_attach/$pid"

    if [ -d "$directory" ]; then
        echo "PID $pid: Folder exists, available to Trace."
    else
        echo "PID $pid: Folder does NOT exist, NOT available to Trace."
    fi
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

# Prompt user to enter a PID
check_user_privilege
echo "Please enter the PID you want to check: "
read pid

# Check if the user entered a PID
if [ -z "$pid" ]; then
    echo "No PID entered. Exiting..."
    exit 1
fi

# Check if the directory exists for the entered PID
check_pid_folder "$pid"
