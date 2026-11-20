#!/usr/bin/env bash
# Stops the AKS cluster so its nodes stop costing money. Everything on the cluster
# (Argo CD, Kyverno, services) is kept and comes back with ./scripts/start.sh.
# Use ./scripts/teardown.sh instead for breaks longer than a few days.
#
# Usage: ./scripts/stop.sh

set -euo pipefail

prefix="${PREFIX:-idp}"
rg="rg-${prefix}-testbed"
cluster="aks-${prefix}"

state="$(az aks show -g "$rg" -n "$cluster" --query powerState.code -o tsv)"
if [[ "$state" == "Stopped" ]]; then
  echo "${cluster} is already stopped."
  exit 0
fi

echo "Stopping ${cluster} (takes a few minutes)..."
start=$(date +%s)
az aks stop -g "$rg" -n "$cluster"
echo "Stopped in $(( $(date +%s) - start ))s. Start again with ./scripts/start.sh"
