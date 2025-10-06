#!/usr/bin/env bash
set -euo pipefail

echo "Starting runtime services for development (supporting services + LocalStack)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# script now lives in .devcontainer/scripts, repo root is two levels up
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Start supporting services (reuse existing script if present)
if [ -f "$WORKSPACE_ROOT/scripts/start-supporting-services.sh" ]; then
  echo "Using existing start-supporting-services.sh"
  bash "$WORKSPACE_ROOT/scripts/start-supporting-services.sh"
else
  echo "No start-supporting-services.sh found; skipping supporting services"
fi

# Start LocalStack (use improved helper if present)
if [ -f "$WORKSPACE_ROOT/scripts/start-localstack.sh" ]; then
  echo "Starting LocalStack via start-localstack.sh"
  bash "$WORKSPACE_ROOT/scripts/start-localstack.sh" || echo "start-localstack.sh failed"
else
  echo "No start-localstack.sh found; skipping LocalStack"
fi

echo "All requested services started"
