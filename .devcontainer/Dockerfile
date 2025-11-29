# syntax=docker/dockerfile:1.3
FROM mcr.microsoft.com/devcontainers/base:bookworm

# If a corporate TLS interception CA is provided as a build secret (id=zscaler_ca),
# install it into the image trust store so apt/curl inside the build trusts intercepted HTTPS.
RUN --mount=type=secret,id=zscaler_ca,target=/run/secrets/zscaler_ca \
  /bin/sh -c '\
  if [ -f /run/secrets/zscaler_ca ]; then \
  echo "Installing corporate CA to /usr/local/share/ca-certificates/zscaler.crt"; \
  cp /run/secrets/zscaler_ca /usr/local/share/ca-certificates/zscaler.crt; \
  update-ca-certificates; \
  else \
  echo "No zscaler CA provided as build secret; skipping."; \
  fi'

# Install lightweight tools: jq, httpie, python3 for awslocal (awscli-local)
RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends \
  jq httpie \
  python3 python3-venv python3-distutils python3-pip \
  && apt-get install -y --no-install-recommends pipx \
  && python3 -m venv /opt/venv \
  && . /opt/venv/bin/activate \
  && python3 -m pip install --upgrade pip setuptools wheel \
  && pip install awscli-local \
  && rm -rf /var/lib/apt/lists/*

# Set a sensible workdir
WORKDIR /workspace
