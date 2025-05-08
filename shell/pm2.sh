#!/bin/bash

# Send messages to stderr
redMsg() { echo -e "\\n\\E[1;31m$*\\033[0m\\n" >&2; }
greMsg() { echo -e "\\n\\E[1;32m$*\\033[0m\\n" >&2; }
bluMsg() { echo -e "\\n\\033[5;34m$*\\033[0m\\n" >&2; }
purMsg() { echo -e "\\n\\033[35m$*\\033[0m\\n" >&2; }

SCRIPT_DIR_PM2="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT_DIR_PM2=$(dirname "$SCRIPT_DIR_PM2")

NODE_PATHS_FILE="$PROJECT_ROOT_DIR_PM2/shell/node/.node_paths"

if [ ! -f "$NODE_PATHS_FILE" ]; then
    redMsg "Node paths file ($NODE_PATHS_FILE) not found. Please run node.sh first (usually via startup.sh)."
    exit 1
fi

# Source the paths to make NPM_EXECUTABLE and NODE_BIN_PATH available
source "$NODE_PATHS_FILE"

if [ -z "$NPM_EXECUTABLE" ] || [ ! -x "$NPM_EXECUTABLE" ] || \
   [ -z "$NODE_BIN_PATH" ] ; then # NODE_BIN_PATH is where pm2 will be installed by local npm -g
    redMsg "Required paths (NPM_EXECUTABLE, NODE_BIN_PATH) not found or not executable in $NODE_PATHS_FILE. Contents:"
    cat "$NODE_PATHS_FILE" >&2
    exit 1
fi

# When npm -g is used with a local npm (from NODE_BIN_PATH/npm),
# "global" packages are installed relative to that Node.js instance's prefix.
# Binaries typically go into that Node.js instance's bin directory.
EXPECTED_PM2_PATH="${NODE_BIN_PATH}/pm2"

find_local_pm2_executable() {
    purMsg "Attempting to find local pm2 executable at: $EXPECTED_PM2_PATH"
    if [ -f "$EXPECTED_PM2_PATH" ]; then
        if [ ! -x "$EXPECTED_PM2_PATH" ]; then
            purMsg "Attempting to make $EXPECTED_PM2_PATH executable..."
            chmod +x "$EXPECTED_PM2_PATH"
            if [ $? -ne 0 ]; then redMsg "Failed to chmod +x $EXPECTED_PM2_PATH"; fi
        fi
        if [ -x "$EXPECTED_PM2_PATH" ]; then
            purMsg "Using local pm2: $EXPECTED_PM2_PATH"
            # This echo is captured by startup.sh
            echo "$EXPECTED_PM2_PATH"
            return 0
        else
            redMsg "File at $EXPECTED_PM2_PATH is still not executable."
            ls -l "$EXPECTED_PM2_PATH" >&2
        fi
    else
        redMsg "File does NOT exist at $EXPECTED_PM2_PATH."
    fi
    return 1
}

# Check if pm2 is already installed locally
# The output of find_local_pm2_executable (the path) will be sent to stdout if found
# and its return status will be 0.
PM2_FOUND_PATH=$(find_local_pm2_executable)
if [ $? -eq 0 ] && [ -n "$PM2_FOUND_PATH" ]; then
    # pm2.sh's job is done, path was already echoed by the function.
    # We echo it again here to ensure it's the *only* thing on stdout from this branch.
    # However, the function itself already echoes. So, if it succeeded, we just exit.
    exit 0
fi


# If not found, prompt for installation
read -r -p "Local pm2 not found at $EXPECTED_PM2_PATH. Do you want to install it using local npm ($NPM_EXECUTABLE)? [y/n] " input_char
read -r -t 0.1 -n 10000 discard || true # Consume trailing newline if any

case $input_char in
    [yY][eE][sS]|[yY])
       purMsg "Attempting to install pm2 globally *to this Node.js instance* using: $NPM_EXECUTABLE"
       
       "$NPM_EXECUTABLE" install pm2 -g --registry=https://registry.npmmirror.com
       INSTALL_STATUS=$?

       if [ $INSTALL_STATUS -eq 0 ]; then
            greMsg "npm install pm2 -g command finished."
            # Try to find pm2 again after installation
            PM2_AFTER_INSTALL_PATH=$(find_local_pm2_executable)
            if [ $? -eq 0 ] && [ -n "$PM2_AFTER_INSTALL_PATH" ]; then
                # Path was already echoed by find_local_pm2_executable
                exit 0
            else
                redMsg "pm2 installed, but find_local_pm2_executable could not determine its path or it's not executable."
                exit 1
            fi
       else
            redMsg "npm install pm2 -g failed with status $INSTALL_STATUS."
            exit 1
       fi
		;;
    [nN][oO]|[nN])
		purMsg "Skipping pm2 installation."
        exit 1 
       	;;
    *)
		redMsg "Invalid input. Please enter y/n."
        exit 1
		;;
esac
