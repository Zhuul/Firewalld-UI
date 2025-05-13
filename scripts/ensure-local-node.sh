#!/bin/bash
set -e

PROJECT_ROOT_ENSURE_SCRIPT_DIR=$(dirname "$(realpath "$0")")/..
cd "$PROJECT_ROOT_ENSURE_SCRIPT_DIR" || exit 1

NODE_VERSION_FILE=".nvmrc"
LOCAL_NODE_DIR="local_node"
NEEDS_NPM_INSTALL=0 # Flag to indicate if npm install should run

if [ ! -f "$NODE_VERSION_FILE" ]; then echo "Error: $NODE_VERSION_FILE not found."; exit 1; fi
NODE_VERSION=$(cat "$NODE_VERSION_FILE" | sed 's/v//')
ARCH="x64" # Assuming x64, can be made dynamic if needed
OS_TYPE="linux" # Assuming linux based on your OS

PATH_TO_LOCAL_NODE_BIN="$PROJECT_ROOT_ENSURE_SCRIPT_DIR/$LOCAL_NODE_DIR/bin/node"
PATH_TO_LOCAL_NPM_CLI="$PROJECT_ROOT_ENSURE_SCRIPT_DIR/$LOCAL_NODE_DIR/lib/node_modules/npm/bin/npm-cli.js" # Path to npm's main CLI script

# Check if correct version is already installed
if [ -f "$PATH_TO_LOCAL_NODE_BIN" ] && [ "$($PATH_TO_LOCAL_NODE_BIN -v 2>/dev/null | sed 's/v//')" == "$NODE_VERSION" ]; then
  # Already set up, do nothing further for Node installation
  : # No-op, Node is fine
else
  echo "Local Node.js v${NODE_VERSION} not found or version mismatch. Setting up..."
  NEEDS_NPM_INSTALL=1 # Will need npm install after setting up new Node
  mkdir -p "$LOCAL_NODE_DIR"
  # Clean out before install to be safe. The :? ensures LOCAL_NODE_DIR is not empty or /.
  rm -rf "${LOCAL_NODE_DIR:?}/"* 

  NODE_DIST_NAME="node-v${NODE_VERSION}-${OS_TYPE}-${ARCH}"
  NODE_TARBALL="${NODE_DIST_NAME}.tar.xz"
  NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TARBALL}"

  echo "Downloading Node.js from $NODE_URL..."
  # Use curl with -# for progress bar, -L to follow redirects
  curl -# -L "$NODE_URL" -o "$LOCAL_NODE_DIR/$NODE_TARBALL"
  if [ $? -ne 0 ]; then echo "Error downloading Node.js. Please check the URL or network."; exit 1; fi

  echo "Extracting Node.js..."
  # Extract into the LOCAL_NODE_DIR, stripping the top-level directory from the tarball
  tar -xJf "$LOCAL_NODE_DIR/$NODE_TARBALL" -C "$LOCAL_NODE_DIR" --strip-components=1
  if [ $? -ne 0 ]; then echo "Error extracting Node.js."; exit 1; fi

  # Clean up the downloaded tarball
  rm "$LOCAL_NODE_DIR/$NODE_TARBALL"
  echo "Node.js v${NODE_VERSION} installed locally in $LOCAL_NODE_DIR/bin"

  # Add local_node to .gitignore if not already present
  GITIGNORE_FILE=".gitignore"
  LOCAL_NODE_GITIGNORE_ENTRY="/$LOCAL_NODE_DIR" # Add leading slash for root-level gitignore
  if [ -f "$GITIGNORE_FILE" ]; then
    if ! grep -qF -- "$LOCAL_NODE_GITIGNORE_ENTRY" "$GITIGNORE_FILE"; then
      echo "$LOCAL_NODE_GITIGNORE_ENTRY" >> "$GITIGNORE_FILE"
      echo "Added $LOCAL_NODE_GITIGNORE_ENTRY to $GITIGNORE_FILE"
    fi
  else
    echo "$LOCAL_NODE_GITIGNORE_ENTRY" > "$GITIGNORE_FILE"
    echo "Created $GITIGNORE_FILE and added $LOCAL_NODE_GITIGNORE_ENTRY"
  fi
fi

# If Node was newly installed/updated, or if node_modules is missing, run npm install
# This ensures dependencies are installed with the correct Node/npm version.
if [ "$NEEDS_NPM_INSTALL" -eq 1 ] || [ ! -d "node_modules" ] || [ ! -f "node_modules/.bin/egg-scripts" ]; then
  echo "Running 'npm install' using local Node.js/npm..."
  "$PATH_TO_LOCAL_NODE_BIN" "$PATH_TO_LOCAL_NPM_CLI" install --no-audit --no-fund
  if [ $? -ne 0 ]; then echo "Error running 'npm install' with local npm."; exit 1; fi
  echo "Dependencies installed."
else
  echo "Local Node.js v$NODE_VERSION is ready. Dependencies appear to be installed."
fi

exit 0
