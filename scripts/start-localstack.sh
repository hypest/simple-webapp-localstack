#!/bin/bash
set -euo pipefail

# Improved LocalStack start helper
# Usage: ./start-localstack.sh [--remove]

REMOVE=false
PERSIST=false
for arg in "$@"; do
    case "$arg" in
        --remove) REMOVE=true ;;
        --persist) PERSIST=true ;;
        *) ;;
    esac
done

# Container name constant for easier maintenance
CONTAINER_NAME="localstack-main"

echo "Starting LocalStack using Docker-in-Docker..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOCALSTACK_DIR="$PROJECT_ROOT/.localstack"

# If already running, exit
if docker ps -q -f name="$CONTAINER_NAME" >/dev/null 2>&1 && [ -n "$(docker ps -q -f name="$CONTAINER_NAME")" ]; then
    echo "LocalStack is already running"
    exit 0
fi

# If the user requested removal, force remove any existing container
if [ "$REMOVE" = true ] && docker ps -aq -f name="$CONTAINER_NAME" >/dev/null 2>&1 && [ -n "$(docker ps -aq -f name="$CONTAINER_NAME")" ]; then
    echo "Forcing removal of existing LocalStack container..."
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# Remove stopped container if present (best-effort)
if docker ps -aq -f name="$CONTAINER_NAME" >/dev/null 2>&1 && [ -n "$(docker ps -aq -f name="$CONTAINER_NAME")" ]; then
    echo "Removing existing LocalStack container..."
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# Use a project-local directory to avoid system /tmp mount issues
mkdir -p "$LOCALSTACK_DIR"
chmod 0777 "$LOCALSTACK_DIR" || true

echo "Starting LocalStack container..."

# Decide whether to mount a host directory for persistence
DOCKER_RUN_CMD=(docker run -d --name "$CONTAINER_NAME" -p 4566:4566)
DOCKER_RUN_CMD+=( -e SERVICES=sqs,ec2,iam,autoscaling,elbv2,ecr,logs )
DOCKER_RUN_CMD+=( -e DEBUG=1 )
DOCKER_RUN_CMD+=( -e DOCKER_HOST=unix:///var/run/docker.sock )
DOCKER_RUN_CMD+=( -v /var/run/docker.sock:/var/run/docker.sock )

if [ "$PERSIST" = true ]; then
    echo "Persisting LocalStack data to: $LOCALSTACK_DIR"
    mkdir -p "$LOCALSTACK_DIR"
    chmod 0777 "$LOCALSTACK_DIR" || true
    DOCKER_RUN_CMD+=( -e DATA_DIR=/tmp/localstack/data )
    DOCKER_RUN_CMD+=( -e LOCALSTACK_HOST_TMP_FOLDER=/tmp/localstack )
    DOCKER_RUN_CMD+=( -v "$LOCALSTACK_DIR":/tmp/localstack )
else
    # No host mount; let LocalStack manage its internal tmp to avoid bind-mount removal issues
    DOCKER_RUN_CMD+=( -e DATA_DIR=/tmp/localstack/data )
fi

DOCKER_RUN_CMD+=( localstack/localstack:3.0 )

"${DOCKER_RUN_CMD[@]}" >/dev/null

# Wait for LocalStack to be ready
echo "Waiting for LocalStack to be ready..."
timeout=120
counter=0
while true; do
    # If the container exited, show logs and fail
    if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || echo false)" != "true" ]; then
        echo "LocalStack container is not running. Showing recent logs to help diagnose:"
        docker logs "$CONTAINER_NAME" --tail 200 || true
        exit 1
    fi

    # Prefer the public /health endpoint, fall back to internal one
    if curl -sS http://localhost:4566/health >/dev/null 2>&1 || curl -sS http://localhost:4566/_localstack/health >/dev/null 2>&1; then
        echo "LocalStack is ready!"
        break
    fi

    if [ $counter -ge $timeout ]; then
        echo "LocalStack failed to start within $timeout seconds"
        echo "Recent logs from the container:"
        docker logs "$CONTAINER_NAME" --tail 200 || true
        exit 1
    fi

    sleep 1
    counter=$((counter+1))
done

# Initialize LocalStack resources if needed
if [ -f "$SCRIPT_DIR/init-localstack.sh" ]; then
    echo "Running LocalStack initialization script..."
    bash "$SCRIPT_DIR/init-localstack.sh"
fi