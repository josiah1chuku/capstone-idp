# Policy-Guarded Self-Service Internal Developer Platform

Graduate capstone project (Computer Science): design and evaluation of a self-service internal developer platform (IDP) for Kubernetes.

A developer makes a single request and gets a running, monitored, policy-compliant service on Azure Kubernetes Service (AKS) without filing a ticket. Policy-as-code guardrails check every request at three layers (CI, Kubernetes admission and Azure Policy), so misconfigurations are blocked before they reach the cluster.

The full project proposal will be published here after it has been graded.

## How it works

1. A developer requests a service by choosing a template (API, web app or worker) and supplying a few parameters: name, team and environment.
2. The control plane renders Kubernetes manifests and infrastructure code from the template and commits them to Git. It never changes the cluster directly.
3. CI runs the policy checks on the commit.
4. Argo CD syncs the desired state to AKS. Kyverno checks it again at admission, and Azure Policy checks any cloud resources.
5. The developer sees the request status, or the reason it was rejected.
6. Argo CD reverts manual changes to managed resources (drift correction).

## Research question

Can a self-service platform that combines declarative provisioning, GitOps and layered policy as code reduce provisioning lead time and configuration errors compared with manual provisioning, while staying reliable as concurrent demand grows?

| Hypothesis | Claim | Test |
|---|---|---|
| H1, speed | Lead time at least 10× lower than a scripted manual baseline | 30 runs per template per method |
| H2, safety | At least 95% of about 40 seeded misconfigurations caught before deployment, with few false positives | Full set, repeated 3 times |
| H3, scalability | No failed or inconsistent environments up to a measured saturation point | 1, 10, 25, 50 and 100 concurrent requests |
| H4, consistency | Manual drift is detected and reverted within a bounded time | 20 changes per type |

## Repository layout

| Path | Contents |
|---|---|
| [`docs/`](docs/) | Proposal, literature notes, design docs, final report |
| [`infra/bicep/`](infra/bicep/) | Testbed infrastructure as code: AKS cluster and Azure resources ([setup guide](infra/bicep/README.md)) |
| [`platform/api/`](platform/api/) | Request interface (API and CLI) |
| [`platform/control-plane/`](platform/control-plane/) | Renders templates and commits desired state to Git; idempotent per request ID |
| [`platform/templates/`](platform/templates/) | Versioned service templates: `api`, `web`, `worker` |
| [`gitops/`](gitops/) | Argo CD configuration: cluster bootstrap (`clusters/`) and provisioned services (`apps/`) |
| [`policies/`](policies/) | Guardrails for each layer: `ci/`, `kyverno/` (admission) and `azure-policy/` (cloud) |
| [`observability/`](observability/) | Default metrics, logs and dashboards for every service |
| [`evaluation/`](evaluation/) | Test harness, manual baseline, raw results and analysis scripts |
| [`.github/workflows/`](.github/workflows/) | CI pipelines |

## Stack

Azure · AKS · Bicep · Argo CD · Kyverno · Azure Policy · GitHub Actions

Alternatives to compare in the write-up: Crossplane, OPA Gatekeeper, Flux and Backstage.

## Status

Early setup, nothing deployed yet.

- Done: testbed infrastructure ([infra/bicep](infra/bicep/README.md)) and GitOps bootstrap with Argo CD and Kyverno ([gitops](gitops/README.md)).
- Next: Kyverno policies, the first service template, and the control plane.

## Scope

In scope: one cloud (Azure), one AKS cluster in one region, two or three service templates, policy at three layers, and default observability.

Out of scope: multi-cloud and multi-cluster, cost showback, fine-grained multi-tenant RBAC, and a production developer portal UI.
