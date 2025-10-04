#!/bin/bash

# SSH into EC2 Instance Selection Script
# 
# This script discovers running EC2 instances and provides an interactive menu
# to select and SSH into them. It supports both LocalStack and real AWS.
#
# Security Features:
# - Extracts SSH private key exclusively from Terraform state (zero filesystem storage)
# - Creates temporary key files with secure permissions that are auto-cleaned
# - No persistent SSH key files anywhere in the project
#
# LocalStack Support:
# - Community Edition: Shows mocked instances (not SSH-accessible)
# - Pro/Ultimate: Creates real Docker containers with SSH access
#
# Usage: ./ssh-into-instance.sh [--list] [--localstack] [--aws]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default configuration
USE_LOCALSTACK=true
DISCOVERY_TIMEOUT=5
# SSH_KEY_PATH removed - keys are now extracted exclusively from Terraform
SSH_USER="ec2-user"
TERRAFORM_DIR="$PROJECT_ROOT/infrastructure"

# Function to detect LocalStack edition and capabilities
detect_localstack_capabilities() {
    if [[ "$USE_LOCALSTACK" == "true" ]]; then
        local edition=$(curl -s http://localhost:4566/_localstack/health 2>/dev/null | jq -r '.edition // "unknown"')
        echo "$edition"
    else
        echo "aws"
    fi
}

# Function to get SSH private key from Terraform output
get_ssh_key_from_terraform() {
    if [[ -d "$TERRAFORM_DIR" && -f "$TERRAFORM_DIR/terraform.tfstate" ]]; then
        log "Extracting SSH private key from Terraform state..."
        
        # Change to terraform directory and extract the key
        if (cd "$TERRAFORM_DIR" && terraform output -raw ssh_private_key 2>/dev/null); then
            return 0
        else
            warn "Failed to extract SSH key from Terraform output"
            return 1
        fi
    else
        warn "Terraform state not found at $TERRAFORM_DIR"
        return 1
    fi
}

# Function to create temporary key file from content
create_temp_key_file() {
    local key_content="$1"
    local temp_key_file
    
    # Create a temporary file with restrictive permissions
    temp_key_file=$(mktemp)
    chmod 600 "$temp_key_file"
    
    # Write the key content to the temporary file
    echo "$key_content" > "$temp_key_file"
    
    echo "$temp_key_file"
}

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${CYAN}$1${NC}"
}

show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --list        List running instances without SSH connection"
    echo "  --localstack  Use LocalStack endpoint (default)"
    echo "  --aws         Use real AWS (requires proper AWS credentials)"
    echo "  --test-key    Test SSH key extraction from Terraform (shows key fingerprint)"
    echo "  --help        Show this help message"
    echo ""
    echo "SSH Key Handling:"
    echo "  - Extracts SSH private key directly from Terraform state"
    echo "  - No filesystem key files are created or used"
    echo ""
    echo "Interactive mode (default): Discover instances and show selection menu"
}

# Parse command line arguments
LIST_ONLY=false
TEST_KEY_ONLY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --list)
            LIST_ONLY=true
            shift
            ;;
        --localstack)
            USE_LOCALSTACK=true
            shift
            ;;
        --aws)
            USE_LOCALSTACK=false
            shift
            ;;
        --test-key)
            TEST_KEY_ONLY=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1. Use --help for usage information."
            ;;
    esac
done

# Note: SSH key check moved to ssh_into_instance function to allow Terraform extraction

# Set appropriate AWS endpoint
if [[ "$USE_LOCALSTACK" == "true" ]]; then
    AWS_ENDPOINT="--endpoint-url=http://localhost:4566"
    info "Using LocalStack endpoint: http://localhost:4566"
else
    AWS_ENDPOINT=""
    info "Using real AWS"
fi

