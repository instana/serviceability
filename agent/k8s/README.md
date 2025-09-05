# Instana Kubernetes Must-Gather Script

## Table of Contents

- [Instana Kubernetes Must-Gather Script](#instana-kubernetes-must-gather-script)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
    - [Key Features](#key-features)
  - [Prerequisites](#prerequisites)
  - [Usage](#usage)
    - [Configuration](#configuration)
    - [Command-Line Arguments](#command-line-arguments)
    - [Expected Output](#expected-output)
  - [Examples](#examples)
  - [Additional Notes](#additional-notes)
  - [Change Log](#change-log)

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

No additional system configurations are required beyond the standard tools listed above.

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
   - Creates a directory named `instana-agent-k8s-mustgather-<version>-<timestamp>` containing all artifacts.
   - Compresses the directory into an archive named `instana-agent-k8s-mustgather-<version>-<timestamp>.tgz`.

### Configuration

- **Environment Variable: `INSTANA_AGENT_NAMESPACE`**  
  By default, the script gathers data from the `instana-agent` namespace. To change this behavior, set the `INSTANA_AGENT_NAMESPACE` variable before running the script:

  ```bash
  export INSTANA_AGENT_NAMESPACE=custom-agent-namespace
  ./instana-k8s-mustgather.sh
  ```

### Command-Line Arguments

The script accepts the following command-line arguments:

- `-n NAMESPACE`: Specify the Instana agent namespace (default: instana-agent)
- `-h`: Display help message

Example:
```bash
./instana-k8s-mustgather.sh -n custom-agent-namespace

### Expected Output

- A new directory, for example:

  ```
  instana-agent-k8s-mustgather-1.1.6-20250324-123056/
  ```

  containing:
  - `node-list.txt`, `node-describe.txt`, `namespaces.txt` (and if OpenShift, `cluster-operators.txt`).
  - Instana Agent secret or configMap details.
  - Detailed pod and container information, as well as logs for the specified `INSTANA_AGENT_NAMESPACE` (defaulting to `instana-agent`), plus `openshift-controller-manager` if on OpenShift.
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
   #   Version: 1.1.6
   #   Running: <various cluster commands>
   #   Must-gather completed. Archive created: instana-agent-k8s-mustgather-1.1.6-20250324-123056.tgz
   ```

2. **Check logs**  
   After the script completes, explore the generated directory to review the captured logs and configurations. For example:

   ```bash
   tar xzf instana-agent-k8s-mustgather-1.1.6-20250324-123056.tgz
   ls instana-agent-k8s-mustgather-1.1.6-20250324-123056/instana-agent/
   ```

## Additional Notes

- **Limitations**:
  - The script is designed primarily for Instana Agent troubleshooting. It does not collect logs or resources from other namespaces unless specified (via `INSTANA_AGENT_NAMESPACE`, plus `openshift-controller-manager` if on OpenShift).
  - Older shells that do not support `pipefail` may have issues.
- **Future enhancements**:
  - Support for additional namespaces or custom filtering of logs.
  - Extended compatibility across different shell environments.
- **Contact**:
  - For support or further information, refer to [Instana documentation](https://www.ibm.com/docs/en/instana-observability). If you need more assistance, contact your Instana support representative.

## Change Log

- **1.1.6**:
  - Added support for the `INSTANA_AGENT_NAMESPACE` environment variable to customize the default namespace.
  - Updated the naming pattern of the output directory to include the version.
  - Other minor improvements and bug fixes.
