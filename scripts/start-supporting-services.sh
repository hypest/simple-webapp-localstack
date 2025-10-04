#!/bin/bash

# Start supporting services for devcontainer volume setup
echo "🚀 Starting supporting services..."

# Create network if it doesn't exist
docker network create devcontainer-network 2>/dev/null || echo "Network already exists"

start_or_reuse_container() {
    local name="$1" image="$2" extra_args="${3:-}"

    # If a running container exists, reuse it
    if docker ps --format "{{.Names}}" | grep -q "^${name}$"; then
        echo "✅ ${name} already running"
        return 0
    fi

    # If a stopped container exists, remove it (clean slate)
    if docker ps -a --format "{{.Names}}" | grep -q "^${name}$"; then
        echo "Found existing container named ${name} (stopped). Removing..."
        docker rm -f "${name}" >/dev/null 2>&1 || true
    fi

    echo "📦 Starting ${name}..."
    docker run -d --name "${name}" ${extra_args} "${image}" >/dev/null
}

# Start Redis
start_or_reuse_container "redis" "redis:7-alpine" "--network devcontainer-network -p 6379:6379"

## Start Docker Registry
start_or_reuse_container "registry" "registry:2" "--network devcontainer-network -p 5001:5000 -e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/data -v registry_data:/data"

echo "✅ Supporting services started!"
echo "   - Redis: localhost:6379"
echo "   - Registry: localhost:5001"