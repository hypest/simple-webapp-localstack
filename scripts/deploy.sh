#!/bin/bash
set -e

# Rails App Deployment Script
# Usage: ./deploy.sh [localstack|aws] [version]

ENVIRONMENT=${1:-localstack}
VERSION=${2:-latest}
# By default, start the app locally for LocalStack deployments so health checks
# succeed (this restores the previous behavior). Pass --no-start-local as the
# third arg to disable.
if [ "$ENVIRONMENT" = "localstack" ]; then
    START_LOCAL=true
else
    START_LOCAL=false
fi
# CLI overrides (explicit args win)
if [ "${3:-}" = "--no-start-local" ]; then
    START_LOCAL=false
elif [ "${3:-}" = "--start-local" ]; then
    START_LOCAL=true
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Configuration
if [ "$ENVIRONMENT" = "localstack" ]; then
    AWS_ENDPOINT="--endpoint-url=http://localhost:4566"
    REGISTRY_URI="localhost:5001/rails-counter-app"  # Use local Docker registry
    USE_ECR=false
    TF_VAR_environment="development"
    log "🏠 Deploying to LocalStack environment (using local Docker registry)"
elif [ "$ENVIRONMENT" = "aws" ]; then
    AWS_ENDPOINT=""
    # Check if ECR repository exists or use fallback
    ECR_REPO_URI=$(aws ecr describe-repositories --repository-names rails-counter-app --query 'repositories[0].repositoryUri' --output text 2>/dev/null || echo "")
    if [ -n "$ECR_REPO_URI" ] && [ "$ECR_REPO_URI" != "None" ]; then
        REGISTRY_URI="$ECR_REPO_URI"
        USE_ECR=true
        log "☁️  Deploying to AWS environment (using ECR: $ECR_REPO_URI)"
    else
        # Fallback to account-based ECR URI - user needs to create the repo
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "YOUR_AWS_ACCOUNT")
        REGISTRY_URI="$ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/rails-counter-app"
        USE_ECR=true
        warn "ECR repository not found. Please create it first or the image will be: $REGISTRY_URI"
    fi
    TF_VAR_environment="production"
else
    error "Invalid environment. Use 'localstack' or 'aws'"
fi

# SSH keys are now managed entirely by Terraform (no filesystem keys needed)
log "🔑 SSH keys managed by Terraform (no filesystem generation needed)..."

