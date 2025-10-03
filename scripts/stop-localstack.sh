#!/bin/bash

# Stop LocalStack container
echo "Stopping LocalStack..."

if [ "$(docker ps -q -f name=localstack)" ]; then
    docker stop localstack
    echo "LocalStack stopped"
else
    echo "LocalStack is not running"
fi

# Optionally remove the container
if [ "$1" = "--remove" ]; then
    if [ "$(docker ps -aq -f name=localstack)" ]; then
        docker rm localstack
        echo "LocalStack container removed"
    fi
fi