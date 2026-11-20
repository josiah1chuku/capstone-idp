#!/usr/bin/env bash
# Deletes the IDP testbed so it stops costing money, and purges the soft-deleted
# Key Vault so the next deploy can reuse its name. The subscription budget is kept.
#
# Usage: ./scripts/teardown.sh [--yes]

set -euo pipefail

prefix="${PREFIX:-idp}"
rg="rg-${prefix}-testbed"

if [[ "$(az group exists --name "$rg")" != "true" ]]; then
  echo "Resource group ${rg} does not exist; nothing to delete."
  exit 0
fi

if [[ "${1:-}" != "--yes" ]]; then
  read -r -p "Delete resource group ${rg} and everything in it? [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Cancelled."; exit 1; }
fi

vaults="$(az keyvault list --resource-group "$rg" --query "[].name" -o tsv)"

start=$(date +%s)
az group delete --name "$rg" --yes
echo "Deleted ${rg} in $(( $(date +%s) - start ))s"

for vault in $vaults; do
  echo "Purging soft-deleted Key Vault ${vault}"
  az keyvault purge --name "$vault"
done
