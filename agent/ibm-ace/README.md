# IBM ACE Must Gather Scripts

## Overview

The IBM ACE Must Gather scripts collect diagnostic data from IBM App Connect Enterprise (ACE) environments. These scripts help troubleshoot Instana monitoring of ACE by gathering configuration details, integration node information, queue manager settings, and other relevant data for analysis.

## Usage

### Linux

1. Copy the script to the environment where IBM ACE is running
2. Make the script executable:
   
   ```bash
   chmod +x instana-ace-mustgather.sh
   ```
3. Run the script in one of the following modes:

   **Interactive mode** (discovers and analyzes all integration nodes):
   ```bash
   ./instana-ace-mustgather.sh
   ```

   **Simple command-line mode** (specify ACE installation path):
   ```bash
   ./instana-ace-mustgather.sh -p /path/to/ace/installation [-m /path/to/mq/bin]
   ```

   **Advanced command-line mode** (specify connection details for a specific integration node):
   ```bash
   ./instana-ace-mustgather.sh -h ACE_HOST -a API_PORT -b INTEGRATION_NODE [-u USERNAME] [-q QM_NAME] [-r PROTOCOL] [-v API_VERSION] [-m MQ_PATH]
   ```

### Windows

1. Copy the script to the environment where IBM ACE is running
2. Open the IBM ACE Command Console (integrated environment)
3. Run the script:

   ```powershell
   .\instana-ace-mustgather.ps1
   ```

## Script Output

The scripts collect the following information:

- Integration node definitions and status
- Integration server details
- Queue manager configurations (if MQ is used)
- Channel authentication rules
- Listener configurations and status
- TCP ports used by ACE/MQ processes
- Resource and flow statistics
- User permissions and group memberships
- TLS configuration details (if enabled)

### Linux Output

The Linux script provides detailed output directly to the console, organized by sections:

- ACE credentials testing
- TLS encryption information
- MQ or MQTT usage determination
- Port configurations
- Channel authentication settings (for MQ)

To generate a log file that can be shared with support teams, redirect the output to a file:

```bash
# Example with specific ACE and MQ paths
./instana-ace-mustgather.sh -p /opt/IBM/ace-13.0.3.1 -m /opt/mqm/bin > ace_mustgather.log 2>&1

# Example in interactive mode
./instana-ace-mustgather.sh > ace_mustgather.log 2>&1
```

> **Note about redirection syntax:**
> - `>` redirects standard output to the specified file
> - `2>&1` redirects standard error to the same destination as standard output
> - Together, this ensures that both normal output and error messages are captured in the log file

### Windows Output

The Windows script automatically creates a directory named `ace_mustgather_YYYYMMDD_HHMMSS` containing:

- `gather.log`: Complete transcript of all collected information that can be shared with support teams
- The log file includes organized sections for:
  - mqsilist summary
  - Running integration servers
  - Group memberships
  - Node to Queue Manager mapping
  - MQSC command outputs
  - TCP port usage
  - Resource and flow statistics
  - Service logon rights

The location of the output directory is displayed at the end of script execution:
```
Results in: ace_mustgather_YYYYMMDD_HHMMSS
```

## Options

### Linux Script Options

- `-p ACE_PATH`: Path to the IBM ACE installation folder
- `-m MQ_PATH`: Path to the IBM MQ bin directory containing runmqsc
- `-h ACE_HOST`: ACE host name or IP address
- `-a API_PORT`: Integration node API port
- `-b INTEGRATION_NODE`: Integration node name
- `-u USERNAME`: Username for authentication (optional)
- `-q QM_NAME`: Queue Manager name (if MQ is used, optional)
- `-r PROTOCOL`: Protocol (http or https, default: http)
- `-v API_VERSION`: API version (apiv1 for IIB10, apiv2 for ACE11 or later)
- `-i`: Force interactive mode

## Additional Notes

- The scripts automatically detect whether IBM ACE is using MQ or MQTT for messaging
- For MQ environments, the scripts check channel authentication settings which are critical for Instana monitoring
- The Linux script can run in interactive mode to discover all integration nodes or in command-line mode for specific diagnostics
- The Windows script must be run in the IBM ACE Command Console to ensure the proper environment is loaded
- Both scripts generate output that can be easily shared with Instana support teams:
  - For Linux: Redirect output to a file using `> filename.log 2>&1`
  - For Windows: Share the automatically generated `gather.log` file from the output directory