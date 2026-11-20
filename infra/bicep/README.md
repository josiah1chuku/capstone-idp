# Testbed infrastructure (Bicep)

Creates the Azure testbed from the proposal: one resource group, in one region, holding everything the platform runs on. The whole testbed can be deleted and recreated between experiment runs.

| Resource | Name | Purpose |
|---|---|---|
| Resource group | `rg-idp-testbed` | Holds the whole testbed; deleting it tears everything down |
| AKS cluster | `aks-idp` | Runs Argo CD, Kyverno and the provisioned services |
| Container registry | `acridp<unique>` | Service images; nodes pull without credentials |
| Key Vault | `kv-idp-<unique>` | Service secrets, read through the CSI driver (FR5) |
| Log Analytics | `log-idp` | Container Insights logs and metrics |
| Budget (optional) | `budget-idp-testbed` | Cost alerts at the subscription level |

## Cluster settings and why

| Setting | Value | Reason |
|---|---|---|
| Kubernetes version | Pinned; auto-upgrade off | Tool versions stay fixed during experiments (risk table) |
| Auth | Entra ID with Azure RBAC, local accounts off | Least privilege and an audit trail (NFR4) |
| Workload identity and OIDC issuer | On | Services authenticate without secrets in Git (NFR4) |
| Azure Policy add-on | On | In-cluster Azure Policy enforcement, alongside Kyverno |
| Key Vault CSI driver | On, with rotation | Secrets wiring for each service (FR5) |
| Container Insights | On, 1 GB per day cap, 30-day retention | Default observability without runaway cost (FR5, NFR7) |
| Networking | Azure CNI overlay with Cilium | Network policies between namespaces |
| System pool | 1 × `Standard_D2s_v5` | Platform components |
| User pool | `Standard_D2s_v5`, autoscaling 1 to 2 | Provisioned services; raise the maximum for the H3 load tests |
| Tier | Free | Student budget (NFR7) |

## Prerequisites

- Azure CLI, signed in: `az login`
- `kubectl` and `kubelogin`: `sudo az aks install-cli`
- On a new subscription, register the providers once:
  ```bash
  for p in Microsoft.ContainerService Microsoft.ContainerRegistry Microsoft.KeyVault \
           Microsoft.OperationalInsights Microsoft.OperationsManagement Microsoft.PolicyInsights; do
    az provider register --namespace "$p"
  done
  ```
- vCPU quota: the defaults need up to 6 vCPUs of the DSv5 family in the region. Azure for Students subscriptions have low quotas, so check with `az vm list-usage -l eastus -o table`.

## Usage

Run from `infra/bicep/`:

```bash
# See which Kubernetes versions are available, then pick one and keep it for the project
az aks get-versions -l eastus -o table

# Preview the changes
KUBERNETES_VERSION=1.33 ./scripts/deploy.sh --what-if

# Deploy (about 10 minutes) and configure kubectl
KUBERNETES_VERSION=1.33 ./scripts/deploy.sh

# End of a work session: stop the nodes, keep everything else
./scripts/stop.sh
./scripts/start.sh      # next session

# Longer breaks, and between experiment runs: delete everything
./scripts/teardown.sh
```

## Cost

Rough figures at East US list prices:

| State | What you pay for | Rough cost |
|---|---|---|
| Running | 2 × D2s_v5 nodes, load balancer, logs, registry | about $5 a day |
| Stopped (`stop.sh`) | Registry, public IP; Key Vault and logs near zero | about $10 a month |
| Torn down (`teardown.sh`) | Nothing (the optional budget is free) | $0 |

Stop the cluster at the end of every session. Left running, it would use up a $100 student credit in about three weeks.

To also create the cost budget, set `BUDGET_ALERT_EMAIL` and `BUDGET_START_DATE` (the first day of the current month, e.g. `2026-11-01`) when you deploy. These are read from environment variables, so your email address is never committed.

## Not here yet

- Per-service managed identities and their Key Vault access. The control plane creates these when it provisions a service.
- Azure Policy assignments for cloud resources. These go in `policies/azure-policy/`.
- Argo CD and Kyverno installation. These go in `gitops/clusters/`.
