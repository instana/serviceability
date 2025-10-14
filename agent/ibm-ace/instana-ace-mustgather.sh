#!/bin/bash

# instana-ace-mustgather.sh - Enhanced with MQSC listener, chlauth, chstatus, ace credentials check
# This script collects diagnostic information for IBM App Connect Enterprise environments

# Default parameter values
NODE_NAME=""       # integration node name
QUEUE_MANAGER=""   # queue manager name
ADMIN_URL=""       # Administration URI
USER=""            # Username
PASS=""            # Password
CUSTOM_API=""      # Optional - If the user is using IIB10. Default is apiv2

# Function to display usage
usage() {
    echo "IBM ACE Must-Gather Script"
    echo ""
    echo "Usage:"
    echo "  $0 [-n NODE_NAME] [-q QUEUE_MANAGER] [-a ADMIN_URL] [-u USER] [-p PASS] [-c CUSTOM_API]"
    echo ""
    echo "Options:"
    echo "  -n NODE_NAME       Integration node name"
    echo "  -q QUEUE_MANAGER   Queue manager name"
    echo "  -a ADMIN_URL       Administration URI (e.g., http://acehost:4414)"
    echo "  -u USER            Username for authentication"
    echo "  -p PASS            Password for authentication"
    echo "  -c CUSTOM_API      Optional - API version (e.g., apiv1 for IIB10, default is apiv2)"
    echo "  -h                 Display this help message"
    echo ""
    echo "Usage examples:"
    echo "  $0 -n iNode1                     # Examines only the specified node"
    echo "  $0 -q QM1                        # Examines only the specified queue manager"
    echo "  $0 -n iNode1 -q QM1 -a http://acehost:4414   # Examines node, queue manager and verifies ace credentials without username/password"
    echo "  $0 -n iNode1 -q QM1 -a http://acehost:4414 -u adminUser -p myStrongPass  # Examines with credentials"
    echo "  $0 -n iNode1 -q QM1 -a http://acehost:4414 -u adminUser -p myStrongPass -c apiv1  # Using custom API version"
    exit 1
}

# Parse command-line options
while getopts ":n:q:a:u:p:c:h" opt; do
    case $opt in
        n) NODE_NAME=$OPTARG ;;
        q) QUEUE_MANAGER=$OPTARG ;;
        a) ADMIN_URL=$OPTARG ;;
        u) USER=$OPTARG ;;
        p) PASS=$OPTARG ;;
        c) CUSTOM_API=$OPTARG ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Create output directory with timestamp
TS=$(date +"%Y%m%d_%H%M%S")
OUT_DIR="ace_mustgather_$TS"
mkdir -p "$OUT_DIR"
LOG_FILE="$OUT_DIR/gather.log"

# Function to implement transcript logging (similar to Start-Transcript)
start_transcript() {
    # Redirect all output to both console and log file
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1
    echo "== ACE Must-Gather Started: $(date) =="
    echo "Log file: $LOG_FILE"
}

# Function to display section headers (similar to Show-Section)
show_section() {
    echo -e "\n============================================================"
    echo ">>> $1"
    echo "============================================================"
}