# Step 2: Build and tag the Docker image
cd "$PROJECT_ROOT"
if [ "$ENVIRONMENT" = "localstack" ]; then
    # Check LocalStack availability before building/pushing
    LS_CODE=$(curl -sS -o /dev/null -w "%{http_code}" http://localhost:4566/health 2>/dev/null || true)
    if [ -z "$LS_CODE" ]; then
        LS_CODE="000"
    fi

    # If HTTP check fails, also check for a listener on port 4566 and active localstack containers
    LS_LISTENER_OK=false
    if [ -n "$LS_CODE" ] && [ "$LS_CODE" != "000" ]; then
        LS_LISTENER_OK=true
    else
        # Check for local process listening on :4566
        if command -v ss >/dev/null 2>&1; then
            if ss -ltn | awk '{print $4}' | grep -E '(:|\[)::?4566$' >/dev/null 2>&1; then
                LS_LISTENER_OK=true
            fi
        elif command -v lsof >/dev/null 2>&1; then
            if lsof -iTCP:4566 -sTCP:LISTEN >/dev/null 2>&1; then
                LS_LISTENER_OK=true
            fi
        fi

        # Check if any docker container image/name mentions localstack
        if [ "$LS_LISTENER_OK" = false ]; then
            if docker ps -a --format '{{.Names}}\t{{.Image}}' | awk 'BEGIN{IGNORECASE=1} /localstack/ {exit 0} END{exit 1}'; then
                LS_LISTENER_OK=true
            fi
        fi
    fi

    if [ "$LS_LISTENER_OK" = false ]; then
        warn "LocalStack is not reachable at http://localhost:4566 and no local listener/container detected"
        echo ""
        echo "Please start LocalStack before running deploy. Options:"
        echo "  1) ./scripts/start-localstack.sh        # start LocalStack"
        echo "  2) Use your preferred LocalStack startup method (LocalStack CLI, docker run, etc.)"
        echo ""
        echo "Suggestion: Run './scripts/start-localstack.sh' and re-run './scripts/deploy.sh localstack'"
        exit 1
    fi

    # Also check local Docker registry early to avoid wasting a build
    REG_CODE=$(curl -sS -o /dev/null -w "%{http_code}" http://localhost:5001/v2/ 2>/dev/null || true)
    if [ -z "$REG_CODE" ]; then
        REG_CODE="000"
    fi
    if [ -z "$REG_CODE" ] || [ "$REG_CODE" = "000" ]; then
        warn "Local Docker registry not reachable at http://localhost:5001"
        echo ""
        echo "Please start the local registry before running deploy. Options:" 
    echo "  1) ./scripts/registry-bridge.sh start    # starts local registry via docker run"
        echo "  2) ./scripts/start-supporting-services.sh # starts registry (and redis) via docker run"
        echo ""
        echo "Suggestion: Run './scripts/registry-bridge.sh start' and re-run './scripts/deploy.sh localstack'"
        exit 1
    fi
fi
    log "🐳 Building Docker image..."
    # Prefer interactive BuildKit progress when running in a TTY, fall back to plain for CI/non-TTY
    if [ -t 1 ]; then
        PROGRESS_MODE=tty
    else
        PROGRESS_MODE=plain
    fi
    # Enable BuildKit by default for nicer output/progress control
    export DOCKER_BUILDKIT=${DOCKER_BUILDKIT:-1}

    if [ "$ENVIRONMENT" = "localstack" ]; then
        docker build --progress="$PROGRESS_MODE" --build-arg PRECOMPILE=false -f app-docker-images/Dockerfile.prod -t "rails-counter-app:$VERSION" .
    else
        docker build --progress="$PROGRESS_MODE" -f app-docker-images/Dockerfile.prod -t "rails-counter-app:$VERSION" .
    fi
docker tag "rails-counter-app:$VERSION" "$REGISTRY_URI:$VERSION"
docker tag "rails-counter-app:$VERSION" "$REGISTRY_URI:latest"

# Step 3: Push to registry
log "📦 Pushing image to registry..."
if [ "$ENVIRONMENT" = "localstack" ]; then
    # For LocalStack, use local Docker registry (no authentication needed)
    log "Using local Docker registry at localhost:5001"
    # Registry health already checked earlier (to fail fast)

    docker push "$REGISTRY_URI:$VERSION"
    docker push "$REGISTRY_URI:latest"
elif [ "$ENVIRONMENT" = "aws" ] && [ "$USE_ECR" = "true" ]; then
    # For real AWS with ECR, authenticate first
    log "Authenticating with ECR..."
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$(echo $REGISTRY_URI | cut -d'/' -f1)"
    
    # Create ECR repository if it doesn't exist
    REPO_NAME=$(echo $REGISTRY_URI | cut -d'/' -f2)
    aws ecr describe-repositories --repository-names "$REPO_NAME" >/dev/null 2>&1 || {
        log "Creating ECR repository: $REPO_NAME"
        aws ecr create-repository --repository-name "$REPO_NAME"
    }
    
    docker push "$REGISTRY_URI:$VERSION"
    docker push "$REGISTRY_URI:latest"
else
    error "Unsupported registry configuration"
fi

# Step 4: Apply Terraform configuration
log "🏗️  Applying infrastructure changes..."
cd "$PROJECT_ROOT/infrastructure"

# Set Terraform variables
export TF_VAR_app_image_uri="$REGISTRY_URI:$VERSION"
export TF_VAR_environment="$TF_VAR_environment"
# Provide SECRET_KEY_BASE for LocalStack deployments if not already provided.
if [ "$ENVIRONMENT" = "localstack" ]; then
    if [ -z "${TF_VAR_secret_key_base:-}" ]; then
        GENERATED_SECRET=$(openssl rand -hex 64 2>/dev/null || python3 -c "import os,sys; sys.stdout.write(os.urandom(64).hex())")
        export TF_VAR_secret_key_base="$GENERATED_SECRET"
        warn "No TF_VAR_secret_key_base provided — generating one and exporting as TF_VAR_secret_key_base.\nNote: this will appear in Terraform state and is not secure for production. Use a secrets manager for production deployments."
    else
        log "Using TF_VAR_secret_key_base from environment"
    fi
fi

# Initialize and apply Terraform
terraform init
terraform plan -var="app_image_uri=$REGISTRY_URI:$VERSION"
terraform apply -auto-approve -var="app_image_uri=$REGISTRY_URI:$VERSION"

# Step 5: Get deployment outputs
log "📊 Getting deployment information..."
LOAD_BALANCER_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "N/A")
ASG_NAME=$(terraform output -raw autoscaling_group_name 2>/dev/null || echo "N/A")

# Step 6: Trigger instance refresh (rolling deployment)
if [ "$ASG_NAME" != "N/A" ]; then
    log "🔄 Triggering rolling deployment..."
    aws $AWS_ENDPOINT autoscaling start-instance-refresh \
        --auto-scaling-group-name "$ASG_NAME" \
        --preferences '{
            "InstanceWarmup": 300,
            "MinHealthyPercentage": 50
        }' || warn "Instance refresh failed - instances may need manual update"
