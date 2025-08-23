#!/usr/bin/env bash
set -euo pipefail

# Usage examples:
#   ./azure/update-rocketchat.sh 7.9.3
#   ./azure/update-rocketchat.sh 9.10.0 --canary 10      # 10% traffic to new revision
#   ./azure/update-rocketchat.sh rollback <REVISION_NAME>

RG="Rocketchat_RG"

require() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 not found"; exit 1; }; }
require az

if ! az account show >/dev/null 2>&1; then
  echo "Please run: az login"
  exit 1
fi

mode="update"
percent=""
case "${1:-}" in
  rollback)
    mode="rollback"
    REV="${2:-}"
    [[ -z "$REV" ]] && { echo "Usage: $0 rollback <REVISION_NAME>"; exit 1; }
    ;;
  "")
    echo "Usage: $0 <image-tag> [--canary <percent>] | rollback <REVISION_NAME>"; exit 1 ;;
  *)
    TAG="$1"
    shift || true
    ;;
 esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --canary)
      percent="$2"; shift 2;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

if [[ "$mode" == "rollback" ]]; then
  echo "==> Routing 100% traffic to revision: $REV"
  az containerapp ingress traffic set -g "$RG" -n rocketchat --revision-weight "$REV"=100
  exit 0
fi

# Discover ACR
ACR_NAME=$(az acr list -g "$RG" --query "[0].name" -o tsv)
ACR_SERVER=$(az acr show -n "$ACR_NAME" --query loginServer -o tsv)

# Import target image if missing
if ! az acr repository show -n "$ACR_NAME" --image "rocketchat:$TAG" >/dev/null 2>&1; then
  echo "==> Importing rocketchat:$TAG into $ACR_NAME"
  az acr import -n "$ACR_NAME" --source "docker.io/rocketchat/rocket.chat:$TAG" --image "rocketchat:$TAG"
fi

echo "==> Updating container app to image: $ACR_SERVER/rocketchat:$TAG"
az containerapp update -g "$RG" -n rocketchat --image "$ACR_SERVER/rocketchat:$TAG"

if [[ -n "$percent" ]]; then
  echo "==> Enabling canary: latest=$percent%"
  az containerapp revision set-mode -g "$RG" -n rocketchat --mode multiple
  az containerapp ingress traffic set -g "$RG" -n rocketchat --revision-weight latest=$percent
  echo "Done. Use this to promote:"
  echo "  az containerapp ingress traffic set -g $RG -n rocketchat --revision-weight latest=100"
fi
