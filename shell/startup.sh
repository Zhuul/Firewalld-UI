#!/bin/bash

# Get the project root directory
# Assuming startup.sh is in the 'shell' subdirectory of the project root
SCRIPT_STARTUP_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DIR=$(dirname "$SCRIPT_STARTUP_DIR") # This is the Project Root Directory

cd "$DIR" || { echo "ERROR: Failed to cd into project root $DIR"; exit 1; }

# Make all shell scripts executable (consider if this is always needed or only once)
# This is generally fine for a setup script.
chmod +x $DIR/shell/*.sh

# Define output colors 
redMsg() { echo -e "\\n\E[1;31m$*\033[0m\\n"; }
greMsg() { echo -e "\\n\E[1;32m$*\033[0m\\n"; }
bluMsg() { echo -e "\\n\033[5;34m$*\033[0m\\n"; }
purMsg() { echo -e "\\n\033[35m$*\033[0m\\n"; }

HTTP=$(grep "httpPort" $DIR/express/config.js | grep -Eo '[0-9]{1,4}')
HTTPS=$(grep "httpsPort" $DIR/express/config.js | grep -Eo '[0-9]{1,4}')
SERVER=$(grep "port" $DIR/config/config.prod.js | grep -Eo '[0-9]{1,4}')

greMsg "-------------------------Startup process begins $(date +%F%n%T)-------------------------"

# --- Node.js Setup ---
purMsg "-------------------------Node.js Setup-------------------------"
# Run node.sh to ensure local Node.js is installed and get its paths
# node.sh will create/update shell/node/.node_paths
sh ./shell/node.sh
if [ $? -ne 0 ]; then
    redMsg "Local Node.js setup via node.sh failed or was skipped. Cannot proceed."
    exit 1
fi

NODE_PATHS_FILE="$DIR/shell/node/.node_paths"
if [ ! -f "$NODE_PATHS_FILE" ]; then
    redMsg "Node paths file ($NODE_PATHS_FILE) not found after node.sh execution. Critical error."
    exit 1
fi

# Source the paths to make NODE_EXECUTABLE, NPM_EXECUTABLE, etc., available
source "$NODE_PATHS_FILE"

if [ -z "$NODE_EXECUTABLE" ] || [ ! -x "$NODE_EXECUTABLE" ] || \
   [ -z "$NPM_EXECUTABLE" ] || [ ! -x "$NPM_EXECUTABLE" ] || \
   [ -z "$NODE_BIN_PATH" ]; then
    redMsg "Failed to load or verify executables from $NODE_PATHS_FILE. Contents:"
    cat "$NODE_PATHS_FILE"
    exit 1
fi

greMsg "Using local Node.js from: $NODE_EXECUTABLE"
greMsg "Using local npm from: $NPM_EXECUTABLE"

NODE_VERSION_OUTPUT=$("$NODE_EXECUTABLE" -v 2>/dev/null)
RECOMMENDED_NODE_MAJOR=22 # As defined in your original script

if ! [[ "$NODE_VERSION_OUTPUT" == "v${RECOMMENDED_NODE_MAJOR}."* ]]; then
    redMsg "Local Node.js version ($NODE_VERSION_OUTPUT) is not the expected v${RECOMMENDED_NODE_MAJOR}.x. Check node.sh."
    exit 1
fi
greMsg "Local Node.js version check passed: $NODE_VERSION_OUTPUT"


# --- Port Information & Checks (using local node/npm if needed by sub-scripts) ---
echo "-------------------------Port Information-------------------------"
# If http.sh, https.sh, server.sh need node/npm, they'll need to source .node_paths or receive paths
# For now, assuming they don't directly execute node/npm themselves.
if [ ! "$HTTP" ]; then redMsg "Front-end port HTTP does not exist"; else bluMsg "Front-end port HTTP: $HTTP"; sh ./shell/http.sh; fi
if [ ! "$HTTPS" ]; then redMsg "Front-end port HTTPS does not exist"; else bluMsg "Front-end port HTTPS: $HTTPS"; sh ./shell/https.sh; fi
if [ ! "$SERVER" ]; then redMsg "Back-end port does not exist"; else bluMsg "Back-end port: $SERVER"; sh ./shell/server.sh; fi

sleep 3

# --- Key Generation ---
echo "-------------------------Key Generation-------------------------"
# If secret.sh needs node/npm, it should source .node_paths
sh $DIR/shell/secret.sh

# --- Environment Detection (already handled Node.js above) ---
echo "-------------------------Environment Detection-------------------------"

# --- PM2 Setup (using local npm) ---
purMsg "-------------------------PM2 Setup-------------------------"
# pm2.sh will also need to source .node_paths to use the correct npm and find pm2 relative to it
PM2_INSTALL_OUTPUT=$(sh ./shell/pm2.sh) 
PM2_INSTALL_STATUS=$?
PM2_INSTALL_OUTPUT=$(echo "$PM2_INSTALL_OUTPUT" | xargs) # Trim whitespace

if [ $PM2_INSTALL_STATUS -eq 0 ] && [ -n "$PM2_INSTALL_OUTPUT" ] && [ -f "$PM2_INSTALL_OUTPUT" ] && [ -x "$PM2_INSTALL_OUTPUT" ]; then
    greMsg "pm2 script successful. pm2 executable found at: $PM2_INSTALL_OUTPUT"
    PM2_EXECUTABLE="$PM2_INSTALL_OUTPUT"
else
    redMsg "pm2.sh failed, or did not return a valid/executable path."
    redMsg "Output captured from pm2.sh: [$PM2_INSTALL_OUTPUT]"
    redMsg "Exit status from pm2.sh: $PM2_INSTALL_STATUS"
    # Add more detailed checks as before if needed
    exit 1
fi

PMV=$("$PM2_EXECUTABLE" -v 2>/dev/null)
if [ $? -ne 0 ]; then
    redMsg "Failed to execute pm2 using path: $PM2_EXECUTABLE. Version check failed."
    exit 1
fi
greMsg "pm2 is available. Version: $PMV. Using: $PM2_EXECUTABLE"

# --- Firewall and dsniff checks ---
FIRE=$(firewall-cmd -V 2>/dev/null)
if [ $? -ne 0 ]; then redMsg "firewalld not found or not working. Please install/configure firewalld."; exit 1; else greMsg "firewalld is installed. Version: $FIRE"; fi

if ! command -v tcpkill &> /dev/null; then # dsniff provides tcpkill
    purMsg "dsniff (tcpkill) not found. This is optional but recommended for some features."
else
    greMsg "tcpkill (from dsniff) is installed."
fi


# --- Dependency Installation (using local npm) ---
purMsg "-------------------------Dependency Installation-------------------------"
# modules.sh will also need to source .node_paths
sh ./shell/modules.sh
if [ $? -ne 0 ]; then
    redMsg "Dependency installation via modules.sh failed."
    exit 1
else
    greMsg "Front-end and back-end dependencies should be downloaded/updated.";
fi

# --- Systemd Service Setup (using local npm) ---
purMsg "-------------------------Setting up systemd service-------------------------"
PROJECT_INSTALL_DIR="$DIR" 
SERVICE_FILE_SOURCE="$SCRIPT_STARTUP_DIR/firewalld-ui.service" # Assumes service template is in shell/
SERVICE_FILE_DEST="/etc/systemd/system/firewalld-ui.service"
TEMP_SERVICE_FILE="/tmp/firewalld-ui.service.$$"

if [ ! -f "$SERVICE_FILE_SOURCE" ]; then
    redMsg "ERROR: Service file template not found at $SERVICE_FILE_SOURCE"
    exit 1
fi

purMsg "Customizing service file template from $SERVICE_FILE_SOURCE..."
# Replace placeholder for WorkingDirectory
sed "s|WorkingDirectory=/workspaces/Firewalld-UI|WorkingDirectory=${PROJECT_INSTALL_DIR}|g" "$SERVICE_FILE_SOURCE" > "$TEMP_SERVICE_FILE"
# Replace placeholder for ExecStart to use the local npm
sed -i "s|ExecStart=__NPM_EXEC_PATH__ start|ExecStart=${NPM_EXECUTABLE} start|g" "$TEMP_SERVICE_FILE"
# Replace placeholder for PIDFile
sed -i "s|PIDFile=%H/run/egg-server.pid|PIDFile=${PROJECT_INSTALL_DIR}/run/egg-server.pid|g" "$TEMP_SERVICE_FILE"

# ... (rest of systemd copy, reload, enable, start logic from your script) ...
# Ensure you check for errors at each step.
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
    if [ $? -ne 0 ]; then
        redMsg "ERROR: systemctl restart firewalld-ui.service failed."
        redMsg "Check service status with: systemctl status firewalld-ui.service"
        redMsg "And logs with: journalctl -u firewalld-ui.service"
    else
        greMsg "Service firewalld-ui setup complete and started via systemd."
    fi
else
    redMsg "ERROR: Failed to copy customized service file to $SERVICE_FILE_DEST."
    # exit 1 # Decide if this is fatal
fi
purMsg "-------------------------Systemd service setup finished-------------------------"


# --- Application Start (using local npm and pm2) ---
cd "$DIR" || exit 1
purMsg "Entering root directory $DIR"

if [ ! -f "./express/express-linux" ];then
    redMsg "Front-end directory or executable ./express/express-linux does not exist"
    exit 1
fi

purMsg "Entering front-end directory $DIR/express"
cd ./express || exit 1
purMsg "Modifying front-end execution permissions for express-linux"
chmod +x express-linux # Only need +x on the executable itself

sleep 1 # Reduced sleep

echo "-------------------------Official Start (via pm2 and npm)-------------------------"
purMsg "Returning to root directory $DIR to start services"
cd "$DIR" || exit 1

# Logging setup
LOG_FILE="$DIR/shell/shell.log"
echo -e "\n------------------------- $(date +%F%n%T) -------------------------" >> "$LOG_FILE"

# Stop existing backend process if not managed by systemd (systemd handles its own stop/start)
# If systemd is primary, this 'npm run stop:linux' might be redundant or conflict.
# For now, keeping it as per original logic, but be mindful of systemd.
if [[ "$1" != "reload" ]]; then # Assuming 'reload' is a special argument
    purMsg "Attempting to stop existing backend process (if any, not managed by systemd)..."
    "$NPM_EXECUTABLE" run stop:linux >> "$LOG_FILE" 2>&1
    # Don't exit on error here, as it might not be running
fi

# Start backend (if systemd failed or is not used for direct management here)
# If systemd is managing it, this 'npm run start:linux' is also redundant.
# The original script had this, so keeping the structure.
purMsg "Starting backend service (egg.js)..."
"$NPM_EXECUTABLE" run start:linux >> "$LOG_FILE" 2>&1 & # Run in background
BACKEND_PID=$!
sleep 5 # Give backend some time to start

# Check if backend started (very basic check)
if ! ps -p $BACKEND_PID > /dev/null; then
    redMsg "Backend (npm run start:linux) may have failed to start. Check $LOG_FILE"
    # Potentially exit or try to show logs
fi


purMsg "Starting/Managing frontend service (express-linux) with pm2..."
cd ./express || exit 1
"$PM2_EXECUTABLE" start express-linux --name=HttpServer --exp-backoff-restart-delay=1000 >> "$LOG_FILE" 2>&1
PM2_START_STATUS=$?
cd "$DIR" || exit 1

if [ $PM2_START_STATUS -ne 0 ]; then
    redMsg "Frontend (pm2 start express-linux) failed. Check $LOG_FILE and pm2 logs."
    # Consider exiting
else
    greMsg "Frontend started/managed by pm2."
fi

greMsg "Service startup initiated."
bluMsg "Front-end HTTP: Local IP:$HTTP"
bluMsg "Front-end HTTPS: Local IP:$HTTPS (If HTTPS is not deployed, please access HTTP)"
bluMsg "Back-end: Local IP:$SERVER"
greMsg "Check $LOG_FILE for detailed startup logs."
greMsg "-------------------------Startup process ends $(date +%F%n%T)-------------------------"
echo -e "\n------------------------- $(date +%F%n%T) END -------------------------" >> "$LOG_FILE"

exit 0
