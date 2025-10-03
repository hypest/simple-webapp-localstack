#!/bin/bash

# Start supporting services for devcontainer volume setup
echo "🚀 Starting supporting services..."

# Create network if it doesn't exist
docker network create devcontainer-network 2>/dev/null || echo "Network already exists"

# Start Redis
if ! docker ps --format "table {{.Names}}" | grep -q "^redis$"; then
    echo "📦 Starting Redis..."
    docker run -d \
        --name redis \
        --network devcontainer-network \
        -p 6379:6379 \
        redis:7-alpine
else
    echo "✅ Redis already running"
fi

# Start Docker Registry
if ! docker ps --format "table {{.Names}}" | grep -q "^registry$"; then
    echo "📦 Starting Docker Registry..."
    docker run -d \
        --name registry \
        --network devcontainer-network \
        -p 5001:5000 \
        -e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/data \
        -v registry_data:/data \
        registry:2
else
    echo "✅ Docker Registry already running"
fi

echo "✅ Supporting services started!"
echo "   - Redis: localhost:6379"
echo "   - Registry: localhost:5001"