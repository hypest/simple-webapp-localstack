#!/usr/bin/env bash
set -euo pipefail

# install_zscaler_cert.sh
# If the environment variable ZSCALER_CERT is present (can be raw PEM or base64-encoded),
# write it to /usr/local/share/ca-certificates/zscaler.crt and run update-ca-certificates.
# Designed for Codespaces where you can set a repository or organization secret and expose
# it as an environment variable named ZSCALER_CERT in the Codespace.

echo "Checking for ZSCALER_CERT..."
if [ -z "${ZSCALER_CERT:-}" ]; then
  echo "ZSCALER_CERT not set; skipping installing corporate CA"
  exit 0
fi

TMP_CERT_FILE="/tmp/zscaler.cert.pem"

# If the env value looks like base64 (no newlines, couple of == at end or contains only base64 chars), try to decode
if echo "$ZSCALER_CERT" | grep -Eq "^[A-Za-z0-9+/=\n\r]+$" && ! echo "$ZSCALER_CERT" | grep -q "BEGIN CERTIFICATE"; then
  echo "Detected base64-encoded cert; decoding"
  echo "$ZSCALER_CERT" | base64 -d > "$TMP_CERT_FILE" || {
    echo "Failed to decode ZSCALER_CERT as base64; treating as raw PEM"
    echo "$ZSCALER_CERT" > "$TMP_CERT_FILE"
  }
else
  echo "Detected raw PEM cert; writing to temp file"
  echo "$ZSCALER_CERT" > "$TMP_CERT_FILE"
fi

if [ ! -s "$TMP_CERT_FILE" ]; then
  echo "Certificate file is empty; skipping"
  exit 0
fi

if [ -w /usr/local/share/ca-certificates ]; then
  echo "Installing corporate CA to /usr/local/share/ca-certificates/zscaler.crt"
  sudo cp "$TMP_CERT_FILE" /usr/local/share/ca-certificates/zscaler.crt
  sudo update-ca-certificates || echo "update-ca-certificates returned non-zero"
  echo "Installed corporate CA"
else
  echo "/usr/local/share/ca-certificates is not writable. On Codespaces you may need to run this script as root or set the secret differently."
  echo "You can also add the cert manually in a shell:"
  echo "  echo \"$ZSCALER_CERT\" > /tmp/zscaler.cert.pem"
  echo "  sudo cp /tmp/zscaler.cert.pem /usr/local/share/ca-certificates/zscaler.crt"
  echo "  sudo update-ca-certificates"
fi

rm -f "$TMP_CERT_FILE"

echo "install_zscaler_cert.sh finished"
