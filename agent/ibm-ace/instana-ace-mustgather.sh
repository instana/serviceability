#!/bin/bash

# IBM ACE Diagnostics Script
# This script combines functionality to:
# 1. Discover and analyze IBM ACE integration nodes (interactive mode)
# 2. Perform diagnostics on a specific integration node (command-line mode)

# Function to display usage
usage() {
    echo "IBM ACE Diagnostics Script"
    echo ""
    echo "Usage:"
    echo "  Interactive mode: $0"
    echo "  Simple command-line mode: $0 -p ACE_PATH [-m MQ_PATH]"
    echo "  Advanced command-line mode: $0 -h ACE_HOST -a API_PORT -b INTEGRATION_NODE [-u USERNAME] [-q QM_NAME] [-r PROTOCOL] [-v API_VERSION] [-m MQ_PATH]"
    echo ""
    echo "Options:"
    echo "  -p ACE_PATH             Path to the IBM ACE installation folder"
    echo "  -m MQ_PATH              Path to the IBM MQ bin directory containing runmqsc"
    echo "  -h ACE_HOST             ACE host name or IP address (for advanced mode)"
    echo "  -a API_PORT             Integration node API port (for advanced mode)"
    echo "  -b INTEGRATION_NODE     Integration node name (for advanced mode)"
    echo "  -u USERNAME             Username for authentication (optional)"
    echo "  -q QM_NAME              Queue Manager name (if MQ is used, optional)"
    echo "  -r PROTOCOL             Protocol (http or https, default: http)"
    echo "  -v API_VERSION          API version (for IIB10 - apiv1, ACE11 or later versions - apiv2. Default: apiv2)"
    echo "  -i                      Force interactive mode"
    exit 1
}

# Default values
PROTOCOL="http"
API_VERSION="apiv2"
INTERACTIVE_MODE=false
SIMPLE_MODE=false
RUNMQSC_PATH=""

# Parse command-line options
while getopts ":p:h:a:b:u:q:r:v:m:i" opt; do
    case $opt in
        p) ACE_PATH=$OPTARG; SIMPLE_MODE=true ;;
        h) ACE_HOST=$OPTARG ;;
        a) API_PORT=$OPTARG ;;
        b) INTEGRATION_NODE=$OPTARG ;;
        u) USERNAME=$OPTARG ;;
        q) QM_NAME=$OPTARG ;;
        r) PROTOCOL=$OPTARG ;;
        v) API_VERSION=$OPTARG ;;
        m) RUNMQSC_PATH=$OPTARG ;;
        i) INTERACTIVE_MODE=true ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
    esac
done

