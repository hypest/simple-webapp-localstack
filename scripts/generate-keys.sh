#!/bin/bash
set -e

# Generate SSH key pair for EC2 access if it doesn't exist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_PATH="$SCRIPT_DIR/rails-app-key"

if [ ! -f "${KEY_PATH}" ]; then
    echo "🔑 Generating SSH key pair for EC2 access..."
    ssh-keygen -t rsa -b 4096 -f "${KEY_PATH}" -N "" -C "rails-app-ec2-key"
    chmod 600 "${KEY_PATH}"
    chmod 644 "${KEY_PATH}.pub"
    echo "✅ SSH key pair generated at ${KEY_PATH}"
else
    echo "✅ SSH key pair already exists"
fi