#!/usr/bin/env bash
# Replaces the placeholder GitHub repo URL in the Argo CD manifests.
# Usage: ./gitops/scripts/set-repo-url.sh https://github.com/<you>/capstone-idp.git

set -euo pipefail

url="${1:-}"
if [[ ! "$url" =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\.git$ ]]; then
  echo "Usage: $0 https://github.com/<you>/<repo>.git" >&2
  exit 1
fi

cd "$(dirname "$0")/.."
files="$(grep -rl "https://github.com/CHANGE-ME/capstone-idp.git" clusters || true)"
if [[ -z "$files" ]]; then
  echo "No placeholder found; the repo URL is already set."
  exit 0
fi

for f in $files; do
  sed -i "s|https://github.com/CHANGE-ME/capstone-idp.git|${url}|g" "$f"
  echo "Updated gitops/$f"
done
