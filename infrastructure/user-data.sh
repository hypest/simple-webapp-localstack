#!/bin/bash
set -e

# User data script for Rails application deployment
echo "Starting Rails application setup..."

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create application directory
mkdir -p /opt/rails-app
cd /opt/rails-app

# Set environment variables
cat > /opt/rails-app/.env << EOF
RAILS_ENV=production
AWS_DEFAULT_REGION=${region}
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
LOCALSTACK_ENDPOINT=${localstack_endpoint}
COUNTER_QUEUE_URL=${counter_queue_url}
DATABASE_URL=sqlite3:///opt/rails-app/db/production.sqlite3
REDIS_URL=redis://localhost:6379/0
EOF

# Check if we need to configure Docker for local registry access
if [[ "${app_image_uri}" == localhost:5001/* ]]; then
    echo "Configuring Docker for local registry access..."
    # For LocalStack deployment, we need to access the host's local registry
    # This requires additional network configuration in a real deployment
    echo '{"insecure-registries": ["localhost:5001", "host.docker.internal:5001"]}' > /etc/docker/daemon.json
    systemctl restart docker
    
    # Wait for Docker to restart
    sleep 10
fi

# Create production docker-compose file
cat > /opt/rails-app/docker-compose.yml << 'EOF'
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

  rails:
    image: ${app_image_uri}
    ports:
      - "3000:3000"
    env_file:
      - .env
    volumes:
      - app_data:/opt/rails-app/db
      - app_storage:/opt/rails-app/storage
    depends_on:
      - redis
    restart: unless-stopped
    command: ["sh", "-c", "bundle exec rails db:prepare && bundle exec rails server -b 0.0.0.0"]

  sidekiq:
    image: ${app_image_uri}
    env_file:
      - .env
    volumes:
      - app_data:/opt/rails-app/db
      - app_storage:/opt/rails-app/storage
    depends_on:
      - redis
      - rails
    restart: unless-stopped
    command: ["bundle", "exec", "sidekiq"]

volumes:
  redis_data:
  app_data:
  app_storage:
EOF

# Install and configure CloudWatch agent (for LocalStack)
yum install -y awscli

# Create a simple health check endpoint script
cat > /opt/rails-app/health-check.sh << 'EOF'
#!/bin/bash
# Simple health check script
curl -f http://localhost:3000/health || exit 1
EOF

chmod +x /opt/rails-app/health-check.sh

# Create systemd service for the application
cat > /etc/systemd/system/rails-app.service << 'EOF'
[Unit]
Description=Rails Counter Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/rails-app
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable the service (but don't start it yet - we need the image first)
systemctl daemon-reload
systemctl enable rails-app.service

echo "Rails application setup complete. Ready for deployment."