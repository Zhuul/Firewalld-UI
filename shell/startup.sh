#!/bin/bash
# filepath: /usr/local/src/Firewalld-UI/shell/startup.sh

# Get the project root directory
# Assuming startup.sh is in the 'shell' subdirectory of the project root
SCRIPT_STARTUP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P )" # Use -P for physical path
DIR=$(dirname "$SCRIPT_STARTUP_DIR") # This is the Project Root Directory

cd "$DIR" || { echo "ERROR: Failed to cd into project root $DIR" >&2; exit 1; }

# Make all shell scripts executable (consider if this is always needed or only once)
chmod +x $DIR/shell/*.sh

# Define output colors (all messages from startup.sh go to stderr by default, or stdout if explicit)
redMsg() { echo -e "\\n\\E[1;31m$*\\033[0m\\n" >&2; }
greMsg() { echo -e "\\n\\E[1;32m$*\\033[0m\\n" >&2; }
bluMsg() { echo -e "\\n\\033[5;34m$*\\033[0m\\n" >&2; }
purMsg() { echo -e "\\n\\033[35m$*\\033[0m\\n" >&2; }

HTTP=$(grep "httpPort" $DIR/express/config.js | grep -Eo '[0-9]{1,4}')
HTTPS=$(grep "httpsPort" $DIR/express/config.js | grep -Eo '[0-9]{1,4}')
SERVER=$(grep "port" $DIR/config/config.prod.js | grep -Eo '[0-9]{1,4}')

greMsg "-------------------------Startup process begins $(date +%F%n%T)-------------------------"

# --- Node.js Setup ---
purMsg "-------------------------Node.js Setup-------------------------"
# Run node.sh to ensure local Node.js is installed and get its paths
# node.sh will create/update shell/node/.node_paths
sh ./shell/node.sh # node.sh messages go to its stderr
NODE_SETUP_STATUS=$?
if [ $NODE_SETUP_STATUS -ne 0 ]; then
    redMsg "Local Node.js setup via node.sh failed or was skipped (exit status: $NODE_SETUP_STATUS). Cannot proceed."
    exit 1
fi

NODE_PATHS_FILE="$DIR/shell/node/.node_paths"
if [ ! -f "$NODE_PATHS_FILE" ]; then
    redMsg "Node paths file ($NODE_PATHS_FILE) not found after node.sh execution. Critical error."
    exit 1
fi

# Source the paths to make NODE_EXECUTABLE, NPM_CLI_JS_PATH, NODE_BIN_PATH etc., available
source "$NODE_PATHS_FILE"

# NPM_EXECUTABLE_SYMLINK is the path to the npm symlink in node/bin, useful for some contexts
# NPM_CLI_JS_PATH is the direct path to npm's main script, used for robust execution with NODE_EXECUTABLE
if [ -z "$NODE_EXECUTABLE" ] || [ ! -x "$NODE_EXECUTABLE" ] || \
   [ -z "$NPM_EXECUTABLE_SYMLINK" ] || [ ! -L "$NPM_EXECUTABLE_SYMLINK" ] || \
   [ -z "$NPM_CLI_JS_PATH" ] || [ ! -f "$NPM_CLI_JS_PATH" ] || \
   [ -z "$NODE_BIN_PATH" ]; then
    redMsg "Failed to load or verify executables/paths from $NODE_PATHS_FILE (NODE_EXECUTABLE, NPM_EXECUTABLE_SYMLINK, NPM_CLI_JS_PATH, NODE_BIN_PATH). Contents:"
    cat "$NODE_PATHS_FILE" >&2
    exit 1
fi

greMsg "Using local Node.js from: $NODE_EXECUTABLE"
greMsg "Using local npm (via CLI script) with: $NODE_EXECUTABLE $NPM_CLI_JS_PATH"
greMsg "Local Node's bin path: $NODE_BIN_PATH"

NODE_VERSION_EXPECTED_PREFIX="v22.2" # Expecting v22.2.x from node.sh
NODE_VERSION_OUTPUT=$("$NODE_EXECUTABLE" -v 2>/dev/null)

if ! [[ "$NODE_VERSION_OUTPUT" == "${NODE_VERSION_EXPECTED_PREFIX}."* ]]; then
    redMsg "Local Node.js version ($NODE_VERSION_OUTPUT) is not the expected ${NODE_VERSION_EXPECTED_PREFIX}.x. Check node.sh."
    # exit 1 # Decide if this is fatal
fi
greMsg "Local Node.js version check: $NODE_VERSION_OUTPUT"

# --- Port Information & Checks ---
purMsg "-------------------------Port Information-------------------------"
if [ ! "$HTTP" ]; then redMsg "Front-end port HTTP does not exist"; else bluMsg "Front-end port HTTP: $HTTP"; sh ./shell/http.sh; fi
if [ ! "$HTTPS" ]; then redMsg "Front-end port HTTPS does not exist"; else bluMsg "Front-end port HTTPS: $HTTPS"; sh ./shell/https.sh; fi
if [ ! "$SERVER" ]; then redMsg "Back-end port does not exist"; else bluMsg "Back-end port: $SERVER"; sh ./shell/server.sh; fi

sleep 1 # Reduced sleep

# --- Key Generation ---
purMsg "-------------------------Key Generation-------------------------"
sh $DIR/shell/secret.sh

# --- Environment Detection (PM2) ---
purMsg "-------------------------Environment Detection (PM2)-------------------------"
# pm2.sh will also need to source .node_paths to use the correct npm (via node + npm-cli.js) and find pm2 relative to it.
# pm2.sh will echo only the path to pm2 if successful.
PM2_EXECUTABLE_PATH_OUTPUT=$(sh ./shell/pm2.sh) 
PM2_SETUP_STATUS=$?
PM2_EXECUTABLE_PATH_OUTPUT=$(echo "$PM2_EXECUTABLE_PATH_OUTPUT" | xargs) # Trim whitespace

if [ $PM2_SETUP_STATUS -eq 0 ] && [ -n "$PM2_EXECUTABLE_PATH_OUTPUT" ] && \
   [ -f "$PM2_EXECUTABLE_PATH_OUTPUT" ] && [ -x "$PM2_EXECUTABLE_PATH_OUTPUT" ]; then
    greMsg "pm2.sh successful. Local pm2 executable found at: $PM2_EXECUTABLE_PATH_OUTPUT"
    PM2_EXECUTABLE="$PM2_EXECUTABLE_PATH_OUTPUT"
else
    redMsg "pm2.sh failed, or did not return a valid/executable path."
    redMsg "Output captured from pm2.sh (should be a path or empty): [$PM2_EXECUTABLE_PATH_OUTPUT]"
    redMsg "Exit status from pm2.sh: $PM2_SETUP_STATUS"
    if [ -n "$PM2_EXECUTABLE_PATH_OUTPUT" ]; then
        if [ ! -f "$PM2_EXECUTABLE_PATH_OUTPUT" ]; then redMsg "Path [$PM2_EXECUTABLE_PATH_OUTPUT] does not exist as a file."; fi
        if [ -f "$PM2_EXECUTABLE_PATH_OUTPUT" ] && [ ! -x "$PM2_EXECUTABLE_PATH_OUTPUT" ]; then redMsg "Path [$PM2_EXECUTABLE_PATH_OUTPUT] is not executable."; ls -l "$PM2_EXECUTABLE_PATH_OUTPUT" >&2; fi
    fi
    exit 1
fi

# Use NODE_EXECUTABLE to run PM2 scripts
PM2_VERSION_OUTPUT=$("$NODE_EXECUTABLE" "$PM2_EXECUTABLE" -v 2>/dev/null)
PM2_VERSION_EXIT_STATUS=$?

if [ $PM2_VERSION_EXIT_STATUS -ne 0 ] || [ -z "$PM2_VERSION_OUTPUT" ]; then
    redMsg "Failed to execute local pm2 version check using: $NODE_EXECUTABLE $PM2_EXECUTABLE -v"
    redMsg "Exit status: $PM2_VERSION_EXIT_STATUS. Output: [$PM2_VERSION_OUTPUT]"
    purMsg "Attempting pm2 -v with NODE_BIN_PATH in PATH for diagnostics (this might show the pm2 help if node is not found by env):"
    env PATH="${NODE_BIN_PATH}:${PATH}" "$PM2_EXECUTABLE" -v >&2
    exit 1
fi
greMsg "Local pm2 is available. Version: $PM2_VERSION_OUTPUT. Using: $NODE_EXECUTABLE $PM2_EXECUTABLE"

# --- Firewall and dsniff checks ---
FIREWALL_VERSION=$(firewall-cmd -V 2>/dev/null)
if [ $? -ne 0 ]; then redMsg "firewalld not found or not working. Please install/configure firewalld."; exit 1; else greMsg "firewalld is installed. Version: $FIREWALL_VERSION"; fi

if ! command -v tcpkill &> /dev/null; then
    purMsg "dsniff (tcpkill) not found. This is optional but recommended for some features."
else
    greMsg "tcpkill (from dsniff) is installed."
fi


# --- Dependency Installation (using local npm) ---
purMsg "-------------------------Dependency Installation-------------------------"
# modules.sh uses local npm via .node_paths (NODE_EXECUTABLE + NPM_CLI_JS_PATH)
sh ./shell/modules.sh
MODULES_STATUS=$?
if [ $MODULES_STATUS -ne 0 ]; then
    redMsg "Dependency installation/check via modules.sh failed or was skipped by user (status: $MODULES_STATUS). Cannot proceed."
    exit 1
else
    greMsg "modules.sh completed successfully (status: $MODULES_STATUS)."
fi

# --- Update packages to latest ---
purMsg "-------------------------Updating packages to latest-------------------------"
purMsg "Installing/Updating npm-check-updates globally for the local Node.js..."
if env PATH="${NODE_BIN_PATH}:${PATH}" "$NODE_EXECUTABLE" "$NPM_CLI_JS_PATH" install -g npm-check-updates; then
    greMsg "npm-check-updates installed/updated successfully."

    purMsg "Running npm-check-updates for backend in $DIR..."
    cd "$DIR" || { redMsg "Failed to cd to $DIR for backend ncu. Exiting."; exit 1; }
    if env PATH="${NODE_BIN_PATH}:${PATH}" ncu -u; then
        greMsg "Backend package.json potentially updated by ncu. Running npm install..."
        if ! env PATH="${NODE_BIN_PATH}:${PATH}" "$NODE_EXECUTABLE" "$NPM_CLI_JS_PATH" install --legacy-peer-deps; then
            redMsg "Backend npm install after ncu failed. Exiting."
            exit 1
        fi
        greMsg "Backend dependencies installed after ncu."
    else
        redMsg "npm-check-updates (ncu -u) failed for backend. Exiting."
        exit 1
    fi

    purMsg "Running npm-check-updates for frontend in $DIR/express..."
    cd "$DIR/express" || { redMsg "Failed to cd to $DIR/express for frontend ncu. Exiting."; exit 1; }
    if env PATH="${NODE_BIN_PATH}:${PATH}" ncu -u; then
        greMsg "Frontend package.json potentially updated by ncu. Running npm install..."
        if ! env PATH="${NODE_BIN_PATH}:${PATH}" "$NODE_EXECUTABLE" "$NPM_CLI_JS_PATH" install --legacy-peer-deps; then
            redMsg "Frontend npm install after ncu failed. Exiting."
            exit 1
        fi
        greMsg "Frontend dependencies installed after ncu."
    else
        redMsg "npm-check-updates (ncu -u) failed for frontend. Exiting."
        exit 1
    fi
    cd "$DIR" || { redMsg "Failed to cd back to $DIR after frontend ncu. Exiting."; exit 1; }
else
    redMsg "Failed to install npm-check-updates globally. Package updates with ncu will be skipped. Exiting."
    exit 1
fi

# --- Attempt to fix vulnerabilities ---
purMsg "-------------------------Fixing Vulnerabilities-------------------------"
purMsg "Attempting to fix vulnerabilities in backend..."
# Ensure we are in the project root for the main audit fix
cd "$DIR" || { redMsg "Failed to cd to $DIR for backend audit fix"; exit 1; }
if "$NODE_EXECUTABLE" "$NPM_CLI_JS_PATH" audit fix; then
    greMsg "Backend npm audit fix completed."
else
    # Capture the exit code of npm audit fix
    AUDIT_FIX_BACKEND_STATUS=$?
    # Check if the exit code indicates that fixes were applied but some vulnerabilities remain (common)
    # npm audit fix exits with 1 if vulnerabilities remain. This is not necessarily a script-stopping error.
    if [ $AUDIT_FIX_BACKEND_STATUS -eq 1 ]; then
        purMsg "Backend npm audit fix applied some fixes, but vulnerabilities may still remain. Check output from audit fix."
    else
        redMsg "Backend npm audit fix failed with exit code $AUDIT_FIX_BACKEND_STATUS or had other issues."
    fi
fi
purMsg "-------------------------Backend Vulnerability Check-------------------------"
"$NODE_EXECUTABLE" "$NPM_CLI_JS_PATH" audit || purMsg "Backend npm audit reported issues (or no issues if exit code 0)."
echo "" # Add a newline for better readability

purMsg "Attempting to fix vulnerabilities in frontend (express)..."
# Change to the express directory for the frontend audit fix
cd "$DIR/express" || { redMsg "Failed to cd to $DIR/express for frontend audit fix"; exit 1; }
if "$NODE_EXECUTABLE" "$NPM_CLI_JS_PATH" audit fix; then
    greMsg "Frontend npm audit fix completed."
else
    AUDIT_FIX_FRONTEND_STATUS=$?
    if [ $AUDIT_FIX_FRONTEND_STATUS -eq 1 ]; then
        purMsg "Frontend npm audit fix applied some fixes, but vulnerabilities may still remain. Check output from audit fix."
    else
        redMsg "Frontend npm audit fix failed with exit code $AUDIT_FIX_FRONTEND_STATUS or had other issues."
    fi
fi
purMsg "-------------------------Frontend Vulnerability Check (express)-------------------------"
"$NODE_EXECUTABLE" "$NPM_CLI_JS_PATH" audit || purMsg "Frontend (express) npm audit reported issues (or no issues if exit code 0)."
echo "" # Add a newline for better readability

cd "$DIR" || { redMsg "Failed to cd back to $DIR after audit fixes"; exit 1; } # Return to project root


# --- Systemd Service Setup Information ---
purMsg "-------------------------Systemd Service Setup Information-------------------------"
PROJECT_INSTALL_DIR_ABS=$(cd "$DIR" && pwd) # Get absolute path for service file
SERVICE_FILE_SOURCE="$SCRIPT_STARTUP_DIR/firewalld-ui.service"
# SERVICE_FILE_DEST="/etc/systemd/system/firewalld-ui.service" # No longer directly writing here
TEMP_SERVICE_FILE="/tmp/firewalld-ui.service.$$"

if [ ! -f "$SERVICE_FILE_SOURCE" ]; then
    redMsg "ERROR: Service file template not found at $SERVICE_FILE_SOURCE"
    # exit 1 # Keep this commented or decide if it's fatal if template is missing
    purMsg "Skipping systemd service file preparation as template is missing."
else
    purMsg "Customizing a template for firewalld-ui.service based on $SERVICE_FILE_SOURCE..."
    # Replace placeholder for WorkingDirectory - more robust sed command
    sed "s|^WorkingDirectory=.*|WorkingDirectory=${PROJECT_INSTALL_DIR_ABS}|g" "$SERVICE_FILE_SOURCE" > "$TEMP_SERVICE_FILE"

    # Replace placeholder for ExecStart to use the local node to run npm-cli.js start:systemd
    # Ensure PATH includes NODE_BIN_PATH for any child processes of npm start
    SYSTEMD_EXEC_START_COMMAND="/bin/sh -c 'PATH=${NODE_BIN_PATH}:\\\\$PATH ${NODE_EXECUTABLE} ${NPM_CLI_JS_PATH} run start:systemd'"
    # Use a different delimiter for sed if paths contain slashes
    sed -i "s|ExecStart=__NPM_EXEC_PATH__ start|ExecStart=${SYSTEMD_EXEC_START_COMMAND}|g" "$TEMP_SERVICE_FILE"

    # Replace placeholder for PIDFile
    sed -i "s|PIDFile=%H/run/egg-server.pid|PIDFile=${PROJECT_INSTALL_DIR_ABS}/run/egg-server.pid|g" "$TEMP_SERVICE_FILE"

    purMsg "Ensuring PIDFile directory exists (application might need it): ${PROJECT_INSTALL_DIR_ABS}/run"
    mkdir -p "${PROJECT_INSTALL_DIR_ABS}/run"

    greMsg "A customized systemd service file template has been prepared at: $TEMP_SERVICE_FILE"
    greMsg "Its content is:"
    echo "----------------------------------------------------------------------"
    cat "$TEMP_SERVICE_FILE" # Display the content
    echo "----------------------------------------------------------------------"
    
    purMsg "To manually install and manage the firewalld-ui service with systemd:"
    purMsg "1. Review the content above (also saved to $TEMP_SERVICE_FILE)."
    purMsg "2. If it looks correct, copy it to the systemd directory:"
    bluMsg "   sudo cp $TEMP_SERVICE_FILE /etc/systemd/system/firewalld-ui.service"
    purMsg "3. Set appropriate permissions:"
    bluMsg "   sudo chmod 644 /etc/systemd/system/firewalld-ui.service"
    purMsg "4. Reload the systemd daemon:"
    bluMsg "   sudo systemctl daemon-reload"
    purMsg "5. Enable the service to start on boot:"
    bluMsg "   sudo systemctl enable firewalld-ui.service"
    purMsg "6. Start the service immediately:"
    bluMsg "   sudo systemctl start firewalld-ui.service"
    purMsg "7. Check its status:"
    bluMsg "   sudo systemctl status firewalld-ui.service"
    bluMsg "   journalctl -u firewalld-ui.service -f"
    purMsg "You can remove the temporary file after copying: rm $TEMP_SERVICE_FILE"
fi
purMsg "-------------------------Systemd service information provided-------------------------"


# --- Application Start (Frontend with PM2) ---
cd "$DIR" || exit 1 # Ensure we are in project root
purMsg "Entering root directory $DIR"

if [ ! -f "./express/express-linux" ];then
    redMsg "Front-end executable ./express/express-linux does not exist"
    exit 1
fi

purMsg "Entering front-end directory $DIR/express"
cd ./express || exit 1
purMsg "Modifying front-end execution permissions for express-linux"
chmod +x express-linux
# No need to run express-linux directly here if PM2 is managing it.

sleep 1

purMsg "-------------------------Application Start (PM2 for Frontend)-------------------------"
# Backend is managed by systemd now. Frontend by PM2.
LOG_FILE="$DIR/shell/shell.log" # Central log for startup.sh actions
echo -e "\\n------------------------- $(date +%F%n%T) PM2 Start -------------------------" >> "$LOG_FILE"

# Stop existing pm2 process for HttpServer if any
# Use NODE_EXECUTABLE and ensure NODE_BIN_PATH is in PATH for pm2 commands
env PATH="${NODE_BIN_PATH}:${PATH}" "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" delete HttpServer >> "$LOG_FILE" 2>&1 # Suppress error if not found
sleep 1

purMsg "Starting/Managing frontend service (express-linux) with local pm2..."
# Already in $DIR/express directory
# Ensure PM2 also uses the correct PATH if it needs to find node for any reason,
# though express-linux is a binary. For consistency with npm, we can set it.
env PATH="${NODE_BIN_PATH}:${PATH}" "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" start express-linux --name=HttpServer --exp-backoff-restart-delay=1000 --output "$DIR/shell/pm2-HttpServer-out.log" --error "$DIR/shell/pm2-HttpServer-err.log"
PM2_START_STATUS=$?
cd "$DIR" || exit 1 # Return to project root

if [ $PM2_START_STATUS -ne 0 ]; then
    redMsg "Frontend (pm2 start express-linux) failed. Check $LOG_FILE and pm2 logs ($DIR/shell/pm2-HttpServer-*.log)."
else
    greMsg "Frontend started/managed by local pm2."
    env PATH="${NODE_BIN_PATH}:${PATH}" "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" list >> "$LOG_FILE" 2>&1
fi

greMsg "Service startup initiated."
bluMsg "Backend (Egg.js) should be running via systemd (port: $SERVER)."
bluMsg "Frontend (Express) running via PM2 (HTTP port: $HTTP, HTTPS port: $HTTPS)."
greMsg "Check $LOG_FILE for detailed startup logs of this script."
greMsg "Check systemd logs for backend: journalctl -u firewalld-ui.service -f"
greMsg "Check PM2 logs for frontend: $PM2_EXECUTABLE logs HttpServer"
greMsg "-------------------------Startup process ends $(date +%F%n%T)-------------------------"
echo -e "\\n------------------------- $(date +%F%n%T) END -------------------------" >> "$LOG_FILE"

# Final lines: run the server in the foreground if systemd argument is provided
if [ "$1" = "systemd" ]; then
  echo "[Firewalld-UI] Starting frontend (PM2) and backend (Egg) in systemd mode..."

  # Use the env PATH so pm2 can be found via $NODE_BIN_PATH
  env PATH="${NODE_BIN_PATH}:${PATH}" "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" start ./express/express-linux --name HttpServer

  # Keep Egg in foreground (--daemon=false) on localhost:7001
  echo "[Firewalld-UI] Starting Egg server in foreground for systemd..."
  exec env PATH="${NODE_BIN_PATH}:${PATH}" npx egg-scripts start --daemon=false --hostname=127.0.0.1 --port=7001

else
  echo "[Firewalld-UI] Starting in normal mode (not systemd)."
  ./shell/stop-all.sh

  # Start frontend in background
  cd "$DIR/express" || exit 1
  env PATH="${NODE_BIN_PATH}:${PATH}" "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" start express-linux --name HttpServer
  cd "$DIR" || exit 1

  # Start Egg in daemon mode
  env PATH="${NODE_BIN_PATH}:${PATH}" npx egg-scripts start --daemon --hostname=127.0.0.1 --port="$SERVER"
  
  # End of script
fi
