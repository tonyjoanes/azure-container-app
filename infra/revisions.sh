#!/usr/bin/env bash
# Helpers for managing Azure Container App revisions and traffic splitting.
#
# Usage:
#   ./infra/revisions.sh list
#   ./infra/revisions.sh split <revision-a> <revision-b>   # 50/50 split
#   ./infra/revisions.sh activate <revision-name>           # 100% to one revision
#   ./infra/revisions.sh deactivate <revision-name>
set -euo pipefail

RESOURCE_GROUP="rg-container-app-demo"
APP_NAME="api-demo"
CMD="${1:-list}"

case "$CMD" in
  list)
    az containerapp revision list \
      --name "$APP_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --output table
    ;;
  split)
    # Splits traffic evenly between two revisions.
    # Use `az containerapp ingress traffic set` with different weights for uneven splits.
    az containerapp ingress traffic set \
      --name "$APP_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --revision-weight \
        "${2:?Provide revision-a name}=50" \
        "${3:?Provide revision-b name}=50"
    ;;
  activate)
    # Routes 100% of traffic to one revision (blue/green cutover).
    az containerapp ingress traffic set \
      --name "$APP_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --revision-weight "${2:?Provide revision name}=100"
    ;;
  deactivate)
    az containerapp revision deactivate \
      --revision "${2:?Provide revision name}" \
      --resource-group "$RESOURCE_GROUP"
    ;;
  *)
    echo "Usage: $0 {list|split <rev-a> <rev-b>|activate <rev>|deactivate <rev>}"
    exit 1
    ;;
esac
