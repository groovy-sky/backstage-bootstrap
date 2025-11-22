#!/bin/bash
set -e

# Script to deploy Backstage to Azure Container Apps
# This creates all necessary Azure resources and deploys the container

echo "================================================"
echo "Backstage Deployment to Azure Container Apps"
echo "================================================"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "Error: Azure CLI is not installed."
    echo "Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo "Error: Not logged in to Azure."
    echo "Please run: az login"
    exit 1
fi

echo "Current Azure subscription:"
az account show --query "{Name:name, SubscriptionId:id}" -o table
echo ""

read -p "Is this the correct subscription? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Please run 'az account set --subscription <subscription-id>' to set the correct subscription."
    exit 1
fi

echo ""

# Get configuration from user
DEFAULT_RESOURCE_GROUP="backstage-rg"
DEFAULT_LOCATION="eastus"
DEFAULT_ACR_NAME="backstageacr$(date +%s)"
DEFAULT_APP_NAME="backstage-app"
DEFAULT_ENVIRONMENT_NAME="backstage-env"
DEFAULT_IMAGE_NAME="backstage"
DEFAULT_IMAGE_TAG="latest"

read -p "Enter resource group name [${DEFAULT_RESOURCE_GROUP}]: " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-$DEFAULT_RESOURCE_GROUP}

read -p "Enter Azure location [${DEFAULT_LOCATION}]: " LOCATION
LOCATION=${LOCATION:-$DEFAULT_LOCATION}

read -p "Enter Azure Container Registry name [${DEFAULT_ACR_NAME}]: " ACR_NAME
ACR_NAME=${ACR_NAME:-$DEFAULT_ACR_NAME}

read -p "Enter Container App name [${DEFAULT_APP_NAME}]: " APP_NAME
APP_NAME=${APP_NAME:-$DEFAULT_APP_NAME}

read -p "Enter Container Apps Environment name [${DEFAULT_ENVIRONMENT_NAME}]: " ENVIRONMENT_NAME
ENVIRONMENT_NAME=${ENVIRONMENT_NAME:-$DEFAULT_ENVIRONMENT_NAME}

read -p "Enter Docker image name [${DEFAULT_IMAGE_NAME}]: " IMAGE_NAME
IMAGE_NAME=${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}

read -p "Enter Docker image tag [${DEFAULT_IMAGE_TAG}]: " IMAGE_TAG
IMAGE_TAG=${IMAGE_TAG:-$DEFAULT_IMAGE_TAG}

MANAGED_IDENTITY_NAME="${APP_NAME}-identity"

echo ""
echo "Configuration:"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo "  Location: ${LOCATION}"
echo "  ACR Name: ${ACR_NAME}"
echo "  Container App: ${APP_NAME}"
echo "  Environment: ${ENVIRONMENT_NAME}"
echo "  Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  Managed Identity: ${MANAGED_IDENTITY_NAME}"
echo ""

read -p "Proceed with deployment? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Starting deployment..."
echo ""

# Create resource group
echo "Creating resource group..."
az group create \
    --name "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --output none

echo "✓ Resource group created"

# Create Azure Container Registry
echo "Creating Azure Container Registry..."
az acr create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${ACR_NAME}" \
    --sku Basic \
    --admin-enabled false \
    --output none

echo "✓ ACR created"

# Build and push image to ACR
echo "Building and pushing Docker image to ACR..."
BACKSTAGE_APP_DIR="backstage-app"

if [ ! -d "${BACKSTAGE_APP_DIR}" ]; then
    echo "Error: Backstage app directory '${BACKSTAGE_APP_DIR}' not found."
    echo "Please run './scripts/create_backstage_app.sh' and './scripts/build_and_run_docker.sh' first."
    exit 1
fi

# Navigate to app directory and build backend if needed
cd "${BACKSTAGE_APP_DIR}"

if [ ! -d "packages/backend/dist" ]; then
    echo "Building backend bundle..."
    yarn install --frozen-lockfile
    yarn build:backend
fi

cd ..

# Build and push using ACR
az acr build \
    --registry "${ACR_NAME}" \
    --image "${IMAGE_NAME}:${IMAGE_TAG}" \
    --file backstage/Dockerfile \
    "${BACKSTAGE_APP_DIR}"

echo "✓ Image pushed to ACR"

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show \
    --name "${ACR_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query loginServer \
    --output tsv)

FULL_IMAGE_NAME="${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "✓ Image available at: ${FULL_IMAGE_NAME}"

# Create user-assigned managed identity
echo "Creating managed identity..."
az identity create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${MANAGED_IDENTITY_NAME}" \
    --output none

echo "✓ Managed identity created"

# Get managed identity details
IDENTITY_ID=$(az identity show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${MANAGED_IDENTITY_NAME}" \
    --query id \
    --output tsv)

IDENTITY_CLIENT_ID=$(az identity show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${MANAGED_IDENTITY_NAME}" \
    --query clientId \
    --output tsv)

IDENTITY_PRINCIPAL_ID=$(az identity show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${MANAGED_IDENTITY_NAME}" \
    --query principalId \
    --output tsv)

# Get ACR resource ID
ACR_ID=$(az acr show \
    --name "${ACR_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query id \
    --output tsv)

# Assign AcrPull role to managed identity
echo "Assigning ACR pull permissions to managed identity..."
az role assignment create \
    --assignee "${IDENTITY_PRINCIPAL_ID}" \
    --role "AcrPull" \
    --scope "${ACR_ID}" \
    --output none

echo "✓ ACR permissions configured"

# Create Container Apps environment
echo "Creating Container Apps environment..."
az containerapp env create \
    --name "${ENVIRONMENT_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --output none

echo "✓ Container Apps environment created"

# Create Container App
echo "Creating Container App..."
az containerapp create \
    --name "${APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --environment "${ENVIRONMENT_NAME}" \
    --image "${FULL_IMAGE_NAME}" \
    --target-port 7007 \
    --ingress external \
    --registry-server "${ACR_LOGIN_SERVER}" \
    --registry-identity "${IDENTITY_ID}" \
    --user-assigned "${IDENTITY_ID}" \
    --cpu 1.0 \
    --memory 2.0Gi \
    --min-replicas 1 \
    --max-replicas 3 \
    --output none

echo "✓ Container App created"

# Get the application URL
APP_URL=$(az containerapp show \
    --name "${APP_NAME}" \
    --resource-group "${RESOURCE_GROUP}" \
    --query properties.configuration.ingress.fqdn \
    --output tsv)

echo ""
echo "================================================"
echo "Deployment completed successfully!"
echo "================================================"
echo ""
echo "Application URL: https://${APP_URL}"
echo ""
echo "Resource details:"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo "  Location: ${LOCATION}"
echo "  ACR: ${ACR_NAME}"
echo "  Container App: ${APP_NAME}"
echo "  Environment: ${ENVIRONMENT_NAME}"
echo "  Managed Identity: ${MANAGED_IDENTITY_NAME}"
echo ""
echo "Useful commands:"
echo "  View logs:     az containerapp logs show --name ${APP_NAME} --resource-group ${RESOURCE_GROUP} --follow"
echo "  Update app:    az containerapp update --name ${APP_NAME} --resource-group ${RESOURCE_GROUP} --image ${FULL_IMAGE_NAME}"
echo "  Scale app:     az containerapp update --name ${APP_NAME} --resource-group ${RESOURCE_GROUP} --min-replicas 2 --max-replicas 5"
echo "  Delete all:    az group delete --name ${RESOURCE_GROUP} --yes"
echo ""
