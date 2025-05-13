#!/bin/bash

# Define output colors
redMsg() { echo -e "\n\\E[1;31m$*\\033[0m\n" >&2; }
greMsg() { echo -e "\n\\E[1;32m$*\\033[0m\n" >&2; }
bluMsg() { echo -e "\n\\033[5;34m$*\\033[0m\n" >&2; }
purMsg() { echo -e "\n\\033[35m$*\\033[0m\n" >&2; }

SCRIPT_MODULES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT_DIR=$(dirname "$SCRIPT_MODULES_DIR")

# The ensure-local-node.sh script (typically run via 'npm run waf')
# is now responsible for the main npm install for the project root.
# This modules.sh script can serve as a supplemental check or for specific cases
# if needed, but primary installation should be through 'npm run waf'.

purMsg "Checking dependencies using the project's local Node.js environment..."

RUN_WITH_LOCAL_NODE_SCRIPT="$PROJECT_ROOT_DIR/scripts/run-with-local-node.sh"

if [ ! -x "$RUN_WITH_LOCAL_NODE_SCRIPT" ]; then
    redMsg "Error: $RUN_WITH_LOCAL_NODE_SCRIPT not found or not executable."
    redMsg "Please ensure the project setup (e.g., 'npm run waf') has been completed."
    exit 1
fi

# Check backend dependencies
cd "$PROJECT_ROOT_DIR" || { redMsg "Failed to cd into project root $PROJECT_ROOT_DIR"; exit 1; }

if [ ! -d "node_modules" ] || [ ! -f "node_modules/.bin/egg-scripts" ]; then
    greMsg "Backend node_modules appear to be missing or incomplete. Running npm install for backend..."
    if bash "$RUN_WITH_LOCAL_NODE_SCRIPT" npm install --no-audit --no-fund; then
        greMsg "Backend dependencies installed successfully."
    else
        redMsg "Failed to install backend dependencies."
        exit 1
    fi
elif [ -n "$1" ] && [ "$1" == "force" ]; then
    greMsg "Forcing backend dependency installation..."
    if bash "$RUN_WITH_LOCAL_NODE_SCRIPT" npm install --no-audit --no-fund; then
        greMsg "Backend dependencies re-installed successfully."
    else
        redMsg "Failed to re-install backend dependencies."
        exit 1
    fi
else
    greMsg "Backend dependencies appear to be installed."
fi

# Check frontend dependencies (express)
FRONTEND_DIR="$PROJECT_ROOT_DIR/express"
if [ -d "$FRONTEND_DIR" ]; then
    cd "$FRONTEND_DIR" || { redMsg "Failed to cd into frontend directory $FRONTEND_DIR"; exit 1; }
    if [ ! -d "node_modules" ] || [ ! -f "package-lock.json" ]; then # Simple check for frontend
        greMsg "Frontend node_modules (in express/) appear to be missing or incomplete. Running npm install for frontend..."
        if bash "$RUN_WITH_LOCAL_NODE_SCRIPT" npm install --no-audit --no-fund; then
            greMsg "Frontend dependencies (in express/) installed successfully."
        else
            redMsg "Failed to install frontend dependencies (in express/)."
            exit 1 # Or handle error as appropriate
        fi
    elif [ -n "$1" ] && [ "$1" == "force" ]; then
        greMsg "Forcing frontend dependency installation (in express/)..."
        if bash "$RUN_WITH_LOCAL_NODE_SCRIPT" npm install --no-audit --no-fund; then
            greMsg "Frontend dependencies (in express/) re-installed successfully."
        else
            redMsg "Failed to re-install frontend dependencies (in express/)."
            exit 1
        fi    
    else
        greMsg "Frontend dependencies (in express/) appear to be installed."
    fi
    cd "$PROJECT_ROOT_DIR" || exit 1 # Return to project root
else
    purMsg "Frontend directory (express/) not found, skipping frontend dependency check."
fi

greMsg "Dependency check/installation process complete."
exit 0
