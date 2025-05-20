#!/bin/bash
# filepath: /usr/local/src/Firewalld-UI/shell/create-default-admin.sh
# This script ensures a default admin user ("admin"/"admin") exists.
# Customize DB logic (SQLite, MySQL, PostgreSQL, etc.) as needed.

set -e

# Example: If using SQLite stored in "database/sqlite-prod.db"
DB_PATH="/usr/local/src/Firewalld-UI/database/sqlite-prod.db"

echo "[create-default-admin] Checking/creating default admin user..."

# For SQLite example, check if admin user exists:
EXISTS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM users WHERE username='admin';" 2>/dev/null || echo 0)

if [ "$EXISTS" -eq 0 ]; then
  echo "[create-default-admin] No admin user found. Creating one..."
  # Insert user with username=admin, password=admin (hash your password in real usage!)
  sqlite3 "$DB_PATH" "INSERT INTO users (username, password, role) VALUES ('admin','admin','administrator');"
  echo "[create-default-admin] Created default admin user."
else
  echo "[create-default-admin] Admin user already exists. No action taken."
fi

echo "[create-default-admin] Done."