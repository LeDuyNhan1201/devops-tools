# Kafka SSL Learned

Kafka SSL provides:
- Encryption for traffic between clients and brokers
- Authentication of clients and brokers
- SSL is disabled by default

## Generate SSL key and certificate for each Kafka broker

- Every broker needs its own public/private keypair in a keystore
- Use Java `keytool`
- Recommended/default keystore format: `PKCS12`
- `JKS` is deprecated in the source summary
- Keystores contain private keys; keep them secure
- Ideally generate the keystore directly on the broker it belongs to

Basic keypair generation:

```bash
keytool -keystore {keystorefile} -alias localhost -validity {validity} -genkey -keyalg RSA -storetype pkcs12
```

CSR flow:
- Generate a CSR from the broker keystore
- Have a CA sign the CSR
- Import the signed certificate back into the keystore

Key generation with SAN included:

```bash
keytool -keystore server.keystore.jks -alias localhost -validity {days} \
-genkey -keyalg RSA -destkeystoretype pkcs12 \
-ext SAN=DNS:{FQDN},IP:{IPADDRESS}
```

Notes:
- Configure SAN during initial key generation / CSR work
- Fixing hostname verification later is much harder

## Host Name Verification

- Purpose: confirm the client is connecting to the intended server and prevent Man-in-the-Middle attacks
- Enabled by default since Kafka `2.0.0`
- Client checks the server address against certificate identity fields

Identity fields:

| Field | Status | Notes |
| :--- | :--- | :--- |
| `SAN` (Subject Alternative Name) | Preferred | Supports multiple DNS and IP entries |
| `CN` (Common Name) | Deprecated | Deprecated since 2000; usage discouraged |

Disable hostname verification only if absolutely necessary:

```properties
ssl.endpoint.identification.algorithm=
```

Warning:
- Disabling hostname verification is not recommended

## Creating your own CA

- Production usually uses a corporate CA
- For a self-managed setup, create a self-signed CA

Why `openssl-ca.cnf` is needed:
- The source notes an OpenSSL `x509` bug that fails to copy SAN extensions
- Use the `ca` module instead
- Critical setting:

```text
copy_extensions = copy
```

- This preserves SAN from the request into the final signed certificate

CA tracking files:

```bash
echo 01 > serial.txt
touch index.txt
```

Generate the CA keypair:

```bash
openssl req -x509 -config openssl-ca.cnf -newkey rsa:4096 -sha256 -nodes -out cacert.pem -outform PEM
```

Critical warning:
- `cakey.pem` is the CA private key
- If it is compromised, an attacker can impersonate any node in the cluster

Keystore vs truststore:

| Feature | Keystore | Truststore |
| :--- | :--- | :--- |
| Purpose | Stores your identity | Stores CA certificates you trust |
| Contains | Private key + certificate | Trusted CA certs |
| Usage | Prove who you are | Verify who others are |

Import the CA into truststores:

Clients:

```bash
keytool -keystore client.truststore.jks -alias CARoot -import -file cacert.pem
```

Brokers (if `ssl.client.auth` is required):

```bash
keytool -keystore server.truststore.jks -alias CARoot -import -file cacert.pem
```

Trust model:
- Trusting the CA means trusting any certificate signed by that CA

## Signing the certificate

Sign the broker CSR with the CA:

```bash
openssl ca -config openssl-ca.cnf -policy signing_policy -extensions signing_req \
-out {server-cert.pem} -infiles {server-request.csr}
```

Then import both into the broker keystore:

```bash
# Import CA Root
keytool -keystore server.keystore.jks -alias CARoot -import -file cacert.pem

# Import Signed Certificate
keytool -keystore server.keystore.jks -alias localhost -import -file server-cert.pem
```

Important:
- Import the CA root to establish the chain of trust
- Import the signed server certificate to establish the broker identity

## SSL key and certificates in PEM format

- Supported in Kafka `2.7.0+`
- You can place PEM strings directly in Kafka configuration
- This avoids external JKS / PKCS12 files
- Benefit noted in the source: easier secret-manager usage and no external files on disk

Relevant properties:

| Property | Meaning |
| :--- | :--- |
| `ssl.keystore.key` | Private key |
| `ssl.keystore.certificate.chain` | Server certificate plus any intermediate certificates |
| `ssl.truststore.certificates` | CA public certificate |

Password notes:
- `ssl.keystore.password` is not used for PEM
- If the private key is encrypted, use `ssl.key.password`

