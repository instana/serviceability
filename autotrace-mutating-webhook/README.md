# Instana Autotrace Mutating Webhook — Serviceability Scripts

This directory contains serviceability scripts for the **Instana autotrace mutating webhook**.

## Contents

| File | Description |
|---|---|
| [`remove-instrumentation.sh`](./remove-instrumentation.sh) | Removes webhook-injected instrumentation from higher-level workload resources (Deployment, DeploymentConfig, DaemonSet, ReplicaSet, StatefulSet) |
| [`collect-lii-logs.sh`](./collect-lii-logs.sh) | Collects `libinstana_init` (LII) debug logs from a running instrumented pod without modifying the workload |

---

## Background

Older versions of the Instana autotrace mutating webhook mutated workload objects directly (Deployment, DeploymentConfig, DaemonSet, ReplicaSet, StatefulSet), embedding instrumentation into their specs. The current webhook version mutates only pods, which makes upgrading and removing instrumentation straightforward.

When upgrading from an older webhook version to the current one, the injected fields must first be removed from the higher-level workload resources. A simple redeployment is not always possible in customer environments, so [`remove-instrumentation.sh`](./remove-instrumentation.sh) automates this cleanup safely.

---

## remove-instrumentation.sh

### Prerequisites

```bash
jq --version   # required

# Install jq if needed
brew install jq          # macOS
sudo apt-get install jq  # Debian/Ubuntu
sudo yum install jq      # RHEL/CentOS
```

The script auto-detects the CLI: it tries `oc` first and falls back to `kubectl` when `oc` is not available. Confirm at least one is present:

```bash
oc whoami                 # OpenShift
kubectl version --client  # Kubernetes
```

### Usage

```bash

./remove-instrumentation.sh [--dry-run] [--resource TYPE] [--cli oc|kubectl] <namespace> [workload-name]
```

#### Options

| Flag | Description |
|---|---|
| `--dry-run` | Show what would be removed; no changes made |
| `--resource TYPE` | One of: `deployment`, `deploymentconfig`, `daemonset`, `replicaset`, `statefulset`, `all` (default: `all`) |
| `--cli oc\|kubectl` | CLI binary to use (auto-detected: `oc` if present, otherwise `kubectl`) |

> **Note:** `deploymentconfig` is an OpenShift-only resource type and requires `--cli oc`.

### Examples

```bash
# Auto-detected CLI — all resource types in a namespace
./remove-instrumentation.sh test-apps

# Dry run first (recommended)
./remove-instrumentation.sh --dry-run test-apps

# Specific workload
./remove-instrumentation.sh test-apps my-app

# Only DeploymentConfigs (OpenShift)
./remove-instrumentation.sh --resource deploymentconfig test-apps

# Force kubectl (plain Kubernetes)
./remove-instrumentation.sh --cli kubectl test-apps

# Force oc (OpenShift) — specific DaemonSet
./remove-instrumentation.sh --cli oc --resource daemonset test-apps my-daemonset
```

### What Gets Removed

The script removes all webhook-added instrumentation from every supported resource type:

- Init containers (`instana-instrumentation-init`)
- Volumes (`instana-instrumentation-volume`, `instana-autotrace-ace-config-volume`, `instana-autotrace-ibmmq-config-volume`)
- Volume mounts referencing the above volumes
- Environment variables (`LD_PRELOAD`, `INSTANA_AGENT_HOST`, `INSTANA_SERVICE_NAME`, `MQ_ENABLE_OPEN_TRACING`, `HOST_IP`, `HOST_ALIAS`, and others)
- Instana-specific paths stripped from `NODE_OPTIONS` and `PYTHONPATH`
- Labels (`instana-autotrace-applied`, `instana-autotrace-version`, `instana-autotrace-transformation`) from both the workload and pod template
- Instana image pull secrets

**Preserved:** your opt-in label (`instana-autotrace: "true"`), all other application env vars, volumes, and image pull secrets.

#### Resource types handled

| Resource | Kubernetes | OpenShift |
|---|---|---|
| `Deployment` | ✓ | ✓ |
| `DeploymentConfig` | — | ✓ |
| `DaemonSet` | ✓ | ✓ |
| `ReplicaSet` | ✓ | ✓ |
| `StatefulSet` | ✓ | ✓ |

> **Not handled by this script:** `Pod` (ephemeral — cleaning the owner resource and triggering a rollout is sufficient) and ingress-nginx `ConfigMap` (different mutation pattern).

### Recommended Workflow

**1 — Confirm instrumentation is present** in the target namespace:

```bash
# OpenShift
oc get deployment,deploymentconfig,daemonset,replicaset,statefulset \
  -n <namespace> -l instana-autotrace-applied=true

# Kubernetes
kubectl get deployment,daemonset,replicaset,statefulset \
  -n <namespace> -l instana-autotrace-applied=true
```

**2 — Dry run first (recommended):**

```bash
./remove-instrumentation.sh --dry-run <namespace>
```

Review the output to confirm only the expected fields would be removed.

**3 — Run the removal:**

```bash
./remove-instrumentation.sh <namespace>
```

**4 — Verify all workloads are clean:**

```bash
# OpenShift
oc get deployment,deploymentconfig,daemonset,replicaset,statefulset \
  -n <namespace> -o yaml \
  | grep -E "(LD_PRELOAD|NODE_OPTIONS.*instana|instana-autotrace-applied)"

# Kubernetes
kubectl get deployment,daemonset,replicaset,statefulset \
  -n <namespace> -o yaml \
  | grep -E "(LD_PRELOAD|NODE_OPTIONS.*instana|instana-autotrace-applied)"

# Should return nothing
```

