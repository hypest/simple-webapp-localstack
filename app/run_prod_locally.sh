#!/usr/bin/env bash
set -euo pipefail

# run_prod_locally.sh
# Helper to run this Rails app locally in "production" mode for testing.
# Usage: ./run_prod_locally.sh [PORT]
#
# Notes:
# - This script is for local testing only. Do NOT use in real production.
# - If you have `config/master.key`, the script will use it via RAILS_MASTER_KEY.
# - Otherwise it generates a temporary SECRET_KEY_BASE.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

PORT=${1:-3000}

echo "Running app in production mode (local test). Port=$PORT"

# Install gems (fast path: skip if vendor/bundle exists)
if [ ! -d "vendor/bundle" ]; then
  echo "Installing gems..."
  bundle install --jobs 4
fi

echo "Preparing runtime directories..."
mkdir -p storage db tmp log
chmod -R 0755 storage db tmp log || true

# Default behavior: auto-kill any listener on the port unless FORCE_KILL is explicitly set to 0
if [ -z "${FORCE_KILL+x}" ]; then
  FORCE_KILL=1
fi

# Clean up stale PID if present
PIDFILE="tmp/pids/server.pid"
if [ -f "$PIDFILE" ]; then
  pid=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    echo "A server process appears to be running with PID $pid (from $PIDFILE)."
    if [ "${FORCE_KILL:-}" = "1" ]; then
      echo "Killing pid $pid as FORCE_KILL=1 was set"
      kill "$pid" || true
      sleep 1
    else
      echo "Use FORCE_KILL=1 to automatically kill it, or stop it manually and re-run this script."
      exit 1
    fi
  else
    echo "Removing stale PID file $PIDFILE"
    rm -f "$PIDFILE"
  fi
fi

# If something is listening on the port, optionally kill it
if ss -ltnp 2>/dev/null | grep -q ":$PORT \|:$PORT$"; then
  listener=$(ss -ltnp 2>/dev/null | grep ":$PORT \|:$PORT$" | head -n1)
  echo "Found process listening on port $PORT: $listener"
  if [ "${FORCE_KILL:-}" = "1" ]; then
    pid_to_kill=$(echo "$listener" | sed -n 's/.*pid=\([0-9]*\),.*/\1/p')
    if [ -n "$pid_to_kill" ]; then
      echo "Killing process $pid_to_kill that listens on port $PORT"
      kill "$pid_to_kill" || true
      sleep 1
    fi
  else
    echo "Set FORCE_KILL=1 to automatically kill the process listening on $PORT, or stop it manually and re-run."
    exit 1
  fi
fi

# Ensure we have a secret for production
if [ -f "config/master.key" ] && [ -z "${RAILS_MASTER_KEY:-}" ]; then
  echo "Using config/master.key for RAILS_MASTER_KEY"
  export RAILS_MASTER_KEY=$(cat config/master.key)
fi

if [ -z "${RAILS_MASTER_KEY:-}" ] && [ -z "${SECRET_KEY_BASE:-}" ]; then
  echo "No RAILS_MASTER_KEY found; generating temporary SECRET_KEY_BASE"
  export SECRET_KEY_BASE=$(bundle exec rails secret)
fi

export RAILS_ENV=production
export RAILS_SERVE_STATIC_FILES=true

echo "Precompiling assets (production)..."
# Use dummy secret precompile if credentials locked
SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile RAILS_ENV=production

echo "Creating and migrating DB..."
bundle exec rails db:create db:migrate RAILS_ENV=production

echo "Starting Puma (Rails server) in production on port $PORT"

# Start server as a child process so we can manage its lifecycle from this script.
bundle exec rails server -e production -p "$PORT" &
child=$!

# Write PID file for convenience
mkdir -p tmp/pids
echo "$child" > tmp/pids/server.pid

shutdown_child() {
  echo "Stopping Puma (pid $child)"
  kill "$child" 2>/dev/null || true
  # wait for child to exit, avoid leaving zombies
  wait "$child" 2>/dev/null || true
  rm -f tmp/pids/server.pid
}

# Trap common termination signals (works when this script is run in foreground)
trap 'shutdown_child' INT TERM EXIT

# Wait for the server process to exit; traps will run on script termination
wait "$child"
