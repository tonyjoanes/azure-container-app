#!/usr/bin/env bash
# Deploys (or updates) all Azure infrastructure using Bicep.
# Re-running is safe — Bicep deployments are idempotent.
#
# Usage:
#   bash infra/deploy.sh                                  # initial deploy
#   bash infra/deploy.sh <github-actions-principal-oid>   # also grants AcrPush to the SP
set -euo pipefail

RESOURCE_GROUP="rg-container-app-demo"
LOCATION="uksouth"
DEPLOYMENT_NAME="infra-$(date +%Y%m%d-%H%M%S)"
INFRA_DIR="$(cd "$(dirname "$0")" && pwd)"
PRINCIPAL_OID="${1:-}"

echo ">>> Ensuring resource group exists: $RESOURCE_GROUP"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

DEPLOY_ARGS=(
  --resource-group "$RESOURCE_GROUP"
  --template-file "$INFRA_DIR/main.bicep"
  --parameters "$INFRA_DIR/main.bicepparam"
  --name "$DEPLOYMENT_NAME"
)

if [ -n "$PRINCIPAL_OID" ]; then
  DEPLOY_ARGS+=(--parameters "githubActionsPrincipalObjectId=$PRINCIPAL_OID")
fi

echo ">>> Deploying Bicep template..."
az deployment group create "${DEPLOY_ARGS[@]}"

echo ""
echo "=== Deployment complete ==="
echo ""
ACR_NAME=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs.acrName.value" -o tsv)
ACR_SERVER=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs.acrLoginServer.value" -o tsv)
APP_URL=$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs.appUrl.value" -o tsv)

echo "ACR Name:          $ACR_NAME"
echo "ACR Login Server:  $ACR_SERVER"
echo "App URL:           $APP_URL"
echo ""
echo "Set these GitHub repository secrets:"
echo "  AZURE_REGISTRY_NAME=$ACR_NAME"
echo "  REGISTRY_LOGIN_SERVER=$ACR_SERVER"
