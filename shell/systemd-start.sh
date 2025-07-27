#!/bin/bash

# Dedicated systemd startup script for Firewalld-UI
# This script is designed to run under systemd and keep services running

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "[$(date)] Starting Firewalld-UI systemd service..."

# Source Node.js environment
NODE_PATHS_FILE="$DIR/shell/node/.node_paths"
if [ -f "$NODE_PATHS_FILE" ]; then
    source "$NODE_PATHS_FILE"
    echo "[$(date)] Loaded Node.js environment from $NODE_PATHS_FILE"
else
    echo "[$(date)] ERROR: Node.js environment file not found: $NODE_PATHS_FILE"
    exit 1
fi

# Verify required variables
if [ -z "$NODE_EXECUTABLE" ] || [ -z "$NODE_BIN_PATH" ]; then
    echo "[$(date)] ERROR: NODE_EXECUTABLE or NODE_BIN_PATH not set"
    exit 1
fi

# Set PM2 path
PM2_EXECUTABLE="$NODE_BIN_PATH/pm2"

# Set PATH to include Node.js bin directory
# This is crucial for sub-processes like pm2 and egg-scripts finding 'node'
export PATH="$NODE_BIN_PATH:$PATH"

echo "[$(date)] Using Node.js: $NODE_EXECUTABLE"
echo "[$(date)] Using PM2: $PM2_EXECUTABLE"
echo "[$(date)] PATH: $PATH"

# Function to cleanup on exit
cleanup() {
    echo "[$(date)] Cleaning up services..."
    # Stop PM2 processes
    if [ -x "$PM2_EXECUTABLE" ]; then
        "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" delete all 2>/dev/null || true
        "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" kill 2>/dev/null || true
    fi
    # Stop Egg.js backend
    cd "$DIR"
    if [ -f "./node_modules/.bin/egg-scripts" ]; then
        "$NODE_EXECUTABLE" "./node_modules/.bin/egg-scripts" stop --title=egg-server 2>/dev/null || true
    fi
    echo "[$(date)] Cleanup completed"
}

# Set trap for cleanup on exit
trap cleanup EXIT TERM INT

# Start Express frontend with PM2 (daemon mode)
echo "[$(date)] Starting Express frontend with PM2..."
cd "$DIR/express"
"$NODE_EXECUTABLE" "$PM2_EXECUTABLE" start index.js --name HttpServer --interpreter "$NODE_EXECUTABLE" || {
    echo "[$(date)] ERROR: Failed to start Express server with PM2"
    exit 1
}

# Return to project root
cd "$DIR"

# Start Egg.js backend in foreground (this keeps the systemd service running)
echo "[$(date)] Starting Egg.js backend in foreground..."

# We call egg-scripts with the full path to node to be explicit.
exec "$NODE_EXECUTABLE" "./node_modules/.bin/egg-scripts" start --daemon=false --hostname=127.0.0.1 --port=7001 --title=egg-server
