#!/bin/bash
set -e

# Script to scaffold a new Backstage.io application
# Runs the official Backstage scaffolding tool inside Docker so no local Node.js/Yarn install is required

echo "================================================"
echo "Backstage.io Application Scaffolding (Docker/Podman)"
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

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "${REPO_ROOT}"

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

DOCKER_IMAGE=${BACKSTAGE_CREATE_IMAGE:-node:20-bookworm}

echo "Using image: ${DOCKER_IMAGE}"
"${CONTAINER_RUNTIME}" pull "${DOCKER_IMAGE}" >/dev/null

# Only force UID/GID mapping when using Docker (Podman rootless already maps correctly)
USER_FLAG=""
if [ "${CONTAINER_RUNTIME}" = "docker" ] && command -v id >/dev/null 2>&1; then
    USER_FLAG="--user $(id -u):$(id -g)"
fi

CONTAINER_SCRIPT=$(cat <<'EOF'
set -e
cd /work
mkdir -p /tmp/yarn-shim
cat <<'SH' >/tmp/yarn-shim/yarn
#!/usr/bin/env bash
exec corepack yarn "$@"
SH
chmod +x /tmp/yarn-shim/yarn
cat <<'SH' >/tmp/yarn-shim/yarnpkg
#!/usr/bin/env bash
exec /tmp/yarn-shim/yarn "$@"
SH
chmod +x /tmp/yarn-shim/yarnpkg
export PATH="/tmp/yarn-shim:$PATH"
npx @backstage/create-app@latest --path "$BACKSTAGE_APP_NAME"
EOF
)

"${CONTAINER_RUNTIME}" run --rm -it \
    ${USER_FLAG} \
    -e BACKSTAGE_APP_NAME="${APP_NAME}" \
    -v "${REPO_ROOT}:/work" \
    -w /work \
    "${DOCKER_IMAGE}" \
    bash -lc "${CONTAINER_SCRIPT}"

echo ""
echo "================================================"
echo "Backstage app created successfully!"
echo "================================================"
echo ""
echo "Your app is located at: ${REPO_ROOT}/${APP_NAME}"
echo "Next steps:"
echo "  1. (Optional) cd ${APP_NAME} && yarn dev   # requires Node/Yarn locally"
echo "  2. Run '../scripts/build_and_run_docker.sh' to build and run via Docker"
echo "  3. Run '../scripts/deploy_to_azure_container_apps.sh' to deploy to Azure"
echo ""
