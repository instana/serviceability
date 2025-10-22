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
3. Run the script with appropriate parameters:

   ```bash
   # Examine only the specified integration node
   ./instana-ace-mustgather.sh -n iNode1
   
   # Examine only the specified queue manager
   ./instana-ace-mustgather.sh -q QM1
   
   # Examine node and queue manager, and verify ACE credentials (without username/password)
   ./instana-ace-mustgather.sh -n iNode1 -q QM1 -a http://acehost:4414
   
   # Examine node and queue manager, and verify ACE credentials (with username/password)
   ./instana-ace-mustgather.sh -n iNode1 -q QM1 -a http://acehost:4414 -u adminUser -p myStrongPass
   
   # Examine node and queue manager, and verify ACE credentials with username/password on a custom API (e.g., apiv1 for IIB10)
   ./instana-ace-mustgather.sh -n iNode1 -q QM1 -a http://acehost:4414 -u adminUser -p myStrongPass -c apiv1
   ```

### AIX

1. Copy the script to the environment where IBM ACE is running on AIX
2. Make the script executable:
   
   ```bash
   chmod +x instana-ace-mustgather-aix.sh
   ```
3. Run the script with appropriate parameters:

   ```bash
   # Examine only the specified integration node
   ./instana-ace-mustgather-aix.sh -n iNode1
   
   # Examine only the specified queue manager
   ./instana-ace-mustgather-aix.sh -q QM1
   
   # Examine node and queue manager, and verify ACE credentials (without username/password)
   ./instana-ace-mustgather-aix.sh -n iNode1 -q QM1 -a http://acehost:4414
   
   # Examine node and queue manager, and verify ACE credentials (with username/password)
   ./instana-ace-mustgather-aix.sh -n iNode1 -q QM1 -a http://acehost:4414 -u adminUser -p myStrongPass
   
   # Examine node and queue manager, and verify ACE credentials with username/password on a custom API (e.g., apiv1 for IIB10)
   ./instana-ace-mustgather-aix.sh -n iNode1 -q QM1 -a http://acehost:4414 -u adminUser -p myStrongPass -c apiv1
   ```

### Windows