# Function to discover running EC2 instances with timeout
discover_instances() {
    log "Discovering running EC2 instances (timeout: ${DISCOVERY_TIMEOUT}s)..." >&2
    
    # Create a temporary file for the instance data
    TEMP_FILE=$(mktemp)
    ERROR_FILE=$(mktemp)
    
    # Run AWS command with timeout
    if timeout $DISCOVERY_TIMEOUT aws ec2 describe-instances $AWS_ENDPOINT \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],PublicIpAddress,PrivateIpAddress,InstanceType]' \
        --output json > "$TEMP_FILE" 2>"$ERROR_FILE"; then
        
        # Check if the output is valid JSON
        if ! jq empty "$TEMP_FILE" 2>/dev/null; then
            error "Received invalid JSON response from AWS CLI" >&2
            rm -f "$TEMP_FILE" "$ERROR_FILE"
            return 1
        fi
        
        # Check if we got any instances
        if [[ $(cat "$TEMP_FILE" | jq '. | length') -eq 0 ]]; then
            warn "No running instances found" >&2
            rm -f "$TEMP_FILE" "$ERROR_FILE"
            return 1
        fi
        
        cat "$TEMP_FILE"
        rm -f "$TEMP_FILE" "$ERROR_FILE"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            error "Timeout: Failed to discover instances within ${DISCOVERY_TIMEOUT} seconds" >&2
        else
            error "AWS command failed. Error: $(cat "$ERROR_FILE" 2>/dev/null || echo 'Unknown error')" >&2
        fi
        rm -f "$TEMP_FILE" "$ERROR_FILE"
        return 1
    fi
}

# Function to display instances in a readable format
display_instances() {
    local instances_json="$1"
    
    echo ""
    info "Running EC2 Instances:"
    info "====================="
    
    # Validate JSON input
    if ! echo "$instances_json" | jq empty 2>/dev/null; then
        error "Invalid instance data received"
        return 1
    fi
    
    # Use a different approach to avoid subshell issues
    local instance_count=$(echo "$instances_json" | jq '. | length')
    for ((i=0; i<instance_count; i++)); do
        local instance=$(echo "$instances_json" | jq -r ".[$i] | @json")
        local instance_id=$(echo "$instance" | jq -r '.[0]')
        local name=$(echo "$instance" | jq -r '.[1] // "N/A"')
        local public_ip=$(echo "$instance" | jq -r '.[2] // "N/A"')
        local private_ip=$(echo "$instance" | jq -r '.[3] // "N/A"')
        local instance_type=$(echo "$instance" | jq -r '.[4] // "N/A"')
        
        printf "${BLUE}%2d)${NC} ${GREEN}%-20s${NC} ${YELLOW}%-19s${NC} Public: %-15s Private: %-15s Type: %s\n" \
            $((i + 1)) "$instance_id" "$name" "$public_ip" "$private_ip" "$instance_type"
    done
    
    # Add LocalStack information
    if [[ "$USE_LOCALSTACK" == "true" ]]; then
        local edition=$(detect_localstack_capabilities)
        echo ""
        
        case "$edition" in
            "community")
                warn "LocalStack Community Edition: Instances are mocked (not SSH-accessible)"
                info "Upgrade to LocalStack Pro for real SSH access to Docker-based instances"
                ;;
            "pro"|"ultimate")
                info "LocalStack Pro/Ultimate: Instances should be SSH-accessible Docker containers"
                info "Look for SSH connection details in LocalStack logs"
                ;;
            *)
                warn "LocalStack edition unknown - SSH access may vary"
                ;;
        esac
        
        info "For real AWS instances, deploy to production and use: $0 --aws"
    fi
}

