#!/bin/bash
set -e

echo "Stopping LocalStack (containers and local processes)..."

# Find docker container IDs whose name or image contain 'localstack' (case-insensitive)
CONTAINERS=$(docker ps -a --format '{{.ID}}\t{{.Names}}\t{{.Image}}' | awk 'BEGIN{IGNORECASE=1} /localstack/ {print $1}' | tr '\n' ' ' || true)

if [ -n "$CONTAINERS" ]; then
    echo "Found LocalStack containers: $CONTAINERS"
    docker stop $CONTAINERS || true
    echo "Stopped LocalStack containers"
else
    echo "No LocalStack containers found"
fi

# Optionally remove the containers when --remove is passed
if [ "$1" = "--remove" ]; then
    if [ -n "$CONTAINERS" ]; then
        docker rm -f $CONTAINERS || true
        echo "LocalStack containers removed"
    else
        echo "No LocalStack containers to remove"
    fi
fi

# Detect any local process listening on port 4566 (LocalStack default)
echo "Checking for local processes listening on port 4566..."
PIDS=""
if command -v lsof >/dev/null 2>&1; then
    PIDS=$(lsof -t -iTCP:4566 -sTCP:LISTEN || true)
else
    # Fallback using ss (may require parsing)
    PIDS=$(ss -ltnp 2>/dev/null | awk '/:4566/ { gsub(/.*pid=/,"",$0); split($0,a,","); print a[1] }' | tr -d '\n' || true)
fi

if [ -n "$PIDS" ]; then
    echo "Found processes listening on :4566 -> $PIDS"
    if [ "$1" = "--force" ]; then
        echo "Killing processes: $PIDS"
        kill -9 $PIDS || true
        echo "Processes killed"
    else
        echo "Run './scripts/stop-localstack.sh --force' to forcibly kill these processes," \
             "or stop them manually if they are important."
    fi
else
    echo "No local processes listening on port 4566 detected"
fi

echo "Done."