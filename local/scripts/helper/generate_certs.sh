#!/usr/bin/env bash
set -euo pipefail

generate_root_ca() {
  local ca_name=${CA_NAME:? CA_NAME is not set}
  local ca_days="${1:-3650}"   # default 10 years

  local ca_dir="$CERTS_DIR/ca"
  local ca_key="$ca_dir/ca.key"
  local ca_cert="$ca_dir/ca.crt"

  # === Prepare CA folder ===
  if [[ -d "$ca_dir" ]]; then
    rm -rf "${ca_dir:? ca_dir is not set}"/*
  else
    mkdir -p "$ca_dir"
  fi

  # ============================================================
  # === Generate Root CA private key (RSA 4096) ===============
  # ============================================================
  echo "Generating Root CA private key (RSA 4096)..."
  openssl genpkey \
      -algorithm RSA \
      -pkeyopt rsa_keygen_bits:4096 \
      -out "$ca_key"

  # ============================================================
  # === Create OpenSSL config for CA ===========================
  # ============================================================
  cat > "$ca_dir/ca.openssl.cnf" << EOF
[ req ]
default_md         = sha512
prompt             = no
distinguished_name = dn
x509_extensions    = v3_ca

[ dn ]
C  = ${SUBJ_C}
ST = ${SUBJ_ST}
L  = ${SUBJ_L}
O  = ${SUBJ_O}
OU = ${SUBJ_OU}
CN = ${ca_name}

[ v3_ca ]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

  # ============================================================
  # === Generate self-signed Root CA certificate ===============
  # ============================================================
  echo "Generating self-signed Root CA certificate..."
  openssl req -x509 -new \
      -key "$ca_key" \
      -days "$ca_days" \
      -config "$ca_dir/ca.openssl.cnf" \
      -out "$ca_cert"

  chmod 600 "$ca_key"
  chmod 644 "$ca_cert"

  echo ""
  echo "Root CA generated successfully:"
  echo " - CA Key:  $ca_key"
  echo " - CA Cert: $ca_cert"
  echo "====================================================================="
}

# ===== Example usage =====
# generate_root_ca "LDNhanCA"
# generate_root_ca "ExampleCA" 730

generate_cert_with_keystore_and_truststore() {
  local cert_dir="$CERTS_DIR/$1"
  local main_domain="$2"
  local local_ip=${LOCAL_IP:? LOCAL_IP is not set}

  shift 2
  local sub_domains=("$@")

  local alias_name="${main_domain//./-}"
  local cert_secret=${CERT_SECRET:? CERT_SECRET is not set}
  local ca_cert="$CERTS_DIR/ca/ca.crt"
  local ca_key="$CERTS_DIR/ca/ca.key"

  # === Prepare cert folder ===
  if [[ -d "$cert_dir" ]]; then
    rm -rf "${cert_dir:? cert_dir is not set}"/*
  else
    mkdir -p "$cert_dir"
  fi

  # ============================================================
  # === Generate private key (RSA 4096) ========================
  # ============================================================
  echo "Generating private key (RSA 4096)..."
  openssl genpkey \
    -algorithm RSA \
    -pkeyopt rsa_keygen_bits:4096 \
    -out "$cert_dir/$alias_name.key.pem"

  # ============================================================
  # === Create OpenSSL config (SAN support) ====================
  # ============================================================
  echo "Creating OpenSSL config with SANs..."

  local san_text=""
  local count=1

  san_text+="DNS.${count} = ${main_domain}"$'\n'; ((count++))
  san_text+="DNS.${count} = localhost"$'\n'; ((count++))
  san_text+="IP.${count} = ${local_ip}"$'\n'; ((count++))
  san_text+="IP.${count} = 127.0.0.1"$'\n'; ((count++))

  if [[ ${#sub_domains[@]} -gt 0 ]]; then
    for sub in "${sub_domains[@]}"; do
      if [[ -n "$sub" ]]; then
        san_text+="DNS.${count} = ${sub}"$'\n'
        ((count++))
      fi
    done
  fi

  cat > "$cert_dir/$alias_name.openssl.cnf" << EOF
[ req ]
prompt             = no
default_md         = sha512
distinguished_name = dn
req_extensions     = req_ext

[ dn ]
C = ${SUBJ_C}
ST = ${SUBJ_ST}
L = ${SUBJ_L}
O = ${SUBJ_O}
OU = ${SUBJ_OU}
CN = ${main_domain}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
$(printf "%s" "$san_text")
EOF

  # ============================================================
  # === Generate CSR ===========================================
  # ============================================================
  echo "Generating CSR..."
  openssl req -new \
    -key "$cert_dir/$alias_name.key.pem" \
    -out "$cert_dir/$alias_name.csr.pem" \
    -config "$cert_dir/$alias_name.openssl.cnf"

  # ============================================================
  # === Sign with CA ===========================================
  # ============================================================
  echo "Signing certificate with CA..."
  openssl x509 -req \
    -in "$cert_dir/$alias_name.csr.pem" \
    -CA "$ca_cert" -CAkey "$ca_key" -CAcreateserial \
    -out "$cert_dir/$alias_name.cert.pem" \
    -days 365 \
    -sha512 \
    -extfile "$cert_dir/$alias_name.openssl.cnf" \
    -extensions req_ext

  # ============================================================
  # === Convert to PKCS8 DER for PostgreSQL ====================
  # ============================================================
  echo "Converting private key to PKCS8 DER (.pk8)..."
  openssl pkcs8 \
    -topk8 \
    -inform PEM \
    -outform DER \
    -in "$cert_dir/$alias_name.key.pem" \
    -out "$cert_dir/$alias_name.pk8" \
    -nocrypt

  # ============================================================
  # === Create PKCS#12 keystore ================================
  # ============================================================
  echo "Creating PKCS#12 keystore..."
  openssl pkcs12 -export \
    -inkey "$cert_dir/$alias_name.key.pem" \
    -in "$cert_dir/$alias_name.cert.pem" \
    -certfile "$ca_cert" \
    -passout pass:"$cert_secret" \
    -out "$cert_dir/$alias_name.keystore.p12" \
    -name "$alias_name"

  # ============================================================
  # === Create PKCS#12 truststore ==============================
  # ============================================================
  echo "Creating PKCS#12 truststore..."
  keytool -importcert \
    -noprompt \
    -trustcacerts \
    -alias "$CA_NAME" \
    -file "$ca_cert" \
    -keystore "$cert_dir/$alias_name.truststore.p12" \
    -storetype PKCS12 \
    -storepass "$cert_secret"

  # ============================================================
  # === Permissions ============================================
  # ============================================================
  chmod 644 "$cert_dir"/*.pem "$cert_dir"/*.pk8 "$cert_dir"/*.p12

  echo "[$main_domain] RSA cert + keystore + truststore generation complete!"
  echo "====================================================================="
}

# ===== Example usage =====
# export CERT_SECRET="your-pass"
# generate_keystore_and_truststore "/path/to/certs" "example.com" "rest_api.example.com" "admin.example.com"
