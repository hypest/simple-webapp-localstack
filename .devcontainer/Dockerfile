# Devcontainer Dockerfile based on the official Ruby devcontainer image
FROM mcr.microsoft.com/devcontainers/ruby:3.2-bookworm

# Install redis-tools (provides redis-cli) and any other lightweight tools we want in the devcontainer
RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends redis-tools jq httpie \
  && rm -rf /var/lib/apt/lists/*

# Keep the rest of the base image behavior

# Set a sensible workdir
WORKDIR /workspaces
