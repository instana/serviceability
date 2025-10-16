#!/usr/bin/ksh
# Fix for potential line ending issues

# instana-ace-mustgather-aix.sh - Enhanced with MQSC listener, chlauth, chstatus, ace credentials check
# This script collects diagnostic information for IBM App Connect Enterprise environments on AIX

# Default parameter values
NODE_NAME=""       # integration node name
QUEUE_MANAGER=""   # queue manager name
ADMIN_URL=""       # Administration URI
USER=""            # Username
PASS=""            # Password
CUSTOM_API=""      # Optional - If the user is using IIB10. Default is apiv2

# Function to display usage
usage() {
    echo "IBM ACE Must-Gather Script for AIX"
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

# Function to log messages to both console and file
log_message() {
    echo "$@"
    echo "$@" >> "$LOG_FILE"
}

# Start logging
start_transcript() {
    # Redirect stderr to the log file
    exec 2>> "$LOG_FILE"
    
    log_message "== ACE Must-Gather Started: $(date) =="
    log_message "Log file: $LOG_FILE"
}

# Function to display section headers
show_section() {
    log_message "\n============================================================"
    log_message ">>> $1"
    log_message "============================================================"
}

# Function to run MQ commands with error handling
run_mq_command() {
    typeset qm_name="$1"
    typeset command="$2"
    
    if ! whence runmqsc >/dev/null 2>&1; then
        log_message "Error: runmqsc command not found. Ensure IBM MQ is installed and in your PATH."
        return 1
    fi
    
    echo "$command" | runmqsc "$qm_name" 2>&1
    return $?
}

# Function to run MQ commands and log the output
run_mq_command_and_log() {
    typeset qm_name="$1"
    typeset command="$2"
    
    if ! whence runmqsc >/dev/null 2>&1; then
        log_message "Error: runmqsc command not found. Ensure IBM MQ is installed and in your PATH."
        return 1
    fi
    
    # Execute the command and capture its output
    output=$(echo "$command" | runmqsc "$qm_name" 2>&1)
    
    # Log each line of the output
    echo "$output" | while read -r line; do
        log_message "$line"
    done
    
    return ${PIPESTATUS[0]}
}

# Function to check if a command exists
command_exists() {
    whence "$1" >/dev/null 2>&1
}

# Function to check if IBM ACE environment is set up
check_ace_environment() {
    log_message "Checking IBM ACE environment..."
    
    # Check for essential commands
    local missing_commands=0
    
    # Check mqsilist command
    if ! command_exists mqsilist; then
        log_message "!! Warning: mqsilist command not found"
        missing_commands=$((missing_commands + 1))
    fi
    
    # Check runmqsc command
    if ! command_exists runmqsc; then
        log_message "!! Warning: runmqsc command not found"
        missing_commands=$((missing_commands + 1))
    fi
    
    if [ $missing_commands -gt 0 ]; then
        log_message "\n!! IMPORTANT: Some essential IBM ACE commands are not available."
        log_message "This usually means the IBM ACE environment is not set up in your current shell."
        log_message "Before running this script, you should source the mqsiprofile:"
        log_message ""
        log_message "  . /opt/ibm/ace-11/server/bin/mqsiprofile"
        log_message "  or"
        log_message "  . <ACE_INSTALL_DIR>/server/bin/mqsiprofile"
        log_message ""
        log_message "Then try running this script again."
        log_message "Continuing with limited functionality...\n"
        return 1
    fi
    
    log_message "IBM ACE environment appears to be properly set up."
    return 0
}

# Start transcript logging
start_transcript

# Check IBM ACE environment
check_ace_environment

# Display warning if no arguments provided
if [ -z "$NODE_NAME" ] && [ -z "$QUEUE_MANAGER" ] && [ -z "$ADMIN_URL" ] && [ -z "$USER" ] && [ -z "$PASS" ] && [ -z "$CUSTOM_API" ]; then
    log_message "!! Warning: No arguments provided."
    log_message ""
    log_message "Basic Usage (choose at least one):"
    log_message "  $0 -n iNode1              # Collect data for a specific integration node"
    log_message "  $0 -q QM1                 # Collect data for a specific queue manager"
    log_message ""
    log_message "API Verification (with or without authentication):"
    log_message "  $0 -n iNode1 -q QM1 -a http://acehost:4414"
    log_message "  $0 -n iNode1 -q QM1 -a http://acehost:4414 -u adminUser -p myStrongPass"
    log_message ""
    log_message "For IIB10 users (using custom API version):"
    log_message "  $0 -n iNode1 -q QM1 -a http://acehost:4414 -c apiv1"
fi

# Function to execute a command and log its output
exec_and_log() {
    local cmd="$@"
    local output
    
    # Execute the command and capture its output
    output=$(eval "$cmd" 2>&1)
    
    # Log each line of the output
    echo "$output" | while read -r line; do
        log_message "$line"
    done
    
    # Return the exit status of the original command
    return ${PIPESTATUS[0]}
}

# Function to execute a command and capture its output (using eval like exec_and_log)
exec_and_capture() {
    local cmd="$@"
    # Use eval to execute in current shell context, just like exec_and_log does
    eval "$cmd" 2>&1
}

# 1. mqsilist summary + running integration server
show_section "mqsilist Summary"
if command_exists mqsilist; then
    exec_and_log "mqsilist"
else
    log_message "Error: mqsilist command not found. Ensure IBM ACE is installed and in your PATH."
fi

show_section "Running Integration Servers on $NODE_NAME"
if [ -n "$NODE_NAME" ] && command_exists mqsilist; then
    exec_and_log mqsilist $NODE_NAME
else
    log_message "Skipping integration server check. Either NODE_NAME not provided or mqsilist not available."
fi

# Resource & flow stats

show_section "Resource and Flow Stats"

# Use exec_and_capture to get the output - same approach as exec_and_log
MQSI_OUTPUT=$(exec_and_capture "mqsilist ${NODE_NAME}")

# Extract server names from the output
SERVERS=$(echo "$MQSI_OUTPUT" | grep "Integration server" | awk -F"'" '{print $2}')

if [ -z "$SERVERS" ]; then
    log_message "No Integration Servers found for node ${NODE_NAME}."
    exit 1
fi

log_message ""

for SERVER in $SERVERS; do
    log_message ""
    log_message "------------------------------------------------------"
    log_message " Server: $SERVER"
    log_message "------------------------------------------------------"

    log_message "[Resource Stats]"
    exec_and_log "mqsireportresourcestats ${NODE_NAME} -e ${SERVER}"

    log_message ""
    log_message "[Flow Stats]"
    exec_and_log "mqsireportflowstats ${NODE_NAME} -s -e ${SERVER}"

    log_message ""
done

# 2. Check group membership
show_section "Group Membership (mqm & mqbrkrs)"
if command_exists id; then
    exec_and_log id
    
    # Additional group information
    log_message "\nGroup membership details:"
    log_message "mqm group members:"
    exec_and_log "lsgroup -a users mqm 2>/dev/null || echo mqm group not found"
    
    log_message "mqbrkrs group members:"
    exec_and_log "lsgroup -a users mqbrkrs 2>/dev/null || echo mqbrkrs group not found"
else
    log_message "id command not available. Cannot check group membership."
fi

# 4. MQSC collection (if QUEUE_MANAGER is provided)
show_section "MQSC Collection"

# Check if NODE_NAME or QUEUE_MANAGER is provided
if [ -z "$NODE_NAME" ] && [ -z "$QUEUE_MANAGER" ]; then
    log_message "!! No node name or queue manager name provided."
    log_message "Please specify at least one of these parameters to examine specific components:"
    log_message "  -n NODE_NAME: To examine a specific integration node"
    log_message "  -q QUEUE_MANAGER: To examine a specific queue manager"
    log_message "Example: $0 -n YourNodeName -q YourQMName"
    
    # Skip MQSC collection if no parameters provided
    log_message "\nSkipping MQSC collection. Please provide QUEUE_MANAGER parameter."
elif [ -n "$QUEUE_MANAGER" ]; then
    # Use the QUEUE_MANAGER parameter directly
    log_message "Using specified queue manager: $QUEUE_MANAGER"
    log_message "\n------------------------------------------------------------"
    log_message " Queue Manager: $QUEUE_MANAGER"
    log_message "------------------------------------------------------------"
    
    # MQSC collection: listeners, channel auth & status
    show_section "MQSC: Listeners for $QUEUE_MANAGER"
    run_mq_command_and_log "$QUEUE_MANAGER" "DISPLAY LISTENER(*) ALL"

    show_section "MQSC: Listener Status for $QUEUE_MANAGER"
    run_mq_command_and_log "$QUEUE_MANAGER" "DISPLAY LSSTATUS(*) ALL"

    show_section "MQSC: Check connection authentication for $QUEUE_MANAGER"
    run_mq_command_and_log "$QUEUE_MANAGER" "dis qmgr connauth"

    show_section "MQSC: Channel Authentication for $QUEUE_MANAGER"
    run_mq_command_and_log "$QUEUE_MANAGER" "dis qmgr chlauth"

    show_section "MQSC: Channel Status for $QUEUE_MANAGER"
    run_mq_command_and_log "$QUEUE_MANAGER" "DISPLAY CHSTATUS(*)"
else
    log_message "Skipping MQSC collection. Please provide QUEUE_MANAGER parameter to collect MQSC information."
    log_message "Example: $0 -q YourQMName"
fi

# 6. TCP Ports used by ACE/MQ Processes
show_section "TCP Ports for runmqlsr, bipMQTT, bipbroker"

# Save the current output to a temporary file
tcp_output_file="$OUT_DIR/tcp_ports.txt"

# AIX-specific network commands
if command_exists netstat; then
    # Using enhanced AIX-specific port detection
    {
        # Set environment for consistent output
        PATH=/usr/bin:/bin:/usr/sbin
        export LANG=C
        
        TARGETS="runmqlsr|bipMQTT|bipbroker"
        
        emit_family() {
            fam=$1   # inet or inet6
            # AIX netstat -Aan columns: PCB proto Recv-Q Send-Q LocalAddr ForeignAddr State
            netstat -Aan -f $fam 2>/dev/null | awk '$NF=="LISTEN"{print $1,$5}' | \
            while read -r sock laddr
            do
                # laddr is like "*.22" / "127.0.0.1.8080" / "::1.11883"
                port=${laddr##*.}
                addr=${laddr%.*}
                if [ "$addr" = "*" ]; then
                    [ "$fam" = "inet6" ] && addr="::" || addr="0.0.0.0"
                fi
                
                # Who owns this TCP control block? (safe: reports for live sockets)
                info=$(/usr/sbin/rmsock "$sock" tcpcb 2>/dev/null)
                
                # Match both "process" and historical "proccess"
                pid=$(printf "%s\n" "$info"   | sed -n 's/.*held by proc[rc]*ess \([0-9][0-9]*\).*/\1/p' | head -1)
                pname=$(printf "%s\n" "$info" | sed -n 's/.*held by proc[rc]*ess [0-9][0-9]* (\([^)]*\)).*/\1/p' | head -1)
                
                # Filter only the requested processes
                case "$pname" in
                    runmqlsr|bipMQTT|bipbroker)
                        [ -n "$pid" ] && echo "$pname|$pid|$port|$addr"
                        ;;
                esac
            done
        }
        
        # Collect IPv4 + IPv6, remove duplicates, then pretty-print
        {
            emit_family inet
            emit_family inet6
        } | sort -u | \
        awk -F'|' '
        BEGIN {
            # Pretty, fixed-width columns
            fmt="%-20s %-10s %-12s %-39s\n"
            printf fmt, "Process Name", "PID", "Local Port", "Local Address"
            printf fmt, "--------------------", "----------", "------------", "---------------------------------------"
        }
        {
            printf fmt, $1, $2, $3, $4
        }'
    } > "$tcp_output_file" 2>/dev/null
    
    # Display the results and log them
    if [ -s "$tcp_output_file" ]; then
        # Read the file line by line and log each line
        while read -r line; do
            log_message "$line"
        done < "$tcp_output_file"
        log_message "\nTCP port information saved to: $tcp_output_file"
    else
        log_message "No IBM ACE-related listening ports found."
    fi
else
    log_message "netstat command not available. Cannot check TCP ports."
fi

# 7. Resource & flow stats
show_section "Resource and Flow Stats"

# Check if NODE_NAME is provided
if [ -z "$NODE_NAME" ] && [ -z "$QUEUE_MANAGER" ]; then
    log_message "Skipping resource and flow stats. Please provide NODE_NAME parameter."
    log_message "Example: $0 -n YourNodeName"
elif [ -n "$NODE_NAME" ]; then
    # If NODE_NAME is provided, collect stats for that specific node
    log_message "======================================================"
    log_message " IBM ACE/IIB Node Resource and Flow Statistics Report "
    log_message " Node: ${NODE_NAME}"
    log_message "======================================================"
    log_message ""
    
    # Get server names directly using the command - exactly as in getResourseAndFlowStats.sh
    log_message "Fetching Integration Servers for node '${NODE_NAME}'..."
    
    # Use exec_and_capture (which uses eval) to get the output - same approach as exec_and_log
    # This matches the exact command from getResourseAndFlowStats.sh line 25
    MQSI_OUTPUT=$(exec_and_capture "mqsilist ${NODE_NAME}")
    
    # Extract server names from the output
    SERVERS=$(echo "$MQSI_OUTPUT" | grep "Integration server" | awk -F"'" '{print $2}')
    
    # Check if any servers were found
    if [ -n "$SERVERS" ]; then
        log_message ""
        log_message "Found Integration Servers:"
        log_message "--------------------------"
        for SERVER in $SERVERS; do
            log_message " - $SERVER"
        done
        
        log_message ""
        log_message "======================================================"
        log_message " Gathering Resource and Flow Stats for each server... "
        log_message "======================================================"
        
        # Process each server using a for loop - exactly as in getResourseAndFlowStats.sh
        for SERVER in $SERVERS; do
            log_message ""
            log_message "------------------------------------------------------"
            log_message " Server: $SERVER"
            log_message "------------------------------------------------------"
            
            log_message "[Resource Stats]"
            exec_and_log "mqsireportresourcestats ${NODE_NAME} -e ${SERVER}"
            
            log_message ""
            log_message "[Flow Stats]"
            exec_and_log "mqsireportflowstats ${NODE_NAME} -s -e ${SERVER}"
            
            log_message ""
        done
        
        log_message "======================================================"
        log_message " All Resource and Flow Stats retrieved successfully.  "
        log_message "======================================================"
    else
        log_message "!! No servers found for node: ${NODE_NAME}"
        log_message "This could be because:"
        log_message "1. The node name is incorrect"
        log_message "2. The integration node is not running"
        log_message "3. The IBM ACE environment is not properly set up"
        log_message "\nPlease verify that the node name is correct and that it has integration servers."
        log_message "Also ensure the IBM ACE environment is properly set up before running this script."
    fi
else
    log_message "Skipping resource and flow stats. NODE_NAME parameter is required for this section."
    log_message "Example: $0 -n YourNodeName"
fi

# 8. Integration Node overrides
show_section "Integration Node Overrides"

# Check if either NODE_NAME or QUEUE_MANAGER is provided
if [ -z "$NODE_NAME" ] && [ -z "$QUEUE_MANAGER" ]; then
    log_message "Skipping integration node overrides. Please provide NODE_NAME parameter."
    log_message "Example: $0 -n YourNodeName"
elif [ -z "$NODE_NAME" ]; then
    log_message "NODE_NAME parameter is required to examine integration node overrides."
    log_message "Example: $0 -n YourNodeName"
else
    log_message "Examining specified integration node: $NODE_NAME"
    
    # Function to check a specific path for node overrides
    check_node_path() {
        local node_path="$1"
        
        log_message "Checking path: $node_path"
        if [ -d "$node_path" ]; then
            log_message "Found node directory: $node_path"
            
            # Check for node overrides file
            node_overrides_path="$node_path/overrides/node.conf.yaml"
            log_message "Looking for override file: $node_overrides_path"
            
            # Check if overrides directory exists
            if [ -d "$node_path/overrides" ]; then
                log_message "Overrides directory exists"
            else
                log_message "Overrides directory does not exist"
            fi
            
            # Check file existence and permissions
            if [ -f "$node_overrides_path" ]; then
                found_override=true
                log_message "Node overrides file exists: $node_overrides_path"
                
                # Check file permissions
                ls -l "$node_overrides_path" >> "$LOG_FILE" 2>&1
                
                log_message "Contents of node overrides file:"
                log_message "----------------------------------------"
                # Read the file and log each line
                if [ -r "$node_overrides_path" ]; then
                    while read -r line; do
                        log_message "$line"
                    done < "$node_overrides_path"
                    log_message "----------------------------------------"
                else
                    log_message "Error: Cannot read file. Check permissions."
                    log_message "----------------------------------------"
                fi
                
                # Copy the file to output directory
                cp "$node_overrides_path" "$OUT_DIR/node.conf.yaml" 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_message "Copied node.conf.yaml to $OUT_DIR/"
                else
                    log_message "Failed to copy node.conf.yaml. Check permissions."
                fi
            else
                log_message "Override file not found at this location"
            fi
        else
            log_message "Directory not found: $node_path"
        fi
    }
    
    # Check common locations for node overrides on AIX
    found_override=false
    
    # Check each path individually
    check_node_path "/var/mqsi/components/$NODE_NAME"
    check_node_path "/var/mqsi/nodes/$NODE_NAME"
    check_node_path "$HOME/IBM/MQSI/components/$NODE_NAME"
    check_node_path "/usr/IBM/MQSI/components/$NODE_NAME"
    
    if [ "$found_override" = false ]; then
        log_message "No node.conf.yaml found for this node in standard locations"
    fi
fi

# ACE credentials Test
show_section "ACE credentials Test"

if [ -z "$ADMIN_URL" ]; then
    log_message "Skipping ACE credentials Test. Please provide ADMIN_URL parameter."
    log_message "Example: $0 -a http://aceHost:port"
else
    log_message "Performing ACE credentials tests..."
    
    # Set up variables for the test
    ADDRESS="$ADMIN_URL"
    API="apiv2"
    if [ -n "$CUSTOM_API" ]; then
        API="$CUSTOM_API"
    fi
    USERNAME="$USER"
    PASSWORD="$PASS"
    NO_VERIFY=false
    CA_BUNDLE=""
    TIMEOUT=10
    DEBUG=false
    
    # Ensure API has no surrounding slashes
    API="${API#/}"
    API="${API%/}"
    
    # Export environment variables for Python
    export ADDRESS API USERNAME PASSWORD NO_VERIFY CA_BUNDLE TIMEOUT DEBUG OUT_DIR
    
    # Run the embedded Python script
    log_message "Running API test..."
    
    python3 - <<'PY_SCRIPT' 2>&1 | while read -r line; do log_message "$line"; done
# Embedded Python block: reads config from environment
import os, sys, time

address = os.environ.get("ADDRESS")
api = os.environ.get("API", "apiv2").strip("/")
username = os.environ.get("USERNAME", "") or None
password = os.environ.get("PASSWORD", "") or None
no_verify = os.environ.get("NO_VERIFY", "False")
ca_bundle = os.environ.get("CA_BUNDLE", "") or None
timeout = float(os.environ.get("TIMEOUT", "10"))
debug = os.environ.get("DEBUG", "False")

from urllib.parse import urlsplit, urlunsplit

def has_scheme(addr):
    la = addr.lower()
    return la.startswith("http://") or la.startswith("https://")

def build_url_with_scheme(addr, scheme):
    if has_scheme(addr):
        base = addr.rstrip('/')
        return f"{base}/{api}"
    else:
        return f"{scheme}://{addr.rstrip('/')}/{api}"

def verify_param():
    if ca_bundle:
        return ca_bundle
    if str(no_verify).lower() in ("1","true","yes"):
        return False
    return True

def print_masked_auth(user, pwd):
    import base64
    if not user:
        print("[DEBUG] No username provided")
        return
    s = f"{user}:{pwd or ''}".encode("utf-8")
    b64 = base64.b64encode(s).decode("ascii")
    print("[DEBUG] Authorization: Basic {}…(masked)".format(b64[:12]))

attempts = []
if has_scheme(address):
    if address.lower().startswith("https://"):
        attempts = ["https"]
    else:
        attempts = ["http"]
else:
    attempts = ["https", "http"]

use_requests = False
try:
    import requests
    use_requests = True
except Exception:
    use_requests = False

last_exc = None

for scheme in attempts:
    url = build_url_with_scheme(address, scheme)
    try:
        if use_requests:
            verify = verify_param()
            auth = (username, password) if username else None
            if debug.lower() in ("1","true","yes"):
                print("[DEBUG] Using requests. URL:", url)
                if username:
                    print_masked_auth(username, password)
            resp = requests.get(url, auth=auth, headers={"Accept":"application/json"}, timeout=timeout, verify=verify)
            print("URL:", url)
            print("Status:", resp.status_code, resp.reason)
            print("Response headers:")
            for k,v in resp.headers.items():
                print(f"{k}: {v}")
            print("\nResponse body:")
            ct = resp.headers.get("Content-Type","")
            if "application/json" in ct.lower():
                try:
                    import json
                    json_response = resp.json()
                    print(json.dumps(json_response, indent=2))
                    # Save response to file
                    with open(os.environ.get("OUT_DIR", ".") + "/ace_api_response.json", "w") as f:
                        json.dump(json_response, f, indent=2)
                    print("\nResponse saved to: " + os.environ.get("OUT_DIR", ".") + "/ace_api_response.json")
                except Exception:
                    print(resp.text)
            else:
                print(resp.text)
            sys.exit(0)
        else:
            import http.client, ssl, base64, socket, json
            from urllib.parse import urlsplit

            parts = urlsplit(url)
            host = parts.hostname
            port = parts.port or (443 if parts.scheme == "https" else 80)
            path = parts.path or "/"
            if parts.query:
                path += "?" + parts.query

            headers = {"Accept": "application/json"}
            if username:
                cred = f"{username}:{password or ''}".encode("utf-8")
                headers["Authorization"] = "Basic " + base64.b64encode(cred).decode("ascii")
                if debug.lower() in ("1","true","yes"):
                    print("[DEBUG] Using stdlib http.client. URL:", url)
                    print_mask = base64.b64encode(cred).decode("ascii")[:12]
                    print(f"[DEBUG] Authorization: Basic {print_mask}…(masked)")

            if parts.scheme == "https":
                if ca_bundle:
                    ctx = ssl.create_default_context(cafile=ca_bundle)
                elif str(no_verify).lower() in ("1","true","yes"):
                    ctx = ssl._create_unverified_context()
                else:
                    ctx = ssl.create_default_context()
                conn = http.client.HTTPSConnection(host, port=port, timeout=timeout, context=ctx)
            else:
                conn = http.client.HTTPConnection(host, port=port, timeout=timeout)

            try:
                conn.request("GET", path, headers=headers)
                resp = conn.getresponse()
                body = resp.read()
                print("URL:", url)
                print("Status:", resp.status, resp.reason)
                print("Response headers:")
                for k,v in resp.getheaders():
                    print(f"{k}: {v}")
                print("\nResponse body:")
                try:
                    text = body.decode()
                    try:
                        parsed = json.loads(text)
                        print(json.dumps(parsed, indent=2))
                        # Save response to file
                        with open(os.environ.get("OUT_DIR", ".") + "/ace_api_response.json", "w") as f:
                            json.dump(parsed, f, indent=2)
                        print("\nResponse saved to: " + os.environ.get("OUT_DIR", ".") + "/ace_api_response.json")
                    except Exception:
                        print(text)
                except Exception:
                    sys.stdout.buffer.write(body)
                sys.exit(0)
            finally:
                try:
                    conn.close()
                except Exception:
                    pass

    except Exception as e:
        last_exc = e
        if has_scheme(address):
            print(f"[ERROR] Request to {url} failed: {e}", file=sys.stderr)
            sys.exit(2)
        else:
            print(f"[WARN] attempt {scheme} -> {url} failed: {e}", file=sys.stderr)
            time.sleep(0.15)

print("[ERROR] All attempts failed. Last exception:", last_exc, file=sys.stderr)
sys.exit(3)
PY_SCRIPT
    
    # Save the Python script output to a file
    python_status=$?
    if [ $python_status -ne 0 ]; then
        log_message "API test failed with status: $python_status"
        
        # If Python fails, try curl as a fallback
        if command_exists curl; then
            log_message "Falling back to curl-based testing..."
            
            # Determine if we're using HTTP or HTTPS
            if echo "$ADMIN_URL" | grep -q "^https://"; then
                USE_HTTPS=true
            else
                USE_HTTPS=false
            fi
            
            # Create full URL
            FULL_URL="$ADMIN_URL/$API"
            
            # Test 1: Without credentials
            log_message "\n### Testing without credentials"
            if [ "$USE_HTTPS" = true ]; then
                log_message "Command: curl -k --header \"Accept: application/json\" \"$FULL_URL\""
                response=$(curl -k -s --header "Accept: application/json" "$FULL_URL")
                status_code=$?
            else
                log_message "Command: curl --header \"Accept: application/json\" \"$FULL_URL\""
                response=$(curl -s --header "Accept: application/json" "$FULL_URL")
                status_code=$?
            fi
            
            if [ $status_code -eq 0 ]; then
                # Check if response contains valid JSON
                if echo "$response" | grep -q "{"; then
                    log_message "Result: SUCCESS - ACE credentials are not required"
                    log_message "Response preview:"
                    echo "$response" | head -20 | while read line; do
                        log_message "$line"
                    done
                else
                    log_message "Result: FAILED - Response doesn't appear to be valid JSON"
                    log_message "Response preview:"
                    echo "$response" | head -5 | while read line; do
                        log_message "$line"
                    done
                fi
            else
                log_message "Result: FAILED - curl command failed with status $status_code"
            fi
            
            # Test 2: With credentials (if provided)
            if [ -n "$USER" ]; then
                log_message "\n### Testing with credentials"
                if [ "$USE_HTTPS" = true ]; then
                    log_message "Command: curl -k -u $USER --header \"Accept: application/json\" \"$FULL_URL\""
                    if [ -n "$PASS" ]; then
                        response=$(curl -k -s -u "$USER:$PASS" --header "Accept: application/json" "$FULL_URL")
                    else
                        log_message "Password will be prompted..."
                        response=$(curl -k -s -u "$USER" --header "Accept: application/json" "$FULL_URL")
                    fi
                    status_code=$?
                else
                    log_message "Command: curl -u $USER --header \"Accept: application/json\" \"$FULL_URL\""
                    if [ -n "$PASS" ]; then
                        response=$(curl -s -u "$USER:$PASS" --header "Accept: application/json" "$FULL_URL")
                    else
                        log_message "Password will be prompted..."
                        response=$(curl -s -u "$USER" --header "Accept: application/json" "$FULL_URL")
                    fi
                    status_code=$?
                fi
                
                if [ $status_code -eq 0 ]; then
                    # Check if response contains valid JSON
                    if echo "$response" | grep -q "{"; then
                        log_message "Result: SUCCESS - Authentication successful"
                        log_message "Response preview:"
                        echo "$response" | head -20 | while read line; do
                            log_message "$line"
                        done
                    else
                        log_message "Result: FAILED - Response doesn't appear to be valid JSON"
                        log_message "Response preview:"
                        echo "$response" | head -5 | while read line; do
                            log_message "$line"
                        done
                    fi
                else
                    log_message "Result: FAILED - curl command failed with status $status_code"
                fi
            else
                log_message "\n### Skipping credential test - no username provided"
                log_message "To test with credentials, run the script with -u and -p parameters"
            fi
            
            # Save full responses to output directory
            if [ -n "$response" ]; then
                log_message "\nSaving full API responses to output directory..."
                echo "$response" > "$OUT_DIR/ace_api_response.json"
                log_message "Full response saved to: $OUT_DIR/ace_api_response.json"
            fi
        else
            log_message "Error: Neither Python nor curl is available. Cannot test ACE credentials."
        fi
    else
        log_message "API test completed successfully."
    fi
fi

# Detailed process information
show_section "All running process details"

# Get detailed process information and save to file
ps_output_file="$OUT_DIR/processes.txt"
if command_exists ps; then
    log_message "Collecting detailed process information..."
    
    # Execute ps command and save output to file
    ps -ef | grep -E 'runmq|bip|mqsi|ace' > "$ps_output_file"
    
    # Log the process information
    log_message "\nProcess details:"
    while read -r line; do
        log_message "$line"
    done < "$ps_output_file"
    
    log_message "\nProcess information saved to: $ps_output_file"
    
    # Count processes by type and log the counts
    log_message "\nProcess count by type:"
    log_message "----------------------"
    
    # Count processes directly without using exec_and_log
    runmq_count=$(grep -c "runmq" "$ps_output_file" 2>/dev/null || echo 0)
    bip_count=$(grep -c "bip" "$ps_output_file" 2>/dev/null || echo 0)
    mqsi_count=$(grep -c "mqsi" "$ps_output_file" 2>/dev/null || echo 0)
    ace_count=$(grep -c "ace" "$ps_output_file" 2>/dev/null || echo 0)
    
    log_message "MQ processes: $runmq_count"
    log_message "Integration Bus processes: $bip_count"
    log_message "MQSI processes: $mqsi_count"
    log_message "ACE processes: $ace_count"
else
    log_message "ps command not available. Cannot collect process information."
fi

# Collect system information
show_section "System Information"
system_info_file="$OUT_DIR/system_info.txt"

# Create the system info file
{
    echo "Operating System:"
    uname -a
    echo "\nAIX Version:"
    oslevel -s 2>/dev/null
    echo "\nCPU Information:"
    lsdev -C | grep proc
    echo "\nMemory Information:"
    lsattr -El sys0 -a realmem
    echo "\nDisk Usage:"
    df -g
} > "$system_info_file"

# Log the system information
log_message "System information:"
while read -r line; do
    log_message "$line"
done < "$system_info_file"

log_message "\nSystem information saved to: $system_info_file"

log_message "\n== ACE Must-Gather Completed: $(date) =="
log_message "\nResults in: $OUT_DIR"
