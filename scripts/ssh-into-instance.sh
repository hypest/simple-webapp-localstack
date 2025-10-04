#!/bin/bash

# EC2 Instance Access Script with Container Bridging
# 
# This script discovers running EC2 instances and provides smart access:
# - LocalStack Community: Shows mocked instances with deployment guidance
# - LocalStack Pro/Ultimate: Maps instances to backing Docker containers
# - Real AWS: Traditional SSH access with Terraform key extraction
#
# Security Features:
# - Extracts SSH private key exclusively from Terraform state (zero filesystem storage)
# - Creates temporary key files with secure permissions that are auto-cleaned
# - No persistent SSH key files anywhere in the project
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
SSH_USER="ec2-user"
TERRAFORM_DIR="$PROJECT_ROOT/infrastructure"

# Function to find backing Docker container for LocalStack EC2 instance
find_backing_container() {
    local instance_id="$1"
    
    log "Searching for Docker container backing instance: $instance_id"
    
    # Try various container naming patterns used by LocalStack
    local container_patterns=(
        "localstack-ec2.${instance_id}"
        "localstack-ec2-${instance_id}"
        "ec2.${instance_id}"
        "ec2-${instance_id}"
        "${instance_id}"
    )
    
    for pattern in "${container_patterns[@]}"; do
        log "Checking pattern: $pattern"
        
        # Check if container exists and is running
        if docker ps --format "table {{.Names}}" | grep -q "^${pattern}$"; then
            echo "$pattern"
            return 0
        fi
    done
    
    # Also try partial matches in case of prefixes/suffixes
    local partial_match
    partial_match=$(docker ps --format "table {{.Names}}" | grep "$instance_id" | head -1 || true)
    
    if [[ -n "$partial_match" ]]; then
        log "Found partial match: $partial_match"
        echo "$partial_match"
        return 0
    fi
    
    return 1
}

# Function to determine the best shell for a container
get_container_shell() {
    local container_name="$1"
    
    # Try to determine available shells in order of preference
    local shells=("/bin/bash" "/bin/sh" "/bin/ash")
    
    for shell in "${shells[@]}"; do
        if docker exec "$container_name" test -x "$shell" 2>/dev/null; then
            echo "$shell"
            return 0
        fi
    done
    
    # Default fallback
    echo "/bin/sh"
}

# Function to detect LocalStack edition and capabilities
detect_localstack_capabilities() {
    if [[ "$USE_LOCALSTACK" == "true" ]]; then
        local edition=$(curl -s http://localhost:4566/_localstack/health 2>/dev/null | jq -r '.edition // "community"')
        echo "$edition"
    else
        echo "aws"
    fi
}

# Function to get SSH private key from Terraform output
get_ssh_key_from_terraform() {
    local terraform_dir="$1"
    
    if [[ -d "$terraform_dir" && -f "$terraform_dir/terraform.tfstate" ]]; then
        log "Extracting SSH private key from Terraform state..."
        
        # Change to terraform directory and extract the key
        if (cd "$terraform_dir" && terraform output -raw ssh_private_key 2>/dev/null); then
            return 0
        else
            warn "Failed to extract SSH key from Terraform output"
            return 1
        fi
    else
        warn "Terraform state not found at $terraform_dir"
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
    echo "  --list          List instances without attempting to connect"
    echo "  --localstack    Use LocalStack endpoint (default)"
    echo "  --aws           Use real AWS"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive selection with LocalStack"
    echo "  $0 --aws             # Interactive selection with real AWS"
    echo "  $0 --list             # List instances only"
    echo ""
    echo "LocalStack Support:"
    echo "  Community Edition: Shows mocked instances (guidance provided)"
    echo "  Pro/Ultimate:      Maps instances to Docker containers"
    echo ""
    echo "Security:"
    echo "  SSH keys are extracted from Terraform state on-demand"
    echo "  No SSH keys are stored in the filesystem"
}

# Parse command line arguments
LIST_ONLY=false
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
        --help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1. Use --help for usage information."
            ;;
    esac
done

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
        --query 'Reservations[].Instances[].[InstanceId,(Tags[?Key==`Name`].Value)[0],PublicIpAddress,PrivateIpAddress,InstanceType]' \
        --output json > "$TEMP_FILE" 2>"$ERROR_FILE"; then
        
        # Check if the output is valid JSON
        if jq empty < "$TEMP_FILE" 2>/dev/null; then
            cat "$TEMP_FILE"
        else
            warn "Invalid JSON response received"
            echo "[]"
        fi
    else
        warn "Failed to discover instances within ${DISCOVERY_TIMEOUT}s timeout"
        if [[ -s "$ERROR_FILE" ]]; then
            warn "Error details:"
            cat "$ERROR_FILE" >&2
        fi
        echo "[]"
    fi
    
    # Clean up temporary files
    rm -f "$TEMP_FILE" "$ERROR_FILE"
}

