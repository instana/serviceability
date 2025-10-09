#!/bin/bash
###############################################################################
#
# Copyright IBM Corp. 2025
#
# This script collects data from IBM MQ
#
###############################################################################

VERSION="1.0.0"
echo "Version: ${VERSION}" >&2

# Function to check if the user belongs to the 'mqm' group
check_mqm_group() {
  if ! groups | grep -qw "mqm"; then
    echo "Error: User '$USER' does not belong to the 'mqm' group. Exiting." >&2
    exit 1
  fi
}

# Function to check if the specified queue manager is running
check_qmgr_running() {
  local status
  status=$(dspmq -m "$1" 2>/dev/null)

  if [[ -z "$status" ]]; then
    echo "Error: Queue Manager '$1' not found. Exiting." >&2
    exit 1
  elif ! echo "$status" | grep -q "Running"; then
    echo "Error: Queue Manager '$1' is not running. Exiting." >&2
    exit 1
  fi
}

# Run group membership check
check_mqm_group

# Check if a queue manager name is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <QueueManagerName>"
  exit 1
fi

# Assign the first argument to QMGR_NAME
QMGR_NAME="$1"

# Check if the queue manager is running
check_qmgr_running "$QMGR_NAME"

# Display installation details
echo "IBM MQ installation details"
dspmqver
echo

# Display full status of all queue managers
echo "Full Queue Manager Status (dspmq -x -o all):"
dspmq -x -o all
echo

# Function to execute MQSC commands
execute_mqsc() {
  echo "$1" | runmqsc "$QMGR_NAME"
}

# 1. Display definition and status of the queue manager
echo "Queue Manager Definition and Status:"
execute_mqsc "DISPLAY QMGR ALL"
execute_mqsc "DISPLAY QMSTATUS ALL"
echo

# 2. Display definitions and statuses of all channels
echo "Channel Definitions:"
execute_mqsc "DISPLAY CHANNEL(*) ALL"
echo
echo "Channel Authentication Rules (CHLAUTH):"
execute_mqsc "DISPLAY CHLAUTH(*) ALL"
echo
echo "Channel Statuses:"
execute_mqsc "DISPLAY CHSTATUS(*) ALL"
echo

# 3. Display definitions and statuses of all listeners
echo "Listener Definitions:"
execute_mqsc "DISPLAY LISTENER(*) ALL"
echo
echo "Listener Statuses:"
execute_mqsc "DISPLAY LSSTATUS(*) ALL"
echo
