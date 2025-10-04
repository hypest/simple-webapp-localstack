#!/bin/bash

# Rover visualization script for LocalStack Terraform configuration
# This script runs Rover with the correct network settings to access LocalStack

set -e

echo "🚀 Starting Rover for Terraform visualization..."

# Check if LocalStack is running
if ! docker ps --format "{{.Names}}" | grep -q "localstack"; then
    echo "❌ LocalStack is not running. Please start it first:"
    echo "   bash scripts/start-localstack.sh"
    exit 1
fi

echo "✅ LocalStack is running"

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"

# Navigate to infrastructure directory
cd "$WORKSPACE_ROOT/infrastructure"

echo "📊 Starting Rover visualization..."
echo "   -> Access via VS Code's forwarded port or"  
echo "   -> Open http://localhost:9000 in your HOST browser (not devcontainer)"
echo "   -> If in devcontainer: Use Command Palette -> 'Ports: Focus on Ports View' -> Add port 9000"
echo "   -> Press Ctrl+C to stop"

# Run Rover with host networking to access LocalStack
docker run --rm -it \
    --network host \
    -v "$(pwd)":/src \
    im2nguyen/rover

echo "🎯 Rover stopped"