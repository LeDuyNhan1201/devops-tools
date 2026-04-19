ARG KEYCLOAK_TAG=latest

# ================= BUILD STAGE =================
FROM quay.io/keycloak/keycloak:${KEYCLOAK_TAG} AS builder

ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_DB=postgres
#ENV KC_HTTP_RELATIVE_PATH=/kc
ENV KC_FEATURES=http-optimized-serializers

WORKDIR /opt/keycloak

# Copy certificates
COPY --chown=keycloak:keycloak secrets/certs/ca/ca.crt conf/root.crt
COPY --chown=keycloak:keycloak secrets/certs/keycloak/keycloak.cert.pem conf/server.crt
COPY --chown=keycloak:keycloak secrets/certs/keycloak/keycloak.key.pem conf/server.key

RUN chmod 600 conf/server.key

# Copy custom providers (SPI)
# COPY providers/*.jar providers/

# Copy themes if needed
# COPY themes/ themes/

# Build optimized Keycloak distribution
RUN /opt/keycloak/bin/kc.sh build


# ================= RUNTIME STAGE =================
FROM quay.io/keycloak/keycloak:${KEYCLOAK_TAG}

WORKDIR /opt/keycloak

COPY --from=builder /opt/keycloak/ /opt/keycloak/

ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_DB=postgres

# TLS
#ENV KC_TLS_HOSTNAME_VERIFIER=DEFAULT
ENV KC_TLS_HOSTNAME_VERIFIER=ANY
#ENV KC_TRUSTSTORE_PATHS=/opt/keycloak/conf/truststores/truststore.pem
#ENV KC_HTTPS_CERTIFICATE_FILE=/opt/keycloak/conf/server.crt
#ENV KC_HTTPS_CERTIFICATE_KEY_FILE=/opt/keycloak/conf/server.key

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]