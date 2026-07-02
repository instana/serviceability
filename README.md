# Serviceability

This repository contains various scripts and tools designed to assist with **Instana serviceability**. Our goal is to provide resources that streamline troubleshooting and optimize usage of Instana in different environments.

## Structure

- **agent/k8s/**
  Contains Kubernetes/OpenShift–specific scripts (e.g., `instana-k8s-mustgather.sh`) that help gather diagnostic information for Instana Host Agents.

- **autotrace-mutating-webhook/**
  Contains serviceability scripts for the Instana autotrace mutating webhook, including a script to manually remove instrumentation that was injected by older webhook versions into higher-level workload resources (Deployment, DeploymentConfig, DaemonSet, ReplicaSet, StatefulSet).

As we grow, more directories will be added for different Instana components and environments (including self-hosted Instana) to further enhance serviceability.

## Contributing

- Pull requests and issue submissions are welcome.
- Please include any relevant testing or usage details for new scripts and tools you contribute.

For more information or questions, reach out via GitHub issues or contact the Instana support team.