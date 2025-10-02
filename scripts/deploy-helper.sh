#!/bin/bash
set -e

# Deployment helper script with common operations
# Usage: ./deploy-helper.sh [command] [environment] [args...]

COMMAND=${1:-help}
ENVIRONMENT=${2:-localstack}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Set AWS endpoint based on environment
if [ "$ENVIRONMENT" = "localstack" ]; then
    AWS_ENDPOINT="--endpoint-url=http://localhost:4566"
    log "🏠 Using LocalStack environment"
elif [ "$ENVIRONMENT" = "aws" ]; then
    AWS_ENDPOINT=""
    log "☁️  Using AWS environment"
fi

case "$COMMAND" in
    "build")
        log "🐳 Building application image..."
        cd "$(dirname "$SCRIPT_DIR")"
        docker build -f Dockerfile.prod -t "rails-counter-app:latest" .
        ;;
    
    "push")
        VERSION=${3:-latest}
        log "📦 Pushing image version: $VERSION"
        "$SCRIPT_DIR/deploy.sh" "$ENVIRONMENT" "$VERSION"
        ;;
    
    "status")
        log "📊 Checking deployment status..."
        cd "$(dirname "$SCRIPT_DIR")/infrastructure"
        
        echo -e "${BLUE}=== Infrastructure Status ===${NC}"
        terraform output
        
        echo -e "\n${BLUE}=== EC2 Instances ===${NC}"
        aws $AWS_ENDPOINT ec2 describe-instances \
            --filters "Name=tag:Project,Values=simple-counter-app" \
            --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress}' \
            --output table || echo "No instances found"
        
        echo -e "\n${BLUE}=== Auto Scaling Group ===${NC}"
        ASG_NAME=$(terraform output -raw autoscaling_group_name 2>/dev/null || echo "")
        if [ -n "$ASG_NAME" ]; then
            aws $AWS_ENDPOINT autoscaling describe-auto-scaling-groups \
                --auto-scaling-group-names "$ASG_NAME" \
                --query 'AutoScalingGroups[].{Name:AutoScalingGroupName,Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Instances:length(Instances)}' \
                --output table
        fi
        
        echo -e "\n${BLUE}=== Load Balancer ===${NC}"
        aws $AWS_ENDPOINT elbv2 describe-load-balancers \
            --query 'LoadBalancers[?contains(LoadBalancerName, `rails-app`)].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}' \
            --output table || echo "No load balancers found"
        ;;
    
    "logs")
        INSTANCE_ID=${3}
        if [ -z "$INSTANCE_ID" ]; then
            echo "Usage: $0 logs $ENVIRONMENT <instance-id>"
            echo "Available instances:"
            aws $AWS_ENDPOINT ec2 describe-instances \
                --filters "Name=tag:Project,Values=simple-counter-app" "Name=instance-state-name,Values=running" \
                --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
                --output table
            exit 1
        fi
        
        log "📋 Fetching logs from instance: $INSTANCE_ID"
        # Note: In LocalStack, this might not work exactly like real AWS
        aws $AWS_ENDPOINT ssm send-command \
            --instance-ids "$INSTANCE_ID" \
            --document-name "AWS-RunShellScript" \
            --parameters 'commands=["journalctl -u rails-app.service -n 50"]' || \
            echo "Note: SSM might not be fully supported in LocalStack"
        ;;
    
    "scale")
        DESIRED_CAPACITY=${3:-2}
        log "📈 Scaling to $DESIRED_CAPACITY instances..."
        cd "$(dirname "$SCRIPT_DIR")/infrastructure"
        ASG_NAME=$(terraform output -raw autoscaling_group_name)
        
        aws $AWS_ENDPOINT autoscaling update-auto-scaling-group \
            --auto-scaling-group-name "$ASG_NAME" \
            --desired-capacity "$DESIRED_CAPACITY"
        
        log "✅ Scaling initiated. Use 'status' command to check progress."
        ;;
    
    "rollback")
        VERSION=${3}
        if [ -z "$VERSION" ]; then
            echo "Usage: $0 rollback $ENVIRONMENT <version>"
            exit 1
        fi
        
        log "🔄 Rolling back to version: $VERSION"
        "$SCRIPT_DIR/deploy.sh" "$ENVIRONMENT" "$VERSION"
        ;;
    
    "destroy")
        log "💥 Destroying infrastructure..."
        read -p "Are you sure you want to destroy all infrastructure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            cd "$(dirname "$SCRIPT_DIR")/infrastructure"
            terraform destroy -auto-approve
            log "✅ Infrastructure destroyed"
        else
            log "❌ Destruction cancelled"
        fi
        ;;
    
    "health")
        log "🏥 Checking application health..."
        cd "$(dirname "$SCRIPT_DIR")/infrastructure"
        LOAD_BALANCER_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "")
        
        if [ -n "$LOAD_BALANCER_DNS" ]; then
            if [ "$ENVIRONMENT" = "localstack" ]; then
                HEALTH_URL="http://localhost:4566/$LOAD_BALANCER_DNS/health"
            else
                HEALTH_URL="http://$LOAD_BALANCER_DNS/health"
            fi
            
            if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
                log "✅ Application is healthy!"
            else
                log "❌ Application health check failed"
                exit 1
            fi
        else
            log "❌ Load balancer DNS not found"
            exit 1
        fi
        ;;
    
    "help"|*)
        echo -e "${BLUE}Rails App Deployment Helper${NC}"
        echo ""
        echo "Usage: $0 [command] [environment] [args...]"
        echo ""
        echo "Commands:"
        echo "  build                     - Build the application Docker image"
        echo "  push [version]           - Build and deploy application (default: latest)"
        echo "  status                   - Show deployment status and resources"
        echo "  logs <instance-id>       - Fetch logs from a specific instance"
        echo "  scale <count>            - Scale the application to specified instances"
        echo "  rollback <version>       - Rollback to a specific version"
        echo "  health                   - Check application health"
        echo "  destroy                  - Destroy all infrastructure"
        echo "  help                     - Show this help message"
        echo ""
        echo "Environments:"
        echo "  localstack              - Deploy to LocalStack (default)"
        echo "  aws                     - Deploy to real AWS"
        echo ""
        echo "Examples:"
        echo "  $0 build"
        echo "  $0 push localstack v1.2.3"
        echo "  $0 status aws"
        echo "  $0 scale localstack 3"
        echo "  $0 health localstack"
        ;;
esac