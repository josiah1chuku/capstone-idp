# Provisioned services

The control plane writes one folder per service here: `gitops/apps/<service>/`, holding that service's rendered Kubernetes manifests. Do not edit these folders by hand.

- **Provision:** the control plane commits a new folder. The `services` ApplicationSet creates an Argo CD Application named `svc-<service>`, which deploys it to the namespace `<service>`.
- **Drift:** Argo CD self-heal reverts manual changes in the cluster.
- **Decommission:** the control plane deletes the folder. Argo CD removes the Application and everything it deployed.

Each service runs under the `services` AppProject, which keeps it out of the platform namespaces and stops it creating cluster-wide resources other than its own Namespace.
