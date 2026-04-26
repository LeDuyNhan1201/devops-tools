export NAMESPACE="leduynhan1201"
export REPOSITORY_NAME="devops-tool"

export KEYCLOAK_TAG=nightly # https://quay.io/repository/keycloak/keycloak?tab=tags
export POSTGRES_TAG=alpine3.23 # https://hub.docker.com/_/postgres/tags
export CONFLUENT_TAG=7.7.7 # https://hub.docker.com/r/confluentinc/cp-kafka/tags
export APACHE_KAFKA_TAG=4.2.1-rc3 # https://hub.docker.com/r/apache/kafka-native/tags
export ENVOY_TAG=tools-dev # https://hub.docker.com/r/envoyproxy/envoy/tags

LOCAL_IP=$(hostname -I | awk '{print $1}')
export LOCAL_IP
export GATEWAY_PORT=8889
export KEYCLOAK_HOSTNAME="keycloak.${NAMESPACE}.${MODE}"
export KAFKA_UI_HOSTNAME="kafka-ui.${NAMESPACE}.${MODE}"
export ENVOY_HOSTNAME="*.${NAMESPACE}.${MODE}"
export CA_NAME="LDNhanRootCA"
export SUBJ_C="VN"
export SUBJ_ST="BinhTriDong"
export SUBJ_L="HCM"
export SUBJ_O="SGU"
export SUBJ_OU="Devops"

export CERT_SECRET='@N120103#'
export PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
export SECRETS_DIR="${SECRETS_DIR:-${PROJECT_DIR}/secrets}"
export DATA_DIR="${DATA_DIR:-${PROJECT_DIR}/data}"
export CERTS_DIR="${CERTS_DIR:-${SECRETS_DIR}/certs}"
export KEYPAIR_DIR="${KEYPAIR_DIR:-${PROJECT_DIR}/keypair}"

export POSTGRES_USER=leduynhan1201
export POSTGRES_TEXT_PASSWORD='@N120103#'

export MONGODB_USERNAME=leduynhan1201
export MONGODB_PASSWORD='@N120103#'

export KC_BOOTSTRAP_ADMIN_USERNAME=leduynhan1201
export KC_BOOTSTRAP_ADMIN_PASSWORD='@N120103#'

# External Kafka library versions
export KAFKA_OAUTH_LIB_VERSION=0.15.1
export NIMBUS_JWT_LIB_VERSION=9.37.2
export PROMETHEUS_JAVAAGENT_VERSION=1.5.0

# Kafka advanced configurations
export BROKER_HEAP=1G
export SCHEMA_HEAP=512M
export SSL_PRINCIPAL_MAPPING_RULES="RULE:^CN=([a-zA-Z0-9._-]+).*$$/$$1/L,DEFAULT"
export SSL_CIPHER_SUITES=TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,TLS_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256

# IDP configurations
export CLUSTER_ID=${NAMESPACE}-${REPOSITORY_NAME}-cluster
export KAFKA_IDP_URL=https://${KEYCLOAK_HOSTNAME}:${GATEWAY_PORT}/
export KAFKA_IDP_REALM=kafka
export KAFKA_IDP_TOKEN_ENDPOINT=${KAFKA_IDP_URL}realms/${KAFKA_IDP_REALM}/protocol/openid-connect/token
export KAFKA_IDP_JWKS_ENDPOINT=${KAFKA_IDP_URL}realms/${KAFKA_IDP_REALM}/protocol/openid-connect/certs
export KAFKA_IDP_EXPECTED_ISSUER=${KAFKA_IDP_URL}realms/${KAFKA_IDP_REALM}
export KAFKA_IDP_AUTH_ENDPOINT=${KAFKA_IDP_URL}realms/${KAFKA_IDP_REALM}/protocol/openid-connect/auth
export KAFKA_IDP_AUTH_DEVICE_ENDPOINT=${KAFKA_IDP_URL}realms/${KAFKA_IDP_REALM}/protocol/openid-connect/auth/device
export KAFKA_IDP_CLOCK_SKEW_SECONDS=60
export KAFKA_IDP_JWKS_REFRESH_SECONDS=300
export KAFKA_IDP_JWKS_REFRESH_MS=300000
export KAFKA_IDP_SUB_CLAIM_NAME=sub
export KAFKA_IDP_SCOPE_CLAIM_NAME=scope
export KAFKA_IDP_GROUP_CLAIM_NAME=groups
export KAFKA_IDP_EXPECTED_AUDIENCE=account
export KAFKA_AUTHORIZER_CLASS=io.strimzi.kafka.oauth.server.authorizer.KeycloakAuthorizer
export KAFKA_PRINCIPAL_BUILDER_CLASS=io.strimzi.kafka.oauth.server.OAuthKafkaPrincipalBuilder
export SASL_LOGIN_CALLBACK_HANDLER_CLASS=io.strimzi.kafka.oauth.client.JaasClientOauthLoginCallbackHandler
export SASL_SERVER_CALLBACK_HANDLER_CLASS=io.strimzi.kafka.oauth.server.JaasServerOauthValidatorCallbackHandler
export KAFKA_DELEGATION_TOKEN_SECRET_KEY="${CERT_SECRET}"
export KAFKA_INTERNAL_SCRAM_USERNAME="broker"
export KAFKA_INTERNAL_SCRAM_PASSWORD='@N120103#-broker'

# Client configurations
export KAFKA_SUPERUSER_CLIENT_ID=kafka
export KAFKA_SUPERUSER_CLIENT_SECRET=kafka-secret

export KAFKA_SR_CLIENT_ID=schema-registry
export KAFKA_SR_CLIENT_SECRET=schema-registry-secret

export KAFKA_C3_CLIENT_ID=control-center
export KAFKA_C3_CLIENT_SECRET=control-center-secret

export KAFKA_SSO_CLIENT_ID=control-center-sso
export KAFKA_SSO_CLIENT_SECRET=control-center-sso-secret

export KAFKA_BACKEND_CLIENT_ID=backend
export KAFKA_BACKEND_CLIENT_SECRET=backend-secret

export KAFKA_SSO_SUPER_USER_GROUP=sso-users
export KAFKA_SSO_USER_GROUP=users
