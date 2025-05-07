#!/bin/bash

# Define output colors
redMsg() { echo -e "\\n\E[1;31m$*\033[0m\\n"; }
greMsg() { echo -e "\\n\E[1;32m$*\033[0m\\n"; }
bluMsg() { echo -e "\\n\033[5;34m$*\033[0m\\n"; }
purMsg() { echo -e "\\n\033[35m$*\033[0m\\n"; }

DIR=$(pwd)
NODE_VERSION="v22.1.0" # Updated Node.js version
NODE_ARCH="linux-x64"
NODE_FILENAME="node-${NODE_VERSION}-${NODE_ARCH}"
NODE_TARBALL="${NODE_FILENAME}.tar.gz"
NODE_URL="https://nodejs.org/dist/${NODE_VERSION}/${NODE_TARBALL}"
NODE_INSTALL_DIR="$DIR/shell/node"
NODE_BIN_DIR="${NODE_INSTALL_DIR}/${NODE_FILENAME}/bin"

read -r -p "Node.js not found or an older version detected. Do you want to download and install Node.js ${NODE_VERSION} (${NODE_ARCH})? [y/n] " input
case $input in
    [yY][eE][sS]|[yY])
      purMsg "Removing old Node.js installation files if they exist..."
      rm -rf "${NODE_INSTALL_DIR:?}/"* # Protect against accidental deletion if $NODE_INSTALL_DIR is empty or unset
      mkdir -p "$NODE_INSTALL_DIR"
      
      purMsg "Downloading Node.js ${NODE_VERSION} from ${NODE_URL}..."
      wget "${NODE_URL}" -O "${NODE_INSTALL_DIR}/${NODE_TARBALL}"
      if [ $? -eq 0 ]; then
        purMsg "Download successful. Extracting Node.js..."
        tar xvf "${NODE_INSTALL_DIR}/${NODE_TARBALL}" -C "$NODE_INSTALL_DIR/"
        if [ $? -ne 0 ]; then
            redMsg "Node.js extraction failed."
            exit 1
        fi

        # Add to /etc/profile if not already there
        if ! grep -q "${NODE_BIN_DIR}" /etc/profile; then
          purMsg "Adding Node.js to PATH in /etc/profile..."
          # Ensure /etc/profile is writable
          if [ -w "/etc/profile" ]; then
              echo >>/etc/profile
              echo "export PATH=\$PATH:${NODE_BIN_DIR}" >>/etc/profile
              # Source /etc/profile for the current session, though it's better to advise a new session.
              # For the script to immediately use the new node, symlinking is more reliable.
          else
              redMsg "Warning: /etc/profile is not writable. Please add ${NODE_BIN_DIR} to your PATH manually."
          fi
        fi
        
        purMsg "Creating symlinks for node and npm in /usr/local/bin..."
        ln -sf "${NODE_BIN_DIR}/node" /usr/local/bin/node
        ln -sf "${NODE_BIN_DIR}/npm" /usr/local/bin/npm
        ln -sf "${NODE_BIN_DIR}/npx" /usr/local/bin/npx


        # Verify installation
        # Need to ensure the new PATH or symlinks are effective for the 'node -v' command
        # Sourcing /etc/profile might not work in subshells or for the current script execution immediately.
        # Relying on the symlink is better for immediate verification.
        if command -v node &>/dev/null && [[ "$(node -v)" == "${NODE_VERSION}"* || "$(node -v)" == "v${NODE_VERSION}"* ]]; then
          greMsg "Node.js ${NODE_VERSION} installation successful."
          greMsg "Please open a new terminal session or run 'source /etc/profile' for PATH changes to take full effect."
          exit 0
        else
          # Attempt to use the direct path if symlink check fails for some reason
          CURRENT_NODE_VERSION=$("${NODE_BIN_DIR}/node" -v 2>/dev/null)
          if [[ "$CURRENT_NODE_VERSION" == "${NODE_VERSION}"* || "$CURRENT_NODE_VERSION" == "v${NODE_VERSION}"* ]]; then
              greMsg "Node.js ${NODE_VERSION} installation successful (verified via direct path)."
              greMsg "Please open a new terminal session or run 'source /etc/profile' for PATH changes to take full effect."
              exit 0
          else
              redMsg "Node.js installation verification failed. Expected ${NODE_VERSION}, found $(node -v 2>/dev/null || echo 'not found')."
              redMsg "Please check /usr/local/bin for symlinks and ensure ${NODE_BIN_DIR} is correct."
              exit 1
          fi
        fi
      else
        redMsg "Download failed from ${NODE_URL}. Please check the URL and your network connection.";
        exit 1
      fi
    ;;
    [nN][oO]|[nN])
        purMsg "Skipping Node.js installation."
        purMsg "Please ensure Node.js (recommended >= v22.0.0) is installed and in your PATH manually."
        exit 1
        ;;
    *)
        redMsg "Invalid input. Please enter y/n."
        exit 1
        ;;
esac
