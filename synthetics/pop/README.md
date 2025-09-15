# Synthetic PoP Log Collection Tool

## Table of Contents
- [Script](#script)
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Parameters](#parameters)
- [Examples](#examples)
- [Output](#output)
- [Troubleshooting](#troubleshooting)

## Script
The `pdcollect.sh` script used for data collection can be found in the external repository:
[pdcollect.sh](https://github.com/instana/synthetic-pop-charts/blob/main/pdcollect.sh)

## Overview

The `pdcollect.sh` script is a utility designed to collect logs and diagnostic information from Synthetic PoP (Point of Presence) pods running in a Kubernetes cluster. This tool simplifies the process of gathering relevant information for troubleshooting and monitoring Synthetic PoP deployments.

The script collects:
- Helm deployment information
- Pod status and details
- Version information for all components
- Log files from all Synthetic PoP components (controller, http, javascript, browserscript, ism, redis)

All collected information is automatically packaged into a single compressed archive for easy sharing and analysis.

## Prerequisites

Before using the `pdcollect.sh` script, ensure you have:

1. Access to a Kubernetes cluster with Synthetic PoP installed
2. One of the following Kubernetes CLI tools installed:
   - `kubectl` command-line tool
   - `microk8s` with kubectl functionality
3. `helm` command-line tool installed
4. Appropriate permissions to:
   - List pods in the target namespace
   - Execute commands in pods
   - Copy files from pods

## Installation

Ensure the script has executable permissions:

```bash
chmod +x pdcollect.sh
```

## Usage

Basic syntax:

```bash
./pdcollect.sh [-n <namespace>] [-d <log_output_directory>] [-h]
```

## Parameters

| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| `-n` | Kubernetes namespace where Synthetic PoP is deployed | `default` |
| `-d` | Directory where log files will be saved | `/tmp` |
| `-h` | Display help information | N/A |

## Examples

### Collect logs from the default namespace

```bash
./pdcollect.sh
```

### Collect logs from a specific namespace

```bash
./pdcollect.sh -n synthetic-monitoring
```

### Save logs to a specific directory

```bash
./pdcollect.sh -d /path/to/logs
```

### Collect logs from a specific namespace and save to a specific directory

```bash
./pdcollect.sh -n synthetic-monitoring -d /path/to/logs
```

## Output

The script creates a compressed tar archive containing all collected logs and information. The archive is named using the following format:

```
<log_output_directory>/syntheticpop_logs_<YYYYMMDDHHMM>.tar.gz
```

Where:
- `<log_output_directory>` is the directory specified with the `-d` parameter (default: `/tmp`)
- `<YYYYMMDDHHMM>` is the timestamp when the script was executed

The archive contains:
- `helm_list.log`: Output of `helm list` command
- `pod_list.log`: Output of `kubectl get pod` command
- `version.log`: Version information for all components
- `*_describe.log`: Detailed information about each pod
- `*_log/`: Directory containing logs from each pod

## Troubleshooting

### No Synthetic PoP installed

If you see the error message:
```
No Synthetic PoP installed in <namespace> namespace.
```

Verify that:
1. You are using the correct namespace
2. Synthetic PoP is properly installed in the specified namespace

### Directory does not exist

If you see the error message:
```
Directory <directory> does not exist, exit.
```

Ensure that the directory specified with the `-d` parameter exists before running the script.

### No logging files

If you see the error message:
```
No logging files. Please check your resources in <namespace> namespace
```

Verify that:
1. The Synthetic PoP pods are running in the specified namespace
2. You have sufficient permissions to access the pods and their logs