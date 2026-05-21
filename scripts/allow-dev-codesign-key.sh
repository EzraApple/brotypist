#!/usr/bin/env bash
set -euo pipefail

CERT_NAME="${CERT_NAME:-Brotypist Local Development}"
KEYCHAIN="${KEYCHAIN:-${HOME}/Library/Keychains/login.keychain-db}"

if ! security find-identity -v -p codesigning | grep -Fq "\"${CERT_NAME}\""; then
  echo "Missing code signing identity: ${CERT_NAME}" >&2
  echo "Run ./scripts/create-dev-codesign-cert.sh first." >&2
  exit 1
fi

if [[ ! -t 0 ]]; then
  echo "Run this script from an interactive terminal so your keychain password is not logged." >&2
  exit 1
fi

printf "Login keychain password: "
IFS= read -r -s KEYCHAIN_PASSWORD
printf "\n"

security unlock-keychain -p "${KEYCHAIN_PASSWORD}" "${KEYCHAIN}"
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -t private \
  -l "${CERT_NAME}" \
  -k "${KEYCHAIN_PASSWORD}" \
  "${KEYCHAIN}"

echo "Allowed /usr/bin/codesign to use: ${CERT_NAME}"
