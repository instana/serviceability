# Instana Autotrace Mutating Webhook — Serviceability Scripts

This directory contains serviceability scripts for the **Instana autotrace mutating webhook**.

## Contents

| File | Description |
|---|---|
| [`remove-instrumentation.sh`](./remove-instrumentation.sh) | Removes webhook-injected instrumentation from higher-level workload resources (Deployment, DeploymentConfig, DaemonSet, ReplicaSet, StatefulSet) |

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

Verify the CLI you intend to use:

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
| `--cli oc\|kubectl` | CLI binary to use (default: `oc`) |

> **Note:** `deploymentconfig` is an OpenShift-only resource type and requires `--cli oc`.

### Examples

```bash
# OpenShift — all resource types in a namespace (Deployment, DeploymentConfig, DaemonSet, ReplicaSet, StatefulSet)
./remove-instrumentation.sh test-apps

# OpenShift — dry run first (recommended)
./remove-instrumentation.sh --dry-run test-apps

# OpenShift — specific workload
./remove-instrumentation.sh test-apps my-app

# OpenShift — only DeploymentConfigs
./remove-instrumentation.sh --resource deploymentconfig test-apps

# Kubernetes (plain) — all resource types
./remove-instrumentation.sh --cli kubectl test-apps

# Kubernetes — specific DaemonSet
./remove-instrumentation.sh --cli kubectl --resource daemonset test-apps my-daemonset
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

You passed `--resource deploymentconfig` together with `--cli kubectl`. Use `--cli oc` or omit `--cli` (it defaults to `oc`).

---

## Support

For issues or questions, contact your Instana support team.
