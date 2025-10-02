#!/bin/bash
set -e

# Rails App Deployment Script
# Usage: ./deploy.sh [localstack|aws] [version]

ENVIRONMENT=${1:-localstack}
VERSION=${2:-latest}
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
    REGISTRY_URI="localhost:4566/rails-counter-app"
    TF_VAR_environment="development"
    log "🏠 Deploying to LocalStack environment"
elif [ "$ENVIRONMENT" = "aws" ]; then
    AWS_ENDPOINT=""
    REGISTRY_URI="YOUR_AWS_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/rails-counter-app"
    TF_VAR_environment="production"
    log "☁️  Deploying to AWS environment"
else
    error "Invalid environment. Use 'localstack' or 'aws'"
fi

# Step 1: Generate SSH keys if needed
log "🔑 Ensuring SSH keys exist..."
"$SCRIPT_DIR/generate-keys.sh"

# Step 2: Build and tag the Docker image
log "🐳 Building Docker image..."
cd "$PROJECT_ROOT"
docker build -f Dockerfile.prod -t "rails-counter-app:$VERSION" .
docker tag "rails-counter-app:$VERSION" "$REGISTRY_URI:$VERSION"
docker tag "rails-counter-app:$VERSION" "$REGISTRY_URI:latest"

# Step 3: Push to registry (ECR for LocalStack or real ECR)
log "📦 Pushing image to registry..."
if [ "$ENVIRONMENT" = "localstack" ]; then
    # For LocalStack, we can push directly
    docker push "$REGISTRY_URI:$VERSION"
    docker push "$REGISTRY_URI:latest"
elif [ "$ENVIRONMENT" = "aws" ]; then
    # For real AWS, need to authenticate with ECR first
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$REGISTRY_URI"
    docker push "$REGISTRY_URI:$VERSION"
    docker push "$REGISTRY_URI:latest"
fi

# Step 4: Apply Terraform configuration
log "🏗️  Applying infrastructure changes..."
cd "$PROJECT_ROOT/infrastructure"

# Set Terraform variables
export TF_VAR_app_image_uri="$REGISTRY_URI:$VERSION"
export TF_VAR_environment="$TF_VAR_environment"

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

# Step 7: Health check
log "🏥 Performing health check..."
if [ "$ENVIRONMENT" = "localstack" ]; then
    HEALTH_URL="http://localhost/$LOAD_BALANCER_DNS/health"
elif [ "$ENVIRONMENT" = "aws" ]; then
    HEALTH_URL="http://$LOAD_BALANCER_DNS/health"
fi

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