# Check which mode to run in
if [ $# -eq 0 ] || [ "$INTERACTIVE_MODE" = true ]; then
    INTERACTIVE_MODE=true
elif [ "$SIMPLE_MODE" = true ]; then
    # Simple mode with just the ACE path
    if [ -z "$ACE_PATH" ]; then
        echo "Error: ACE_PATH is required for simple command-line mode."
        usage
    fi
else
    # Advanced command-line mode
    if [ -z "$ACE_HOST" ] || [ -z "$API_PORT" ] || [ -z "$INTEGRATION_NODE" ]; then
        echo "Error: ACE_HOST, API_PORT, and INTEGRATION_NODE are required for advanced command-line mode."
        usage
    fi

    # Validate PROTOCOL
    if [ "$PROTOCOL" != "http" ] && [ "$PROTOCOL" != "https" ]; then
        echo "Error: PROTOCOL must be 'http' or 'https'."
        usage
    fi

    # Validate API_VERSION
    if [ "$API_VERSION" != "apiv1" ] && [ "$API_VERSION" != "apiv2" ]; then
        echo "Error: API_VERSION must be 'apiv1' or 'apiv2'."
        usage
    fi
fi

# Function to find or prompt for runmqsc path
find_runmqsc_path() {
    # If path was provided via command line, use it
    if [ -n "$RUNMQSC_PATH" ]; then
        if [ -f "$RUNMQSC_PATH/runmqsc" ]; then
            echo "Using provided runmqsc path: $RUNMQSC_PATH"
            return 0
        else
            echo "Warning: runmqsc not found at provided path: $RUNMQSC_PATH"
            # Continue to check PATH or prompt
        fi
    fi
    
    # Check if runmqsc is in PATH
    if command -v runmqsc &> /dev/null; then
        RUNMQSC_PATH=$(dirname $(which runmqsc))
        echo "Found runmqsc in PATH: $RUNMQSC_PATH"
        return 0
    fi
    
    # Always prompt for the path if runmqsc is not found
    echo "runmqsc command not found in PATH."
    echo "Please enter the path to the directory containing runmqsc (or leave empty to skip MQ commands):"
    read -r user_mq_path
    
    if [ -n "$user_mq_path" ]; then
        if [ -f "$user_mq_path/runmqsc" ]; then
            RUNMQSC_PATH="$user_mq_path"
            echo "Using provided runmqsc path: $RUNMQSC_PATH"
            return 0
        else
            echo "Warning: runmqsc not found at provided path: $user_mq_path"
            echo "MQ-related diagnostics will be skipped."
            return 1
        fi
    else
        echo "No path provided. MQ-related diagnostics will be skipped."
        return 1
    fi
}

# Function to run MQ commands with better error handling
run_mq_command() {
    local qm_name="$1"
    local command="$2"
    local description="$3"
    
    echo "### $description"
    
    # Check if we have a valid runmqsc path
    if [ -z "$RUNMQSC_PATH" ]; then
        echo "Skipping MQ command: runmqsc path not available"
        return 1
    fi
    
    # Run the command and capture both output and error
    output=$(echo "$command" | "$RUNMQSC_PATH/runmqsc" "$qm_name" 2>&1)
    exit_code=$?
    
    # Display the output
    if [ $exit_code -eq 0 ] && [ -n "$output" ]; then
        echo "$output"
    elif [ $exit_code -ne 0 ]; then
        echo "Error executing command. Exit code: $exit_code"
        echo "Error message: $output"
    else
        echo "No output returned. The command may have succeeded but produced no output."
    fi
}

# Function to check curl response
check_curl() {
    local curl_cmd="$1"
    local response=$(eval "$curl_cmd")
    local status=$?
    if [ $status -ne 0 ]; then
        echo "Curl failed with exit status $status"
        return 1
    fi
    local http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" -eq 200 ]; then
        echo "Success: HTTP 200 OK"
        return 0
    else
        echo "Failed: HTTP $http_code"
        return 1
    fi
}

# Function to extract queue manager name from mqsilist output
extract_qm_name() {
    local line="$1"
    # Use grep and awk instead of sed for more reliable extraction
    echo "$line" | grep -o "default queue manager '[^']*'" | awk -F"'" '{print $2}'
}

# Function to run interactive mode diagnostics
run_interactive_mode() {
    # Prompt the user for the IBM ACE folder path if not provided
    if [ -z "$ACE_PATH" ]; then
        echo "Please enter the path to the IBM ACE folder:"
        read ACE_PATH
    else
        echo "Using provided ACE path: $ACE_PATH"
    fi
    
    ACE_BIN_PATH=$ACE_PATH/server/bin

    # Check if the provided directory exists
    if [ ! -d "$ACE_BIN_PATH" ]; then
        echo "Error: Directory $ACE_BIN_PATH does not exist."
        exit 1
    fi

    # Check if mqsiprofile exists in the provided directory
    if [ ! -f "$ACE_BIN_PATH/mqsiprofile" ]; then
        echo "Error: mqsiprofile not found in $ACE_BIN_PATH."
        exit 1
    fi

    # Find or prompt for runmqsc path
    find_runmqsc_path

    # Source the mqsiprofile script only if it hasn't been sourced already
    if [ -z "$MQSI_VERSION" ]; then
        . "$ACE_BIN_PATH/mqsiprofile"
    else
        echo "mqsiprofile has already been sourced; skipping."
    fi

    # Run mqsilist and capture its output
    mqsilist_output=$(mqsilist)
    if [ $? -ne 0 ]; then
        echo "Error: mqsilist command failed."
        exit 1
    fi

    # Check if there are any integration nodes in the output
    if echo "$mqsilist_output" | grep -q "Integration node"; then
        # Process each line containing "Integration node"
        echo "$mqsilist_output" | grep "Integration node" | while read -r line; do
            echo "---"
            # Extract all quoted parts from the line
            quoted_parts=$(echo "$line" | grep -o "'[^']*'")
            # Count the number of quoted parts
            num_parts=$(echo "$quoted_parts" | wc -l)

            # Extract node name (first quoted part)
            node_name=$(echo "$quoted_parts" | sed -n 1p)
            node_name=${node_name//\'/}  # Remove single quotes

            # Check if the line contains a URI (http:// or https://)
            if echo "$line" | grep -q "'http[s]\?://"; then
                # It's a running node with a URI
                if [ $num_parts -eq 3 ]; then
                    queue_manager=$(echo "$quoted_parts" | sed -n 2p)
                    queue_manager=${queue_manager//\'/}
                    uri=$(echo "$quoted_parts" | sed -n 3p)
                elif [ $num_parts -eq 2 ]; then
                    queue_manager="Not available"
                    uri=$(echo "$quoted_parts" | sed -n 2p)
                else
                    echo "Unexpected number of quoted parts in line: $line"
                    continue
                fi

                # Remove single quotes from the URI
                uri=${uri//\'/}

                # Extract protocol, host, and port from the URI
                if [[ $uri =~ ^(https?)://([^:/]+):([0-9]+) ]]; then
                    protocol=${BASH_REMATCH[1]}
                    host=${BASH_REMATCH[2]}
                    port=${BASH_REMATCH[3]}
                else
                    echo "Invalid URI format: $uri"
                    continue
                fi

                # Display the extracted information
                echo "Integration Node: $node_name"
                echo "Status: Running"
                echo "Protocol: $protocol"
                echo "ACE_HOST: $host"
                echo "API_PORT: $port"
                echo "Queue Manager: $queue_manager"
            else
                # No URI present, node is not fully operational
                echo "Integration Node: $node_name"
                if echo "$line" | grep -q "is stopped"; then
                    echo "Status: Stopped"
                elif echo "$line" | grep -q "standby"; then
                    echo "Status: Standby"
                else
                    echo "Status: Unknown (no URI provided)"
                fi
                echo "Protocol: Not available"
                echo "ACE_HOST: Not available"
                echo "API_PORT: Not available"
                
                # Check if a queue manager is present (second quoted part)
                if [ $num_parts -eq 2 ]; then
                    queue_manager=$(echo "$quoted_parts" | sed -n 2p)
                    queue_manager=${queue_manager//\'/}
                    echo "Queue Manager: $queue_manager"
                else
                    echo "Queue Manager: Not available"
                fi
            fi

            # Check operational events for MQ
            echo "Operational Events for $node_name:"
            events_output=$(mqsireportproperties "$node_name" -b Events -o OperationalEvents/MQ -n enabled 2>/dev/null)
            if [ $? -eq 0 ]; then
                # Parse the 'enabled' value (e.g., enabled='true')
                enabled_status=$(echo "$events_output" | grep -i "^true$\|^false$" | tr -d '\n')
                if [ -n "$enabled_status" ]; then
                    echo "  Operational Events (MQ): $enabled_status"
                else
                    echo "  Unable to retrieve operational events status."
                fi
            else
                echo "  Failed to run mqsireportproperties (node may be stopped or inaccessible)."
            fi

            # List integration servers for this node
            echo "Integration Servers for $node_name:"
            servers_output=$(mqsilist "$node_name" 2>/dev/null)
            if echo "$servers_output" | grep -q "No integration servers.*defined\|No execution groups.*defined"; then
                echo "  No integration servers have been defined."
            elif echo "$servers_output" | grep -Eq "Integration server.*(is running|active|running)"; then
                echo "$servers_output" | grep -E "Integration server.*(is running|active|running)" | while read -r server_line; do
                    server_name=$(echo "$server_line" | grep -o "'[^']*'" | sed -n 1p)
                    server_name=${server_name//\'/}
                    echo "  $server_name: Running"
                done
            else
                echo "  Unable to retrieve integration server information."
            fi

            # Report flow stats and resource stats for each running server
            if echo "$servers_output" | grep -Eq "Integration server.*(is running|active|running)"; then
                echo "$servers_output" | grep -E "Integration server.*(is running|active|running)" | while read -r server_line; do
                    server_name=$(echo "$server_line" | grep -o "'[^']*'" | sed -n 1p)
                    server_name=${server_name//\'/}

                    # Report Flow Stats
                    echo "Flow Statistics for $server_name on $node_name:"
                    flow_stats=$(mqsireportflowstats "$node_name" -e "$server_name" -s 2>/dev/null)
                    if echo "$flow_stats" | grep -q "Snapshot.*Active\|state='[^']*'"; then
                        state=$(echo "$flow_stats" | grep -o "state='[^']*'" | head -1 | cut -d "'" -f 2)
                        output_format=$(echo "$flow_stats" | grep -o "outputFormat='[^']*'" | head -1 | cut -d "'" -f 2)
                        if [ -n "$state" ] && [ -n "$output_format" ]; then
                            echo "  State: $state"
                            echo "  Output Format: $output_format"
                            if [ "$state" = "active" ] && [ "$output_format" = "json" ]; then
                                echo "  Flow Stats: Enabled"
                            else
                                echo "  Flow Stats: Not fully enabled (requires state='active' and outputFormat='json')"
                            fi
                        else
                            echo "  Partial flow stats data retrieved; format may vary by version."
                        fi
                    else
                        echo "  Unable to retrieve flow statistics."
                    fi

                    # Report Resource Stats
                    echo "Resource Statistics for $server_name on $node_name:"
                    resource_stats=$(mqsireportresourcestats "$node_name" -e "$server_name" 2>/dev/null)
                    if echo "$resource_stats" | grep -q "Active.*state='[^']*'\|\bstate='[^']*'"; then
                        state=$(echo "$resource_stats" | grep -o "state='[^']*'" | head -1 | cut -d "'" -f 2)
                        if [ -n "$state" ]; then
                            echo "  State: $state"
                            if [ "$state" = "true" ]; then
                                echo "  Resource Stats: Enabled"
                            else
                                echo "  Resource Stats: Disabled"
                            fi
                        else
                            echo "  Partial resource stats data retrieved; format may vary by version."
                        fi
                    else
                        echo "  Unable to retrieve resource statistics."
                    fi
                done
            fi
            
            # Additional diagnostics from command-line mode
            if [ -f "/var/mqsi/components/$node_name/overrides/node.conf.yaml" ]; then
                echo "TLS Configuration for $node_name:"
                echo "Contents of /var/mqsi/components/$node_name/overrides/node.conf.yaml:"
                cat "/var/mqsi/components/$node_name/overrides/node.conf.yaml"
            fi
            
            # Check for MQ or MQTT usage
            if echo "$line" | grep -q "default queue manager"; then
                echo "Messaging: Using MQ"
                # Extract QM_NAME if available - using the new function
                node_qm=$(extract_qm_name "$line")
                if [ -n "$node_qm" ]; then
                    echo "Queue Manager: $node_qm"
                    
                    # Check MQ Port
                    mq_port=$(ps -ef | grep runmqlsr | grep "$node_qm" | awk '{for(i=1;i<=NF;i++) if($i ~ /^-p$/) print $(i+1)}')
                    if [ -n "$mq_port" ]; then
                        echo "MQ listener port: $mq_port"
                    fi
                    
                    # Check Channel Authentication using the new function
                    echo "Channel Authentication for Queue Manager $node_qm:"
                    run_mq_command "$node_qm" "dis qmgr connauth" "Displaying QMGR CONNAUTH"
                    run_mq_command "$node_qm" "dis qmgr chlauth" "Displaying QMGR CHLAUTH"
                    run_mq_command "$node_qm" "dis qmgr PUBSUB CHLEV" "Displaying QMGR PUBSUB CHLEV"
                    run_mq_command "$node_qm" "dis qmgr CLUSTER PERFMEV" "Displaying QMGR CLUSTER PERFMEV"
                    
                    echo "---"
                    echo "Note: To check specific channel authentication, run the following manually:"
                    echo "  dis chlauth(YOUR_CHANNEL_NAME)"
                    echo "  dis channel(YOUR_CHANNEL_NAME) MCAUSER"
                    echo "Interpretation:"
                    echo "- If CONNAUTH is empty and CHLAUTH is DISABLED, no specific authentication is required."
                    echo "- If CONNAUTH is set or CHLAUTH is ENABLED, consult your MQ admin for credential details."
                fi
            else
                echo "Messaging: Using MQTT"
                # Check MQTT Port from config
                if [ -f "/var/mqsi/components/$node_name/overrides/node.conf.yaml" ]; then
                    mqtt_port=$(grep mqttPort "/var/mqsi/components/$node_name/overrides/node.conf.yaml" | awk '{print $2}')
                    if [ -n "$mqtt_port" ]; then
                        echo "MQTT port from config: $mqtt_port"
                    fi
                fi
                
                # Check MQTT Port from process
                mqtt_process_port=$(ps -ef | grep bipMQTT | grep "$node_name" | awk '{for(i=1;i<=NF;i++) if($i ~ /^--port$/) print $(i+1)}')
                if [ -n "$mqtt_process_port" ]; then
                    echo "MQTT port from process: $mqtt_process_port"
                fi
            fi
            
            echo ""
        done
    else
        echo "No integration nodes found."
    fi
    
    # Check all IBM ACE-related listening ports
    echo "---"
    echo "All IBM ACE-related listening ports:"
    echo "Checking for bipbroker, bipmqtt, and runmqlsr processes..."
    if command -v sudo >/dev/null 2>&1 && command -v lsof >/dev/null 2>&1; then
        sudo lsof -i -P -n | grep LISTEN | grep -Ei 'bipbroker|bipmqtt|runmqlsr'
        if [ $? -ne 0 ]; then
            echo "No IBM ACE-related listening ports found or lsof command failed."
        fi
    else
        echo "sudo or lsof command not available. Cannot check listening ports."
    fi
}

# Function to run command-line mode diagnostics
run_command_line_mode() {
    # Find or prompt for runmqsc path
    find_runmqsc_path
    
    # Construct the URL
    URL="$PROTOCOL://$ACE_HOST:$API_PORT/$API_VERSION"

    echo "Starting IBM App Connect Enterprise diagnostics..."
    echo "---------------------------------"

    ### Task 1: Test ACE Credentials
    echo "## Testing ACE Credentials"

    # Try without credentials
    echo "### Attempting without credentials"
    curl_cmd="curl -s -o /dev/null -w '%{http_code}' --header 'Accept: application/json' '$URL'"
    if [ "$PROTOCOL" = "https" ]; then
        curl_cmd="curl -k -s -o /dev/null -w '%{http_code}' --header 'Accept: application/json' '$URL'"
    fi
    check_curl "$curl_cmd"
    if [ $? -eq 0 ]; then
        echo "Result: ACE credentials are not required."
        CREDS_REQUIRED=false
    else
        CREDS_REQUIRED=true
        if [ -n "$USERNAME" ]; then
            echo "### Attempting with credentials"
            curl_cmd="curl -u '$USERNAME' -s -o /dev/null -w '%{http_code}' --header 'Accept: application/json' '$URL'"
            if [ "$PROTOCOL" = "https" ]; then
                curl_cmd="curl -k -u '$USERNAME' -s -o /dev/null -w '%{http_code}' --header 'Accept: application/json' '$URL'"
            fi
            check_curl "$curl_cmd"
            if [ $? -eq 0 ]; then
                echo "Result: Credentials are required and the provided username works."
            else
                echo "Result: Credentials are required but the provided username does not work."
            fi
        else
            echo "Result: Credentials are required but no username was provided."
        fi
    fi

    echo "---------------------------------"

    ### Task 2: Get TLS Encryption Information
    echo "## Check for TLS Encryption Information in this configuration file if you have enabled TLS Encryption for IBM ACE"
    CONFIG_FILE="/var/mqsi/components/$INTEGRATION_NODE/overrides/node.conf.yaml"
    if [ -f "$CONFIG_FILE" ]; then
        echo "Contents of $CONFIG_FILE:"
        cat "$CONFIG_FILE"
    else
        echo "Error: $CONFIG_FILE not found for broker $INTEGRATION_NODE."
    fi

    echo "---------------------------------"

    ### Task 3: Determine Whether MQ or MQTT is in Use
    echo "## Determining MQ or MQTT Usage"
    mqsilist_output=$(mqsilist | grep "$INTEGRATION_NODE")
    if [ -n "$mqsilist_output" ]; then
        if echo "$mqsilist_output" | grep -q "default queue manager"; then
            echo "Result: Broker $INTEGRATION_NODE is using MQ."
            # Extract QM_NAME if not provided
            if [ -z "$QM_NAME" ]; then
                QM_NAME=$(extract_qm_name "$mqsilist_output")
                echo "Extracted Queue Manager Name: $QM_NAME"
            fi
        else
            echo "Result: Broker $INTEGRATION_NODE is using MQTT."
        fi
    else
        echo "Error: No information found for broker $INTEGRATION_NODE in mqsilist output."
    fi

    echo "---------------------------------"

    ### Task 4: Determine MQ and MQTT Ports
    echo "## Determining Ports"
    if [ -n "$QM_NAME" ]; then
        echo "### MQ Port for Queue Manager $QM_NAME"
        mq_port=$(ps -ef | grep runmqlsr | grep "$QM_NAME" | awk '{for(i=1;i<=NF;i++) if($i ~ /^-p$/) print $(i+1)}')
        if [ -n "$mq_port" ]; then
            echo "MQ listener port: $mq_port"
        else
            echo "No runmqlsr process found for Queue Manager $QM_NAME."
        fi
    else
        echo "### MQTT Port for Broker $INTEGRATION_NODE"
        # From node.conf.yaml
        if [ -f "$CONFIG_FILE" ]; then
            mqtt_port=$(grep mqttPort "$CONFIG_FILE" | awk '{print $2}')
            if [ -n "$mqtt_port" ]; then
                echo "MQTT port from config: $mqtt_port"
            else
                echo "mqttPort not found in $CONFIG_FILE."
            fi
        fi
        # From process information
        mqtt_process_port=$(ps -ef | grep bipMQTT | grep "$INTEGRATION_NODE" | awk '{for(i=1;i<=NF;i++) if($i ~ /^--port$/) print $(i+1)}')
        if [ -n "$mqtt_process_port" ]; then
            echo "MQTT port from process: $mqtt_process_port"
        else
            echo "No bipMQTT process found for Broker $INTEGRATION_NODE."
        fi
    fi
    
    # Check all IBM ACE-related listening ports
    echo "### All IBM ACE-related listening ports"
    echo "Checking for bipbroker, bipmqtt, and runmqlsr processes..."
    if command -v sudo >/dev/null 2>&1 && command -v lsof >/dev/null 2>&1; then
        sudo lsof -i -P -n | grep LISTEN | grep -Ei 'bipbroker|bipmqtt|runmqlsr'
        if [ $? -ne 0 ]; then
            echo "No IBM ACE-related listening ports found or lsof command failed."
        fi
    else
        echo "sudo or lsof command not available. Cannot check listening ports."
    fi

    echo "---------------------------------"

    ### Task 5: Check Channel Authentication (MQ Only)
    if [ -n "$QM_NAME" ]; then
        echo "## Checking Channel Authentication for Queue Manager $QM_NAME"
        run_mq_command "$QM_NAME" "dis qmgr connauth" "Displaying QMGR CONNAUTH"
        run_mq_command "$QM_NAME" "dis qmgr chlauth" "Displaying QMGR CHLAUTH"
        run_mq_command "$QM_NAME" "dis qmgr PUBSUB CHLEV" "Displaying QMGR PUBSUB CHLEV"
        run_mq_command "$QM_NAME" "dis qmgr CLUSTER PERFMEV" "Displaying QMGR CLUSTER PERFMEV"
        echo "---"
        echo "Note: To check specific channel authentication, run the following manually:"
        echo "  dis chlauth(YOUR_CHANNEL_NAME)"
        echo "  dis channel(YOUR_CHANNEL_NAME) MCAUSER"
        echo "Interpretation:"
        echo "- If CONNAUTH is empty and CHLAUTH is DISABLED, no specific authentication is required."
        echo "- If CONNAUTH is set or CHLAUTH is ENABLED, consult your MQ admin for credential details."
    else
        echo "## Skipping Channel Authentication Check"
        echo "No Queue Manager Name provided or detected."
    fi

    echo "Diagnostics complete."
}

# Main execution
echo "IBM ACE Diagnostics Script"
echo "=========================="

if [ "$INTERACTIVE_MODE" = true ]; then
    echo "Running in interactive mode..."
    run_interactive_mode
elif [ "$SIMPLE_MODE" = true ]; then
    echo "Running in simple command-line mode with ACE path: $ACE_PATH"
    run_interactive_mode  # We reuse the interactive mode function but with the path already set
else
    echo "Running in advanced command-line mode..."
    run_command_line_mode
fi