fi

# If requested, start the app locally (useful for LocalStack dev where ec2 user-data won't run)
if [ "$ENVIRONMENT" = "localstack" ] && [ "$START_LOCAL" = "true" ]; then
    log "🚀 Starting application locally for LocalStack testing..."
    CONTAINER_NAME="rails-local-deploy"
    # stop any existing container with that name
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker stop "$CONTAINER_NAME" || true
        docker rm "$CONTAINER_NAME" || true
    fi

    # Ensure we have a secret
    if [ -z "$TF_VAR_secret_key_base" ]; then
        TF_VAR_secret_key_base=$(openssl rand -hex 64 2>/dev/null || python3 -c "import os,sys; sys.stdout.write(os.urandom(64).hex())")
        export TF_VAR_secret_key_base
    fi

    # Run the container mapping host 8080 to container 80
    docker run -d --name "$CONTAINER_NAME" -p 8080:80 -e RAILS_ENV=production -e SECRET_KEY_BASE="$TF_VAR_secret_key_base" "$REGISTRY_URI:$VERSION" \
        sh -c "bundle exec rails db:prepare && bundle exec rails server -b 0.0.0.0 -p 80" || warn "Failed to start local container"
fi

# Step 7: Health check
log "🏥 Performing health check..."
if [ "$ENVIRONMENT" = "localstack" ]; then
    # LocalStack deployments may not create a load balancer. If Terraform didn't
    # produce a load balancer DNS (it will be "N/A"), fall back to the local
    # host port where the application's Docker compose exposes the app.
    if [ -z "$LOAD_BALANCER_DNS" ] || [ "$LOAD_BALANCER_DNS" = "N/A" ]; then
        warn "Load balancer DNS not found in Terraform outputs; falling back to localhost:8080 for health checks"
        HEALTH_URL="http://localhost:8080/up"
    else
        HEALTH_URL="http://$LOAD_BALANCER_DNS/up"
    fi
elif [ "$ENVIRONMENT" = "aws" ]; then
    HEALTH_URL="http://$LOAD_BALANCER_DNS/health"
fi

log "Healthcheck URL: $HEALTH_URL"

# Wait for deployment to be ready
for i in {1..30}; do
    if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
        log "✅ Application is healthy!"
        break
    else
        log "⏳ Waiting for application to be ready... (attempt $i/30)"
        sleep 10
    fi
done

# Final summary
log "🎉 Deployment completed!"
echo ""
echo -e "${BLUE}=== Deployment Summary ===${NC}"
echo -e "Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Version: ${YELLOW}$VERSION${NC}"
echo -e "Image: ${YELLOW}$REGISTRY_URI:$VERSION${NC}"
if [ "$LOAD_BALANCER_DNS" != "N/A" ]; then
    echo -e "Load Balancer: ${YELLOW}$LOAD_BALANCER_DNS${NC}"
    echo -e "Application URL: ${YELLOW}http://$LOAD_BALANCER_DNS${NC}"
fi
echo -e "Auto Scaling Group: ${YELLOW}$ASG_NAME${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Monitor the deployment: aws $AWS_ENDPOINT ec2 describe-instances"
echo "2. Check application logs: aws $AWS_ENDPOINT logs describe-log-groups"
echo "3. Scale if needed: aws $AWS_ENDPOINT autoscaling update-auto-scaling-group --auto-scaling-group-name $ASG_NAME --desired-capacity 3"