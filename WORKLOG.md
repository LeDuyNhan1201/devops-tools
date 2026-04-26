# WORKLOG

## Project Snapshot
- Name: `devops-tools`
- Current Status: local folder refactor and startup validation completed; working tree is not yet committed; local generated artifacts exist in `.env`, `secrets/`, `keypair/`, and `data/`
- Key Stack: Docker Compose, Bash scripts, Envoy, Postgres, Keycloak, Kafka config/templates, Grafana, Loki, Tempo, Prometheus, OpenTelemetry Collector, Logstash
- Main Structure: `deployment/`, `scripts/local/`, `services/`, `environments/local/`, `observability/`

## Recent History

### [2026-04-26 22:32]
Task: Align Kafka OAUTHBEARER validation settings with the learned broker property set
Done:
- `deployment/kafka.dev.yml`: added broker-level `sasl.oauthbearer.clock.skew.seconds` and `sasl.oauthbearer.jwks.endpoint.refresh.ms` env wiring, reused the same values in the EXTERNAL listener JAAS block, and corrected misleading comments about controller and INTERNAL auth behavior
- `scripts/local/helper/env_config.sh`: added local defaults for Kafka OAuth clock skew and JWKS refresh intervals
- `scripts/local/helper/functions.sh`: added the new OAuth timing vars to generated `.env`
- `services/kafka/templates/server.template`: corrected the broker property name from `sasl.oauthbearer.jwks.endpoint.uri` to `sasl.oauthbearer.jwks.endpoint.url` and added the missing native broker claim-mapping / timing properties
- `environments/local/kafka/configs/server.properties`: regenerated the checked-in local broker reference config to match the corrected template
Impact:
- prevents Kafka broker OAuth validation from relying on an incorrect reference property name and keeps the broker-level OAUTHBEARER validation settings aligned with the listener JAAS behavior already in use
Next:
- leave Kafka client token-refresh properties on Kafka defaults unless a shorter token lifetime or IdP-specific refresh issue requires explicit tuning

### [2026-04-26 13:34]
Task: Replace INTERNAL delegation-token placeholders with best-practice inter-broker SCRAM credentials
Done:
- `deployment/kafka.dev.yml`: kept `SCRAM-SHA-256` on the INTERNAL listener and inter-broker path, but replaced the invalid delegation-token JAAS fields with a standard `ScramLoginModule` username/password config for broker-to-broker auth
- `scripts/local/helper/env_config.sh`: replaced `KAFKA_INTERNAL_DELEGATION_TOKEN_ID` and `KAFKA_INTERNAL_DELEGATION_TOKEN_HMAC` with concrete local dev values for `KAFKA_INTERNAL_SCRAM_USERNAME` and `KAFKA_INTERNAL_SCRAM_PASSWORD`
- `scripts/local/helper/functions.sh`: updated generated `.env` output to carry the new INTERNAL SCRAM vars
- `README.md`: corrected the Kafka note so INTERNAL broker auth is documented as SCRAM bootstrap auth, not delegation-token auth
Impact:
- removes an invalid inter-broker token-auth bootstrap path and aligns the INTERNAL listener with Kafka’s documented pre-start SCRAM credential flow
Next:
- ensure the INTERNAL SCRAM user is created in Kafka storage/bootstrap before starting the broker, since config alone does not create SCRAM credentials

### [2026-04-26 13:19]
Task: Switch INTERNAL broker SASL to delegation-token SCRAM while leaving other listeners unchanged
Done:
- `deployment/kafka.dev.yml`: changed broker-wide enabled mechanisms to `OAUTHBEARER,SCRAM-SHA-256`, switched `KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL` to `SCRAM-SHA-256`, replaced the INTERNAL listener OAUTHBEARER JAAS config with listener-scoped `ScramLoginModule` token-auth config, and removed the now-wrong global OAuth callback handler wiring from the broker env
- `scripts/local/helper/env_config.sh`: added `KAFKA_INTERNAL_DELEGATION_TOKEN_ID` and `KAFKA_INTERNAL_DELEGATION_TOKEN_HMAC` so local `.env` generation can carry the delegation-token credentials needed by the INTERNAL listener
- `scripts/local/helper/functions.sh`: added the new INTERNAL delegation-token vars to generated `.env`
- `README.md`: documented that EXTERNAL stays OAUTHBEARER while INTERNAL now requires delegation-token SCRAM credentials in `env_config.sh`
Impact:
- aligns the INTERNAL listener and inter-broker mechanism with delegation-token SCRAM requirements while leaving the EXTERNAL OAUTHBEARER listener unchanged
Next:
- populate `KAFKA_INTERNAL_DELEGATION_TOKEN_ID` and `KAFKA_INTERNAL_DELEGATION_TOKEN_HMAC` with real delegation-token values before starting Kafka, or the INTERNAL broker auth path will not succeed

