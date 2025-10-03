#!/bin/bash

# Start LocalStack using Docker-in-Docker
echo "Starting LocalStack using Docker-in-Docker..."

# Check if LocalStack container is already running
if [ "$(docker ps -q -f name=localstack)" ]; then
    echo "LocalStack is already running"
    exit 0
fi

# Remove existing LocalStack container if it exists but is stopped
if [ "$(docker ps -aq -f name=localstack)" ]; then
    echo "Removing existing LocalStack container..."
    docker rm localstack
fi

# Create LocalStack data directory
mkdir -p /tmp/localstack

# Start LocalStack container
docker run -d \
  --name localstack \
  -p 4566:4566 \
  -e SERVICES=sqs,ec2,iam,autoscaling,elbv2,ecr,logs \
  -e DEBUG=1 \
  -e DATA_DIR=/tmp/localstack/data \
  -e DOCKER_HOST=unix:///var/run/docker.sock \
  -e LOCALSTACK_HOST_TMP_FOLDER=/tmp/localstack \
  -v /tmp/localstack:/tmp/localstack \
  -v /var/run/docker.sock:/var/run/docker.sock \
  localstack/localstack:3.0

# Wait for LocalStack to be ready
echo "Waiting for LocalStack to be ready..."
timeout=60
counter=0
while ! curl -s http://localhost:4566/_localstack/health > /dev/null; do
    if [ $counter -ge $timeout ]; then
        echo "LocalStack failed to start within $timeout seconds"
        exit 1
    fi
    sleep 1
    counter=$((counter+1))
done

echo "LocalStack is ready!"

# Initialize LocalStack resources if needed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/init-localstack.sh" ]; then
    echo "Running LocalStack initialization script..."
    bash "$SCRIPT_DIR/init-localstack.sh"
fi