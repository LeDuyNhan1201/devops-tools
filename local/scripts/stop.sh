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

# shellcheck source=/helper/env_config.sh
source "${ENV_FILE}"

# -------------------------------
# Stop
# -------------------------------

# docker compose -f docker-compose/docker-compose."${MODE}".yml down -v
docker compose -f docker-compose/docker-compose.yml down -v

echo "Stop completed successfully."
