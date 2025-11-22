#!/bin/bash
set -e

# Script to build and optionally run the Backstage Docker image
# This builds the backend bundle and creates a production Docker image

echo "================================================"
echo "Backstage Backend Docker Build"
echo "================================================"
echo ""

# Default values
DEFAULT_APP_DIR="backstage-app"
DEFAULT_IMAGE_NAME="backstage"
DEFAULT_IMAGE_TAG="latest"

# Get configuration from user
read -p "Enter the Backstage app directory [${DEFAULT_APP_DIR}]: " APP_DIR
APP_DIR=${APP_DIR:-$DEFAULT_APP_DIR}

if [ ! -d "${APP_DIR}" ]; then
    echo "Error: Directory '${APP_DIR}' does not exist."
    echo "Please run './scripts/create_backstage_app.sh' first to create a Backstage app."
    exit 1
fi

read -p "Enter Docker image name [${DEFAULT_IMAGE_NAME}]: " IMAGE_NAME
IMAGE_NAME=${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}

read -p "Enter Docker image tag [${DEFAULT_IMAGE_TAG}]: " IMAGE_TAG
IMAGE_TAG=${IMAGE_TAG:-$DEFAULT_IMAGE_TAG}

FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo ""
echo "Building Backstage backend for: ${APP_DIR}"
echo "Docker image: ${FULL_IMAGE_NAME}"
echo ""

# Navigate to the app directory
cd "${APP_DIR}"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    yarn install --frozen-lockfile
    echo ""
fi

# Build the backend
echo "Building backend bundle..."
echo "Running: yarn build:backend"
yarn build:backend

echo ""
echo "Backend bundle built successfully!"
echo ""

# Build Docker image
echo "Building Docker image..."
DOCKERFILE_PATH="../backstage/Dockerfile"

if [ ! -f "${DOCKERFILE_PATH}" ]; then
    echo "Error: Dockerfile not found at ${DOCKERFILE_PATH}"
    exit 1
fi

docker build -f "${DOCKERFILE_PATH}" -t "${FULL_IMAGE_NAME}" .

echo ""
echo "================================================"
echo "Docker image built successfully!"
echo "================================================"
echo "Image: ${FULL_IMAGE_NAME}"
echo ""

# Ask if user wants to run the container
read -p "Do you want to run the container locally? (y/N): " RUN_CONTAINER

if [[ $RUN_CONTAINER =~ ^[Yy]$ ]]; then
    echo ""
    echo "Starting container..."
    PORT=7007
    CONTAINER_NAME="backstage-local"
    
    # Stop and remove existing container if it exists
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
    
    # Run the container
    docker run -d \
        --name "${CONTAINER_NAME}" \
        -p "${PORT}:7007" \
        "${FULL_IMAGE_NAME}"
    
    echo ""
    echo "================================================"
    echo "Container started successfully!"
    echo "================================================"
    echo "Container name: ${CONTAINER_NAME}"
    echo "Access the application at: http://localhost:${PORT}"
    echo ""
    echo "Useful commands:"
    echo "  View logs:    docker logs -f ${CONTAINER_NAME}"
    echo "  Stop:         docker stop ${CONTAINER_NAME}"
    echo "  Remove:       docker rm ${CONTAINER_NAME}"
    echo ""
else
    echo ""
    echo "To run the container manually:"
    echo "  docker run -p 7007:7007 ${FULL_IMAGE_NAME}"
    echo ""
fi

cd ..
