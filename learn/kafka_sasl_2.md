## **4. Production Security Hardening**
To use OAUTHBEARER in a production environment, the following requirements must be met:

| Requirement | Description |
| :--- | :--- |
| **Custom Handlers** | You must implement `AuthenticateCallbackHandler` for both the login (client-side) and the validator (broker-side). |
| **TLS Encryption** | **Mandatory.** Always use `SASL_SSL` to prevent tokens from being intercepted in transit. |
| **Override Defaults** | The default Kafka implementation uses **Unsecured JWTs**, which are insecure. You must override these with production-ready handlers that interact with a real IdP. |

---

### **Summary of Client Configuration Properties**
* **`security.protocol`**: Set to `SASL_SSL`.
* **`sasl.mechanism`**: Set to `OAUTHBEARER`.
* **`sasl.oauthbearer.token.endpoint.url`**: The URL where the client fetches tokens.
* **`sasl.login.callback.handler.class`**: The custom class used to handle token logic.

---

Here is the final part of the summary, covering multiple mechanisms, rolling updates, and Delegation Tokens:

---

## **Enabling Multiple SASL Mechanisms**
Kafka allows a single broker to support multiple SASL mechanisms (e.g., PLAIN and Kerberos) simultaneously.

1.  **JAAS Configuration:** Include all required login modules within the same `KafkaServer` section in your JAAS file.
2.  **Broker Properties:** List all enabled mechanisms in `server.properties`:
    `sasl.enabled.mechanisms=GSSAPI,PLAIN,SCRAM-SHA-256`
3.  **Inter-broker Communication:** If you want brokers to communicate using a specific mechanism, define `sasl.mechanism.inter.broker.protocol`.



---

## **Modifying SASL in a Running Cluster**
To change SASL mechanisms without downtime, use a **multi-stage rolling restart (incremental bounce)**:

* **Step 1:** Add the new mechanism to `sasl.enabled.mechanisms` and the JAAS file. Restart brokers one by one.
* **Step 2:** Update and restart your **clients** to use the new mechanism.
* **Step 3 (Optional):** If the inter-broker mechanism needs to change, update `sasl.mechanism.inter.broker.protocol` and restart brokers again.
* **Step 4 (Optional):** Once everything is stable, remove the old mechanism from the config and perform a final rolling restart.

---

## **Authentication via Delegation Tokens**
Delegation Tokens provide a **lightweight** alternative to SASL/SSL, especially useful in distributed frameworks where distributing Kerberos keytabs or SSL certificates to every worker node is difficult.

### **The Workflow**
1.  **Obtain:** A user authenticates via a strong method (SASL/SSL) and requests a token via Admin APIs or CLI.
2.  **Distribute:** The user passes this token to workers/clients.
3.  **Authenticate:** Clients use the token as a shared secret to connect to the cluster.
4.  **Manage:** Tokens can be renewed or cancelled by the owner or a designated renewer.



---

## **Token Management & Security**
Managing these "shared secrets" requires specific broker configurations:

| Feature | Configuration / Detail |
| :--- | :--- |
| **Shared Secret** | `delegation.token.secret.key` must be **identical** across all brokers and controllers. |
| **Storage** | Stored in metadata; currently kept as plain text in `server.properties`. |
| **Expiry** | Default: Must be renewed every **24 hours** (`delegation.token.expiry.time.ms`). |
| **Max Lifetime** | Default: **7 days** (`delegation.token.max.lifetime.ms`). After this, it cannot be renewed. |
| **Cleanup** | Expired or cancelled tokens are automatically deleted from broker caches. |

> **Note:** Delegation tokens are most secure when controllers are on a private network or when all inter-node communication is encrypted, as the secret key is currently stored in plain text.

---

Here is the continued summary regarding **Creating and Authenticating with Delegation Tokens** in Apache Kafka:

---

## **1. Creating and Managing Tokens**
Delegation tokens can be managed via the **Admin API** or the `kafka-delegation-tokens.sh` script.

### **Operational Requirements**
* **Secure Channel:** Requests (create, renew, expire, describe) must be issued over **SASL or SSL** authenticated channels.
* **No Chaining:** You cannot request a new delegation token if your current authentication is already using a delegation token.
* **Permissions:** * **Owners/Renewers:** Can renew, expire, or describe their own tokens.
    * **Administrative Access:** To describe tokens owned by others, a user must have the `DESCRIBE_TOKEN` permission on the specific User resource.

### **CLI Command Examples**
| Action | Example Command Component |
| :--- | :--- |
| **Create** | `--create --max-life-time-period -1 --renewer-principal User:user1` |
| **Renew** | `--renew --renew-time-period -1 --hmac <token_hmac>` |
| **Expire** | `--expire --expiry-time-period -1 --hmac <token_hmac>` |
| **Describe** | `--describe --owner-principal User:user1` |

---

## **2. Token Authentication Mechanism**
Delegation token authentication is built on top of the **SASL/SCRAM** mechanism.

* **Requirement:** The Kafka cluster must have SASL/SCRAM enabled for token authentication to function.
* **Logic:** The token ID acts as the "username," and the token HMAC acts as the "password."

---

## **3. Configuring Kafka Clients**
To use a token for authentication, clients must update their JAAS configuration.

### **Method A: Property-based (Recommended)**
Define the credentials in `producer.properties` or `consumer.properties`. This allows multiple clients in the same JVM to use different tokens.

```properties
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
    username="tokenID123" \
    password="lAYYSFmLs4bTjf+lTZ1LCHR/ZZFNA==" \
    tokenauth="true";
```

### **Method B: JVM Parameter**
Pass the config via `-Djava.security.auth.login.config`.
* **Note:** This uses the `KafkaClient` section and limits the entire JVM to **one single token** for all connections.

### **Key JAAS Parameters**
* **`username`**: The unique Token ID.
* **`password`**: The Token HMAC (secret).
* **`tokenauth="true"`**: A critical flag that instructs the server to treat these credentials as a delegation token rather than a standard SCRAM user.

---

## **Summary of Security Considerations**
* **Initial Trust:** You must already have a secure way to connect (Kerberos/SSL) to get a token in the first place.
* **Portability:** Once obtained, the token is a lightweight way for temporary or distributed workers to connect without needing complex security files (keytabs/truststores).