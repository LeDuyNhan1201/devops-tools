# Kafka SASL Learned

## JAAS configuration

- Kafka uses JAAS for SASL authentication on both brokers and clients.
- Mechanisms named across the source notes:
  - `GSSAPI` (Kerberos)
  - `PLAIN`
  - `SCRAM-SHA-256`
  - `SCRAM-SHA-512`
  - `OAUTHBEARER`

| Scope | Method | Details |
| --- | --- | --- |
| Broker | Static JAAS file | Use `KafkaServer`. For listener-specific config, use `{listenerName}.KafkaServer` such as `sasl_ssl.KafkaServer`. |
| Broker | Direct property | Use `listener.name.{listenerName}.{saslMechanism}.sasl.jaas.config`. |
| Client | Direct property | Set `sasl.jaas.config` in client properties. Preferred when multiple clients in one JVM need different credentials. |
| Client | Static JAAS file | Use `KafkaClient`, then pass `-Djava.security.auth.login.config=/path/to/jaas.conf` to the JVM. |

| Broker JAAS precedence | Source rule |
| --- | --- |
| 1 | Broker property `sasl.jaas.config` |
| 2 | `{listenerName}.KafkaServer` section in the JAAS file |
| 3 | `KafkaServer` section in the JAAS file |

- Client note:
  - `sasl.jaas.config` overrides the static JAAS file if both are present.
- Limitation:
  - each `sasl.jaas.config` entry supports only one login module.
- Multi-mechanism static JAAS note:
  - when using a JAAS file for a broker that supports multiple mechanisms, include the required login modules in the `KafkaServer` section.

## SASL configuration

| Area | Facts from the merged notes |
| --- | --- |
| Transport protocols | `SASL_PLAINTEXT`, `SASL_SSL` |
| SSL note | If `SASL_SSL` is used, SSL must also be configured. |
| Supported mechanisms listed | `GSSAPI`, `PLAIN`, `SCRAM-SHA-256`, `SCRAM-SHA-512`, `OAUTHBEARER` |
| Inter-broker transport | If brokers authenticate each other via SASL, `security.inter.broker.protocol` must be set to a SASL protocol. |
| Inter-broker mechanism | If multiple mechanisms are enabled, use `sasl.mechanism.inter.broker.protocol` to choose the broker-to-broker mechanism. |
| Broker enabled mechanisms | Use `sasl.enabled.mechanisms` to list supported mechanisms. |
| API support | SASL is supported only for the new Java Kafka producer and consumer; older APIs are not supported. |

- DNS caveat:
  - use fully qualified domain names for `bootstrap.servers` and `advertised.listeners`
  - otherwise SASL handshakes may be slowed by JRE reverse DNS lookups

- OAUTHBEARER production hardening called out by the notes:
  - use `SASL_SSL`
  - implement `AuthenticateCallbackHandler` on the client login side
  - implement `AuthenticateCallbackHandler` on the broker validator side
  - do not rely on Kafka’s default unsecured JWT behavior in production

## Authentication using SASL/OAUTHBEARER

- Purpose:
  - Kafka can use OAuth 2.0 tokens from an identity provider so non-HTTP Kafka clients can authenticate with third-party issued tokens.
- Principal mapping:
  - by default, `principalName` from `OAuthBearerToken` becomes the authenticated `Principal`
  - that principal is then used for ACLs and other authorization decisions
- Security caveat:
  - the default implementation uses unsecured JWTs
  - that default is for testing or non-production only
  - production should use a real OAuth 2.0-compliant IdP with production-ready handlers

### Broker setup

1. Create a JAAS file:

```java
KafkaServer {
    org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;
};
```

2. Pass the JAAS file to the broker JVM:

```bash
-Djava.security.auth.login.config=/etc/kafka/kafka_server_jaas.conf
```

3. Configure listener and validation properties:

