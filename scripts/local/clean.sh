#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Configuration
# -------------------------------

MODE="${1:-dev}"
export MODE
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." >/dev/null 2>&1 && pwd)"
HELPER_DIR="${SCRIPT_DIR}/helper"
export PROJECT_DIR

ENV_FILE="${HELPER_DIR}/env_config.sh"

# shellcheck source=scripts/local/helper/env_config.sh
source "${ENV_FILE}"

IMAGE_PREFIX="${NAMESPACE}/${REPOSITORY_NAME}"

# -------------------------------
# Cleanup Files
# -------------------------------

echo "Removing certs, data and environment files..."

sudo rm -rf "${PROJECT_DIR}/secrets/"*
sudo rm -rf "${PROJECT_DIR}/data/"*
sudo rm -f "${PROJECT_DIR}/.env"

# -------------------------------
# Remove Docker Images
# -------------------------------

docker rmi "${IMAGE_PREFIX}/postgres:${POSTGRES_TAG}" || true
docker rmi "${IMAGE_PREFIX}/keycloak:${KEYCLOAK_TAG}" || true

echo "Cleanup completed successfully."