# Function to display instances in a readable format  
display_instances() {
    local instances="$1"
    
    echo "$instances" | jq -r '
        if length == 0 then
            "No running instances found"
        else
            .[] | 
            "\(.[0]) | \(.[1] // "unnamed") | \(.[2] // "no-public-ip") | \(.[3] // "no-private-ip") | \(.[4] // "unknown")"
        end
    '
}

# Function to show selection menu with arrow key navigation
show_selection_menu() {
    local instances="$1"
    
    # Parse instances into arrays
    local instance_ids=()
    local instance_names=()
    local public_ips=()
    local private_ips=()
    local instance_types=()
    
    while IFS='|' read -r id name public_ip private_ip type; do
        # Trim whitespace
        id=$(echo "$id" | xargs)
        name=$(echo "$name" | xargs)
        public_ip=$(echo "$public_ip" | xargs)
        private_ip=$(echo "$private_ip" | xargs)
        type=$(echo "$type" | xargs)
        
        instance_ids+=("$id")
        instance_names+=("$name")
        public_ips+=("$public_ip")
        private_ips+=("$private_ip")
        instance_types+=("$type")
    done < <(echo "$instances" | jq -r '.[] | "\(.[0])|\(.[1] // "unnamed")|\(.[2] // "no-public-ip")|\(.[3] // "no-private-ip")|\(.[4] // "unknown")"')
    
    local num_instances=${#instance_ids[@]}
    
    if [[ $num_instances -eq 0 ]]; then
        warn "No running instances found"
        return 1
    fi
    
    echo ""
    info "Found $num_instances running instance(s):"
    echo ""
    
    # If only one instance, auto-select it
    if [[ $num_instances -eq 1 ]]; then
        info "Only one instance found, auto-selecting:"
        echo ""
        printf "  %-20s %-15s %-15s %-15s %s\n" "Instance ID" "Name" "Public IP" "Private IP" "Type"
        printf "  %-20s %-15s %-15s %-15s %s\n" "────────────" "────────" "─────────" "──────────" "────"
        printf "  %-20s %-15s %-15s %-15s %s\n" "${instance_ids[0]}" "${instance_names[0]}" "${public_ips[0]}" "${private_ips[0]}" "${instance_types[0]}"
        echo ""
        
        access_instance "${instance_ids[0]}" "${instance_names[0]}" "${public_ips[0]}" "${private_ips[0]}"
        return $?
    fi
    
    # Multiple instances - show interactive menu
    local selected=0
    local key
    
    while true; do
        # Clear screen and show header
        clear
        echo ""
        info "Select an EC2 instance to access (use ↑/↓ arrows, Enter to select, q to quit):"
        echo ""
        printf "  %-20s %-15s %-15s %-15s %s\n" "Instance ID" "Name" "Public IP" "Private IP" "Type"
        printf "  %-20s %-15s %-15s %-15s %s\n" "────────────" "────────" "─────────" "──────────" "────"
        
        # Show instances with selection indicator
        for ((i=0; i<num_instances; i++)); do
            if [[ $i -eq $selected ]]; then
                printf "${GREEN}> %-19s %-15s %-15s %-15s %s${NC}\n" "${instance_ids[i]}" "${instance_names[i]}" "${public_ips[i]}" "${private_ips[i]}" "${instance_types[i]}"
            else
                printf "  %-20s %-15s %-15s %-15s %s\n" "${instance_ids[i]}" "${instance_names[i]}" "${public_ips[i]}" "${private_ips[i]}" "${instance_types[i]}"
            fi
        done
        
        echo ""
        info "Navigation: ↑/↓ to move, Enter to select, q to quit"
        
        # Read single character
        read -rsn1 key
        
        case $key in
            # Up arrow (escape sequence: ^[[A)
            $'\e')
                read -rsn2 key
                if [[ $key == "[A" ]]; then
                    ((selected--))
                    if [[ $selected -lt 0 ]]; then
                        selected=$((num_instances-1))
                    fi
                elif [[ $key == "[B" ]]; then
                    ((selected++))
                    if [[ $selected -ge $num_instances ]]; then
                        selected=0
                    fi
                fi
                ;;
            # Enter
            '')
                clear
                echo ""
                info "Selected instance:"
                printf "  %-20s %-15s %-15s %-15s %s\n" "${instance_ids[selected]}" "${instance_names[selected]}" "${public_ips[selected]}" "${private_ips[selected]}" "${instance_types[selected]}"
                echo ""
                
                access_instance "${instance_ids[selected]}" "${instance_names[selected]}" "${public_ips[selected]}" "${private_ips[selected]}"
                return $?
                ;;
            # Quit
            'q'|'Q')
                echo ""
                info "Goodbye!"
                return 0
                ;;
        esac
    done
}

