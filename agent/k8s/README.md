# Instana Kubernetes Must-Gather Script

## Table of Contents

- [Instana Kubernetes Must-Gather Script](#instana-kubernetes-must-gather-script)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
    - [Key Features](#key-features)
  - [Prerequisites](#prerequisites)
  - [Usage](#usage)
    - [Command-Line Arguments](#command-line-arguments)
    - [Expected Output](#expected-output)
  - [Examples](#examples)
  - [Additional Notes](#additional-notes)

## Overview

The `instana-k8s-mustgather.sh` script is designed to collect diagnostic data for the Instana Host Agent running on Kubernetes or OpenShift clusters. It simplifies troubleshooting by gathering logs, configuration details, and cluster information—packaging everything into a compressed tarball for easy sharing with support teams or for archival.

### Key Features

- **Automatic command detection**: Determines whether to use `oc` (OpenShift) or `kubectl` (vanilla Kubernetes).
- **Comprehensive data collection**: Gathers node listings, namespace information, Instana Agent secrets/configMaps, pod descriptions, and container logs (including previous logs if available).
- **Built-in checks**: Verifies required tools (e.g., `awk`, `sed`) and ensures critical resources exist before proceeding.
- **Tarball creation**: Finalizes all collected data into a single archive (`.tgz`) for easy distribution.

## Prerequisites

1. **Cluster command-line tool**  
   - **OpenShift**: `oc`  
   - **Kubernetes**: `kubectl`  
   (Must be installed and authenticated for your cluster)
2. **Additional utilities**  
   - `awk`  
   - `sed`  
   - A shell that supports `set -euo pipefail` (modern Bash or similar).
3. **Sufficient permissions**  
   - Ensure you have the necessary permissions to read namespaces, pods, secrets, and copy logs from pods in your cluster.

No special environment variables or system configurations are required beyond the standard tools listed above.

## Usage

1. **Clone or copy the script** into an environment where the above prerequisites are met.
2. **Make the script executable** (if needed):

   ```bash
   chmod +x instana-k8s-mustgather.sh
   ```

3. **Run the script**:

   ```bash
   ./instana-k8s-mustgather.sh
   ```

   The script:
   - Detects whether you are on OpenShift (`oc`) or Kubernetes (`kubectl`).
   - Gathers cluster information, Instana Agent configurations, and logs.
   - Creates a directory named `instana-k8s-mustgather-<timestamp>` containing all artifacts.
   - Compresses the directory into an archive named `instana-k8s-mustgather-<timestamp>.tgz`.

### Command-Line Arguments

This script does not accept command-line arguments. Simply run it as shown above.

### Expected Output

- A new directory:  

  ```
  instana-k8s-mustgather-YYYY.MM.DD-HH.MM.SS/
  ```

  containing:
  - `node-list.txt`, `node-describe.txt`, `namespaces.txt` (and if OpenShift, `cluster-operators.txt`).
  - Instana Agent secret or configMap details.
  - Detailed pod and container information, as well as logs for the `instana-agent` namespace (and `openshift-controller-manager` if on OpenShift).
- A compressed tarball (`.tgz`) of that directory for sharing or storage.

## Examples

1. **Basic run**  

   ```bash
   # Ensure you are logged in to your cluster
   oc login <cluster_url>          # for OpenShift
   # or
   kubectl config use-context ...  # for Kubernetes

   ./instana-k8s-mustgather.sh
   # Output:
   #   Version: 1.1.5
   #   Running: <various cluster commands>
   #   Must-gather completed. Archive created: instana-k8s-mustgather-YYYY.MM.DD-HH.MM.SS.tgz
   ```

2. **Check logs**  
   After the script completes, explore the generated directory to review the captured logs and configurations. For example:

   ```bash
   tar xzf instana-k8s-mustgather-YYYY.MM.DD-HH.MM.SS.tgz
   ls instana-k8s-mustgather-YYYY.MM.DD-HH.MM.SS/instana-agent/
   ```

## Additional Notes

- **Limitations**:  
  - The script is designed primarily for Instana Agent troubleshooting. It does not collect logs or resources from other namespaces unless specified (`instana-agent`, plus `openshift-controller-manager` if on OpenShift).
  - Older shells that do not support `pipefail` may have issues.
- **Future enhancements**:  
  - Support for additional namespaces or custom filtering of logs.
  - Extended compatibility across different shell environments.
- **Contact**:  
  - For support or further information, refer to [Instana documentation](https://www.ibm.com/docs/en/instana-observability). If you need more assistance, contact your Instana support representative.
