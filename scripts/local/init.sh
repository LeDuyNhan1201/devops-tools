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
# shellcheck source=scripts/local/helper/generate_keypair.sh
source "${KEYPAIR_SCRIPT}"

# -------------------------------
# Generate Environment & Certificates
# -------------------------------

create_files_from_templates
create_env_file
create_secrets
create_data_folders

generate_root_ca
generate_cert_with_keystore_and_truststore "envoy" "envoy" "${ENVOY_HOSTNAME}"
generate_cert_with_keystore_and_truststore "postgres" "postgres"
generate_cert_with_keystore_and_truststore "keycloak" "keycloak" "${KEYCLOAK_HOSTNAME}"
generate_cert_with_keystore_and_truststore "kafka-ui" "kafka-ui" "${KAFKA_UI_HOSTNAME}"
generate_cert_with_keystore_and_truststore "kafka0" "kafka0" "kafka0.${NAMESPACE}.${MODE}"
generate_cert_with_keystore_and_truststore "kafka1" "kafka1" "kafka1.${NAMESPACE}.${MODE}"
generate_cert_with_keystore_and_truststore "kafka2" "kafka2" "kafka2.${NAMESPACE}.${MODE}"

generate_jwt_keypair kafka kafka true

# -------------------------------
# Docker Image Build
# -------------------------------

IMAGE_PREFIX="${NAMESPACE}/${REPOSITORY_NAME}"

docker build \
  --build-arg POSTGRES_TAG="${POSTGRES_TAG}" \
  -f "${PROJECT_DIR}/services/postgres/Dockerfile" \
  -t "${IMAGE_PREFIX}/postgres:${POSTGRES_TAG}" \
  "${PROJECT_DIR}" || true

docker build \
  --build-arg KEYCLOAK_TAG="${KEYCLOAK_TAG}" \
  -f "${PROJECT_DIR}/services/keycloak/Dockerfile" \
  -t "${IMAGE_PREFIX}/keycloak:${KEYCLOAK_TAG}" \
  "${PROJECT_DIR}" || true

echo "Initialize completed successfully."
