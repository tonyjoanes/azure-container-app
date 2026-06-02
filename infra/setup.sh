#!/usr/bin/env bash
# Creates all Azure resources needed for this project.
# Run once before the first deployment. Outputs the values you need as GitHub secrets.
set -euo pipefail

RESOURCE_GROUP="rg-container-app-demo"
LOCATION="uksouth"
SUFFIX=$(openssl rand -hex 3)
ACR_NAME="acrdemo${SUFFIX}"         # Must be globally unique, 5-50 alphanumeric chars
ENVIRONMENT_NAME="cae-demo"
APP_NAME="api-demo"

echo ">>> Creating resource group: $RESOURCE_GROUP"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

echo ">>> Creating Azure Container Registry: $ACR_NAME"
az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --sku Basic

echo ">>> Creating Container Apps Environment: $ENVIRONMENT_NAME"
az containerapp env create \
  --name "$ENVIRONMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION"

echo ">>> Creating Container App: $APP_NAME"
# --revisions-mode multiple allows multiple revisions to run simultaneously,
# which is required for traffic splitting and blue/green deployments.
az containerapp create \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --image "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" \
  --target-port 8080 \
  --ingress external \
  --revisions-mode multiple \
  --min-replicas 0 \
  --max-replicas 3 \
  --env-vars "APP_VERSION=0.0.0"

echo ""
echo "=== Setup complete ==="
echo ""
echo "Set these GitHub repository secrets (Settings → Secrets → Actions):"
echo "  AZURE_REGISTRY_NAME=${ACR_NAME}"
echo "  REGISTRY_LOGIN_SERVER=${ACR_NAME}.azurecr.io"
echo ""
echo "Then run:  bash infra/github-oidc-setup.sh <your-github-username>"