| Purpose | Property / example |
| --- | --- |
| Listener | `listeners=SASL_SSL://host.name:port` |
| Enable mechanism | `sasl.enabled.mechanisms=OAUTHBEARER` |
| Listener-scoped server callback handler | `listener.name.<name>.oauthbearer.sasl.server.callback.handler.class=org.apache.kafka.common.security.oauthbearer.OAuthBearerValidatorCallbackHandler` |
| Listener-scoped JWKS endpoint | `listener.name.<name>.oauthbearer.sasl.oauthbearer.jwks.endpoint.url=https://example.com/oauth2/v1/keys` |

### Important OAUTHBEARER properties

| Category | Properties named in the notes |
| --- | --- |
| Validation | `sasl.oauthbearer.expected.audience`, `sasl.oauthbearer.expected.issuer` |
| Timing | `sasl.oauthbearer.clock.skew.seconds` |
| JWKS management | `sasl.oauthbearer.jwks.endpoint.url`, `sasl.oauthbearer.jwks.endpoint.refresh.ms` |
| Retry/backoff | `sasl.oauthbearer.jwks.endpoint.retry.backoff.ms`, `sasl.oauthbearer.jwks.endpoint.retry.backoff.max.ms` |
| Claim mapping | `sasl.oauthbearer.scope.claim.name`, `sasl.oauthbearer.sub.claim.name` |

### Client setup

| Area | Notes |
| --- | --- |
| Preferred JAAS supply | Set `sasl.jaas.config` directly in producer/consumer properties |
| JVM-wide JAAS supply | Use `-Djava.security.auth.login.config` with `KafkaClient` when one credential set for the whole JVM is acceptable |
| Required client transport in production | `security.protocol=SASL_SSL` |
| Mechanism | `sasl.mechanism=OAUTHBEARER` |
| Token endpoint | `sasl.oauthbearer.token.endpoint.url` |
| Login handler | `sasl.login.callback.handler.class` |

| OAuth 2.0 flow | Retriever class | Required fields named in the notes |
| --- | --- | --- |
| Client Credentials Grant | `ClientCredentialsJwtRetriever` | `client.id`, `client.secret`, `scope`, `token.endpoint.url` |
| JWT Bearer Grant | `JwtBearerJwtRetriever` | `assertion.private.key.file`, `assertion.algorithm`, `token.endpoint.url` |

- Dependency note:
  - the default implementation requires `jackson-databind`
  - the notes say it is an optional dependency that must be added manually to the build

### Token refresh

- Kafka refreshes OAUTHBEARER tokens before expiry.
- Refresh behavior is controlled by:
  - `sasl.login.refresh.window.factor`
  - `sasl.login.refresh.window.jitter`
  - `sasl.login.refresh.min.period.seconds`

## Enabling multiple SASL mechanisms in a broker

- A single broker can support multiple SASL mechanisms at the same time.
- Example broker setting from the notes:

```properties
sasl.enabled.mechanisms=GSSAPI,PLAIN,SCRAM-SHA-256
```

### Configuration rules

| Case | Rule |
| --- | --- |
| Static JAAS file | Put the required login modules in the broker’s `KafkaServer` section. |
| Direct listener-scoped JAAS property | Provide a separate `listener.name.{listenerName}.{saslMechanism}.sasl.jaas.config` for each mechanism. |
| Inter-broker mechanism selection | Set `sasl.mechanism.inter.broker.protocol=<mechanism>`. |

- Related constraint:
  - each `sasl.jaas.config` entry can declare only one login module

## Modifying SASL mechanism in a Running Cluster

- The merged notes describe a multi-stage rolling restart to avoid downtime.

| Stage | Action |
| --- | --- |
| 1 | Add the new mechanism to `sasl.enabled.mechanisms` and add the required JAAS configuration, then restart brokers one by one |
| 2 | Update clients to use the new mechanism and restart those clients |
| 3 | If inter-broker auth also needs to change, update `sasl.mechanism.inter.broker.protocol` and roll brokers again |
| 4 | After the migration is stable, remove the old mechanism and do a final rolling restart |

