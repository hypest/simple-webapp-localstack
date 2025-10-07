#!/usr/bin/env bash
# Helper: build the devcontainer image with BuildKit secret for corporate CA
# Place your corporate Zscaler root cert at ~/.certs/zscaler.crt (or update ZS_CERT variable below)
set -euo pipefail
ZS_CERT=${ZS_CERT:-$HOME/.certs/zscaler.crt}
IMAGE_NAME=${IMAGE_NAME:-my-devcontainer:local}
DOCKERFILE=${DOCKERFILE:-.devcontainer/Dockerfile}

SECRET_ARG=""
if [ ! -f "$ZS_CERT" ]; then
  echo "Warning: Zscaler certificate not found at $ZS_CERT"
  echo "Continuing without the BuildKit secret. If your environment requires the corporate CA for network access during image build, the build may fail later."
  echo "To provide the certificate, place it at: $ZS_CERT"
else
  SECRET_ARG="--secret id=zscaler_ca,src=\"$ZS_CERT\""
fi

export DOCKER_BUILDKIT=1

docker build $SECRET_ARG -f "$DOCKERFILE" -t "$IMAGE_NAME" .

echo "Built $IMAGE_NAME"
