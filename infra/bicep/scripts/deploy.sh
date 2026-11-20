#!/usr/bin/env bash
# Deploys the IDP testbed (resource group, AKS, ACR, Key Vault, Log Analytics) and
# configures kubectl for the new cluster.
#
# Usage:
#   KUBERNETES_VERSION=1.33 ./scripts/deploy.sh             # deploy
#   KUBERNETES_VERSION=1.33 ./scripts/deploy.sh --what-if   # preview changes only
#
# Optional environment variables:
#   AZURE_LOCATION      region (default: eastus)
#   BUDGET_ALERT_EMAIL  email for cost alerts; set together with BUDGET_START_DATE
#   BUDGET_START_DATE   first day of the budget month, e.g. 2026-11-01

set -euo pipefail

cd "$(dirname "$0")/.."

export AZURE_LOCATION="${AZURE_LOCATION:-eastus}"

if ! az account show >/dev/null 2>&1; then
  echo "Not signed in to Azure. Run: az login" >&2
  exit 1
fi

if [[ -z "${KUBERNETES_VERSION:-}" ]]; then
  echo "Set KUBERNETES_VERSION to a pinned minor version. Available in ${AZURE_LOCATION}:" >&2
  az aks get-versions --location "$AZURE_LOCATION" --query "values[].version" -o tsv >&2
  exit 1
fi
export KUBERNETES_VERSION

ADMIN_PRINCIPAL_ID="$(az ad signed-in-user show --query id -o tsv)"
export ADMIN_PRINCIPAL_ID

echo "Subscription: $(az account show --query name -o tsv)"
echo "Region:       ${AZURE_LOCATION}"
echo "Kubernetes:   ${KUBERNETES_VERSION}"

if [[ "${1:-}" == "--what-if" ]]; then
  az deployment sub what-if \
    --location "$AZURE_LOCATION" \
    --template-file main.bicep \
    --parameters main.bicepparam
  exit 0
fi

deployment="idp-testbed-$(date +%Y%m%d-%H%M%S)"
start=$(date +%s)

az deployment sub create \
  --name "$deployment" \
  --location "$AZURE_LOCATION" \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --output none

echo "Deployed in $(( $(date +%s) - start ))s"

rg="$(az deployment sub show -n "$deployment" --query properties.outputs.resourceGroupName.value -o tsv)"
cluster="$(az deployment sub show -n "$deployment" --query properties.outputs.clusterName.value -o tsv)"

az aks get-credentials --resource-group "$rg" --name "$cluster" --overwrite-existing
# Local accounts are disabled, so kubectl authenticates through the Azure CLI login.
kubelogin convert-kubeconfig -l azurecli

az deployment sub show -n "$deployment" --query properties.outputs -o table
kubectl get nodes