- Coordination note:
  - brokers can expose old and new mechanisms during transition
  - clients should move before the old mechanism is removed

## Authentication using Delegation Tokens

- Delegation tokens are a lightweight alternative for distributed clients when distributing Kerberos keytabs or SSL certificates to every worker is difficult.
- Strong initial authentication is still required to obtain or manage a token.

### Workflow

1. A user authenticates through SASL or SSL and requests a token through Admin APIs or CLI.
2. The user distributes the token to workers or clients.
3. Clients authenticate with the token as a shared secret.
4. Tokens can be renewed or cancelled by the owner or an allowed renewer.

### Broker-side management and security

| Feature | Detail |
| --- | --- |
| Shared secret | `delegation.token.secret.key` must be identical across all brokers and controllers |
| Storage | Tokens are stored in metadata; the secret key is currently plain text in `server.properties` |
| Renewal interval default | renew every 24 hours via `delegation.token.expiry.time.ms` |
| Maximum lifetime default | 7 days via `delegation.token.max.lifetime.ms` |
| Cleanup | expired or cancelled tokens are automatically removed from broker caches |

- Security caveat:
  - delegation tokens are safer when controllers are on a private network, or when all inter-node communication is encrypted, because the secret key is stored in plain text

### Operational rules

- Token operations must run over SASL- or SSL-authenticated channels.
- A session already authenticated with a delegation token cannot request another delegation token.
- Permissions noted in the merged notes:
  - owners and renewers can renew, expire, or describe their own tokens
  - describing someone else’s token requires `DESCRIBE_TOKEN` on the target User resource

### CLI examples

| Action | Example command component |
| --- | --- |
| Create | `--create --max-life-time-period -1 --renewer-principal User:user1` |
| Renew | `--renew --renew-time-period -1 --hmac <token_hmac>` |
| Expire | `--expire --expiry-time-period -1 --hmac <token_hmac>` |
| Describe | `--describe --owner-principal User:user1` |

### Authentication model

- Delegation-token authentication uses SASL/SCRAM.
- Requirement:
  - the cluster must already have SASL/SCRAM enabled
- Credential mapping:
  - token ID is the username
  - token HMAC is the password

### Client configuration

| Method | Guidance |
| --- | --- |
| `sasl.jaas.config` in client properties | Recommended; allows multiple clients in the same JVM to use different tokens |
| `-Djava.security.auth.login.config` | Uses `KafkaClient` and limits the JVM to one token for all Kafka connections |

Example:

```properties
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="tokenID123" \
    password="lAYYSFmLs4bTjf+lTZ1LCHR/ZZFNA==" \
    tokenauth="true";
```

| JAAS field | Meaning |
| --- | --- |
| `username` | token ID |
| `password` | token HMAC |
| `tokenauth="true"` | tells the server to treat the SCRAM credentials as a delegation token |

### Core Summary

- JAAS is the configuration layer Kafka uses for SASL authentication on brokers and clients.
- `sasl.jaas.config` is the most specific JAAS source and overrides static JAAS file entries; each such entry supports one login module.
- Brokers can support multiple SASL mechanisms at once with `sasl.enabled.mechanisms`; choose the broker-to-broker mechanism with `sasl.mechanism.inter.broker.protocol`.
- Listener-scoped JAAS for multiple mechanisms uses `listener.name.{listenerName}.{saslMechanism}.sasl.jaas.config`.
- OAUTHBEARER’s default unsecured JWT behavior is non-production; production requires `SASL_SSL`, custom handlers, and a real IdP.
- OAUTHBEARER client behavior in the notes covers token endpoint config, login callback handling, supported grant styles, and token refresh settings.
- Delegation tokens are lightweight SASL/SCRAM-based credentials, but they still depend on a secure initial authentication path and careful shared-secret handling.
