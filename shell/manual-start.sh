#!/bin/bash

# Manual startup script for Firewalld-UI
# This script starts services and keeps them running for manual use

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "Starting Firewalld-UI manually..."

# Source Node.js environment
NODE_PATHS_FILE="$DIR/shell/node/.node_paths"
if [ -f "$NODE_PATHS_FILE" ]; then
    source "$NODE_PATHS_FILE"
    echo "Loaded Node.js environment"
else
    echo "ERROR: Node.js environment file not found: $NODE_PATHS_FILE"
    exit 1
fi

# Set PATH to include Node.js bin directory
export PATH="$NODE_BIN_PATH:$PATH"

# Verify required variables
if [ -z "$NODE_EXECUTABLE" ] || [ -z "$NODE_BIN_PATH" ]; then
    echo "ERROR: NODE_EXECUTABLE or NODE_BIN_PATH not set"
    exit 1
fi

# Set PM2 path manually since it's not in .node_paths
PM2_EXECUTABLE="$NODE_BIN_PATH/pm2"

echo "Using Node.js: $NODE_EXECUTABLE"
echo "Using PM2: $PM2_EXECUTABLE"

# Stop any existing services first
echo "Stopping existing services..."
./shell/stop-all.sh

# Start Express frontend with PM2 (persistent daemon mode)
echo "Starting Express frontend with PM2..."
cd "$DIR/express"
"$NODE_EXECUTABLE" "$PM2_EXECUTABLE" start index.js --name HttpServer --exp-backoff-restart-delay=1000 || {
    echo "ERROR: Failed to start Express server with PM2"
    exit 1
}

# Return to project root
cd "$DIR"

# Start Egg.js backend in daemon mode
echo "Starting Egg.js backend in daemon mode..."
"$NODE_EXECUTABLE" "./node_modules/.bin/egg-scripts" start --daemon=true --hostname=127.0.0.1 --port=7001 --title=egg-server || {
    echo "ERROR: Failed to start Egg.js backend"
    exit 1
}

echo "Services started successfully!"
echo ""
echo "Frontend (Express): http://localhost:5000"
echo "Backend (Egg.js): http://localhost:7001"
echo ""
echo "Check status with:"
echo "  PM2 Frontend: $PM2_EXECUTABLE list"
echo "  Backend: $PM2_EXECUTABLE logs HttpServer"
echo ""
echo "Stop services with: ./shell/stop-all.sh"
