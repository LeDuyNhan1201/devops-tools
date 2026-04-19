#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Configuration
# -------------------------------

MODE="${1:-dev}"
export MODE
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

ENV_FILE="${ROOT_DIR}/helper/env_config.sh"
FUNCTIONS_FILE="${ROOT_DIR}/helper/functions.sh"

# -------------------------------
# Load Environment & Helpers
# -------------------------------

# shellcheck source=/helper/env_config.sh
source "${ENV_FILE}"
# shellcheck source=/helper/functions.sh
source "${FUNCTIONS_FILE}"

# -------------------------------
# Generate Environment
# -------------------------------

create_client_files
create_env_file
create_secrets

# -------------------------------
# Start Containers
# -------------------------------

#docker compose -f docker-compose/docker-compose."${MODE}".yml up -d
docker compose -f docker-compose/docker-compose.yml up -d

echo "Start completed successfully."