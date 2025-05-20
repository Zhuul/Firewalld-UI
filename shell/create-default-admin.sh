#!/bin/bash
# filepath: /usr/local/src/Firewalld-UI/shell/create-default-admin.sh
# This script ensures a default admin user ("admin"/"admin") exists.

set -e

export NODE_EXECUTABLE="/usr/local/src/Firewalld-UI/shell/node/node-v22.2.0-linux-x64/bin/node"
export NPM_CLI_JS_PATH="/usr/local/src/Firewalld-UI/shell/node/node-v22.2.0-linux-x64/lib/node_modules/npm/bin/npm-cli.js"
export NODE_BIN_PATH="/usr/local/src/Firewalld-UI/shell/node/node-v22.2.0-linux-x64/bin"
export SQLITE_EXECUTABLE="/usr/bin/sqlite3"
export PM2_EXECUTABLE="/usr/local/src/Firewalld-UI/shell/node/node-v22.2.0-linux-x64/bin/pm2"

DB_PATH="/usr/local/src/Firewalld-UI/database/sqlite-prod.db"

# Source node paths, which also define SQLITE_EXECUTABLE
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P )"
DIR=$(dirname "$SCRIPT_DIR")
NODE_PATHS_FILE="$DIR/shell/node/.node_paths"

if [ ! -f "$NODE_PATHS_FILE" ]; then
  echo "[create-default-admin] $NODE_PATHS_FILE not found. Cannot load \$SQLITE_EXECUTABLE."
  exit 1
fi

source "$NODE_PATHS_FILE"

if [ -z "$SQLITE_EXECUTABLE" ] || [ ! -x "$SQLITE_EXECUTABLE" ]; then
  echo "[create-default-admin] SQLITE_EXECUTABLE not defined or not executable. Check $NODE_PATHS_FILE."
  exit 1
fi

echo "[create-default-admin] Checking/creating default admin user..."

# For example, to ensure libraries can be found if necessary:
env PATH="${NODE_BIN_PATH}:${PATH}" "$SQLITE_EXECUTABLE" "$DB_PATH" "SELECT 1;" >/dev/null 2>&1 || {
  echo "[create-default-admin] Error: Cannot run local sqlite3 on DB $DB_PATH. Is the binary compatible?"
  exit 1
}

EXISTS=$(env PATH="${NODE_BIN_PATH}:${PATH}" "$SQLITE_EXECUTABLE" "$DB_PATH" \
  "SELECT COUNT(*) FROM users WHERE username='admin';" 2>/dev/null || echo 0)

if [ "$EXISTS" -eq 0 ]; then
  echo "[create-default-admin] No admin user found. Creating one..."
  env PATH="${NODE_BIN_PATH}:${PATH}" "$SQLITE_EXECUTABLE" "$DB_PATH" \
    "INSERT INTO users (username, password, role) VALUES ('admin','admin','administrator');"
  echo "[create-default-admin] Created default admin user."
else
  echo "[create-default-admin] Admin user already exists. Updating password to 'admin'..."
  env PATH="${NODE_BIN_PATH}:${PATH}" "$SQLITE_EXECUTABLE" "$DB_PATH" \
    "UPDATE users SET password='admin' WHERE username='admin';"
  echo "[create-default-admin] Password updated for existing admin."
fi

echo "[create-default-admin] Done."
