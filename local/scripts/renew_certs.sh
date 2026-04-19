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
CERT_SCRIPT="${ROOT_DIR}/helper/generate_certs.sh"
KEYPAIR_SCRIPT="${ROOT_DIR}/helper/generate_keypair.sh"

# -------------------------------
# Load Environment & Helpers
# -------------------------------

# shellcheck source=/helper/env_config.sh
source "${ENV_FILE}"
# shellcheck source=/helper/functions.sh
source "${FUNCTIONS_FILE}"
# shellcheck source=/helper/generate_certs.sh
source "${CERT_SCRIPT}"

server_name="${2:? server_name is not set}"
server_dir="${CERTS_DIR}/${server_name}"

if [[ -d "$server_dir" ]]; then
    rm -rf "${server_dir:? server_dir is not set}"/*
else
    mkdir -p "$server_dir"
fi

# -------------------------------
# Generate Environment & Certificates
# -------------------------------

create_env_file
create_secrets

generate_cert_with_keystore_and_truststore "${server_name}" "${server_name}" "${server_name}.${NAMESPACE}.${MODE}"

echo "${server_name}'s certificates generated successfully."