# Function to show interactive selection menu
show_selection_menu() {
    local instances_json="$1"
    local instance_count=$(echo "$instances_json" | jq '. | length')
    
    if [[ $instance_count -eq 1 ]]; then
        log "Only one instance found, connecting automatically..."
        return 0
    fi
    
    echo ""
    info "Use arrow keys to select an instance, then press ENTER:"
    
    local selected=0
    local key
    
    while true; do
        # Clear screen and redraw
        clear
        info "Select EC2 Instance to SSH into:"
        info "================================"
        echo ""
        
        local index=0
        echo "$instances_json" | jq -r '.[] | @json' | while IFS= read -r instance; do
            local instance_id=$(echo "$instance" | jq -r '.[0]')
            local name=$(echo "$instance" | jq -r '.[1] // "N/A"')
            local public_ip=$(echo "$instance" | jq -r '.[2] // "N/A"')
            local private_ip=$(echo "$instance" | jq -r '.[3] // "N/A"')
            local instance_type=$(echo "$instance" | jq -r '.[4] // "N/A"')
            
            if [[ $index -eq $selected ]]; then
                printf "${GREEN}→ %2d) %-20s %-19s Public: %-15s Private: %-15s Type: %s${NC}\n" \
                    $((index + 1)) "$instance_id" "$name" "$public_ip" "$private_ip" "$instance_type"
            else
                printf "  ${BLUE}%2d)${NC} ${YELLOW}%-20s${NC} %-19s Public: %-15s Private: %-15s Type: %s\n" \
                    $((index + 1)) "$instance_id" "$name" "$public_ip" "$private_ip" "$instance_type"
            fi
            ((index++))
        done
        
        echo ""
        info "Use ↑/↓ arrow keys to navigate, ENTER to select, 'q' to quit"
        
        # Read a single character
        read -rsn1 key
        
        case "$key" in
            $'\033')
                # Arrow key sequence
                read -rsn2 key
                case "$key" in
                    '[A') # Up arrow
                        ((selected > 0)) && ((selected--))
                        ;;
                    '[B') # Down arrow
                        ((selected < instance_count - 1)) && ((selected++))
                        ;;
                esac
                ;;
            '') # Enter key
                break
                ;;
            'q'|'Q')
                echo ""
                info "Cancelled by user"
                exit 0
                ;;
        esac
    done
    
    return $selected
}

# Function to SSH into selected instance
ssh_into_instance() {
    local instances_json="$1"
    local selected_index="$2"
    
    local selected_instance=$(echo "$instances_json" | jq -r ".[$selected_index] | @json")
    local instance_id=$(echo "$selected_instance" | jq -r '.[0]')
    local name=$(echo "$selected_instance" | jq -r '.[1] // "N/A"')
    local public_ip=$(echo "$selected_instance" | jq -r '.[2]')
    local private_ip=$(echo "$selected_instance" | jq -r '.[3]')
    
    # Check LocalStack capabilities
    if [[ "$USE_LOCALSTACK" == "true" ]]; then
        local edition=$(detect_localstack_capabilities)
        echo ""
        
        if [[ "$edition" == "community" ]]; then
            warn "LocalStack Community Edition uses Mock VM manager - instances are not SSH-accessible"
            warn "The instance '$instance_id ($name)' exists in LocalStack's API but is not a real server"
            echo ""
            info "To SSH into real instances, you have these options:"
            info "1. Upgrade to LocalStack Pro for Docker-based EC2 instances with SSH support"
            info "2. Deploy to real AWS: terraform apply in infrastructure/environments/production/"
            info "3. Then run: $0 --aws"
            echo ""
            info "For development with LocalStack Community, you can:"
            info "- Use 'docker exec -it <container_name> /bin/bash' for local containers"
            info "- Access the Rails app directly at http://localhost:3000"
            info "- Use LocalStack's web interface at http://localhost:4566"
            return 0
        elif [[ "$edition" == "pro" ]] || [[ "$edition" == "ultimate" ]]; then
            # Check if there are actual Docker containers for this instance
            local container_name="localstack-ec2.$instance_id"
            if docker ps --format "table {{.Names}}" | grep -q "$container_name"; then
                info "LocalStack Pro detected - this should be a real SSH-accessible container"
                # Continue with SSH attempt
            else
                warn "LocalStack Pro detected but no Docker container found for instance $instance_id"
                warn "The instance may not be using the Docker VM manager"
                info "Try terminating and recreating the instance, or check LocalStack configuration"
                return 0
            fi
        else
            warn "Could not determine LocalStack edition. Attempting SSH connection anyway..."
        fi
    fi
    
    # Determine which IP to use for SSH
    local ssh_ip
    if [[ "$public_ip" != "null" && "$public_ip" != "N/A" && -n "$public_ip" ]]; then
        ssh_ip="$public_ip"
        info "Using public IP: $public_ip"
    elif [[ "$private_ip" != "null" && "$private_ip" != "N/A" && -n "$private_ip" ]]; then
        ssh_ip="$private_ip"
        info "Using private IP: $private_ip"
    else
        error "No valid IP address found for instance $instance_id"
    fi
    
    log "Connecting to instance: $instance_id ($name)"
    
    # Extract SSH key from Terraform state
    local ssh_key_content
    local temp_key_file
    
    if ssh_key_content=$(get_ssh_key_from_terraform); then
        temp_key_file=$(create_temp_key_file "$ssh_key_content")
        info "Using SSH key from Terraform state"
    else
        error "Failed to extract SSH key from Terraform state. Ensure terraform is available and applied."
        return 1
    fi
    
    log "SSH key source: $ssh_key_source"
    
    # Test connectivity first
    echo ""
    info "Testing connectivity to $ssh_ip..."
    
    if timeout 5 bash -c "</dev/tcp/$ssh_ip/22" 2>/dev/null; then
        log "Port 22 is reachable, attempting SSH connection..."
    else
        warn "Port 22 is not reachable on $ssh_ip"
        warn "The instance may not be fully started or may have connectivity issues"
        echo ""
        read -p "Do you want to attempt SSH anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "SSH attempt cancelled"
            # Clean up temporary key file
            rm -f "$temp_key_file"
            return 0
        fi
    fi
    
    # Connect via SSH
    echo ""
    info "Connecting to $SSH_USER@$ssh_ip..."
    info "Instance: $instance_id ($name)"
    echo ""
    
    # SSH with proper options
    ssh -i "$temp_key_file" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 \
        "$SSH_USER@$ssh_ip"
    
    local ssh_exit_code=$?
    
    # Clean up temporary key file
    rm -f "$temp_key_file"
    
    return $ssh_exit_code
}

