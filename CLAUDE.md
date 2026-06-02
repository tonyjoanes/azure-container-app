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

## Architecture

### API (`src/Api/Program.cs`)

Single-file .NET 8 minimal API with two endpoints:

- `GET /api/info` — returns `appVersion`, `revisionName`, and the current UTC time. Use this to confirm which revision is handling a given request.
- `GET /api/products` — returns a product list where every item includes a `servedBy` field echoing `APP_VERSION`. When traffic is split across two revisions, repeated calls to this endpoint will show alternating `servedBy` values, making the split visible.

`APP_VERSION` is populated from an environment variable set per revision by the deploy workflow. `CONTAINER_APP_REVISION` is injected automatically by Azure at runtime.

### Revision model

The Container App is created with `--revisions-mode multiple` (see `infra/setup.sh`). Key behaviours:

- Every `az containerapp update` creates a new **immutable** revision — you cannot modify a running revision, only replace it.
- Multiple revisions run simultaneously; traffic is distributed by integer weight totalling 100.
- The deploy workflow sets `--revision-suffix build-<run_number>` and `APP_VERSION=<branch>-<run_number>` on every push, so each revision is identifiable by its workflow run.

### CI/CD (`.github/workflows/deploy.yml`)

1. **Auth** — Uses OIDC (`azure/login@v2`) with a federated credential. No client secrets are stored; GitHub issues a short-lived token that Azure validates. Set up once with `infra/github-oidc-setup.sh`.
2. **Build** — `az acr build` runs the Docker build server-side on Azure Container Registry. No Docker daemon is needed on the GitHub Actions runner.
3. **Deploy** — `az containerapp update` points the app at the new image (tagged with `github.sha`) and creates a named revision.

### Infrastructure scripts (`infra/`)

| Script | When to run |
|---|---|
| `setup.sh` | Once — creates the resource group, ACR, Container Apps Environment, and initial app |
| `github-oidc-setup.sh <github-username>` | Once after `setup.sh` — creates a service principal with a federated credential and prints the three GitHub secrets to set |
| `revisions.sh` | On demand — `list`, `split`, `activate`, `deactivate` |

## First-time setup sequence

```bash
# 1. Create Azure resources
bash infra/setup.sh

# 2. Set AZURE_REGISTRY_NAME and REGISTRY_LOGIN_SERVER secrets from the output above

# 3. Configure OIDC — pass your GitHub username
bash infra/github-oidc-setup.sh tonyjoanes

# 4. Set AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID from the output above

# 5. Push to main — the workflow deploys automatically
```

## Required GitHub secrets

| Secret | Source |
|---|---|
| `AZURE_CLIENT_ID` | Output of `infra/github-oidc-setup.sh` |
| `AZURE_TENANT_ID` | Output of `infra/github-oidc-setup.sh` |
| `AZURE_SUBSCRIPTION_ID` | Output of `infra/github-oidc-setup.sh` |
| `AZURE_REGISTRY_NAME` | Output of `infra/setup.sh` (name only, e.g. `acrdemoa1b2c3`) |
| `REGISTRY_LOGIN_SERVER` | Output of `infra/setup.sh` (full URL, e.g. `acrdemoa1b2c3.azurecr.io`) |

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
