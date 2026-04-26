#!/usr/bin/env bash
set -euo pipefail

# Usage: create_dir <use_sudo> <dir>
create_dir() {
  local use_sudo=$1
  local dir=$2

  if [ "$use_sudo" = true ]; then
    sudo mkdir -p "$dir"
    sudo chown -R 1000:1000 "$dir"
    sudo chmod -R 755 "$dir"
  else
    mkdir -p "$dir"
    chown -R 1000:1000 "$dir"
    chmod -R 755 "$dir"
  fi

  echo "Created $dir"
}

create_files_from_templates() {
  echo "Creating files from templates"

  local templates=(
    "${PROJECT_DIR}/services/kafka/templates/server.template:${PROJECT_DIR}/environments/local/kafka/configs/server.properties"
    "${PROJECT_DIR}/services/kafka/templates/client.template:${PROJECT_DIR}/environments/local/kafka/configs/client.properties"

    # TODO: Add more templates as needed, pattern is "source:destination"
  )

  for item in "${templates[@]}"; do
    IFS=":" read -r src dest <<< "$item"

    envsubst < "$src" > "$dest"
    echo "$src --> $dest"
  done

  echo "Files created successfully."
}

create_data_folders() {
  echo "Creating data folders"

  create_dir true "$DATA_DIR"
  create_dir true "$DATA_DIR/kafka0/logs"
  create_dir true "$DATA_DIR/kafka0/configs"
  create_dir true "$DATA_DIR/kafka0/data"
  create_dir true "$DATA_DIR/pgdata"

  # TODO: Add more data folders as needed"
}

create_secrets() {
  echo "Creating secrets"

  local secrets=(
    "kafka/kafka.secret:$CERT_SECRET"
    "postgres/postgres.password:$CERT_SECRET"

    # TODO: Add more secrets as needed, pattern is "path:value"
  )

  for item in "${secrets[@]}"; do
    IFS=":" read -r path value <<< "$item"
    local full_path="$SECRETS_DIR/$path"

    mkdir -p "$(dirname "$full_path")"
    printf "%s" "$value" > "$full_path"

    chmod 600 "$full_path"
    echo "Created $full_path"
  done
}

create_env_file() {
  echo "Creating env file"

  : > "${PROJECT_DIR}/.env"

  local vars=(
    LOCAL_IP
    GATEWAY_PORT
    KEYCLOAK_HOSTNAME
    KAFKA_UI_HOSTNAME
    ENVOY_HOSTNAME

    NAMESPACE
    REPOSITORY_NAME

    KEYCLOAK_TAG
    POSTGRES_TAG
    CONFLUENT_TAG
    APACHE_KAFKA_TAG
    ENVOY_TAG

    CERT_SECRET

    POSTGRES_USER
    POSTGRES_TEXT_PASSWORD

    MONGODB_USERNAME
    MONGODB_PASSWORD

    KC_BOOTSTRAP_ADMIN_USERNAME
    KC_BOOTSTRAP_ADMIN_PASSWORD

    KAFKA_OAUTH_LIB_VERSION
    NIMBUS_JWT_LIB_VERSION
    PROMETHEUS_JAVAAGENT_VERSION

    BROKER_HEAP
    SCHEMA_HEAP
    SSL_PRINCIPAL_MAPPING_RULES
    SSL_CIPHER_SUITES

    CLUSTER_ID
    KAFKA_IDP_TOKEN_ENDPOINT
    KAFKA_IDP_JWKS_ENDPOINT
    KAFKA_IDP_EXPECTED_ISSUER
    KAFKA_IDP_AUTH_ENDPOINT
    KAFKA_IDP_AUTH_DEVICE_ENDPOINT
    KAFKA_IDP_SUB_CLAIM_NAME
    KAFKA_IDP_SCOPE_CLAIM_NAME
    KAFKA_IDP_GROUP_CLAIM_NAME
    KAFKA_IDP_EXPECTED_AUDIENCE
    KAFKA_AUTHORIZER_CLASS
    KAFKA_PRINCIPAL_BUILDER_CLASS
    SASL_LOGIN_CALLBACK_HANDLER_CLASS
    SASL_SERVER_CALLBACK_HANDLER_CLASS
    KAFKA_DELEGATION_TOKEN_SECRET_KEY
    KAFKA_INTERNAL_SCRAM_USERNAME
    KAFKA_INTERNAL_SCRAM_PASSWORD

    KAFKA_SUPERUSER_CLIENT_ID
    KAFKA_SUPERUSER_CLIENT_SECRET

    KAFKA_SR_CLIENT_ID
    KAFKA_SR_CLIENT_SECRET

    KAFKA_C3_CLIENT_ID
    KAFKA_C3_CLIENT_SECRET

    KAFKA_SSO_CLIENT_ID
    KAFKA_SSO_CLIENT_SECRET

    KAFKA_BACKEND_CLIENT_ID
    KAFKA_BACKEND_CLIENT_SECRET

    KAFKA_SSO_SUPER_USER_GROUP
    KAFKA_SSO_USER_GROUP

    # TODO: Add more variables as needed
  )

  for var in "${vars[@]}"; do
    echo "$var=\"${!var}\"" >> "${PROJECT_DIR}/.env"
  done

  echo "Env file created successfully."
}