# Function to run MQ commands with error handling
run_mq_command() {
    local qm_name="$1"
    local command="$2"
    
    if ! command -v runmqsc &> /dev/null; then
        echo "Error: runmqsc command not found. Ensure IBM MQ is installed and in your PATH."
        return 1
    fi
    
    echo "$command" | runmqsc "$qm_name" 2>&1
    return $?
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Start transcript logging
start_transcript

# Display warning if no arguments provided
if [ -z "$NODE_NAME" ] && [ -z "$QUEUE_MANAGER" ] && [ -z "$ADMIN_URL" ] && [ -z "$USER" ] && [ -z "$PASS" ] && [ -z "$CUSTOM_API" ]; then
    echo "!! Warning: No arguments provided."
    echo ""
    echo "Basic Usage (choose at least one):"
    echo "  $0 -n iNode1              # Collect data for a specific integration node"
    echo "  $0 -q QM1                 # Collect data for a specific queue manager"
    echo ""
    echo "API Verification (with or without authentication):"
    echo "  $0 -n iNode1 -q QM1 -a http://acehost:4414"
    echo "  $0 -n iNode1 -q QM1 -a http://acehost:4414 -u adminUser -p myStrongPass"
    echo ""
    echo "For IIB10 users (using custom API version):"
    echo "  $0 -n iNode1 -q QM1 -a http://acehost:4414 -c apiv1"
fi

# 1. mqsilist summary + running integration server
show_section "mqsilist Summary"
if command_exists mqsilist; then
    mqsilist
else
    echo "Error: mqsilist command not found. Ensure IBM ACE is installed and in your PATH."
fi

show_section "Running Integration Servers on $NODE_NAME"
if [ -n "$NODE_NAME" ] && command_exists mqsilist; then
    mqsilist "$NODE_NAME"
else
    echo "Skipping integration server check. Either NODE_NAME not provided or mqsilist not available."
fi

# 2. Check group membership (equivalent to whoami /groups)
show_section "Group Membership (mqm & mqbrkrs)"
if command_exists id; then
    id | grep -E 'mqm|mqbrkrs'
    
    # Additional group information
    echo -e "\nGroup membership details:"
    if command_exists getent; then
        echo "mqm group members:"
        getent group mqm || echo "mqm group not found"
        
        echo "mqbrkrs group members:"
        getent group mqbrkrs || echo "mqbrkrs group not found"
    else
        echo "getent command not available. Cannot retrieve detailed group information."
    fi
else
    echo "id command not available. Cannot check group membership."
fi

# 4. MQSC collection (if QUEUE_MANAGER is provided)
show_section "MQSC Collection"

# Check if NODE_NAME or QUEUE_MANAGER is provided
if [ -z "$NODE_NAME" ] && [ -z "$QUEUE_MANAGER" ]; then
    echo "!! No node name or queue manager name provided."
    echo "Please specify at least one of these parameters to examine specific components:"
    echo "  -n NODE_NAME: To examine a specific integration node"
    echo "  -q QUEUE_MANAGER: To examine a specific queue manager"
    echo "Example: $0 -n YourNodeName -q YourQMName"
    
    # Skip MQSC collection if no parameters provided
    echo -e "\nSkipping MQSC collection. Please provide QUEUE_MANAGER parameter."
elif [ -n "$QUEUE_MANAGER" ]; then
    # Use the QUEUE_MANAGER parameter directly
    echo "Using specified queue manager: $QUEUE_MANAGER"
    echo -e "\n------------------------------------------------------------"
    echo " Queue Manager: $QUEUE_MANAGER"
    echo "------------------------------------------------------------"
    
    # MQSC collection: listeners, channel auth & status
    show_section "MQSC: Listeners for $QUEUE_MANAGER"
    run_mq_command "$QUEUE_MANAGER" "DISPLAY LISTENER(*) ALL"

    show_section "MQSC: Listener Status for $QUEUE_MANAGER"
    run_mq_command "$QUEUE_MANAGER" "DISPLAY LSSTATUS(*) ALL"

    show_section "MQSC: Check connection authentication for $QUEUE_MANAGER"
    run_mq_command "$QUEUE_MANAGER" "dis qmgr connauth"

    show_section "MQSC: Channel Authentication for $QUEUE_MANAGER"
    run_mq_command "$QUEUE_MANAGER" "dis qmgr chlauth"

    show_section "MQSC: Channel Status for $QUEUE_MANAGER"
    run_mq_command "$QUEUE_MANAGER" "DISPLAY CHSTATUS(*)"
else
    echo "Skipping MQSC collection. Please provide QUEUE_MANAGER parameter to collect MQSC information."
    echo "Example: $0 -q YourQMName"
fi

# 6. TCP Ports used by ACE/MQ Processes
show_section "TCP Ports for runmqlsr, bipMQTT, bipbroker"
echo "Process Name | PID | Local Port | Local Address"
echo "-------------|-----|------------|-------------"

# Use different commands based on OS
if command_exists ss; then
    # Modern Linux with ss
    ss -tlnp 2>/dev/null | grep -E 'runmqlsr|bipMQTT|bipbroker' | while read -r line; do
        pid=$(echo "$line" | grep -oP 'pid=\K\d+')
        process=$(ps -p "$pid" -o comm= 2>/dev/null)
        port=$(echo "$line" | grep -oP ':\K\d+(?=\s)')
        addr=$(echo "$line" | grep -oP '\S+:\d+' | head -1)
        echo "$process | $pid | $port | $addr"
    done
elif command_exists netstat; then
    # Older systems with netstat
    netstat -tlnp 2>/dev/null | grep -E 'runmqlsr|bipMQTT|bipbroker' | while read -r line; do
        pid=$(echo "$line" | grep -oP '\d+/\K\S+')
        process=$(echo "$line" | grep -oP '\d+/\K\S+')
        port=$(echo "$line" | grep -oP ':\K\d+(?=\s)')
        addr=$(echo "$line" | grep -oP '\S+:\d+' | head -1)
        echo "$process | $pid | $port | $addr"
    done
elif command_exists lsof; then
    # Using lsof as fallback
    lsof -i -P -n | grep LISTEN | grep -E 'runmqlsr|bipMQTT|bipbroker' | while read -r line; do
        process=$(echo "$line" | awk '{print $1}')
        pid=$(echo "$line" | awk '{print $2}')
        addr=$(echo "$line" | grep -oP '\S+:\d+' | tail -1)
        port=$(echo "$addr" | cut -d':' -f2)
        echo "$process | $pid | $port | $addr"
    done
else
    echo "No suitable command (ss, netstat, lsof) found to check TCP ports."
fi

# 7. Resource & flow stats
show_section "Resource and Flow Stats"

# Check if NODE_NAME is provided
if [ -z "$NODE_NAME" ] && [ -z "$QUEUE_MANAGER" ]; then
    echo "Skipping resource and flow stats. Please provide NODE_NAME parameter."
    echo "Example: $0 -n YourNodeName"
elif [ -n "$NODE_NAME" ]; then
    # If NODE_NAME is provided, collect stats for that specific node
    echo "Collecting resource and flow stats for specified node: $NODE_NAME"
    
    # Get servers for this specific node directly
    if command_exists mqsilist; then
        servers=$(mqsilist "$NODE_NAME" | grep -E "Integration server '([^']+)'" | sed -E "s/.*Integration server '([^']+)'.*/\1/g")
        
        if [ -n "$servers" ]; then
            echo "$servers" | while read -r is; do
                echo -e "\n>>> Resource stats for Node [$NODE_NAME] / Server [$is]"
                if command_exists mqsireportresourcestats; then
                    mqsireportresourcestats "$NODE_NAME" -e "$is"
                else
                    echo "mqsireportresourcestats command not found"
                fi

                echo -e "\n>>> Flow stats for Node [$NODE_NAME] / Server [$is]"
                if command_exists mqsireportflowstats; then
                    mqsireportflowstats "$NODE_NAME" -s -e "$is"
                else
                    echo "mqsireportflowstats command not found"
                fi
            done
        else
            echo "!! No servers found for node: $NODE_NAME"
        fi
    else
        echo "mqsilist command not found. Cannot retrieve server information."
    fi
else
    echo "Skipping resource and flow stats. NODE_NAME parameter is required for this section."
    echo "Example: $0 -n YourNodeName"
fi


# 8. Integration Node overrides
show_section "Integration Node Overrides"

# Check if either NODE_NAME or QUEUE_MANAGER is provided
if [ -z "$NODE_NAME" ] && [ -z "$QUEUE_MANAGER" ]; then
    echo "Skipping integration node overrides. Please provide NODE_NAME parameter."
    echo "Example: $0 -n YourNodeName"
elif [ -z "$NODE_NAME" ]; then
    echo "NODE_NAME parameter is required to examine integration node overrides."
    echo "Example: $0 -n YourNodeName"
else
    echo "Examining specified integration node: $NODE_NAME"
    
    # Check common locations for node overrides
    node_paths=(
        "/var/mqsi/components/$NODE_NAME"
        "/var/mqsi/nodes/$NODE_NAME"
        "$HOME/IBM/MQSI/components/$NODE_NAME"
        "/opt/ibm/ace-11/server/config/$NODE_NAME"
    )
    
    found_override=false
    
    for node_path in "${node_paths[@]}"; do
        if [ -d "$node_path" ]; then
            echo "Found node directory: $node_path"
            
            # Check for node overrides file
            node_overrides_path="$node_path/overrides/node.conf.yaml"
            if [ -f "$node_overrides_path" ]; then
                found_override=true
                echo "Node overrides file exists: $node_overrides_path"
                echo "Contents of node overrides file:"
                echo "----------------------------------------"
                cat "$node_overrides_path"
                echo "----------------------------------------"
                # Copy the file to output directory
                cp "$node_overrides_path" "$OUT_DIR/node.conf.yaml" 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo "Copied node.conf.yaml to $OUT_DIR/"
                fi
            fi
        fi
    done
    
    if [ "$found_override" = false ]; then
        echo "No node.conf.yaml found for this node in standard locations"
    fi
fi

# ACE credentials Test
show_section "ACE credentials Test"

if [ -z "$ADMIN_URL" ]; then
    echo "Skipping ACE credentials Test. Please provide ADMIN_URL parameter."
    echo "Example: $0 -a http://aceHost:port"
else
    if [ -z "$CUSTOM_API" ]; then
        API_VERSION="apiv2"
    else
        API_VERSION="$CUSTOM_API"
    fi
    
    # Extract host and port from ADMIN_URL
    if [[ "$ADMIN_URL" =~ ^(https?://)?([^:/]+):([0-9]+) ]]; then
        PROTOCOL=${BASH_REMATCH[1]:-http://}
        ACE_HOST=${BASH_REMATCH[2]}
        API_PORT=${BASH_REMATCH[3]}
    else
        echo "!! Invalid ADMIN_URL format. Expected format: [http(s)://]hostname:port"
        echo "Using provided URL as-is: $ADMIN_URL"
        ACE_HOST="<ACE_HOST>"
        API_PORT="<INTEGTATION_NODE_API_PORT>"
    fi
    
    echo "Performing ACE credentials tests..."
    
    # Check if curl is available
    if ! command_exists curl; then
        echo "Error: curl command not found. Cannot test ACE credentials."
        return
    fi
    
    # Determine if we're using HTTP or HTTPS
    if [[ "$ADMIN_URL" == https://* ]]; then
        USE_HTTPS=true
    else
        USE_HTTPS=false
    fi
    
    # Create full URL
    FULL_URL="$ADMIN_URL/$API_VERSION"
    
    # Test 1: Without credentials
    echo -e "\n### Testing without credentials"
    if [ "$USE_HTTPS" = true ]; then
        echo "Command: curl -k --header \"Accept: application/json\" \"$FULL_URL\""
        response=$(curl -k -s --header "Accept: application/json" "$FULL_URL")
        status_code=$?
    else
        echo "Command: curl --header \"Accept: application/json\" \"$FULL_URL\""
        response=$(curl -s --header "Accept: application/json" "$FULL_URL")
        status_code=$?
    fi
    
    if [ $status_code -eq 0 ]; then
        # Check if response contains valid JSON
        if echo "$response" | grep -q "{"; then
            echo "Result: SUCCESS - ACE credentials are not required"
            echo "Response preview:"
            echo "$response" | head -20
        else
            echo "Result: FAILED - Response doesn't appear to be valid JSON"
            echo "Response preview:"
            echo "$response" | head -5
        fi
    else
        echo "Result: FAILED - curl command failed with status $status_code"
    fi
    
    # Test 2: With credentials (if provided)
    if [ -n "$USER" ]; then
        echo -e "\n### Testing with credentials"
        if [ "$USE_HTTPS" = true ]; then
            echo "Command: curl -k -u $USER --header \"Accept: application/json\" \"$FULL_URL\""
            if [ -n "$PASS" ]; then
                response=$(curl -k -s -u "$USER:$PASS" --header "Accept: application/json" "$FULL_URL")
            else
                echo "Password will be prompted..."
                response=$(curl -k -s -u "$USER" --header "Accept: application/json" "$FULL_URL")
            fi
            status_code=$?
        else
            echo "Command: curl -u $USER --header \"Accept: application/json\" \"$FULL_URL\""
            if [ -n "$PASS" ]; then
                response=$(curl -s -u "$USER:$PASS" --header "Accept: application/json" "$FULL_URL")
            else
                echo "Password will be prompted..."
                response=$(curl -s -u "$USER" --header "Accept: application/json" "$FULL_URL")
            fi
            status_code=$?
        fi
        
        if [ $status_code -eq 0 ]; then
            # Check if response contains valid JSON
            if echo "$response" | grep -q "{"; then
                echo "Result: SUCCESS - Authentication successful"
                echo "Response preview:"
                echo "$response" | head -20
            else
                echo "Result: FAILED - Response doesn't appear to be valid JSON"
                echo "Response preview:"
                echo "$response" | head -5
            fi
        else
            echo "Result: FAILED - curl command failed with status $status_code"
        fi
    else
        echo -e "\n### Skipping credential test - no username provided"
        echo "To test with credentials, run the script with -u and -p parameters"
    fi
    
    # Save full responses to output directory
    if [ -n "$response" ]; then
        echo -e "\nSaving full API responses to output directory..."
        echo "$response" > "$OUT_DIR/ace_api_response.json"
        echo "Full response saved to: $OUT_DIR/ace_api_response.json"
    fi
fi

# Detailed process information
show_section "All running process details"

# Get detailed process information and save to file
ps_output_file="$OUT_DIR/processes.txt"
if command_exists ps; then
    echo "Collecting detailed process information..."
    ps -ef | grep -E 'runmq|bip|mqsi|ace' > "$ps_output_file"
    echo "Process information saved to: $ps_output_file"
    
    # Count processes by type
    echo -e "\nProcess count by type:"
    echo "----------------------"
    grep -c "runmq" "$ps_output_file" | xargs echo "MQ processes:"
    grep -c "bip" "$ps_output_file" | xargs echo "Integration Bus processes:"
    grep -c "mqsi" "$ps_output_file" | xargs echo "MQSI processes:"
    grep -c "ace" "$ps_output_file" | xargs echo "ACE processes:"
else
    echo "ps command not available. Cannot collect process information."
fi

# Collect system information
show_section "System Information"
echo "Operating System:" > "$OUT_DIR/system_info.txt"
uname -a >> "$OUT_DIR/system_info.txt"
echo -e "\nCPU Information:" >> "$OUT_DIR/system_info.txt"
if [ -f "/proc/cpuinfo" ]; then
    grep -E "model name|processor" /proc/cpuinfo | sort -u >> "$OUT_DIR/system_info.txt"
fi
echo -e "\nMemory Information:" >> "$OUT_DIR/system_info.txt"
if command_exists free; then
    free -h >> "$OUT_DIR/system_info.txt"
fi
echo -e "\nDisk Usage:" >> "$OUT_DIR/system_info.txt"
if command_exists df; then
    df -h >> "$OUT_DIR/system_info.txt"
fi

echo "System information saved to: $OUT_DIR/system_info.txt"

echo -e "\n== ACE Must-Gather Completed: $(date) =="
echo -e "\nResults in: $OUT_DIR"

# Made with Bob
