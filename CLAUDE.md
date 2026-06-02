# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

A hands-on learning project for Azure Container Apps. It covers containerising a .NET 8 minimal API, deploying via GitHub Actions with OIDC authentication, and managing traffic across revisions (canary releases, blue/green deployments).

## Commands

### Run locally
```bash
docker compose up --build        # API at http://localhost:8080/swagger
docker compose down
```

### Run without Docker (.NET 8 SDK required)
```bash
cd src/Api && dotnet run
```

### Build image locally (without pushing)
```bash
docker build -t api-demo .
```

### Deploy Azure infrastructure (Bicep)
```bash
# Initial deploy — creates all resources
bash infra/deploy.sh

# Re-deploy after granting AcrPush to the GitHub Actions service principal
bash infra/deploy.sh <github-actions-principal-object-id>
```

## Architecture

### API (`src/Api/Program.cs`)

Single-file .NET 8 minimal API with two endpoints:

- `GET /api/info` — returns `appVersion`, `revisionName`, and the current UTC time. Use this to confirm which revision is handling a given request.
- `GET /api/products` — returns a product list where every item includes a `servedBy` field echoing `APP_VERSION`. When traffic is split across two revisions, repeated calls to this endpoint will show alternating `servedBy` values, making the split visible.

`APP_VERSION` is populated from an environment variable set per revision by the deploy workflow. `CONTAINER_APP_REVISION` is injected automatically by Azure at runtime.

### Revision model

The Container App is created with `activeRevisionsMode: 'Multiple'` (in `infra/modules/app.bicep`). Key behaviours:

- Every `az containerapp update` creates a new **immutable** revision — you cannot modify a running revision, only replace it.
- Multiple revisions run simultaneously; traffic is distributed by integer weight totalling 100.
- The deploy workflow sets `--revision-suffix build-<run_number>` and `APP_VERSION=<branch>-<run_number>` on every push, so each revision is identifiable by its workflow run.

### CI/CD (`.github/workflows/deploy.yml`)

1. **Auth** — Uses OIDC (`azure/login@v2`) with a federated credential. No client secrets are stored; GitHub issues a short-lived token that Azure validates. Set up once with `infra/github-oidc-setup.sh`.
2. **Build** — `az acr build` runs the Docker build server-side on Azure Container Registry. No Docker daemon is needed on the GitHub Actions runner.
3. **Deploy** — `az containerapp update` points the app at the new image (tagged with `github.sha`) and creates a named revision.

### Infrastructure as Code (`infra/`)

All Azure resources are defined in Bicep and deployed via `infra/deploy.sh`.

| File | Purpose |
|---|---|
| `infra/main.bicep` | Entry point — wires together the two modules and exposes outputs |
| `infra/main.bicepparam` | Default parameter values (location, names) |
| `infra/modules/registry.bicep` | Azure Container Registry; conditionally grants AcrPush to the GitHub Actions service principal |
| `infra/modules/app.bicep` | Log Analytics workspace, Container Apps Environment, user-assigned managed identity, AcrPull role assignment, and Container App |

The Container App uses a **user-assigned managed identity** for image pulls so no registry credentials are stored in the app configuration. The identity is granted AcrPull on the ACR inside `modules/app.bicep`. AcrPush for the GitHub Actions service principal is granted in `modules/registry.bicep` via the optional `githubActionsPrincipalObjectId` parameter.

| Script | When to run |
|---|---|
| `infra/github-oidc-setup.sh <github-username>` | Once — creates an Azure AD service principal with a federated credential for OIDC; prints the principal object ID needed for the next step |
| `infra/deploy.sh [principal-object-id]` | Once initially, and whenever Bicep templates change; idempotent |
| `infra/revisions.sh` | On demand — `list`, `split`, `activate`, `deactivate` |

## First-time setup sequence

```bash
# 1. Configure OIDC — creates the service principal and prints its object ID
bash infra/github-oidc-setup.sh tonyjoanes

# 2. Deploy infrastructure — creates ACR, Container Apps Environment, app,
#    managed identity, role assignments; pass the object ID from step 1
bash infra/deploy.sh <principal-object-id>

# 3. Set these GitHub repository secrets from the output above:
#    AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
#    AZURE_REGISTRY_NAME, REGISTRY_LOGIN_SERVER

# 4. Push to main — the workflow deploys automatically
```

## Required GitHub secrets

| Secret | Source |
|---|---|
| `AZURE_CLIENT_ID` | Output of `infra/github-oidc-setup.sh` |
| `AZURE_TENANT_ID` | Output of `infra/github-oidc-setup.sh` |
| `AZURE_SUBSCRIPTION_ID` | Output of `infra/github-oidc-setup.sh` |
| `AZURE_REGISTRY_NAME` | Output of `infra/deploy.sh` (name only, e.g. `acrdemoa1b2c3`) |
| `REGISTRY_LOGIN_SERVER` | Output of `infra/deploy.sh` (full URL, e.g. `acrdemoa1b2c3.azurecr.io`) |

## Experimenting with traffic splitting

```bash
# See all revisions and their traffic weights
bash infra/revisions.sh list

# Route 50% to each of two revisions (canary)
bash infra/revisions.sh split api-demo--build-3 api-demo--build-4

# Cut over fully to one revision (blue/green)
bash infra/revisions.sh activate api-demo--build-4
```

Hit `GET /api/products` repeatedly while a split is active — the `servedBy` field in the response will alternate between the two `APP_VERSION` values.