# Function to access an instance (SSH or container)
access_instance() {
    local instance_id="$1"
    local name="$2"
    local public_ip="$3"
    local private_ip="$4"
    local user="${SSH_USER}"
    
    # Handle LocalStack instances by finding backing containers
    if [[ "$USE_LOCALSTACK" == "true" ]]; then
        local edition=$(detect_localstack_capabilities)
        echo ""
        
        if [[ "$edition" == "community" ]]; then
            warn "LocalStack Community Edition: Instance '$instance_id' is mocked"
            echo ""
            info "The instance exists in the API but has no backing container."
            info "To access your deployed application:"
            echo ""
            info "1. 🚀 Deploy the app first:"
            info "   ./scripts/deploy.sh localstack"
            echo ""
            info "2. 🐳 Then access the app container directly:"
            info "   docker ps  # Find your rails app container"
            info "   docker exec -it <container-name> bash"
            echo ""
            info "3. 💰 Or upgrade to LocalStack Pro for direct instance→container mapping"
            return 0
            
        else
            # LocalStack Pro/Ultimate - look for backing container
            info "LocalStack Pro/Ultimate: Looking for backing container..."
            
            local backing_container
            if backing_container=$(find_backing_container "$instance_id"); then
                log "✅ Found backing container: $backing_container"
                
                # Get appropriate shell
                local shell
                shell=$(get_container_shell "$backing_container")
                
                echo ""
                info "🐳 Connecting to container: $backing_container"
                info "📦 Instance: $instance_id ($name)"
                info "🐚 Shell: $shell"
                echo ""
                
                # Execute shell in container
                log "Starting shell in container..."
                docker exec -it "$backing_container" "$shell"
                return $?
                
            else
                warn "❌ No backing container found for instance $instance_id"
                echo ""
                info "This could mean:"
                info "• Instance is using Mock VM manager (not Docker VM manager)"
                info "• Container hasn't been created yet"
                info "• Instance was terminated but still shows in API"
                echo ""
                info "Try:"
                info "1. Terminate and recreate the instance"
                info "2. Check LocalStack configuration (EC2_VM_MANAGER=docker)"
                info "3. Check LocalStack logs: docker logs localstack"
                return 1
            fi
        fi
    fi
    
    # For real AWS instances, use SSH
    log "SSH-ing into $instance_id..."
    
    # Create cleanup trap for temporary SSH key
    local temp_ssh_key
    temp_ssh_key="$(mktemp -t ssh-key-XXXXXX)"
    
    # Set up cleanup trap
    trap 'rm -f "$temp_ssh_key" 2>/dev/null || true' EXIT INT TERM
    
    # Get SSH private key from Terraform output
    log "Extracting SSH private key from Terraform..."
    
    local terraform_dir="infrastructure/environments/production"
    
    # Get private key and write to temporary file
    if ! get_ssh_key_from_terraform "$terraform_dir" > "$temp_ssh_key" 2>/dev/null; then
        error "Failed to extract SSH private key from Terraform outputs"
        error "Make sure you've run 'terraform apply' and the ssh_private_key output exists"
        return 1
    fi
    
    # Set proper permissions on temporary key file
    chmod 600 "$temp_ssh_key"
    
    # Connect to instance
    log "Connecting to $public_ip with user '$user'..."
    echo ""
    info "🔑 Using SSH key from Terraform output"
    info "📦 Instance: $instance_id ($name)"
    info "🌍 Address: $public_ip"
    echo ""
    
    # Use SSH with various connection options
    ssh -i "$temp_ssh_key" \
        -o "StrictHostKeyChecking=no" \
        -o "UserKnownHostsFile=/dev/null" \
        -o "ConnectTimeout=10" \
        -o "ServerAliveInterval=60" \
        -o "ServerAliveCountMax=3" \
        "${user}@${public_ip}"
    
    return $?
}

# Main function
main() {
    echo ""
    info "🚀 EC2 Instance Access Script"
    echo ""
    
    # Discover instances
    local instances
    instances=$(discover_instances)
    
    if [[ "$LIST_ONLY" == "true" ]]; then
        echo ""
        info "📋 Running instances:"
        echo ""
        display_instances "$instances"
        return 0
    fi
    
    # Show interactive selection menu
    show_selection_menu "$instances"
}

# Run main function
main "$@"