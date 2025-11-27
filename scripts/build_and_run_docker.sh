#!/bin/bash
set -e

# Script to build and optionally run the Backstage Docker image
# All installs/builds happen inside Docker/Podman for reproducibility

echo "================================================"
echo "Backstage Backend Docker Build"
echo "================================================"
echo ""

# Detect container runtime (Docker preferred, Podman fallback)
if [ -n "${CONTAINER_RUNTIME:-}" ]; then
    if ! command -v "${CONTAINER_RUNTIME}" >/dev/null 2>&1; then
        echo "Error: Container runtime '${CONTAINER_RUNTIME}' not found in PATH."
        exit 1
    fi
else
    for candidate in docker podman; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            CONTAINER_RUNTIME="${candidate}"
            break
        fi
    done
fi

if [ -z "${CONTAINER_RUNTIME:-}" ]; then
    echo "Error: Neither Docker nor Podman is installed or available in PATH."
    exit 1
fi

echo "Using container runtime: ${CONTAINER_RUNTIME}"

# Default values
DEFAULT_APP_DIR="backstage-app"
DEFAULT_IMAGE_NAME="backstage"
DEFAULT_IMAGE_TAG="latest"

# Move to repo root so relative paths are predictable
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "${REPO_ROOT}"

# Use env overrides for non-interactive usage
if [ -n "${BACKSTAGE_APP_DIR:-}" ]; then
    APP_DIR="${BACKSTAGE_APP_DIR}"
    echo "Using Backstage app directory from BACKSTAGE_APP_DIR: ${APP_DIR}"
else
    read -p "Enter the Backstage app directory [${DEFAULT_APP_DIR}]: " APP_DIR
    APP_DIR=${APP_DIR:-$DEFAULT_APP_DIR}
fi

if [ ! -d "${APP_DIR}" ]; then
    echo "Error: Directory '${APP_DIR}' does not exist."
    echo "Please run './scripts/create_backstage_app.sh' first to create a Backstage app."
    exit 1
fi

if [ -n "${BACKSTAGE_IMAGE_NAME:-}" ]; then
    IMAGE_NAME="${BACKSTAGE_IMAGE_NAME}"
    echo "Using Docker image name from BACKSTAGE_IMAGE_NAME: ${IMAGE_NAME}"
else
    read -p "Enter Docker image name [${DEFAULT_IMAGE_NAME}]: " IMAGE_NAME
    IMAGE_NAME=${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}
fi

if [ -n "${BACKSTAGE_IMAGE_TAG:-}" ]; then
    IMAGE_TAG="${BACKSTAGE_IMAGE_TAG}"
    echo "Using Docker image tag from BACKSTAGE_IMAGE_TAG: ${IMAGE_TAG}"
else
    read -p "Enter Docker image tag [${DEFAULT_IMAGE_TAG}]: " IMAGE_TAG
    IMAGE_TAG=${IMAGE_TAG:-$DEFAULT_IMAGE_TAG}
fi

FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo ""
echo "Building Backstage backend from: ${APP_DIR}"
echo "Docker image: ${FULL_IMAGE_NAME}"
echo ""

# Build Docker image (multi-stage handles install + build inside Docker)
echo "Building Docker image..."
DOCKERFILE_PATH="backstage/Dockerfile"

if [ ! -f "${DOCKERFILE_PATH}" ]; then
    echo "Error: Dockerfile not found at ${DOCKERFILE_PATH}"
    exit 1
fi

"${CONTAINER_RUNTIME}" build \
    -f "${DOCKERFILE_PATH}" \
    --build-arg APP_DIR="${APP_DIR}" \
    -t "${FULL_IMAGE_NAME}" \
    .

echo ""
echo "================================================"
echo "Docker image built successfully!"
echo "================================================"
echo "Image: ${FULL_IMAGE_NAME}"
echo ""

# Ask if user wants to run the container
if [ -n "${RUN_CONTAINER:-}" ]; then
    RUN_CONTAINER_INPUT="${RUN_CONTAINER}"
else
    read -p "Do you want to run the container locally? (y/N): " RUN_CONTAINER_INPUT
fi

if [[ ${RUN_CONTAINER_INPUT} =~ ^[Yy]$ ]]; then
    echo ""
    echo "Starting container..."
    PORT=${BACKSTAGE_PORT:-7007}
    CONTAINER_NAME=${BACKSTAGE_CONTAINER_NAME:-backstage-local}
    REQUIRED_ENV_VARS=(BACKEND_SECRET AUTH_MICROSOFT_CLIENT_ID AUTH_MICROSOFT_CLIENT_SECRET AUTH_MICROSOFT_TENANT_ID)
    ENV_FLAGS=()
    for VAR_NAME in "${REQUIRED_ENV_VARS[@]}"; do
        VAR_VALUE=${!VAR_NAME:-}
        if [ -n "${VAR_VALUE}" ]; then
            ENV_FLAGS+=("-e" "${VAR_NAME}=${VAR_VALUE}")
        fi
    done

    # Stop and remove existing container if it exists
    "${CONTAINER_RUNTIME}" rm -f "${CONTAINER_NAME}" 2>/dev/null || true

    # Run the container
    "${CONTAINER_RUNTIME}" run -d \
        --name "${CONTAINER_NAME}" \
        -p "${PORT}:7007" \
        "${ENV_FLAGS[@]}" \
        "${FULL_IMAGE_NAME}"

    echo ""
    echo "================================================"
    echo "Container started successfully!"
    echo "================================================"
    echo "Container name: ${CONTAINER_NAME}"
    echo "Access the application at: http://localhost:${PORT}"
    echo ""
    echo "Useful commands:"
    echo "  View logs:    ${CONTAINER_RUNTIME} logs -f ${CONTAINER_NAME}"
    echo "  Stop:         ${CONTAINER_RUNTIME} stop ${CONTAINER_NAME}"
    echo "  Remove:       ${CONTAINER_RUNTIME} rm ${CONTAINER_NAME}"
    echo ""
else
    echo ""
    cat <<EOF
To run the container manually:
  ${CONTAINER_RUNTIME} run -p 7007:7007 \
      -e BACKEND_SECRET=... -e AUTH_MICROSOFT_CLIENT_ID=... \
      -e AUTH_MICROSOFT_CLIENT_SECRET=... -e AUTH_MICROSOFT_TENANT_ID=... \
      ${FULL_IMAGE_NAME}
EOF
    echo ""
fi
