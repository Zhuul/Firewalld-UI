#!/bin/bash

# A robust script to stop all components of the Firewalld-UI application.
# This script is designed to be run manually to ensure a clean state.

set +e # Continue even if some commands fail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "---"
echo "[$(date)] Starting Firewalld-UI Full Shutdown Process"
echo "---"

# Source Node.js environment to get executable paths
NODE_PATHS_FILE="$DIR/shell/node/.node_paths"
if [ -f "$NODE_PATHS_FILE" ]; then
    source "$NODE_PATHS_FILE"
    echo "[INFO] Loaded Node.js environment from $NODE_PATHS_FILE"
else
    echo "[ERROR] Node.js environment file not found: $NODE_PATHS_FILE"
    # Try to find a default node executable if paths file is missing
    NODE_EXECUTABLE=$(command -v node)
    if [ -z "$NODE_EXECUTABLE" ]; then
        echo "[ERROR] Cannot find node executable. Aborting."
        exit 1
    fi
fi

# --- 1. Stop systemd service ---
echo
echo "[STEP 1/5] Stopping systemd service..."
if command -v systemctl &> /dev/null && systemctl is-active --quiet firewalld-ui.service; then
    sudo systemctl stop firewalld-ui.service
    echo "[INFO] Stopped firewalld-ui.service."
    sleep 1
else
    echo "[INFO] systemd service is not active or systemctl is not available."
fi

# --- 2. Stop PM2-managed processes ---
echo
echo "[STEP 2/5] Stopping PM2 processes..."
PM2_EXECUTABLE="$NODE_BIN_PATH/pm2"
if [ -x "$PM2_EXECUTABLE" ]; then
    echo "[INFO] Using PM2 executable: $PM2_EXECUTABLE"
    "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" delete all &> /dev/null
    "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" kill &> /dev/null
    echo "[INFO] PM2 processes stopped and daemon killed."
else
    echo "[WARN] PM2 executable not found at $PM2_EXECUTABLE. Skipping."
fi

# --- 3. Stop Egg.js backend ---
echo
echo "[STEP 3/5] Stopping Egg.js backend..."
EGG_SCRIPT="$DIR/node_modules/.bin/egg-scripts"
if [ -f "$EGG_SCRIPT" ]; then
    echo "[INFO] Using egg-scripts: $EGG_SCRIPT"
    "$NODE_EXECUTABLE" "$EGG_SCRIPT" stop --title=egg-server &> /dev/null
    echo "[INFO] egg-scripts stop command issued."
else
    echo "[WARN] egg-scripts not found at $EGG_SCRIPT. Skipping."
fi
sleep 2

# --- 4. Forcefully kill processes by port and name ---
echo
echo "[STEP 4/5] Forcefully killing remaining processes..."
echo "[INFO] This may require sudo privileges."

# Kill listeners on ports
for port in 5000 7001; do
    echo "[INFO] Checking for processes on port $port..."
    PIDS=$(sudo lsof -t -i:$port)
    if [ -n "$PIDS" ]; then
        echo "[INFO] Killing processes on port $port: $PIDS"
        sudo kill -9 $PIDS &> /dev/null
    else
        echo "[INFO] No processes found on port $port."
    fi
done

# Kill by process name/path
echo "[INFO] Killing processes by name..."
sudo pkill -f "egg-server" &> /dev/null
sudo pkill -f "HttpServer" &> /dev/null
sudo pkill -f "egg-cluster" &> /dev/null
sudo pkill -f "firewalld-ui" &> /dev/null
# Specifically target the node executable used by the project
if [ -n "$NODE_EXECUTABLE" ]; then
    sudo pkill -f "$NODE_EXECUTABLE .*Firewalld-UI" &> /dev/null
fi
echo "[INFO] Kill commands issued for remaining processes."

# --- 5. Clean up temporary files ---
echo
echo "[STEP 5/5] Cleaning up temporary files..."
if [ -d "/tmp/firewalld-ui-node" ]; then
    rm -rf "/tmp/firewalld-ui-node"
    echo "[INFO] Removed temporary node wrapper directory."
fi
echo "[INFO] Cleanup complete."

echo
echo "---"
echo "[$(date)] Firewalld-UI Shutdown Process Finished"
echo "---"
