#!/usr/bin/env bash
# Starts a stopped AKS cluster and waits until its nodes are ready.
#
# Usage: ./scripts/start.sh

set -euo pipefail

prefix="${PREFIX:-idp}"
rg="rg-${prefix}-testbed"
cluster="aks-${prefix}"

state="$(az aks show -g "$rg" -n "$cluster" --query powerState.code -o tsv)"
if [[ "$state" == "Running" ]]; then
  echo "${cluster} is already running."
else
  echo "Starting ${cluster} (takes a few minutes)..."
  start=$(date +%s)
  az aks start -g "$rg" -n "$cluster"
  echo "Started in $(( $(date +%s) - start ))s"
fi

kubectl wait --for=condition=Ready nodes --all --timeout=10m
kubectl get nodes
echo "Argo CD applications:"
kubectl -n argocd get applications 2>/dev/null || echo "  (Argo CD not installed yet; run ./gitops/scripts/bootstrap.sh)"
