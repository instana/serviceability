# Instana Kubernetes Must-Gather Script

A diagnostic data collection tool for Instana agents running on Kubernetes and OpenShift.

**Version:** 2.0.0

## Overview

The `instana-k8s-mustgather.sh` script automatically collects diagnostic information from Instana agent deployments. It uses **label-based discovery** to find all Instana-related pods across your entire cluster.

### How It Works

The script searches for pods using these Kubernetes labels:

- `app.kubernetes.io/name=instana-agent`
- `app.kubernetes.io/component=instana-agent`
- `app.kubernetes.io/part-of=instana`
- `app.kubernetes.io/name=instana-agent-operator`
- `app=instana-agent`

It automatically discovers Instana agent related pods **across all namespaces** and collects their diagnostic data.

## Requirements

**Tools:**

- `kubectl` or `oc` (OpenShift CLI)
- `awk`, `sed`, `tar`, `date`

**Permissions:**

- Read access to pods, secrets, and configmaps across all namespaces
- Execute commands in pods
- Copy files from pods

## Quick Start

> Make sure that `kubectl` or `oc` is configured to access your cluster.

```bash
# Download
curl -O https://raw.githubusercontent.com/instana/serviceability/main/agent/k8s/instana-k8s-mustgather.sh

# Make executable
chmod +x instana-k8s-mustgather.sh

# Run
./instana-k8s-mustgather.sh
```

## Usage

### Basic Usage

```bash
./instana-k8s-mustgather.sh
```

Discovers all Instana agent related pods and collects 10,000 log lines per container.

### Debug Mode

```bash
./instana-k8s-mustgather.sh -d
```

Shows detailed output including discovery process and commands executed. Skips cleanup of temporary directories used to create the must gather archive.

### Limit Log Lines

```bash
./instana-k8s-mustgather.sh -t 5000
```

Collects only 5,000 log lines per container (useful for large deployments).

### Combined Options

```bash
./instana-k8s-mustgather.sh -t 20000 -d
```

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-t LINES` | Number of log lines to collect | 10000 |
| `-d` | Enable debug mode | off |
| `-h` | Show help | - |

## Output

The script creates a timestamped archive:

```text
instana-k8s-mustgather-VERSION-TIMESTAMP.tgz
```

### Directory Structure

```text
instana-k8s-mustgather-VERSION-TIMESTAMP/
├── cluster-info_nodes.txt
├── cluster-info_nodes-describe.txt
├── cluster-info_namespaces.txt
├── cluster-info_openshift_clusteroperators.txt (OpenShift only)
├── agent-config-<namespace>.json
└── namespaces/
    └── openshift-controller-manager/ (Openshift only)
        ├── resources-and-events.txt
    └── <namespace>/
        ├── resources-and-events.txt
        └── pods/
            └── <pod-name>/
                └── containers/
                    └── <container-name>/
                        ├── kubectl/
                        │   ├── log.log
                        │   ├── log_previous.log
                        │   └── describe.txt
                        ├── agent-logs/          (agent pods only)
                        │   └── agent.log*
                        └── diagnostics-tool/    (agent pods only)
                            ├── version.log
                            ├── check-ports.log
                            └── check-configuration.log
```

## What Data is Collected

### Cluster Information

- Node list and descriptions
- All namespaces
- Cluster operators (OpenShift only)

### Agent Configuration

- Agent secrets and configmaps from all discovered namespaces

### Namespace Resources

- All resources and events in namespaces containing Instana components

### Pod Data

- Pod descriptions
- Container logs (current and previous)
- For agent pods specifically:
  - Complete log directory from pod filesystem
  - Agent diagnostics (version, port checks, configuration validation)
