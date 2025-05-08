#!/bin/bash

# Get the project root directory
# Assuming startup.sh is in the 'shell' subdirectory of the project root
SCRIPT_STARTUP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
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

NODE_VERSION_EXPECTED_PREFIX="v22.1" # Expecting v22.1.x from node.sh
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

PM2_VERSION_OUTPUT=$("$PM2_EXECUTABLE" -v 2>/dev/null)
if [ $? -ne 0 ]; then
    redMsg "Failed to execute local pm2 using path: $PM2_EXECUTABLE. Version check failed."
    exit 1
fi
greMsg "Local pm2 is available. Version: $PM2_VERSION_OUTPUT. Using: $PM2_EXECUTABLE"

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
    redMsg "Dependency installation via modules.sh failed or was skipped."
    exit 1
else
    greMsg "Front-end and back-end dependencies should be downloaded/updated.";
fi

# --- Systemd Service Setup (using local npm) ---
purMsg "-------------------------Setting up systemd service-------------------------"
PROJECT_INSTALL_DIR_ABS=$(cd "$DIR" && pwd) # Get absolute path for service file
SERVICE_FILE_SOURCE="$SCRIPT_STARTUP_DIR/firewalld-ui.service"
SERVICE_FILE_DEST="/etc/systemd/system/firewalld-ui.service"
TEMP_SERVICE_FILE="/tmp/firewalld-ui.service.$$"

if [ ! -f "$SERVICE_FILE_SOURCE" ]; then
    redMsg "ERROR: Service file template not found at $SERVICE_FILE_SOURCE"
    exit 1
fi

purMsg "Customizing service file template from $SERVICE_FILE_SOURCE..."
# Replace placeholder for WorkingDirectory
sed "s|WorkingDirectory=/workspaces/Firewalld-UI|WorkingDirectory=${PROJECT_INSTALL_DIR_ABS}|g" "$SERVICE_FILE_SOURCE" > "$TEMP_SERVICE_FILE"

# Replace placeholder for ExecStart to use the local node to run npm-cli.js start
# Ensure PATH includes NODE_BIN_PATH for any child processes of npm start
SYSTEMD_EXEC_START_COMMAND="/bin/sh -c 'PATH=${NODE_BIN_PATH}:\$PATH ${NODE_EXECUTABLE} ${NPM_CLI_JS_PATH} start'"
sed -i "s|ExecStart=__NPM_EXEC_PATH__ start|ExecStart=${SYSTEMD_EXEC_START_COMMAND}|g" "$TEMP_SERVICE_FILE"

# Replace placeholder for PIDFile
sed -i "s|PIDFile=%H/run/egg-server.pid|PIDFile=${PROJECT_INSTALL_DIR_ABS}/run/egg-server.pid|g" "$TEMP_SERVICE_FILE"

purMsg "Installing systemd service file to $SERVICE_FILE_DEST..."
cp "$TEMP_SERVICE_FILE" "$SERVICE_FILE_DEST"
CP_STATUS=$?
rm -f "$TEMP_SERVICE_FILE" 

if [ $CP_STATUS -eq 0 ]; then
    greMsg "Service file successfully copied to $SERVICE_FILE_DEST."
    chmod 644 "$SERVICE_FILE_DEST"
    systemctl daemon-reload
    systemctl enable firewalld-ui.service
    systemctl restart firewalld-ui.service
    RESTART_STATUS=$?
    sleep 2 # Give systemd a moment
    systemctl is-active --quiet firewalld-ui.service
    ACTIVE_STATUS=$?

    if [ $RESTART_STATUS -ne 0 ] || [ $ACTIVE_STATUS -ne 0 ]; then
        redMsg "ERROR: systemctl restart/activation of firewalld-ui.service failed."
        systemctl status firewalld-ui.service --no-pager >&2
        journalctl -u firewalld-ui.service -n 20 --no-pager >&2
    else
        greMsg "Service firewalld-ui setup complete and started via systemd."
    fi
else
    redMsg "ERROR: Failed to copy customized service file to $SERVICE_FILE_DEST."
fi
purMsg "-------------------------Systemd service setup finished-------------------------"


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
"$PM2_EXECUTABLE" delete HttpServer >> "$LOG_FILE" 2>&1 # Suppress error if not found
sleep 1

purMsg "Starting/Managing frontend service (express-linux) with local pm2..."
# Already in $DIR/express directory
# Ensure PM2 also uses the correct PATH if it needs to find node for any reason,
# though express-linux is a binary. For consistency with npm, we can set it.
env PATH="${NODE_BIN_PATH}:${PATH}" "$PM2_EXECUTABLE" start express-linux --name=HttpServer --exp-backoff-restart-delay=1000 --output "$DIR/shell/pm2-HttpServer-out.log" --error "$DIR/shell/pm2-HttpServer-err.log"
PM2_START_STATUS=$?
cd "$DIR" || exit 1 # Return to project root

if [ $PM2_START_STATUS -ne 0 ]; then
    redMsg "Frontend (pm2 start express-linux) failed. Check $LOG_FILE and pm2 logs ($DIR/shell/pm2-HttpServer-*.log)."
else
    greMsg "Frontend started/managed by local pm2."
    "$PM2_EXECUTABLE" list >> "$LOG_FILE" 2>&1
fi

greMsg "Service startup initiated."
bluMsg "Backend (Egg.js) should be running via systemd (port: $SERVER)."
bluMsg "Frontend (Express) running via PM2 (HTTP port: $HTTP, HTTPS port: $HTTPS)."
greMsg "Check $LOG_FILE for detailed startup logs of this script."
greMsg "Check systemd logs for backend: journalctl -u firewalld-ui.service -f"
greMsg "Check PM2 logs for frontend: $PM2_EXECUTABLE logs HttpServer"
greMsg "-------------------------Startup process ends $(date +%F%n%T)-------------------------"
echo -e "\\n------------------------- $(date +%F%n%T) END -------------------------" >> "$LOG_FILE"

exit 0
