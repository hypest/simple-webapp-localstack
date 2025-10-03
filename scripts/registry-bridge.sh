#!/bin/bash
set -e

# LocalStack Registry Bridge Script
# This script helps LocalStack EC2 instances access the local Docker registry

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

log() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')] $1\033[0m"
}

warn() {
    echo -e "\033[1;33m[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1\033[0m"
}

case "${1:-help}" in
    "start")
        log "🚀 Starting LocalStack registry bridge..."
        
        # Ensure the registry is running
        cd "$PROJECT_ROOT"
        docker-compose -f docker-compose.dev.yml up -d registry
        
        # Check registry health
        for i in {1..30}; do
            if curl -sf http://localhost:5001/v2/ >/dev/null 2>&1; then
                log "✅ Local Docker registry is healthy at localhost:5001"
                break
            else
                log "⏳ Waiting for registry to be ready... (attempt $i/30)"
                sleep 2
            fi
        done
        
        log "📋 Registry bridge configured. LocalStack EC2 instances can now access:"
        log "   - localhost:5001 (from host)"
        log "   - registry:5000 (from within Docker network)"
        ;;
    
    "status")
        log "📊 Checking registry status..."
        
        if curl -sf http://localhost:5001/v2/ >/dev/null 2>&1; then
            log "✅ Registry is running at localhost:5001"
            
            # List available images
            CATALOG=$(curl -s http://localhost:5001/v2/_catalog 2>/dev/null || echo '{"repositories":[]}')
            REPOS=$(echo "$CATALOG" | grep -o '"repositories":\[[^]]*\]' | sed 's/"repositories":\[//;s/\]$//' | tr -d '"' | tr ',' '\n')
            
            if [ -n "$REPOS" ] && [ "$REPOS" != "" ]; then
                log "📦 Available images:"
                echo "$REPOS" | while read -r repo; do
                    if [ -n "$repo" ]; then
                        TAGS=$(curl -s "http://localhost:5001/v2/$repo/tags/list" 2>/dev/null | grep -o '"tags":\[[^]]*\]' | sed 's/"tags":\[//;s/\]$//' | tr -d '"' | tr ',' ' ')
                        log "   - $repo: $TAGS"
                    fi
                done
            else
                log "📦 No images found in registry"
            fi
        else
            warn "❌ Registry is not running"
            log "💡 Run './scripts/registry-bridge.sh start' to start the registry"
        fi
        ;;
    
    "push-test")
        IMAGE_NAME=${2:-rails-counter-app}
        TAG=${3:-test}
        
        log "🧪 Pushing test image to registry..."
        
        # Create a simple test image
        docker run --rm -d --name test-nginx nginx:alpine
        docker commit test-nginx "localhost:5001/$IMAGE_NAME:$TAG"
        docker rm -f test-nginx
        
        # Push to registry
        docker push "localhost:5001/$IMAGE_NAME:$TAG"
        
        log "✅ Test image pushed: localhost:5001/$IMAGE_NAME:$TAG"
        ;;
    
    "clean")
        log "🧹 Cleaning up registry data..."
        cd "$PROJECT_ROOT"
        docker-compose -f docker-compose.dev.yml down -v
        docker volume rm simple-app-localstack_registry_data 2>/dev/null || true
        log "✅ Registry data cleaned"
        ;;
    
    "help"|*)
        echo "LocalStack Registry Bridge Helper"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start               - Start the local Docker registry"
        echo "  status              - Check registry status and list images"
        echo "  push-test [name] [tag] - Push a test image to registry"
        echo "  clean               - Clean up registry data"
        echo "  help                - Show this help message"
        echo ""
        echo "The registry runs at localhost:5001 and provides Docker image"
        echo "storage for LocalStack deployments without requiring ECR."
        ;;
esac