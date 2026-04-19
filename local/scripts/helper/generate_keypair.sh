#!/usr/bin/env bash
set -euo pipefail

generate_jwt_keypair() {
  local output_dir="${1:-.}"
  local name="${2:-}"
  local overwrite="${3:-false}"

  if [[ -z "$name" ]]; then
    echo "Error: key name is required"
    return 1
  fi

  if ! command -v openssl >/dev/null 2>&1; then
    echo "Error: openssl is not installed"
    return 1
  fi

  mkdir -p "${KEYPAIR_DIR}/${output_dir}"

  local private_key="${KEYPAIR_DIR}/${output_dir}/${name}.key.pem"
  local public_key="${KEYPAIR_DIR}/${output_dir}/${name}.pub.pem"

  if [[ -f "$private_key" && "$overwrite" != "true" ]]; then
    echo "Key already exists: $private_key"
    echo "Skipping (overwrite=false)"
    return 0
  fi

  echo "Generating RSA keypair for JWT (RS256)..."

  # Generate private key
  openssl genpkey \
    -algorithm RSA \
    -pkeyopt rsa_keygen_bits:2048 \
    -out "$private_key"

  # Extract public key
  openssl rsa \
    -pubout \
    -in "$private_key" \
    -out "$public_key"

  chmod 600 "$private_key"
  chmod 644 "$public_key"

  echo "Private key: $private_key"
  echo "Public key : $public_key"
}

# ===== Example usage =====
# generate_jwt_keypair auth auth-service true
