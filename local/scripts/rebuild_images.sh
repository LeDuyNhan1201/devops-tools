#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Configuration
# -------------------------------

MODE="${1:-dev}"
export MODE
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DEPLOYMENT_DIR="$(dirname "$ROOT_DIR")"

ENV_FILE="${ROOT_DIR}/helper/env_config.sh"

# shellcheck source=/helper/env_config.sh
source "${ENV_FILE}"

IMAGE_PREFIX="${NAMESPACE}/${REPOSITORY_NAME}"

# -------------------------------
# Remove Docker Images
# -------------------------------

docker rmi "${IMAGE_PREFIX}/postgres:${POSTGRES_TAG}" || true
docker rmi "${IMAGE_PREFIX}/keycloak:${KEYCLOAK_TAG}" || true

docker build \
  --build-arg POSTGRES_TAG="${POSTGRES_TAG}" \
  -f postgres/Dockerfile \
  -t "${IMAGE_PREFIX}/postgres:${POSTGRES_TAG}" \
  . || true

docker build \
  --build-arg KEYCLOAK_TAG="${KEYCLOAK_TAG}" \
  -f keycloak/Dockerfile \
  -t "${IMAGE_PREFIX}/keycloak:${KEYCLOAK_TAG}" \
  . || true

echo "Renew local images completed successfully."
