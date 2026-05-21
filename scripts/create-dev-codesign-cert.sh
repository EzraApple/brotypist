#!/usr/bin/env bash
set -euo pipefail

CERT_NAME="${CERT_NAME:-Brotypist Local Development}"
KEYCHAIN="${KEYCHAIN:-${HOME}/Library/Keychains/login.keychain-db}"
DAYS="${DAYS:-3650}"
P12_PASSWORD="${P12_PASSWORD:-brotypist-dev}"

if security find-identity -v -p codesigning | grep -Fq "\"${CERT_NAME}\""; then
  echo "Code signing identity already exists: ${CERT_NAME}"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

KEY_PATH="${TMP_DIR}/brotypist-dev.key"
CERT_PATH="${TMP_DIR}/brotypist-dev.crt"
P12_PATH="${TMP_DIR}/brotypist-dev.p12"

openssl req -new -newkey rsa:2048 -nodes -x509 -days "${DAYS}" \
  -subj "/CN=${CERT_NAME}/" \
  -keyout "${KEY_PATH}" \
  -out "${CERT_PATH}" \
  -addext "extendedKeyUsage=codeSigning" \
  -addext "keyUsage=digitalSignature"

openssl pkcs12 -export \
  -legacy \
  -inkey "${KEY_PATH}" \
  -in "${CERT_PATH}" \
  -out "${P12_PATH}" \
  -passout "pass:${P12_PASSWORD}"

security import "${P12_PATH}" \
  -k "${KEYCHAIN}" \
  -P "${P12_PASSWORD}" \
  -T /usr/bin/codesign \
  -A

security add-trusted-cert \
  -r trustRoot \
  -p codeSign \
  -k "${KEYCHAIN}" \
  "${CERT_PATH}"

if ! security find-identity -v -p codesigning | grep -Fq "\"${CERT_NAME}\""; then
  echo "Created certificate, but it is not listed as a valid code-signing identity." >&2
  echo "Open Keychain Access, trust '${CERT_NAME}' for code signing, then rerun this script." >&2
  exit 1
fi

echo "Created code signing identity: ${CERT_NAME}"
