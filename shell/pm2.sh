#!/bin/bash

# Define output colors
redMsg() { echo -e "\n\\E[1;31m$*\\033[0m\n" >&2; }
greMsg() { echo -e "\n\\E[1;32m$*\\033[0m\n" >&2; }
bluMsg() { echo -e "\n\\033[5;34m$*\\033[0m\n" >&2; }
purMsg() { echo -e "\n\\033[35m$*\\033[0m\n" >&2; }

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT_DIR=$(dirname "$SCRIPT_DIR")

RUN_WITH_LOCAL_NODE_SCRIPT="$PROJECT_ROOT_DIR/scripts/run-with-local-node.sh"

if [ ! -x "$RUN_WITH_LOCAL_NODE_SCRIPT" ]; then
    redMsg "Error: $RUN_WITH_LOCAL_NODE_SCRIPT not found or not executable."
    redMsg "Please ensure the project setup (e.g., 'npm run waf') has been completed."
    exit 1
fi

cd "$PROJECT_ROOT_DIR" || { redMsg "Failed to cd into project root $PROJECT_ROOT_DIR"; exit 1; }

# Check if pm2 is installed locally (via local npm)
# The run-with-local-node.sh script will ensure that 'npm' and 'npx' point to local versions.
if bash "$RUN_WITH_LOCAL_NODE_SCRIPT" npx pm2 -v > /dev/null 2>&1; then
    PM2_VERSION=$(bash "$RUN_WITH_LOCAL_NODE_SCRIPT" npx pm2 -v)
    greMsg "PM2 is already installed locally. Version: $PM2_VERSION"
else
    purMsg "Local PM2 not found or not working."
    read -r -p "Do you want to install PM2 globally using the project's local npm? (npm install pm2 -g) [y/n] " input_char
    case $input_char in
        [yY][eE][sS]|[yY])
            purMsg "Installing PM2 globally using local npm..."
            # Note: 'npm install pm2 -g' will install pm2 using the shims from local_node/bin,
            # making it available on the PATH if local_node/bin is on the PATH.
            # The actual global installation behavior might depend on npm's configuration.
            # For a truly project-local pm2, it would be a devDependency and run via npx.
            # However, pm2 is often used as a system-wide daemon manager.
            if bash "$RUN_WITH_LOCAL_NODE_SCRIPT" npm install pm2 -g; then
                greMsg "PM2 installed successfully."
                # Verify again
                if bash "$RUN_WITH_LOCAL_NODE_SCRIPT" npx pm2 -v > /dev/null 2>&1; then
                    PM2_VERSION_AFTER_INSTALL=$(bash "$RUN_WITH_LOCAL_NODE_SCRIPT" npx pm2 -v)
                    greMsg "PM2 version after install: $PM2_VERSION_AFTER_INSTALL"
                else
                    redMsg "PM2 still not found after attempting global install with local npm. Check npm logs."
                    exit 1
                fi
            else
                redMsg "Failed to install PM2."
                exit 1
            fi
            ;;
        [nN][oO]|[nN])
            redMsg "PM2 installation skipped. Some scripts might not work without PM2."
            # Depending on requirements, you might want to exit here or allow continuation
            # exit 1;
            ;;
        *)
            redMsg "Invalid input. Please enter y/n."
            exit 1
            ;;
    esac
fi

exit 0
