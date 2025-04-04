# Instana Kubernetes Must-Gather Script

## Table of Contents

- [Instana zOS Must-Gather Script](#instana-zOS-must-gather-script)
    - [Table of Contents](#table-of-contents)
    - [Overview](#overview)
        - [Key Features](#key-features)
    - [Prerequisites](#prerequisites)
    - [Usage](#usage)
        - [Configuration](#configuration)
        - [Command-Line Arguments](#command-line-arguments)
        - [Expected Output](#expected-output)
    - [Examples](#examples)


## Overview

The `instana-zOS-mustgather.sh` script is designed to collect diagnostic data for the Instana Host Agent running on zOS. It simplifies troubleshooting by gathering logs, configuration details, and host information everything into a compressed tarball for easy sharing with support teams or for archival.

### Key Features

- **Automatic command detection**: Determines whether to use `oc` (OpenShift) or `kubectl` (vanilla Kubernetes).
- **Comprehensive data collection**: Gathers Websphere Feature flag is enabled or not, user privileges information, Instana Agent logs.
- **Built-in checks**: Verifies required tools (e.g., `bash`, `tar`) and ensures critical resources exist before proceeding.
- **Tarball creation**: Finalizes all collected data into a single archive (`.tgz`) for easy distribution.

## Prerequisites


1. **Additional utilities**
    - `bash`
    - `tar`
    - A shell that supports `set -euo pipefail` (modern Bash or similar).
3. **Sufficient permissions**
    - Ensure you have the necessary permissions to read and collect data and copy logs from instana-agent/data/log in your zOS-USS layer.

No additional system configurations are required beyond the standard tools listed above.

## Usage

1. **Clone or copy the script** into an environment where the above prerequisites are met.
2. **Make the script executable** (if needed):

   ```bash
   chmod +x instana-zOS-mustgather.sh
   ```

3. **Run the script**:

   ```bash
   ./instana-zOS-mustgather.sh
   ```

   The script:
    - Detects whether you required privilege to execute this script to collect data.
    - Gathers information required to trace Websphere also collects Instana Agent logs.
    - Creates a directory named `instana-agent-zOS-mustgather-<version>-<timestamp>` containing all artifacts.
    - Compresses the directory into an archive named `instana-agent-zOS-mustgather-<timestamp>.tgz`.

### Configuration


  ```bash
  ./instana-zOS-mustgather.sh
  ```

### Command-Line Arguments

This script accept command-line arguments as path of your Instana-agent directory, so provide path once it asks interactively. `e.g. /u/user1/instana-agent` Simply run it as shown above.

### Expected Output

- A new directory, for example:

  ```
  instana-agent-zOS-mustgather-20250324-123056/
  ```

  containing:
    - `tag-for-bin-files.txt`, `tag-for-etc-files.txt`, `tmp-instana-files.txt`, `websphere-zOS-Prereq-output.txt`.
    
- A compressed tarball (`.tgz`) of that directory for sharing or storage.

## Examples

1. **Basic run**

   ```bash
   # Ensure you are logged in to your zOS-USS layer

   ./instana-zOS-mustgather.sh
   
   #   Must-gather completed. Archive created: instana-agent-zOS-mustgather-20250324-123056.tgz
   ```

2. **Check logs**  
   After the script completes, explore the generated directory to review the captured logs and configurations. For example:

   ```bash
   tar xzf instana-agent-zOS-mustgather-20250324-123056.tgz
   ls instana-agent-zOS-mustgather-20250324-123056/instana-agent/
   ```


