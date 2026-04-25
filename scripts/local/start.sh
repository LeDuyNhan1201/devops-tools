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
FUNCTIONS_FILE="${HELPER_DIR}/functions.sh"

# -------------------------------
# Load Environment & Helpers
# -------------------------------

# shellcheck source=scripts/local/helper/env_config.sh
source "${ENV_FILE}"
# shellcheck source=scripts/local/helper/functions.sh
source "${FUNCTIONS_FILE}"

# -------------------------------
# Generate Environment
# -------------------------------

create_files_from_templates
create_env_file
create_secrets

# -------------------------------
# Start Containers
# -------------------------------

docker compose \
  --env-file "${PROJECT_DIR}/.env" \
  -f "${PROJECT_DIR}/deployment/docker-compose.local.yml" \
  up -d

echo "Start completed successfully."
