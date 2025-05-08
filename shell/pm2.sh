#!/bin/bash

# Send messages to stderr
redMsg() { echo -e "\\n\E[1;31m$*\033[0m\\n" >&2; }
greMsg() { echo -e "\\n\E[1;32m$*\033[0m\\n" >&2; }
bluMsg() { echo -e "\\n\033[5;34m$*\033[0m\\n" >&2; }
purMsg() { echo -e "\\n\033[35m$*\033[0m\\n" >&2; }

SCRIPT_DIR_PM2="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT_DIR_PM2=$(dirname "$SCRIPT_DIR_PM2")

NODE_PATHS_FILE="$PROJECT_ROOT_DIR_PM2/shell/node/.node_paths"

if [ ! -f "$NODE_PATHS_FILE" ]; then
    redMsg "Node paths file ($NODE_PATHS_FILE) not found. Please run node.sh first (usually via startup.sh)." >&2
    exit 1
fi

# Source the paths to make NPM_EXECUTABLE and NODE_BIN_PATH available
source "$NODE_PATHS_FILE"

if [ -z "$NPM_EXECUTABLE" ] || [ ! -x "$NPM_EXECUTABLE" ] || \
   [ -z "$NODE_BIN_PATH" ] ; then # NODE_BIN_PATH is where pm2 will be installed
    redMsg "Required paths (NPM_EXECUTABLE, NODE_BIN_PATH) not found or not executable in $NODE_PATHS_FILE. Contents:" >&2
    cat "$NODE_PATHS_FILE" >&2
    exit 1
fi

# pm2 will be installed into the local Node's bin directory by npm -g
# The -g flag, when using a local npm, typically means global *to that Node.js instance's prefix*
EXPECTED_PM2_PATH="${NODE_BIN_PATH}/pm2"

find_local_pm2_executable() {
    purMsg "Attempting to find local pm2 executable at: $EXPECTED_PM2_PATH" >&2
    if [ -f "$EXPECTED_PM2_PATH" ]; then
        if [ ! -x "$EXPECTED_PM2_PATH" ]; then
            purMsg "Attempting to make $EXPECTED_PM2_PATH executable..." >&2
            chmod +x "$EXPECTED_PM2_PATH"
            if [ $? -ne 0 ]; then redMsg "Failed to chmod +x $EXPECTED_PM2_PATH" >&2; fi
        fi
        if [ -x "$EXPECTED_PM2_PATH" ]; then
            purMsg "Using local pm2: $EXPECTED_PM2_PATH" >&2
            echo "$EXPECTED_PM2_PATH" # This echo goes to stdout for capture by startup.sh
            return 0
        else
            redMsg "File at $EXPECTED_PM2_PATH is still not executable." >&2
            ls -l "$EXPECTED_PM2_PATH" >&2
        fi
    else
        redMsg "File does NOT exist at $EXPECTED_PM2_PATH." >&2
    fi
    return 1
}

# Check if pm2 is already installed locally
if find_local_pm2_executable; then
    # If found, pm2.sh's job is done, path was echoed by the function
    exit 0
fi

# If not found, prompt for installation
read -r -p "Local pm2 not found. Do you want to install it using local npm ($NPM_EXECUTABLE)? [y/n] " input_char
read -r -t 0.1 -n 10000 discard || true 

case $input_char in
    [yY][eE][sS]|[yY])
       purMsg "Attempting to install pm2 globally *to this Node.js instance* using: $NPM_EXECUTABLE" >&2
       
       # The --prefix option can explicitly tell npm where to install global packages for this Node instance.
       # However, npm -g with a local npm usually does the right thing by installing into its own prefix.
       # Let's rely on the standard behavior of `npm -g` with the local npm.
       "$NPM_EXECUTABLE" install pm2 -g --registry=https://registry.npmmirror.com
       INSTALL_STATUS=$?

       if [ $INSTALL_STATUS -eq 0 ]; then
            greMsg "npm install pm2 -g command finished." >&2
            # Try to find pm2 again after installation
            if find_local_pm2_executable; then
                # Path was echoed by the function
                exit 0
            else
                redMsg "pm2 installed, but find_local_pm2_executable could not determine its path or it's not executable." >&2
                exit 1
            fi
       else
            redMsg "npm install pm2 -g failed with status $INSTALL_STATUS." >&2
            exit 1
       fi
        ;;
    [nN][oO]|[nN])
        purMsg "Skipping pm2 installation." >&2
        exit 1 # Or 0 if skipping is not an error for startup.sh
           ;;
    *)
        redMsg "Invalid input. Please enter y/n." >&2
        exit 1
        ;;
esac
