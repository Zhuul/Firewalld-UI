#!/bin/bash

# Define output colors
redMsg() { echo -e "\\n\\E[1;31m$*\\033[0m\\n" >&2; } # Messages to stderr
greMsg() { echo -e "\\n\\E[1;32m$*\\033[0m\\n" >&2; }
bluMsg() { echo -e "\\n\\033[5;34m$*\\033[0m\\n" >&2; }
purMsg() { echo -e "\\n\\033[35m$*\\033[0m\\n" >&2; }

# Get the absolute physical path of the directory where this script is located
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# PROJECT_ROOT_DIR is the parent of SCRIPT_DIR (e.g., /path/to/Firewalld-UI)
PROJECT_ROOT_DIR=$(dirname "$SCRIPT_DIR")

NODE_VERSION="v22.1.0" # Specify the exact Node.js version
NODE_ARCH="linux-x64" # Specify architecture
NODE_FILENAME="node-${NODE_VERSION}-${NODE_ARCH}"
NODE_TARBALL="${NODE_FILENAME}.tar.gz"
NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/${NODE_TARBALL}"

# Install Node.js into a 'node' subdirectory within the 'shell' directory
NODE_INSTALL_BASE_DIR="${SCRIPT_DIR}/node" # e.g., /path/to/Firewalld-UI/shell/node
NODE_EXTRACTED_DIR="${NODE_INSTALL_BASE_DIR}/${NODE_FILENAME}" # e.g., .../shell/node/node-v22.1.0-linux-x64
NODE_BIN_DIR="${NODE_EXTRACTED_DIR}/bin" # e.g., .../shell/node/node-v22.1.0-linux-x64/bin
NODE_LIB_DIR="${NODE_EXTRACTED_DIR}/lib" # e.g., .../shell/node/node-v22.1.0-linux-x64/lib

# File to store the paths of the installed executables
NODE_PATHS_FILE="${NODE_INSTALL_BASE_DIR}/.node_paths" # Stored within shell/node/

# Check if already installed correctly by checking the paths file and executables
VERIFY_NODE_EXEC=""
VERIFY_NPM_EXEC_SYMLINK=""
VERIFY_NPM_CLI_JS=""

if [ -f "$NODE_PATHS_FILE" ]; then
    source "$NODE_PATHS_FILE" # Try to load paths
    VERIFY_NODE_EXEC="$NODE_EXECUTABLE"
    VERIFY_NPM_EXEC_SYMLINK="$NPM_EXECUTABLE_SYMLINK" # Path to the npm symlink in bin
    VERIFY_NPM_CLI_JS="$NPM_CLI_JS_PATH"         # Path to the actual npm-cli.js
fi

if [ -n "$VERIFY_NODE_EXEC" ] && [ -x "$VERIFY_NODE_EXEC" ] && \
   [ -n "$VERIFY_NPM_EXEC_SYMLINK" ] && [ -L "$VERIFY_NPM_EXEC_SYMLINK" ] && \
   [ -n "$VERIFY_NPM_CLI_JS" ] && [ -f "$VERIFY_NPM_CLI_JS" ]; then
    CURRENT_VERSION=$("$VERIFY_NODE_EXEC" -v 2>/dev/null)
    if [[ "$CURRENT_VERSION" == "$NODE_VERSION" ]]; then
        greMsg "Node.js ${NODE_VERSION} already installed locally at ${NODE_EXTRACTED_DIR}."
        # Ensure paths file is up-to-date
        NPM_CLI_JS_ACTUAL_PATH="${NODE_LIB_DIR}/node_modules/npm/bin/npm-cli.js" # Standard path
        echo "NODE_EXECUTABLE=${NODE_BIN_DIR}/node" > "$NODE_PATHS_FILE"
        echo "NPM_EXECUTABLE_SYMLINK=${NODE_BIN_DIR}/npm" >> "$NODE_PATHS_FILE"
        echo "NPM_CLI_JS_PATH=${NPM_CLI_JS_ACTUAL_PATH}" >> "$NODE_PATHS_FILE"
        echo "NPX_EXECUTABLE_SYMLINK=${NODE_BIN_DIR}/npx" >> "$NODE_PATHS_FILE"
        echo "NODE_BIN_PATH=${NODE_BIN_DIR}" >> "$NODE_PATHS_FILE"
        exit 0
    else
        purMsg "Existing local Node.js version ($CURRENT_VERSION) differs from target ($NODE_VERSION)."
    fi
fi

