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
CERT_SCRIPT="${HELPER_DIR}/generate_certs.sh"
KEYPAIR_SCRIPT="${HELPER_DIR}/generate_keypair.sh"

# -------------------------------
# Load Environment & Helpers
# -------------------------------

# shellcheck source=scripts/local/helper/env_config.sh
source "${ENV_FILE}"
# shellcheck source=scripts/local/helper/functions.sh
source "${FUNCTIONS_FILE}"
# shellcheck source=scripts/local/helper/generate_certs.sh
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
