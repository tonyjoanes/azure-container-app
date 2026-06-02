#!/usr/bin/env bash
# Configures passwordless GitHub Actions → Azure authentication using OIDC federation.
# No client secrets are created. GitHub issues short-lived tokens that Azure validates
# against the federated credential registered here.
#
# Usage: bash infra/github-oidc-setup.sh <github-username-or-org>
set -euo pipefail

GITHUB_ORG="${1:?Usage: $0 <github-username-or-org>}"
GITHUB_REPO="azure-container-app"
RESOURCE_GROUP="rg-container-app-demo"
SP_NAME="sp-azure-container-app-deploy"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
ACR_ID=$(az acr list --resource-group "$RESOURCE_GROUP" --query "[0].id" -o tsv)

echo ">>> Creating service principal: $SP_NAME"
APP_ID=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role "Contributor" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}" \
  --query appId -o tsv)

echo ">>> Granting AcrPush on the registry"
az role assignment create \
  --assignee "$APP_ID" \
  --role "AcrPush" \
  --scope "$ACR_ID"

echo ">>> Adding federated credential for pushes to main"
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "{
    \"name\": \"github-main\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

echo ""
echo "=== OIDC setup complete ==="
echo ""
echo "Set these GitHub repository secrets (Settings → Secrets → Actions):"
echo "  AZURE_CLIENT_ID=${APP_ID}"
echo "  AZURE_TENANT_ID=${TENANT_ID}"
echo "  AZURE_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}"
