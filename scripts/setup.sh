#!/bin/bash

# Setup script for the Rails + LocalStack development environment

echo "🚀 Setting up Rails + LocalStack development environment..."

# Get the script directory and workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"

echo "📁 Working in: $WORKSPACE_ROOT"

# Navigate to the app directory
cd "$WORKSPACE_ROOT/app"

# Install Ruby gems (if Gemfile exists)
if [ -f "Gemfile" ]; then
    echo "📦 Installing Ruby gems..."
    bundle install
else
    echo "⚠️  No Gemfile found, skipping gem installation"
fi

# Install JavaScript dependencies (if package.json exists)
if [ -f "package.json" ]; then
    echo "📦 Installing JavaScript dependencies..."
    yarn install
else
    echo "⚠️  No package.json found, skipping JavaScript dependencies"
fi

# Set up the database
echo "🗄️ Setting up database..."
if [ ! -f "config/database.yml" ]; then
    echo "Creating database configuration..."
    cat > config/database.yml << 'EOF'
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  <<: *default
  database: db/development.sqlite3

test:
  <<: *default
  database: db/test.sqlite3

production:
  <<: *default
  database: db/production.sqlite3
EOF
fi

# Create database if Rails is available
if command -v rails >/dev/null 2>&1 && [ -f "Gemfile" ]; then
    echo "Creating database..."
    rails db:create 2>/dev/null || echo "Database already exists or will be created on first migration"
else
    echo "⚠️  Rails not available yet, skipping database creation"
fi

# Navigate to infrastructure directory and set up Terraform
echo "🏗️ Setting up Terraform infrastructure..."
cd "$WORKSPACE_ROOT/infrastructure"

# Initialize Terraform
terraform init

# Generate SSH keys for EC2 access
echo "🔑 Generating SSH keys for EC2 access..."
bash "$WORKSPACE_ROOT/scripts/generate-keys.sh"

# Start supporting services (Redis, Registry)
echo "🔧 Starting supporting services..."
bash "$WORKSPACE_ROOT/scripts/start-supporting-services.sh"

# Start LocalStack using Docker-in-Docker
echo "🐳 Starting LocalStack using Docker-in-Docker..."
bash "$WORKSPACE_ROOT/scripts/start-localstack.sh"

# Apply Terraform configuration
echo "🔧 Applying Terraform configuration..."
terraform plan
terraform apply -auto-approve

# Extract SSH private key for local use
echo "🔑 Extracting SSH private key for local access..."
terraform output -raw ssh_private_key > "$WORKSPACE_ROOT/scripts/rails-app-key"
chmod 600 "$WORKSPACE_ROOT/scripts/rails-app-key"
echo "✅ SSH private key saved to scripts/rails-app-key"

echo "✅ Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Run 'rails generate' commands to create your controllers and models"
echo "2. Run 'rails server' to start the application"
echo "3. Access the app at http://localhost:3000"
echo "4. LocalStack is available at http://localhost:4566"
echo ""
echo "🔍 Useful commands:"
echo "- rails server: Start the Rails server"
echo "- terraform plan: Preview infrastructure changes"
echo "- terraform apply: Apply infrastructure changes"
echo "- aws --endpoint-url=http://localhost:4566 sqs list-queues: List SQS queues"
echo "- awslocal sqs list-queues: List SQS queues (using awslocal)"
echo "- awslocal s3 ls: List S3 buckets"
echo "- bash ./scripts/start-localstack.sh: Start LocalStack"
echo "- bash ./scripts/stop-localstack.sh: Stop LocalStack"