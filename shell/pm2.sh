#!/bin/bash

# Define output colors
redMsg() { echo -e "\\n\\E[1;31m$*\\033[0m\\n" >&2; }
greMsg() { echo -e "\\n\\E[1;32m$*\\033[0m\\n" >&2; }
bluMsg() { echo -e "\\n\\033[5;34m$*\\033[0m\\n" >&2; }
purMsg() { echo -e "\\n\\033[35m$*\\033[0m\\n" >&2; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT_DIR=$(dirname "$SCRIPT_DIR")
NODE_PATHS_FILE="$SCRIPT_DIR/node/.node_paths"

# Source the node paths to get NODE_EXECUTABLE, NPM_CLI_JS_PATH, NODE_BIN_PATH
if [ -f "$NODE_PATHS_FILE" ]; then
    source "$NODE_PATHS_FILE"
else
    # This script relies on .node_paths being created by node.sh first.
    # startup.sh should call node.sh before this script.
    # If running standalone and .node_paths doesn't exist, this script might not find the intended Node/npm.
    purMsg "Warning: ${NODE_PATHS_FILE} not found. Relying on Node/npm in global PATH or pre-set environment."
fi

# Attempt to find local pm2 executable first (it might be installed by a previous run)
# NODE_BIN_PATH should be set if .node_paths was sourced and contained it.
PM2_LOCAL_PATH_GUESS=""
if [ -n "$NODE_BIN_PATH" ]; then
    PM2_LOCAL_PATH_GUESS="${NODE_BIN_PATH}/pm2"
    purMsg "Attempting to find local pm2 executable at: $PM2_LOCAL_PATH_GUESS"
    if [ -x "$PM2_LOCAL_PATH_GUESS" ]; then
        greMsg "Local pm2 found and executable at $PM2_LOCAL_PATH_GUESS"
        echo "$PM2_LOCAL_PATH_GUESS" # Output the path
        exit 0
    else
        if [ -f "$PM2_LOCAL_PATH_GUESS" ]; then
            purMsg "File exists at $PM2_LOCAL_PATH_GUESS but is not executable."
        else
            purMsg "File does NOT exist at $PM2_LOCAL_PATH_GUESS."
        fi
    fi
else
    purMsg "NODE_BIN_PATH not set, cannot guess local pm2 path effectively."
fi

# If NODE_EXECUTABLE and NPM_CLI_JS_PATH are not set, we can't install pm2 locally.
if [ -z "$NODE_EXECUTABLE" ] || [ -z "$NPM_CLI_JS_PATH" ] || [ -z "$NODE_BIN_PATH" ]; then
    redMsg "NODE_EXECUTABLE, NPM_CLI_JS_PATH, or NODE_BIN_PATH is not set. Cannot install pm2 locally."
    redMsg "Ensure node.sh has run successfully and .node_paths is sourced."
    exit 1
fi

read -r -p "Local pm2 not found at ${PM2_LOCAL_PATH_GUESS}. Do you want to install it using local npm (${NODE_EXECUTABLE} ${NPM_CLI_JS_PATH})? [y/n] " input_char
case $input_char in
    [yY][eE][sS]|[yY])
       purMsg "Attempting to install pm2 globally *to this Node.js instance* using: ${NODE_EXECUTABLE} ${NPM_CLI_JS_PATH}"
       purMsg "Temporarily prepending $NODE_BIN_PATH to PATH and using local Node to execute npm-cli.js for this command."
       
       # Execute npm install pm2 -g using the sourced NODE_EXECUTABLE to run the sourced NPM_CLI_JS_PATH
       # Ensure NODE_BIN_PATH is in the PATH for this command so npm can find other node tools if needed
       env PATH="${NODE_BIN_PATH}:${PATH}" "${NODE_EXECUTABLE}" "${NPM_CLI_JS_PATH}" install pm2 -g --registry=https://registry.npmmirror.com
       INSTALL_STATUS=$?

       if [ $INSTALL_STATUS -eq 0 ]; then
            # Verify installation
            PM2_INSTALLED_PATH="${NODE_BIN_PATH}/pm2" # Default location for global installs within a node version
            if [ -x "$PM2_INSTALLED_PATH" ]; then
                greMsg "pm2 installed successfully at $PM2_INSTALLED_PATH"
                echo "$PM2_INSTALLED_PATH" # Output the path
                exit 0
            else
                redMsg "pm2 installation command seemed to succeed, but $PM2_INSTALLED_PATH is not found or not executable."
                ls -l "$NODE_BIN_PATH" >&2 # List contents of bin for debugging
                exit 1
            fi
       else
            redMsg "npm install pm2 -g failed with status $INSTALL_STATUS."
            exit 1
       fi
        ;;
    [nN][oO]|[nN])
        redMsg "pm2 installation skipped by user."
        exit 1
        ;;
    *)
        redMsg "Invalid input. Please answer y/n."
        exit 1
        ;;
esac

exit 1 # Should not reach here if successful
