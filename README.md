# Backstage Bootstrap

A comprehensive guide and automation scripts for deploying Backstage.io on Azure Container Apps.

## Overview

This repository provides step-by-step documentation and scripts to:
1. Scaffold a Backstage.io application
2. Build a production-ready Docker image
3. Deploy to Azure Container Apps with Azure Container Registry (ACR) and managed identity

## Prerequisites

- **Node.js** 18.x or 20.x (LTS versions)
- **Yarn** 1.22.x or newer
- **Docker** 20.10.x or newer
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

Run the scaffolding script to create a new Backstage app:

```bash
./scripts/create_backstage_app.sh
```

This script will:
- Create a new Backstage app using `npx @backstage/create-app@latest`
- Place the app in the `backstage-app/` directory (excluded from git)
- Prompt you for an app name (default: `backstage-app`)

### 2. Build and Run Docker Image Locally

Build the Backstage backend Docker image and test it locally:

```bash
./scripts/build_and_run_docker.sh
```

This script will:
- Build the Backstage backend bundle
- Create a Docker image using the provided Dockerfile
- Optionally run the container locally on port 7007

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

### Docker Image

The Dockerfile is based on the official Backstage backend Dockerfile and includes:
- Node.js 20 (Debian Bookworm slim)
- SQLite3 support
- TechDocs local generation support (Python, pip, mkdocs-techdocs-core)
- Production-optimized Yarn workspace installation
- Runs as non-root user (`node`)

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
- Ensure you've run `yarn install` and `yarn build:backend` in the Backstage app
- Check Docker daemon is running
- Verify Node.js version compatibility

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