### [2026-04-26 13:07]
Task: Add SCRAM/delegation-token prerequisite knowledge and local Kafka secret-key plumbing
Done:
- `learn/kafka_sasl_learned.md`: merged the SCRAM summary into the learned note, including credential storage, lifecycle commands, TLS guidance, and callback-handler caveats
- `scripts/local/helper/env_config.sh`: added `KAFKA_DELEGATION_TOKEN_SECRET_KEY` derived from the local dev secret so delegation-token support has a shared broker/controller key
- `scripts/local/helper/functions.sh`: added `KAFKA_DELEGATION_TOKEN_SECRET_KEY` to generated `.env` output
- `deployment/kafka.dev.yml`: wired `KAFKA_DELEGATION_TOKEN_SECRET_KEY` into the Kafka broker environment
Impact:
- prevents delegation-token broker setup from missing its required shared secret while keeping the current listener mechanisms unchanged until real SCRAM/token credentials are available
Next:
- if internal broker auth should actually switch to delegation tokens, create real SCRAM/delegation token credentials first, then replace the INTERNAL listener OAUTHBEARER JAAS/mechanism settings with SCRAM token-auth settings

### [2026-04-26 12:38]
Task: Restore Kafka client mTLS compatibility with `KAFKA_SSL_CLIENT_AUTH='required'`
Done:
- `services/kafka/templates/client.template`: added client-side `ssl.keystore.*` and `ssl.key.password` so the generated OAUTHBEARER client config can present a certificate over `SASL_SSL`
- `environments/local/kafka/configs/client.properties`: regenerated the checked-in local Kafka client config with the same keystore settings
- `deployment/kafka.dev.yml`: restored `KAFKA_SSL_CLIENT_AUTH: 'required'` now that the checked-in client config is mTLS-capable again
- `README.md`: documented that Kafka clients now need both `keystore.p12` and `truststore.p12` mounted at `/etc/kafka/secrets/` when using the generated client config against brokers that require client certificates
Impact:
- prevents Kafka TLS handshake failure when brokers require client certificates and the generated client config is used as the connection baseline
Next:
- use a client certificate directory that exposes `keystore.p12` and `truststore.p12` at `/etc/kafka/secrets/` wherever `environments/local/kafka/configs/client.properties` is consumed

### [2026-04-26 12:27]
Task: Audit Kafka SASL scripts and `kafka.dev.yml` against learned notes
Done:
- `scripts/local/helper/generate_certs.sh`: added stable `keystore.p12` and `truststore.p12` symlinks beside the service-specific PKCS12 outputs so Kafka mounts and generated configs resolve the expected paths on repeat runs
- `deployment/kafka.dev.yml`: changed the Kafka config bind mount to `environments/local/kafka/configs`, removed the obsolete `kafka.secret` file mount that conflicted with the cert directory mount, and added listener-scoped OAUTHBEARER server callback handler env vars
- `README.md`: documented the generated Kafka PKCS12 aliases used by the Kafka mounts/configs
Impact:
- prevents missing keystore/truststore path failures and removes a dead/conflicting secret mount while keeping the Kafka OAUTHBEARER listener wiring explicit
Next:
- rerun `make -f deployment/Makefile init` or `make -f deployment/Makefile renew-certs SERVER_NAME=kafka0` before using `deployment/kafka.dev.yml` so the Kafka PKCS12 aliases are present in the generated cert directory

