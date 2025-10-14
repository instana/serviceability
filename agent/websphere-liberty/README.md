# WebSphere Liberty Must Gather Scripts

## Overview
These scripts collect diagnostic data for the Instana WebSphere Liberty Sensor on various platforms. They gather configuration information, logs, and system details to help troubleshoot issues with the Instana monitoring of WebSphere Liberty servers.

## Available Scripts

### Unix/Linux
The `instana-websphere-liberty-mustgather-unix.sh` script collects data from WebSphere Liberty running on Unix/Linux systems.

### Windows
The `instana-websphere-liberty-mustgather-windows.ps1` script collects data from WebSphere Liberty running on Windows systems.

### AIX
The `instana-websphere-liberty-mustgather-aix.sh` script collects data from WebSphere Liberty running on AIX systems.

### Kubernetes
The `instana-websphere-liberty-mustgather-k8s.sh` script collects data from WebSphere Liberty running in Kubernetes environments.

## Usage

### Unix/Linux
1. Copy the script to the environment where WebSphere Liberty is running
2. Make the script executable:
   ```bash
   chmod +x instana-websphere-liberty-mustgather-unix.sh
   ```
3. Run the script:
   ```bash
   ./instana-websphere-liberty-mustgather-unix.sh
   ```

### Windows
1. Copy the script to the environment where WebSphere Liberty is running
2. Run the script in PowerShell:
   ```powershell
   .\instana-websphere-liberty-mustgather-windows.ps1
   ```

### AIX
1. Copy the script to the AIX environment where WebSphere Liberty is running
2. Make the script executable:
   ```bash
   chmod +x instana-websphere-liberty-mustgather-aix.sh
   ```
3. Run the script:
   ```bash
   ./instana-websphere-liberty-mustgather-aix.sh
   ```

### Kubernetes
1. Copy the script to a system with kubectl access to your Kubernetes cluster
2. Make the script executable:
   ```bash
   chmod +x instana-websphere-liberty-mustgather-k8s.sh
   ```
3. Run the script:
   ```bash
   ./instana-websphere-liberty-mustgather-k8s.sh
   ```

## Data Collected
Each script collects the following information:
- WebSphere Liberty version
- Server configuration (server.xml)
- JVM options (jvm.options)
- Server logs
- Server status
- Java version
- System information
- Monitor feature configuration
- JMX configuration
- Java agent configuration

The collected data is packaged into an archive file that can be provided to IBM Support for analysis.

## Requirements
- Access to the WebSphere Liberty installation
- Appropriate permissions to read configuration files and execute commands
- For the Kubernetes script: kubectl access to the cluster where Liberty is deployed