**5 — Rollback if needed** (backup path is printed by the script):

```bash
# OpenShift
oc apply -f ./backups-<timestamp>/<namespace>-<kind>-<name>.yaml

# Kubernetes
kubectl apply -f ./backups-<timestamp>/<namespace>-<kind>-<name>.yaml
```

### Important Notes

- The script uses `replace` to avoid cached configuration issues
- Automatic backups are created in `./backups-<timestamp>/` before any changes; the path is printed at the start of every run
- The opt-in label (`instana-autotrace: "true"`) is preserved for the new webhook
- After cleanup, deploy the current webhook version that mutates only pods

### Next Steps

After running this script:

1. Deploy the current webhook version
2. Restart workloads so the webhook can mutate their pods:

   ```bash
   # Deployment (Kubernetes or OpenShift)
   kubectl rollout restart deployment <name> -n <namespace>

   # DaemonSet / StatefulSet
   kubectl rollout restart daemonset <name> -n <namespace>
   kubectl rollout restart statefulset <name> -n <namespace>

   # DeploymentConfig (OpenShift only)
   oc rollout latest deploymentconfig/<name> -n <namespace>
   ```

3. Verify pods (not workloads) get instrumented:

   ```bash
   kubectl get pods -n <namespace> -l instana-autotrace-applied=true
   kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Init Containers"
   ```

4. Confirm your application works correctly

### Troubleshooting

#### "jq: command not found"

Install jq using the commands in the Prerequisites section.

#### "No instrumented workloads found"

The script looks for workloads with the label `instana-autotrace-applied=true`. If none are found:

- The webhook may not have run yet — verify pods carry the label
- Wrong namespace specified
- Instrumentation was already removed

#### Workload still shows instrumentation after running the script

1. Check the backup file to confirm the original state
2. Verify no webhook is running: `kubectl get mutatingwebhookconfiguration` (or `oc get mutatingwebhookconfiguration` on OpenShift)
3. Contact support with the workload YAML

#### "DeploymentConfig is an OpenShift resource and requires --cli oc"

You passed `--resource deploymentconfig` together with `--cli kubectl`. Use `--cli oc` or omit `--cli` (the script will auto-detect `oc` if it is available).

#### "neither 'oc' nor 'kubectl' found in PATH"

Neither CLI binary is available. Install either `oc` (OpenShift) or `kubectl` (Kubernetes) and ensure it is on your `PATH`.

---

## collect-lii-logs.sh

Collects `libinstana_init` (LII) debug logs from a running, webhook-instrumented pod. It does **not** modify the Deployment or pod, does not restart anything, and does not create any Kubernetes object, so it is safe to run in production clusters.

### Why this is needed

LII logs nothing by default. Its logging is enabled with `INSTANA_LII_LOG_LEVEL=debug` and `INSTANA_LII_LOG_STDERR=1`, which would normally require changing the workload and restarting the pod.

### How it works

LII is injected via `LD_PRELOAD`, so every new process started in the container loads it. The script runs a short-lived process (default: `java -version`) inside the existing container with the debug variables set for that process only.

The webhook also sets `INSTANA_LII_INIT=1` in the container, which makes LII skip initialization (and logging). The script unsets it for the one process it starts. Without that, the output is empty.

Equivalent manual command:

```bash
kubectl exec <pod> -n <namespace> [-c <container>] -- \
  env -u INSTANA_LII_INIT INSTANA_LII_LOG_LEVEL=debug INSTANA_LII_LOG_STDERR=1 \
  java -version 2>&1 | tee lii-startup.log
```

### Prerequisites

- `oc` or `kubectl` (auto-detected, `oc` first), with permission to `get pods` and `exec` into the target pod
- The target pod carries the label `instana-autotrace-applied=true`
- `env` and the command to run exist in the container image (not the case for distroless images)

### Usage

```bash
./collect-lii-logs.sh [--cli oc|kubectl] [--container NAME] [--output FILE] <namespace> <pod> [-- command [args...]]
```

| Option | Description |
|---|---|
| `--cli oc\|kubectl` | CLI binary to use (auto-detected: `oc` if present, otherwise `kubectl`) |
| `--container NAME` | Container to run in (default: the pod's default container) |
| `--output FILE` | File for the full output (default: `./lii-<pod>-<timestamp>.log`) |
| `-- command [args]` | Process to run in the container (default: `java -version`) |

### Examples

```bash
# Default container, default command
./collect-lii-logs.sh test-apps my-app-5d8f7c-abcde

# Multi-container pod
./collect-lii-logs.sh --container app test-apps my-app-5d8f7c-abcde

# Explicit command
./collect-lii-logs.sh test-apps my-app-5d8f7c-abcde -- java -version
```

The script prints the LII lines (`[INSTANA] [lii <version>] ...`) and saves the complete output, including the output of the command itself, to the output file.

### Limitations

- **This is a replay, not the original startup log.** The script starts a new process in the running container. Files LII created on first start already exist, so some messages differ. For example, `File /tmp/instana/nginx/watcher_started already exists` and `Java version already detected (read from file)` appear instead of `Created file ...`. To capture the real first-start log, debug logging must be enabled before the pod starts, which requires changing the workload.
- **Short-lived extra process.** It starts one extra JVM in the target container, which uses some CPU and memory briefly.
- **Container image requirements.** The script fails with "no LII log lines captured" if `env` or the command is missing from the image, the container is wrong, or `LD_PRELOAD` does not point to `libinstana_init.so`.
- **Output may contain environment details.** Review the saved log before sharing it.

---

## Support

For issues or questions, contact your Instana support team.
