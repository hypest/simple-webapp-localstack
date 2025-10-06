# syntax=docker/dockerfile:1.3
# Devcontainer Dockerfile based on the official Ruby devcontainer image
FROM mcr.microsoft.com/devcontainers/ruby:3.4-bookworm

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

# Install redis-tools (provides redis-cli) and any other lightweight tools we want in the devcontainer
RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends redis-tools jq httpie \
  && rm -rf /var/lib/apt/lists/*

# Keep the rest of the base image behavior

# Set a sensible workdir
WORKDIR /workspaces