## Common Pitfalls in Production

### 1. Extended Key Usage (EKU)

- Corporate CAs may restrict certificate usage
- A "Web Server" profile may only allow server authentication
- Kafka brokers act as both:
  - servers
  - clients (for inter-broker communication)
- Broker certificates must allow:
  - `clientAuth`
  - `serverAuth`

### 2. Intermediate Certificates

- Enterprises often sign with an Intermediate CA, not directly with the Root CA
- You must provide the full chain:
  - Root
  - Intermediate
  - Server certificate
- The source notes you can merge them by concatenating the files

### 3. Missing SAN

- Some CA tooling strips SAN during signing
- Result: hostname verification fails even if the certificate is otherwise valid

Verification command:

```bash
openssl x509 -in certificate.crt -text -noout
```

Check:
- `Subject Alternative Name` section exists
- SAN content is correct

## Configuring Kafka Brokers

### Listener configuration

If SSL is not used for all traffic, configure both plaintext and SSL listeners:

```properties
listeners=PLAINTEXT://host.name:9092,SSL://host.name:9093
```

### Core SSL broker settings

Required keystore settings:
- `ssl.keystore.location`
- `ssl.keystore.password`
- `ssl.key.password`

Required truststore settings:
- `ssl.truststore.location`
- `ssl.truststore.password`

Note:
- Truststore password is technically optional
- The source recommends setting it to preserve integrity checking

### Inter-broker communication

- Default inter-broker communication is `PLAINTEXT`
- To encrypt broker-to-broker traffic:

```properties
security.inter.broker.protocol=SSL
```

### Optional and advanced settings

Client authentication:

| Property | Meaning |
| :--- | :--- |
| `ssl.client.auth=required` | Client must present a valid certificate |
| `ssl.client.auth=requested` | Client cert is checked if present, but uncertified clients may still connect |
| `ssl.client.auth=none` | No client certificate required |

Other settings:
- `ssl.enabled.protocols` to restrict accepted protocol versions, e.g. `TLSv1.2`
- TLS is preferred over older SSL protocol versions
- Store type properties define keystore / truststore formats, e.g. `JKS`

Performance / system notes:
- On Linux, default `NativePRNG` can bottleneck because of global locking
- The source recommends:

```properties
ssl.secure.random.implementation=SHA1PRNG
```

- If using strong encryption such as `AES-256`, JCE Unlimited Strength Jurisdiction Policy Files may be required in the JDK/JRE

### Verification

Check broker logs for endpoint mapping, e.g.:
- `PLAINTEXT -> EndPoint(..., 9092, PLAINTEXT)`
- `SSL -> EndPoint(..., 9093, SSL)`

External handshake test:

```bash
openssl s_client -debug -connect localhost:9093 -tls1
```

Success indicators:
- `-----BEGIN CERTIFICATE-----` appears
- Subject / Issuer details are correct

## Configuring Kafka Clients

### Compatibility and scope

- SSL is supported only for the new Kafka Producer and Consumer APIs
- Legacy / older APIs are not supported
- SSL configuration parameters are the same for producers and consumers

### One-way SSL

If the broker does not require client authentication:

```properties
security.protocol=SSL
ssl.truststore.location=/var/private/ssl/client.truststore.jks
ssl.truststore.password=test1234
```

Note:
- Truststore password is technically optional
- Omitting it disables integrity checking, which the source does not recommend

### Mutual authentication

If the broker uses `ssl.client.auth=required` or `ssl.client.auth=requested`, the client must also provide a keystore:

```properties
ssl.keystore.location=/var/private/ssl/client.keystore.jks
ssl.keystore.password=test1234
ssl.key.password=test1234
```

### Optional and advanced parameters

- `ssl.enabled.protocols`: must overlap with broker-supported protocols
- `ssl.provider`: optional; defaults to JVM default provider
- `ssl.truststore.type` and `ssl.keystore.type`: default `JKS`
- `ssl.cipher.suites`: optional; limits allowed encryption / MAC / key-exchange algorithms

## Core Summary

- SSL in Kafka provides encryption and authentication, but it is not enabled by default.
- Each broker needs its own keypair, a CA-signed certificate, and trust in the CA chain.
- Use SAN for hostname verification; CN is deprecated; disabling endpoint identification is not recommended.
- Keystore = your identity. Truststore = CAs you trust.
- For inter-broker SSL, set `security.inter.broker.protocol=SSL`; for mutual auth, configure keystore and truststore on both sides.