# Main execution
main() {
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed. Please install jq to use this script."
    fi
    
    # Check if aws CLI is available
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is required but not installed. Please install awscli to use this script."
    fi
    
    # Check if terraform is available (for key extraction)
    if ! command -v terraform &> /dev/null; then
        warn "Terraform not found - will use filesystem SSH key as fallback"
    fi
    
    # If test key mode, test key extraction and exit
    if [[ "$TEST_KEY_ONLY" == "true" ]]; then
        echo ""
        info "Testing SSH key extraction from Terraform..."
        
        local ssh_key_content
        if ssh_key_content=$(get_ssh_key_from_terraform); then
            local temp_key_file
            temp_key_file=$(create_temp_key_file "$ssh_key_content")
            
            log "✅ Successfully extracted SSH key from Terraform state"
            
            # Show key fingerprint for verification\n            if command -v ssh-keygen &> /dev/null; then\n                info \"SSH key fingerprint:\"\n                local fingerprint\n                if fingerprint=$(ssh-keygen -l -f \"$temp_key_file\" 2>/dev/null); then\n                    echo \"  $fingerprint\"\n                else\n                    echo \"  Could not generate fingerprint (key format may be unsupported)\"\n                fi\n            fi
            
            # Clean up
            rm -f "$temp_key_file"
            log "✅ Temporary key file cleaned up"
            
        else
            error "❌ Failed to extract SSH key from Terraform state"
            exit 1
        fi
        
        echo ""
        info "Key extraction test completed successfully!"
        info "The script will use this key instead of filesystem keys during SSH connections."
        exit 0
    fi
    
    # Discover instances
    local instances_json
    if ! instances_json=$(discover_instances); then
        exit 1
    fi
    
    # If list only mode, just display and exit
    if [[ "$LIST_ONLY" == "true" ]]; then
        display_instances "$instances_json"
        exit 0
    fi
    
    local instance_count=$(echo "$instances_json" | jq '. | length')
    
    if [[ $instance_count -eq 0 ]]; then
        warn "No running instances found"
        exit 1
    elif [[ $instance_count -eq 1 ]]; then
        display_instances "$instances_json"
        log "Only one instance found, connecting automatically..."
        ssh_into_instance "$instances_json" 0
    else
        show_selection_menu "$instances_json"
        local selected_index=$?
        clear
        ssh_into_instance "$instances_json" $selected_index
    fi
}

# Run main function
main "$@"