### [2026-04-25 19:48]
Task: Audit Kafka SSL scripts and `kafka.dev.yml`
Done:
- `services/kafka/templates/server.template`: switched Kafka OAuth placeholders to the existing canonical vars `KAFKA_IDP_EXPECTED_AUDIENCE` and `KAFKA_IDP_SUB_CLAIM_NAME`
- `deployment/kafka.dev.yml`: removed `creds.txt` password-file references because the local secret generation flow creates `secrets/kafka/kafka.secret`, not `creds.txt`; also corrected `KAFKA_IDP_AUTH_DEVICE_ENDPOINT` usage in `KAFKA_OPTS`
- `environments/local/kafka/configs/server.properties`: regenerated from the fixed script env so the checked-in local Kafka server config now contains concrete audience and principal values
Impact:
- prevents broken Kafka OAuth configuration, avoids runtime references to a mismatched credential filename, and fixes an empty allowed-URLs entry in Kafka OAuth startup options
Next:
- decide whether `KAFKA_SSL_CLIENT_AUTH: 'required'` is intentional; the current Kafka client template is truststore-only, so strict mTLS would still require a client keystore path/config before those clients can connect

### [Approx 2026-04-25 17:30]
Task: Validate local stack after path changes
Done:
- fixed stale startup helper call in `start.sh` (`create_client_files` -> `create_files_from_templates`)
- removed undefined `POSTGRES_HOSTNAME` dependency from local init cert generation
- validated shell syntax, Compose config, Postgres and Keycloak image builds, real startup, health, and clean shutdown
- confirmed running local Compose services were `envoy`, `postgres`, `keycloak0`, `keycloak1`, `keycloak2`
Files:
- `scripts/local/start.sh`
- `scripts/local/init.sh`
- `.env`
- `secrets/`
- `keypair/`
Impact:
- local startup/shutdown flow now works end-to-end against the refactored paths
Next:
- stage and commit the validated refactor if this repo state should become canonical

### [Approx 2026-04-25 17:00]
Task: Refactor project structure by responsibility
Done:
- replaced old `general/` + `local/` split with clearer top-level areas: `services/`, `observability/`, `environments/local/`, `scripts/local/`
- moved service assets, local runtime configs, and observability configs without changing business logic
- updated path-sensitive script, Makefile, and Compose references to resolve from repo root
Files:
- `deployment/Makefile`
- `deployment/docker-compose.local.yml`
- `scripts/local/`
- `services/`
- `environments/local/`
- `observability/`
Impact:
- the repo is easier to scan and maintain; path resolution is explicit instead of relying on the old mixed layout
Next:
- validate local runtime after the move and patch only path regressions

### [2026-04-19 20:47]
Task: Add initial local stack assets
Done:
- added `.gitignore`, `deployment/Makefile`, and `deployment/docker-compose.local.yml`
- added service assets under the original `general/` tree for Kafka, Keycloak, Postgres, Logstash, and observability tools
- added local runtime configs, Keycloak realm files, Postgres init/config files, and shell helpers under the original `local/` tree
Files:
- `.gitignore`
- `deployment/Makefile`
- `deployment/docker-compose.local.yml`
- `general/`
- `local/`
Impact:
- created the first runnable devops environment and helper script surface for local setup
Next:
- use the scripts and compose flow to stabilize local initialization/startup

### [2026-04-19 17:25]
Task: Initialize repository
Done:
- created base repository with `LICENSE` and minimal `README.md`
Files:
- `LICENSE`
- `README.md`
Impact:
- established the repo baseline for later stack setup work
Next:
- add actual deployment assets and local environment scripts

## Open Items
- stage/commit the current refactor, validation fixes, and `WORKLOG.md`
- decide whether any broader runtime coverage is needed beyond the current local Compose services

## Notes For Next Session
- current local startup was validated with `scripts/local/init.sh`, `scripts/local/start.sh`, and `scripts/local/stop.sh`
- current Compose file covers `envoy`, `postgres`, and a 3-node Keycloak cluster; Kafka and observability assets exist in the repo but are not part of `deployment/docker-compose.local.yml`
- generated local artifacts now exist under `.env`, `secrets/`, `keypair/`, and `data/`; they are local runtime state, not structural source changes
- git history only has two committed entries so far: `759c598` and `f08e754`; the refactor and startup validation are currently uncommitted work