read -r -p "Local Node.js ${NODE_VERSION} not found or version mismatch. Download and install into project? [y/n] " input
case $input in
    [yY][eE][sS]|[yY])
        purMsg "Creating installation directory: ${NODE_INSTALL_BASE_DIR}"
        mkdir -p "$NODE_INSTALL_BASE_DIR"
        if [ $? -ne 0 ]; then
            redMsg "Failed to create directory ${NODE_INSTALL_BASE_DIR}. Check permissions."
            exit 1
        fi

        if [ -d "$NODE_EXTRACTED_DIR" ]; then
            purMsg "Removing existing local Node.js directory: $NODE_EXTRACTED_DIR"
            rm -rf "$NODE_EXTRACTED_DIR"
        fi
        if [ -f "${NODE_INSTALL_BASE_DIR}/${NODE_TARBALL}" ]; then
            purMsg "Removing existing local Node.js tarball: ${NODE_INSTALL_BASE_DIR}/${NODE_TARBALL}"
            rm -f "${NODE_INSTALL_BASE_DIR}/${NODE_TARBALL}"
        fi
        if [ -f "$NODE_PATHS_FILE" ]; then
            rm -f "$NODE_PATHS_FILE"
        fi

        cd "$NODE_INSTALL_BASE_DIR" || { redMsg "Failed to cd into $NODE_INSTALL_BASE_DIR"; exit 1; }

        purMsg "Downloading Node.js ${NODE_VERSION} (${NODE_ARCH}) from ${NODE_URL}..."
        curl -LO "$NODE_URL"
        if [ $? -ne 0 ] || [ ! -f "$NODE_TARBALL" ]; then
            redMsg "Node.js download failed. Please check the URL or network connection."
            rm -f "$NODE_TARBALL" 
            exit 1
        fi

        purMsg "Extracting ${NODE_TARBALL}..."
        tar -xzf "$NODE_TARBALL"
        if [ $? -ne 0 ] || [ ! -d "$NODE_FILENAME" ]; then
            redMsg "Node.js extraction failed."
            rm -f "$NODE_TARBALL"
            rm -rf "$NODE_FILENAME" 
            exit 1
        fi

        NPM_CLI_JS_ACTUAL_PATH="${NODE_LIB_DIR}/node_modules/npm/bin/npm-cli.js"

        if [ ! -x "${NODE_BIN_DIR}/node" ] || [ ! -L "${NODE_BIN_DIR}/npm" ] || [ ! -f "$NPM_CLI_JS_ACTUAL_PATH" ]; then
            redMsg "Node.js executable, npm symlink, or npm-cli.js not found after extraction."
            redMsg "Expected node at: ${NODE_BIN_DIR}/node"
            redMsg "Expected npm symlink at: ${NODE_BIN_DIR}/npm"
            redMsg "Expected npm-cli.js at: $NPM_CLI_JS_ACTUAL_PATH"
            ls -l "${NODE_BIN_DIR}/"
            ls -l "$NPM_CLI_JS_ACTUAL_PATH" 2>/dev/null
            rm -f "$NODE_TARBALL"
            rm -rf "$NODE_FILENAME"
            exit 1
        fi

        greMsg "Node.js ${NODE_VERSION} installation successful into ${NODE_EXTRACTED_DIR}."
        
        echo "NODE_EXECUTABLE=${NODE_BIN_DIR}/node" > "$NODE_PATHS_FILE"
        echo "NPM_EXECUTABLE_SYMLINK=${NODE_BIN_DIR}/npm" >> "$NODE_PATHS_FILE"
        echo "NPM_CLI_JS_PATH=${NPM_CLI_JS_ACTUAL_PATH}" >> "$NODE_PATHS_FILE"
        echo "NPX_EXECUTABLE_SYMLINK=${NODE_BIN_DIR}/npx" >> "$NODE_PATHS_FILE"
        echo "NODE_BIN_PATH=${NODE_BIN_DIR}" >> "$NODE_PATHS_FILE" # For convenience for pm2 and other global installs
        greMsg "Executable paths saved to ${NODE_PATHS_FILE}"

        purMsg "Cleaning up downloaded tarball: ${NODE_TARBALL}..."
        rm "$NODE_TARBALL"
        
        cd "$PROJECT_ROOT_DIR"
        ;;
    [nN][oO]|[nN])
        redMsg "Node.js installation skipped by user."
        exit 1
        ;;
    *)
        redMsg "Invalid input. Please answer y/n."
        exit 1
        ;;
esac

exit 0
