# Backstage Bootstrap

A comprehensive guide and automation scripts for deploying Backstage.io on Azure Container Apps.

## Overview

This repository provides step-by-step documentation and scripts to:
1. Scaffold a Backstage.io application
2. Build a production-ready Docker image
3. Deploy to Azure Container Apps with Azure Container Registry (ACR) and managed identity

## Prerequisites

- **Docker** 20.10.x+ or **Podman** 4.x+ (all scripts auto-detect `docker`/`podman`)
- **Node.js** 18.x or 20.x (optional; only needed for local `yarn dev` outside containers)
- **Yarn** 1.22.x or newer (optional; installs run inside containers otherwise)
- **Azure CLI** 2.40.x or newer
- **Git** 2.x or newer

### Azure Requirements
- An active Azure subscription
- Permissions to create:
  - Resource Groups
  - Container Registry (ACR)
  - Container Apps
  - Managed Identities
  - Role Assignments

## Quick Start

### 1. Scaffold a Backstage Application

Run the scaffolding script to create a new Backstage app (it pulls a Node image and runs `npx` inside Docker/Podman, so no local Node.js/Yarn install is required):

```bash
./scripts/create_backstage_app.sh
```

This script will:
- Create a new Backstage app using `npx @backstage/create-app@latest` inside Docker/Podman
- Place the app in the `backstage-app/` directory (excluded from git)
- Prompt you for an app name (default: `backstage-app`)
- Respect `BACKSTAGE_CREATE_IMAGE` if you want to use a different Node base image

### 2. Build and Run Docker Image Locally

Build the Backstage backend Docker image (no host Node.js/Yarn required) and test it locally:

```bash
./scripts/build_and_run_docker.sh
```

This script will:
- Run the entire Backstage build inside Docker using the multi-stage `backstage/Dockerfile`
- Create a Docker image using the app located under `backstage-app/`
- Optionally run the container locally on port 7007

Set the following environment variables before running the script (or export them when invoking `podman run`) to enable Azure Entra ID authentication:

| Variable | Description |
| --- | --- |
| `BACKEND_SECRET` | Random 32+ character string used to sign Backstage backend tokens |
| `AUTH_MICROSOFT_CLIENT_ID` | Application (client) ID from your Entra ID app registration |
| `AUTH_MICROSOFT_CLIENT_SECRET` | Client secret created for the registration |
| `AUTH_MICROSOFT_TENANT_ID` | Directory (tenant) ID that holds the registration |

> Want to run the Docker build manually? Use (`docker` or `podman`):
>
> ```bash
> docker build -f backstage/Dockerfile -t backstage:latest --build-arg APP_DIR=backstage-app .
> ```
> (Replace `docker` with `podman` if that's your runtime.)

> The scripts automatically pick `docker` first and fall back to `podman`. To override, set `CONTAINER_RUNTIME=docker|podman` before running them.

> Want to run the container manually (daemonized)?
>
> ```bash
> podman run -d --name backstage-local -p 7007:7007 \
>   -e BACKEND_SECRET=... -e AUTH_MICROSOFT_CLIENT_ID=... \
>   -e AUTH_MICROSOFT_CLIENT_SECRET=... -e AUTH_MICROSOFT_TENANT_ID=... \
>   backstage:latest
> # or swap podman for docker
> ```

### 3. Deploy to Azure Container Apps

Deploy your Backstage application to Azure:

```bash
./scripts/deploy_to_azure_container_apps.sh
```

This script will:
- Create or use existing Azure Resource Group
- Set up Azure Container Registry (ACR)
- Build and push the Docker image to ACR
- Create a user-assigned managed identity
- Configure ACR pull permissions for the managed identity
- Deploy to Azure Container Apps
- Output the application URL

## Architecture

### Azure Entra ID Authentication

1. Create an Azure Entra ID application registration (Web platform) and add the following redirect URIs:
  - `http://localhost:7007/api/auth/microsoft/handler/frame`
  - `http://localhost:3000/api/auth/microsoft/handler/frame` (for the frontend during local dev)
2. Generate a client secret and copy the **Application (client) ID**, **Directory (tenant) ID**, and secret value.
3. Export the values along with a strong `BACKEND_SECRET` before running the build or starting the container. The helper scripts automatically forward these variables when launching the container.
4. When deploying to Azure Container Apps, set the same variables as container environment variables/secrets so authentication works in production.

### Docker Image

The Dockerfile is based on the official Backstage backend Dockerfile and includes:
- Node.js 20 (Debian Bookworm slim)
- SQLite3 support
- TechDocs local generation support (Python, pip, mkdocs-techdocs-core)
- Production-optimized Yarn workspace installation
- Runs as non-root user (`node`)

Set the `APP_DIR` build argument (defaults to `backstage-app`) to point at your Backstage application relative to the build context. This allows you to run `docker build` from the repository root without copying files manually. The runtime image already contains the compiled backend, frontend static assets, and Microsoft authentication wiring, so you only need to provide the Azure-related environment variables at runtime.

### Azure Resources

The deployment creates the following Azure resources:

1. **Resource Group**: Container for all resources
2. **Container Registry (ACR)**: Stores the Docker image
3. **User-Assigned Managed Identity**: Provides secure authentication
4. **Container Apps Environment**: Runtime environment for the container
5. **Container App**: The running Backstage application

### Security

- Uses managed identity for ACR authentication (no passwords in configuration)
- Runs container as non-root user
- Follows Azure security best practices
- Supports Azure AD integration for Backstage authentication

## Directory Structure

```
.
├── README.md                                    # This file
├── scripts/
│   ├── create_backstage_app.sh                 # Scaffold Backstage app
│   ├── build_and_run_docker.sh                 # Build and run Docker image
│   └── deploy_to_azure_container_apps.sh       # Deploy to Azure
├── backstage/
│   └── Dockerfile                               # Production Dockerfile
└── .gitignore                                   # Excludes generated files
```

## Customization

### Application Configuration

After scaffolding, customize your Backstage app:

1. Edit `backstage-app/app-config.yaml` for app settings
2. Add plugins in `backstage-app/packages/app/`
3. Configure backend in `backstage-app/packages/backend/`

### Docker Build

To customize the Docker build:

1. Modify `backstage/Dockerfile` as needed
2. Update build scripts in `scripts/build_and_run_docker.sh`

### Azure Deployment

To customize Azure deployment:

1. Edit `scripts/deploy_to_azure_container_apps.sh`
2. Adjust container resources (CPU, memory)
3. Configure environment variables
4. Set up custom domains and SSL

## Troubleshooting

### Build Failures

If the Docker build fails:
- Ensure `backstage-app/` exists (run `./scripts/create_backstage_app.sh` if needed)
- Verify the `APP_DIR` build argument points to the correct directory
- Check Docker daemon is running and you have enough disk space

### Deployment Issues

If Azure deployment fails:
- Verify Azure CLI is authenticated: `az login`
- Check subscription access: `az account show`
- Ensure resource names are unique
- Review Azure quota limits

### Runtime Errors

If the application fails to start:
- Check container logs: `az containerapp logs show`
- Verify environment variables
- Check ACR access permissions
- Review app-config.yaml for misconfigurations

## References

- [Backstage.io Documentation](https://backstage.io/docs)
- [Backstage GitHub Repository](https://github.com/backstage/backstage)
- [Azure Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Azure Container Registry Documentation](https://learn.microsoft.com/en-us/azure/container-registry/)

## License

This project is licensed under the same license as the repository (see LICENSE file).

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.