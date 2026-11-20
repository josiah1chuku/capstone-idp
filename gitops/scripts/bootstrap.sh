#!/usr/bin/env bash
# Installs Argo CD on the testbed cluster and hands control to Git.
# After this, Argo CD installs Kyverno, the platform policies and the services
# ApplicationSet from gitops/clusters/testbed/apps/, and manages itself.
#
# Prerequisites: the cluster is deployed (infra/bicep/scripts/deploy.sh), kubectl
# points at it, and this repository is pushed to GitHub.
#
# Usage: ./gitops/scripts/bootstrap.sh

set -euo pipefail

cd "$(dirname "$0")/../.."
cluster_dir=gitops/clusters/testbed

if grep -rq "CHANGE-ME" "$cluster_dir"; then
  echo "The GitHub repo URL is still a placeholder. Run:" >&2
  echo "  ./gitops/scripts/set-repo-url.sh https://github.com/<you>/capstone-idp.git" >&2
  exit 1
fi

# Same chart version Argo CD later uses to manage itself.
chart_version="$(awk '/chart: argo-cd/{found=1} found && /targetRevision:/{print $2; exit}' "$cluster_dir/apps/argocd.yaml")"

echo "Cluster: $(kubectl config current-context)"
echo "Installing Argo CD chart ${chart_version}"

helm upgrade --install argocd argo-cd \
  --repo https://argoproj.github.io/argo-helm \
  --version "$chart_version" \
  --namespace argocd --create-namespace \
  --values "$cluster_dir/argocd-values.yaml" \
  --wait --timeout 10m

kubectl apply -f "$cluster_dir/root-app.yaml"

echo
echo "Argo CD is installed and syncing from Git. To open the UI:"
echo "  kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo "  then visit https://localhost:8080 and sign in as 'admin' with:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo
echo "Watch the platform come up:"
echo "  kubectl -n argocd get applications -w"
