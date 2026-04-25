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

# -------------------------------
# Stop
# -------------------------------

docker compose \
  --env-file "${PROJECT_DIR}/.env" \
  -f "${PROJECT_DIR}/deployment/docker-compose.local.yml" \
  down -v

echo "Stop completed successfully."
