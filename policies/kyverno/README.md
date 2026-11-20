# Kyverno policies (admission layer)

Policies in this folder are synced to the cluster by the `kyverno-policies` Argo CD Application. Kyverno enforces them when resources are admitted to the cluster: layer 2 of the three guardrail layers (CI, admission, Azure Policy).

Argo CD reads only `.yaml`, `.yml` and `.json` files here, so this README is ignored.
