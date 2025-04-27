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

# Check if a queue manager name is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <QueueManagerName>"
  exit 1
fi

# Assign the first argument to QMGR_NAME
QMGR_NAME="$1"

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
