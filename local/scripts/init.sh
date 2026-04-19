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
# shellcheck source=/helper/generate_keypair.sh
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
generate_cert_with_keystore_and_truststore "postgres" "postgres" "${POSTGRES_HOSTNAME}"
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
  -f postgres/Dockerfile \
  -t "${IMAGE_PREFIX}/postgres:${POSTGRES_TAG}" \
  . || true

docker build \
  --build-arg KEYCLOAK_TAG="${KEYCLOAK_TAG}" \
  -f keycloak/Dockerfile \
  -t "${IMAGE_PREFIX}/keycloak:${KEYCLOAK_TAG}" \
  . || true

echo "Initialize completed successfully."