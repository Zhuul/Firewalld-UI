#!/bin/bash

# Define output colors
redMsg() { echo -e "\\n\\E[1;31m$*\\033[0m\\n" >&2; }
greMsg() { echo -e "\\n\\E[1;32m$*\\033[0m\\n" >&2; }
bluMsg() { echo -e "\\n\\033[5;34m$*\\033[0m\\n" >&2; }
purMsg() { echo -e "\\n\\033[35m$*\\033[0m\\n" >&2; }

SCRIPT_MODULES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT_DIR=$(dirname "$SCRIPT_MODULES_DIR")

NODE_PATHS_FILE="$PROJECT_ROOT_DIR/shell/node/.node_paths"

if [ ! -f "$NODE_PATHS_FILE" ]; then
    redMsg "Node paths file ($NODE_PATHS_FILE) not found. Please run node.sh first (usually via startup.sh)."
    exit 1
fi

source "$NODE_PATHS_FILE"

if [ -z "$NODE_EXECUTABLE" ] || [ ! -x "$NODE_EXECUTABLE" ] || \
   [ -z "$NPM_CLI_JS_PATH" ] || [ ! -f "$NPM_CLI_JS_PATH" ] || \
   [ -z "$NODE_BIN_PATH" ]; then
    redMsg "Required paths (NODE_EXECUTABLE, NPM_CLI_JS_PATH, NODE_BIN_PATH) not found, not executable, or npm cli script not a file in $NODE_PATHS_FILE. Contents:"
    cat "$NODE_PATHS_FILE" >&2
    exit 1
fi

purMsg "Using local node to run npm cli: $NODE_EXECUTABLE $NPM_CLI_JS_PATH for dependency installation."

cd "$PROJECT_ROOT_DIR" || { redMsg "Failed to cd into project root $PROJECT_ROOT_DIR"; exit 1; }

NPM_VERSION=$("$NODE_EXECUTABLE" "$NPM_CLI_JS_PATH" -v)
REQUIRED_NPM_VERSION="7.0.0"

if [ "$(printf '%s\n' "$REQUIRED_NPM_VERSION" "$NPM_VERSION" | sort -V | head -n1)" != "$NPM_VERSION" ] && [ "$NPM_VERSION" != "$REQUIRED_NPM_VERSION" ]; then
    redMsg "Your npm version ($NPM_VERSION) is outdated. Required: $REQUIRED_NPM_VERSION or later."
    redMsg "The local npm is at $NPM_EXECUTABLE (using $NPM_CLI_JS_PATH). If this is wrong, check node.sh."
fi
greMsg "npm version check passed: $NPM_VERSION"

if [ ! -d "$PROJECT_ROOT_DIR/node_modules/" ];then
    redMsg "Backend node_modules directory not found at $PROJECT_ROOT_DIR/node_modules/"
    INSTALL_BACKEND=true
else
    purMsg "Backend node_modules directory found."
    INSTALL_BACKEND=false
fi

if [ ! -d "$PROJECT_ROOT_DIR/express/node_modules/" ];then
    redMsg "Frontend node_modules directory not found at $PROJECT_ROOT_DIR/express/node_modules/"
    INSTALL_FRONTEND=true
else
    purMsg "Frontend node_modules directory found."
    INSTALL_FRONTEND=false
fi

if [ "$INSTALL_BACKEND" = true ] || [ "$INSTALL_FRONTEND" = true ]; then
    redMsg "If the download fails, please delete $PROJECT_ROOT_DIR/node_modules and $PROJECT_ROOT_DIR/express/node_modules and try again."
    read -r -p "Do you want to run npm install for missing modules? (Ensure smooth network) [y/n] " input
    case $input in
        [yY][eE][sS]|[yY])
            if [ "$INSTALL_BACKEND" = true ]; then
                purMsg "Installing backend dependencies in $PROJECT_ROOT_DIR..."
                "$NODE_EXECUTABLE" "$NPM_CLI_JS_PATH" install --legacy-peer-deps
                if [ $? -ne 0 ]; then
                    redMsg "Error downloading backend dependencies."
                    exit 1
                else
                    greMsg "Successfully downloaded backend dependencies.";
                fi
            fi

            if [ "$INSTALL_FRONTEND" = true ]; then
                purMsg "Installing frontend dependencies in $PROJECT_ROOT_DIR/express..."
                cd "$PROJECT_ROOT_DIR/express" || { redMsg "Failed to cd into $PROJECT_ROOT_DIR/express"; exit 1; }
                "$NODE_EXECUTABLE" "$NPM_CLI_JS_PATH" install --legacy-peer-deps
                if [ $? -ne 0 ]; then
                    redMsg "Error downloading frontend dependencies."
                    cd "$PROJECT_ROOT_DIR" 
                    exit 1
                else
                    greMsg "Successfully downloaded frontend dependencies.";
                fi
                cd "$PROJECT_ROOT_DIR" || exit 1 
            fi
            greMsg "Dependency installation process finished."
            exit 0
            ;;
        [nN][oO]|[nN])
            purMsg "Dependency installation skipped by user."
            exit 1 
            ;;
        *)
            redMsg "Invalid input. Please enter y/n."
            exit 1
            ;;
    esac
else
    greMsg "All dependencies seem to be installed."
    exit 0
fi
