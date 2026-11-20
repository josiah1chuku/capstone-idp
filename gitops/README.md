# GitOps

Argo CD reconciles the testbed cluster from this repository. Git is the single source of truth: neither people nor the control plane change the cluster directly.

```
gitops/
├── clusters/testbed/
│   ├── argocd-values.yaml       Argo CD Helm values (bootstrap and self-management)
│   ├── root-app.yaml            Root Application, applied once by bootstrap.sh
│   └── apps/                    Everything the root Application installs
│       ├── services-project.yaml  wave -1  AppProject limiting what services can touch
│       ├── argocd.yaml            wave 0   Argo CD manages itself (chart 10.11.7, v3.5.7)
│       ├── kyverno.yaml           wave 0   Kyverno admission controller (chart 3.9.2, v1.19.2)
│       ├── kyverno-policies.yaml  wave 1   Policies from policies/kyverno/
│       └── services.yaml          wave 2   ApplicationSet: one Application per gitops/apps/<service>/
├── apps/                        Provisioned services, written by the control plane
└── scripts/
    ├── bootstrap.sh             Installs Argo CD and applies the root Application
    └── set-repo-url.sh          Fills in the GitHub repo URL
```

## Bootstrap

Prerequisites: the cluster is deployed (see [infra/bicep](../infra/bicep/README.md)), `kubectl` points at it, `helm` is installed, and this repository is pushed to GitHub. Argo CD reads from GitHub, not from your laptop.

```bash
# Once: set the repo URL in the manifests, then commit and push
./gitops/scripts/set-repo-url.sh https://github.com/<you>/capstone-idp.git

# After every fresh cluster deploy
./gitops/scripts/bootstrap.sh
kubectl -n argocd get applications -w
```

The repository is expected to be public, as the proposal's deliverables require. A private repository would need a repo credential added to Argo CD.

## Settings that affect the experiments

- **Git polling interval: 60 seconds** (`timeout.reconciliation` in `argocd-values.yaml`). A new service can wait up to this long before Argo CD sees its commit, which adds to the H1 lead time. Record it with every run, or add a GitHub webhook to remove the wait.
- **Self-heal on every service:** manual changes are reverted automatically. This is what H4 measures.
- **Single replicas everywhere:** fine for a testbed. H3 load tests will show where the Argo CD controller saturates.
