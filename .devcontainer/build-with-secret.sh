#!/usr/bin/env bash
# Helper: build the devcontainer image with BuildKit secret for corporate CA
# Place your corporate Zscaler root cert at ~/.certs/zscaler.crt (or update ZS_CERT variable below)
set -euo pipefail
ZS_CERT=${ZS_CERT:-$HOME/.certs/zscaler.crt}
IMAGE_NAME=${IMAGE_NAME:-my-devcontainer:local}
DOCKERFILE=${DOCKERFILE:-.devcontainer/Dockerfile}

if [ ! -f "$ZS_CERT" ]; then
  echo "Zscaler certificate not found at $ZS_CERT"
  echo "Export your Zscaler root certificate to this path, e.g. copy from Windows Downloads to WSL:"
  echo "  cp /mnt/c/Users/<you>/Downloads/ZscalerRootCA.crt $ZS_CERT"
  exit 1
fi

export DOCKER_BUILDKIT=1

docker build --secret id=zscaler_ca,src="$ZS_CERT" -f "$DOCKERFILE" -t "$IMAGE_NAME" .

echo "Built $IMAGE_NAME"
