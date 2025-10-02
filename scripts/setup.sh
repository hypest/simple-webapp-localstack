#!/bin/bash

# Setup script for the Rails + LocalStack development environment

echo "🚀 Setting up Rails + LocalStack development environment..."

# Navigate to the app directory
cd /workspace/app

# Install Ruby gems
echo "📦 Installing Ruby gems..."
bundle install

# Install JavaScript dependencies (if package.json exists)
if [ -f "package.json" ]; then
    echo "📦 Installing JavaScript dependencies..."
    yarn install
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

# Create database if it doesn't exist
rails db:create 2>/dev/null || echo "Database already exists or will be created on first migration"

# Navigate to infrastructure directory and set up Terraform
echo "🏗️ Setting up Terraform infrastructure..."
cd /workspace/infrastructure

# Initialize Terraform
terraform init

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack to be ready..."
while ! curl -s http://localstack:4566/health > /dev/null; do
    echo "Waiting for LocalStack..."
    sleep 2
done

# Apply Terraform configuration
echo "🔧 Applying Terraform configuration..."
terraform plan
terraform apply -auto-approve

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
echo "- aws --endpoint-url=http://localstack:4566 sqs list-queues: List SQS queues"