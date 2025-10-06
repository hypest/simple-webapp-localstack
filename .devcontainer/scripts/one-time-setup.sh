#!/usr/bin/env bash
set -euo pipefail

echo "Running one-time setup tasks..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# script now lives in .devcontainer/scripts, repo root is two levels up
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Workspace root: $WORKSPACE_ROOT"

# -- App dependencies --
if [ -d "$WORKSPACE_ROOT/app" ]; then
  cd "$WORKSPACE_ROOT/app"

  if [ -f "Gemfile" ]; then
    echo "Installing Ruby gems (bundle install)..."
    if command -v bundle >/dev/null 2>&1; then
      bundle install || echo "bundle install failed; please run manually"
    else
      echo "bundle not found; skipping bundle install"
    fi
  else
    echo "No Gemfile found in app/, skipping bundle install"
  fi

  if [ -f "package.json" ]; then
    echo "Installing JS dependencies (yarn)..."
    if command -v yarn >/dev/null 2>&1; then
      yarn install || echo "yarn install failed; please run manually"
    else
      echo "yarn not found; skipping JS install"
    fi
  else
    echo "No package.json found in app/, skipping JS install"
  fi

  # Database config
  echo "Ensuring database configuration..."
  if [ ! -f "config/database.yml" ]; then
    echo "Creating config/database.yml (sqlite fallback)"
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
  else
    echo "config/database.yml already exists"
  fi

  # Create DB if Rails is available
  if command -v rails >/dev/null 2>&1 && [ -f "Gemfile" ]; then
    echo "Creating database if missing..."
    rails db:create 2>/dev/null || echo "Database already exists or cannot be created yet"
  else
    echo "Rails not available or Gemfile missing; skipping db:create"
  fi
else
  echo "No app/ directory found; skipping app-specific setup"
fi

# -- Terraform infrastructure (init + plan; apply optional) --
if [ -d "$WORKSPACE_ROOT/infrastructure" ]; then
  echo "Initializing Terraform in infrastructure/"
  cd "$WORKSPACE_ROOT/infrastructure"
  # Ensure LocalStack/supporting services are running so terraform can reach the AWS endpoint
  if [ -f "$SCRIPT_DIR/start-services.sh" ]; then
    echo "Starting LocalStack and supporting services so Terraform can reach the AWS endpoint..."
    bash "$SCRIPT_DIR/start-services.sh" || echo "start-services.sh returned non-zero; Terraform may still fail if endpoint is unreachable"
  else
    echo "No $SCRIPT_DIR/start-services.sh found; ensure LocalStack is running before terraform plan"
  fi
  if command -v terraform >/dev/null 2>&1; then
    terraform init -input=false || echo "terraform init failed"
    terraform plan -input=false || echo "terraform plan failed"
    # Only auto-apply if explicitly enabled by env var
    if [ "${DEVCONTAINER_AUTO_APPLY_TF:-false}" = "true" ]; then
      echo "DEVCONTAINER_AUTO_APPLY_TF=true: running terraform apply (non-interactive)"
      terraform apply -auto-approve || echo "terraform apply failed"
    else
      echo "Skipping terraform apply (set DEVCONTAINER_AUTO_APPLY_TF=true to enable)"
    fi
  else
    echo "terraform not found; skipping terraform steps"
  fi
else
  echo "No infrastructure/ directory found; skipping terraform steps"
fi

echo "One-time setup complete"
