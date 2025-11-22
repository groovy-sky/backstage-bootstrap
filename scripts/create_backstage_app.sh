#!/bin/bash
set -e

# Script to scaffold a new Backstage.io application
# This uses the official Backstage scaffolding tool

echo "================================================"
echo "Backstage.io Application Scaffolding"
echo "================================================"
echo ""

# Default app name
DEFAULT_APP_NAME="backstage-app"

# Get app name from user
read -p "Enter the name for your Backstage app [${DEFAULT_APP_NAME}]: " APP_NAME
APP_NAME=${APP_NAME:-$DEFAULT_APP_NAME}

echo ""
echo "Creating Backstage app: ${APP_NAME}"
echo ""

# Check if the directory already exists
if [ -d "${APP_NAME}" ]; then
    echo "Error: Directory '${APP_NAME}' already exists."
    read -p "Do you want to remove it and create a new app? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "Removing existing directory..."
        rm -rf "${APP_NAME}"
    else
        echo "Aborted. Please choose a different app name or remove the existing directory."
        exit 1
    fi
fi

# Run the Backstage create-app command
echo "Running: npx @backstage/create-app@latest --path ${APP_NAME}"
echo ""
npx @backstage/create-app@latest --path "${APP_NAME}"

echo ""
echo "================================================"
echo "Backstage app created successfully!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. cd ${APP_NAME}"
echo "  2. Review and customize app-config.yaml"
echo "  3. Run 'yarn install' if not already done"
echo "  4. Run 'yarn dev' to start the development server"
echo ""
echo "To build and deploy:"
echo "  1. Run '../scripts/build_and_run_docker.sh' to build Docker image"
echo "  2. Run '../scripts/deploy_to_azure_container_apps.sh' to deploy to Azure"
echo ""
