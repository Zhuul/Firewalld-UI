#!/bin/bash
# This script sets up the PATH to use the project's local Node.js version
# and then executes the provided command.

set -e

# Get the absolute path to the project root directory
# This assumes the script is in PROJECT_ROOT/scripts/
PROJECT_ROOT_RUN_SCRIPT_DIR=$(dirname "$(realpath "$0")")/..
cd "$PROJECT_ROOT_RUN_SCRIPT_DIR" || exit 1

LOCAL_NODE_DIR="local_node" # Define LOCAL_NODE_DIR
LOCAL_NODE_BIN_DIR="$PROJECT_ROOT_RUN_SCRIPT_DIR/$LOCAL_NODE_DIR/bin"
PATH_TO_LOCAL_NODE_BIN="$PROJECT_ROOT_RUN_SCRIPT_DIR/$LOCAL_NODE_DIR/bin/node"
PATH_TO_LOCAL_NPM_CLI="$PROJECT_ROOT_RUN_SCRIPT_DIR/$LOCAL_NODE_DIR/lib/node_modules/npm/bin/npm-cli.js"


# Check if the local Node.js bin directory exists
if [ ! -d "$LOCAL_NODE_BIN_DIR" ] || [ ! -f "$PATH_TO_LOCAL_NODE_BIN" ]; then
  echo "Error: Local Node.js binary directory or executable not found at $LOCAL_NODE_BIN_DIR"
  echo "Please run the project's setup script first (e.g., 'npm run waf' or 'bash scripts/ensure-local-node.sh')."
  exit 1
fi

# Prepend the local Node.js bin directory to the PATH
export PATH="$LOCAL_NODE_BIN_DIR:$PATH"

# If the command is 'npm', we need to ensure it's our local npm.
# The `npm` executable in local_node/bin is a symlink/shim.
# We can directly call the npm-cli.js script with our local node.
if [ "$1" == "npm" ]; then
  shift # Remove 'npm' from arguments
  # Execute npm-cli.js with the local node, passing remaining arguments
  exec "$PATH_TO_LOCAL_NODE_BIN" "$PATH_TO_LOCAL_NPM_CLI" "$@"
else
  # For other commands (like egg-scripts, eslint, etc.),
  # they should be resolved from node_modules/.bin/ due to the PATH modification,
  # or be global commands that are fine.
  exec "$@"
fi