1. Copy the script to the environment where IBM ACE is running
2. Open the IBM ACE Command Console (integrated environment)
3. Run the script:

   ```powershell
   # Examine only the specified integration node
   powershell .\instana-ace-mustgather.ps1 -NodeName iNode1

   # Examine only the specified queue manager
   powershell .\instana-ace-mustgather.ps1 -QueueManager QM1

   # Examine node and queue manager, and verify ACE credentials (without username/password)
   powershell .\instana-ace-mustgather.ps1 -NodeName iNode1 -QueueManager QM1 -AdminURL http://acewindows21:4415

   # Examine node and queue manager, and verify ACE credentials (with username/password)
   powershell .\instana-ace-mustgather.ps1 -NodeName iNode1 -QueueManager QM1 -AdminURL http://acewindows21:4415 -User adminUser -Pass myStrongPass
   
   # Examine node and queue manager, and verify ACE credentials with username/password on a custom API (e.g., apiv1 for IIB10)
   powershell .\instana-ace-mustgather.ps1 -NodeName iNode1 -QueueManager QM1 -AdminURL http://acewindows21:4415 -User adminUser -Pass myStrongPass -CustomApi apiv1
   ```

   **If you encounter any kind of problem while running the above command**, try using these commands(inside ibm ace console):
   
      ```powershell
   # Examine only the specified integration node
   powershell -ExecutionPolicy Bypass -File instana-ace-mustgather.ps1 -NodeName iNode1

   # Examine only the specified queue manager
   powershell -ExecutionPolicy Bypass -File instana-ace-mustgather.ps1 -QueueManager QM1

   # Examine node and queue manager, and verify ACE credentials (without username/password)
   powershell -ExecutionPolicy Bypass -File instana-ace-mustgather.ps1 -NodeName iNode1 -QueueManager QM1 -AdminURL http://acewindows21:4415

   # Examine node and queue manager, and verify ACE credentials (with username/password)
   powershell -ExecutionPolicy Bypass -File instana-ace-mustgather.ps1 -NodeName iNode1 -QueueManager QM1 -AdminURL http://acewindows21:4415 -User adminUser -Pass myStrongPass
   
   # Examine node and queue manager, and verify ACE credentials with username/password on a custom API (e.g., apiv1 for IIB10)
   powershell -ExecutionPolicy Bypass -File instana-ace-mustgather.ps1 -NodeName iNode1 -QueueManager QM1 -AdminURL http://acewindows21:4415 -User adminUser -Pass myStrongPass -CustomApi apiv1
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

The Linux script automatically creates a directory named `ace_mustgather_YYYYMMDD_HHMMSS` containing:

- `gather.log`: Complete transcript of all collected information that can be shared with support teams
- `processes.txt`: Detailed information about running ACE/MQ processes
- `system_info.txt`: System information including OS, CPU, memory, and disk usage
- `ace_api_response.json`: API response from ACE credentials test (if performed)
- The log file includes organized sections for:
  - mqsilist summary
  - Running integration servers
  - Group memberships
  - MQSC command outputs
  - TCP port usage
  - Resource and flow statistics
  - Integration node overrides
  - ACE credentials test
  - Process information

The location of the output directory is displayed at the end of script execution:
```
Results in: ace_mustgather_YYYYMMDD_HHMMSS
```

### AIX Output

The AIX script automatically creates a directory named `ace_mustgather_YYYYMMDD_HHMMSS` containing:

- `gather.log`: Complete transcript of all collected information that can be shared with support teams
- `processes.txt`: Detailed information about running ACE/MQ processes
- `system_info.txt`: System information including OS version, CPU, memory, and disk usage
- `tcp_ports.txt`: Information about TCP ports used by ACE/MQ processes
- `node.conf.yaml`: Configuration overrides for the integration node (if found)
- `ace_api_response.json`: API response from ACE credentials test (if performed)
- The log file includes organized sections for:
  - mqsilist summary
  - Running integration servers
  - Resource and flow statistics
  - Group memberships (mqm & mqbrkrs)
  - MQSC command outputs
  - TCP port usage
  - Integration node overrides
  - ACE credentials test
  - Process information

The location of the output directory is displayed at the end of script execution:
```
Results in: ace_mustgather_YYYYMMDD_HHMMSS
```

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
  - node.conf.yaml file
  - ACE rest api credentials test
  - All running process list

The location of the output directory is displayed at the end of script execution:
```
Results in: ace_mustgather_YYYYMMDD_HHMMSS
```

## Options

### Linux Script Options

- `-n NODE_NAME`: Integration node name
- `-q QUEUE_MANAGER`: Queue manager name
- `-a ADMIN_URL`: Administration URI (e.g., http://acehost:4414)
- `-u USER`: Username for authentication (optional)
- `-p PASS`: Password for authentication (optional)
- `-c CUSTOM_API`: API version (e.g., apiv1 for IIB10, default is apiv2)
- `-h`: Display help message

### AIX Script Options

- `-n NODE_NAME`: Integration node name
- `-q QUEUE_MANAGER`: Queue manager name
- `-a ADMIN_URL`: Administration URI (e.g., http://acehost:4414)
- `-u USER`: Username for authentication (optional)
- `-p PASS`: Password for authentication (optional)
- `-c CUSTOM_API`: API version (e.g., apiv1 for IIB10, default is apiv2)
- `-h`: Display help message

## Additional Notes

- The scripts automatically detect whether IBM ACE is using MQ or MQTT for messaging
- For MQ environments, the scripts check channel authentication settings which are critical for Instana monitoring
- The Windows script must be run in the IBM ACE Command Console to ensure the proper environment is loaded
- The AIX script uses Korn shell (ksh) and includes AIX-specific commands for system information collection
- The AIX script includes both Python-based and curl-based API testing methods for maximum compatibility
- All scripts generate output that can be easily shared with Instana support teams by providing the automatically generated output directory containing log files and diagnostic information