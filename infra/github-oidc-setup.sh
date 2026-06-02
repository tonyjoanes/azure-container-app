#!/usr/bin/env bash
# Creates a service principal with an OIDC federated credential for GitHub Actions.
# Bicep handles all Azure role assignments — this script only performs Azure AD
# operations that Bicep cannot do without the Microsoft Graph extension.
#
# Usage: bash infra/github-oidc-setup.sh <github-username-or-org>
# Then:  bash infra/deploy.sh <printed-principal-object-id>
set -euo pipefail

GITHUB_ORG="${1:?Usage: $0 <github-username-or-org>}"
GITHUB_REPO="azure-container-app"
SP_NAME="sp-azure-container-app-deploy"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo ">>> Creating service principal: $SP_NAME"
RESOURCE_GROUP="rg-container-app-demo"

APP_ID=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role "Contributor" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}" \
  --query appId -o tsv)

PRINCIPAL_OID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

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
echo "Next: deploy infrastructure and grant the AcrPush role via Bicep:"
echo "  bash infra/deploy.sh $PRINCIPAL_OID"
echo ""
echo "Then set these GitHub repository secrets (Settings → Secrets → Actions):"
echo "  AZURE_CLIENT_ID=$APP_ID"
echo "  AZURE_TENANT_ID=$TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
