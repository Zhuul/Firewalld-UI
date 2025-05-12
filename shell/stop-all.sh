#!/bin/bash

# Get the project root directory
# Assuming this script is in the 'shell' subdirectory of the project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P )" # Use -P for physical path
DIR=$(dirname "$SCRIPT_DIR") # This is the Project Root Directory

cd "$DIR" || { echo -e "\\n\\E[1;31mERROR: Failed to cd into project root $DIR\\033[0m\\n" >&2; exit 1; }

# Define output colors
redMsg() { echo -e "\\n\\E[1;31m$*\\033[0m\\n" >&2; }
greMsg() { echo -e "\\n\\E[1;32m$*\\033[0m\\n" >&2; }
bluMsg() { echo -e "\\n\\033[5;34m$*\\033[0m\\n" >&2; }
purMsg() { echo -e "\\n\\033[35m$*\\033[0m\\n" >&2; }

purMsg "-------------------------Starting Firewalld-UI Shutdown Process-------------------------"

# --- Source Node.js Environment ---
NODE_PATHS_FILE="$DIR/shell/node/.node_paths"
if [ -f "$NODE_PATHS_FILE" ]; then
    greMsg "Sourcing Node.js environment from $NODE_PATHS_FILE..."
    source "$NODE_PATHS_FILE"
else
    redMsg "Node paths file ($NODE_PATHS_FILE) not found. Cannot proceed with all Node-dependent shutdowns."
    # Unset to prevent partial execution with bad/missing paths
    unset NODE_EXECUTABLE
    unset NPM_CLI_JS_PATH
fi

# Verify essential Node variables if paths file was sourced and exists
if [ -n "$NODE_PATHS_FILE" ] && [ -f "$NODE_PATHS_FILE" ]; then
    if [ -z "$NODE_EXECUTABLE" ] || [ ! -x "$NODE_EXECUTABLE" ] || \
       [ -z "$NPM_CLI_JS_PATH" ] || [ ! -f "$NPM_CLI_JS_PATH" ]; then
        redMsg "NODE_EXECUTABLE or NPM_CLI_JS_PATH is not correctly set from $NODE_PATHS_FILE. Node-dependent shutdowns may fail."
        unset NODE_EXECUTABLE # Prevent use of bad paths
        unset NPM_CLI_JS_PATH
    else
        greMsg "Using local Node.js: $NODE_EXECUTABLE"
        greMsg "Using local npm: $NODE_EXECUTABLE $NPM_CLI_JS_PATH"
    fi
fi

# --- Stop PM2 Managed Frontend (HttpServer) ---
purMsg "-------------------------Stopping PM2 Frontend (HttpServer)-------------------------"
PM2_EXECUTABLE=""

if [ -n "$NODE_EXECUTABLE" ]; then
    # Try shell/pm2.sh first
    if [ -f "$DIR/shell/pm2.sh" ]; then
        greMsg "Attempting to get PM2 path from $DIR/shell/pm2.sh..."
        PM2_EXECUTABLE_PATH_OUTPUT=$(sh "$DIR/shell/pm2.sh") # pm2.sh should output the path to pm2
        PM2_SETUP_STATUS=$?
        TEMP_PM2_EXECUTABLE=$(echo "$PM2_EXECUTABLE_PATH_OUTPUT" | xargs) # Trim whitespace

        if [ $PM2_SETUP_STATUS -eq 0 ] && [ -n "$TEMP_PM2_EXECUTABLE" ] && [ -f "$TEMP_PM2_EXECUTABLE" ] && [ -x "$TEMP_PM2_EXECUTABLE" ]; then
            PM2_EXECUTABLE="$TEMP_PM2_EXECUTABLE"
            greMsg "Using PM2 executable from shell/pm2.sh: $PM2_EXECUTABLE"
        else
            purMsg "shell/pm2.sh did not yield a valid PM2 executable. Status: $PM2_SETUP_STATUS, Output: '$PM2_EXECUTABLE_PATH_OUTPUT'."
        fi
    fi

    # If shell/pm2.sh didn't provide a valid path, try default node_modules path
    if [ -z "$PM2_EXECUTABLE" ]; then
        DEFAULT_PM2_PATH="$DIR/node_modules/.bin/pm2"
        if [ -f "$DEFAULT_PM2_PATH" ] && [ -x "$DEFAULT_PM2_PATH" ]; then
            PM2_EXECUTABLE="$DEFAULT_PM2_PATH"
            greMsg "Using default PM2 executable: $PM2_EXECUTABLE"
        else
            purMsg "Default PM2 executable not found at $DEFAULT_PM2_PATH."
        fi
    fi

    if [ -n "$PM2_EXECUTABLE" ]; then
        greMsg "Attempting to stop HttpServer using PM2: $NODE_EXECUTABLE $PM2_EXECUTABLE delete HttpServer"
        "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" delete HttpServer
        # Check status but don't exit, as process not existing is also a success for "stopping"
        if [ $? -eq 0 ]; then greMsg "PM2 delete HttpServer command successful."; else purMsg "PM2 delete HttpServer command finished (status $?)."; fi

        greMsg "Attempting to stop PM2 daemon process: $NODE_EXECUTABLE $PM2_EXECUTABLE kill"
        "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" kill
        if [ $? -eq 0 ]; then greMsg "PM2 kill command successful."; else purMsg "PM2 kill command finished (status $?)."; fi
    else
        redMsg "No valid PM2 executable found. Skipping PM2 stop."
    fi
else
    purMsg "NODE_EXECUTABLE not set. Skipping PM2 stop."
fi

# --- Stop Egg.js Backend (egg-server) ---
purMsg "-------------------------Stopping Egg.js Backend (egg-server)-------------------------"
EGG_SCRIPTS_PATH="$DIR/node_modules/.bin/egg-scripts"
if [ -n "$NODE_EXECUTABLE" ] && [ -f "$EGG_SCRIPTS_PATH" ]; then
    greMsg "Attempting to stop egg-server using local egg-scripts: $NODE_EXECUTABLE $EGG_SCRIPTS_PATH stop --sticky --title=egg-server"
    "$NODE_EXECUTABLE" "$EGG_SCRIPTS_PATH" stop --sticky --title=egg-server
    if [ $? -eq 0 ]; then
        greMsg "Local egg-scripts stop command executed successfully."
    else
        purMsg "Local egg-scripts stop command finished (may have already been stopped or encountered an issue). Exit status: $?"
    fi
elif [ -n "$NODE_EXECUTABLE" ] && [ -n "$NPM_CLI_JS_PATH" ]; then
    # Fallback to npm run stop if direct egg-scripts path fails, though this had issues
    greMsg "Local egg-scripts not found at $EGG_SCRIPTS_PATH. Falling back to npm run stop (may have issues)."
    greMsg "Attempting to stop egg-server using npm script: $NODE_EXECUTABLE $NPM_CLI_JS_PATH run stop -- --title=egg-server"
    "$NODE_EXECUTABLE" "$NPM_CLI_JS_PATH" run stop -- --title=egg-server # package.json stop script
    if [ $? -eq 0 ]; then
        greMsg "egg-server stop script executed successfully."
    else
        purMsg "npm run stop script finished. Exit status: $?"
    fi
else
    purMsg "NODE_EXECUTABLE not set or local egg-scripts/npm not available. Skipping backend stop."
fi

# --- Stop firewalld-ui systemd service ---
purMsg "-------------------------Stopping firewalld-ui systemd service-------------------------"
if command -v systemctl &> /dev/null; then
    greMsg "Attempting to stop firewalld-ui.service (requires sudo if not already root)..."
    if sudo systemctl is-active --quiet firewalld-ui.service; then
        if sudo systemctl stop firewalld-ui.service; then
            greMsg "firewalld-ui.service stopped successfully."
        else
            redMsg "Failed to stop firewalld-ui.service. Status: $?"
        fi
    else
        purMsg "firewalld-ui.service was not active or not found."
    fi
else
    purMsg "systemctl command not found. Skipping systemd service stop."
fi

# --- Force Stop Processes by Port (Fallback) ---
purMsg "-------------------------Force stopping processes by port (Fallback)-------------------------"
bluMsg "This section may require sudo privileges if not already root."

HTTP_PORT=""
HTTPS_PORT=""
SERVER_PORT_FROM_CONFIG=""

EXPRESS_CONFIG_JS="$DIR/express/config.js"
PROD_CONFIG_JS="$DIR/config/config.prod.js"

if [ -f "$EXPRESS_CONFIG_JS" ]; then
    HTTP_PORT=$(grep "httpPort" "$EXPRESS_CONFIG_JS" | grep -Eo '[0-9]{1,5}' | head -n 1)
    HTTPS_PORT=$(grep "httpsPort" "$EXPRESS_CONFIG_JS" | grep -Eo '[0-9]{1,5}' | head -n 1)
fi

if [ -f "$PROD_CONFIG_JS" ]; then
    SERVER_PORT_FROM_CONFIG=$(awk '/config.cluster *= *{/{flag=1;next}/}/{flag=0}flag && /port:/{print $NF}' "$PROD_CONFIG_JS" | tr -d ',' | grep -Eo '[0-9]+' | head -n 1)
fi
# Default backend port if not found in config or if config parsing fails
if [ -z "$SERVER_PORT_FROM_CONFIG" ]; then
    SERVER_PORT_EFFECTIVE="7001" # Default as commonly used
    purMsg "Could not reliably determine backend server port from $PROD_CONFIG_JS, will use default $SERVER_PORT_EFFECTIVE for kill attempt if not already covered."
else
    SERVER_PORT_EFFECTIVE="$SERVER_PORT_FROM_CONFIG"
fi

PORTS_TO_KILL=()
[ -n "$HTTP_PORT" ] && PORTS_TO_KILL+=("$HTTP_PORT")
[ -n "$HTTPS_PORT" ] && PORTS_TO_KILL+=("$HTTPS_PORT")
[ -n "$SERVER_PORT_EFFECTIVE" ] && PORTS_TO_KILL+=("$SERVER_PORT_EFFECTIVE")

UNIQUE_PORTS_TO_KILL=($(echo "${PORTS_TO_KILL[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

if [ ${#UNIQUE_PORTS_TO_KILL[@]} -gt 0 ]; then
    for PORT in "${UNIQUE_PORTS_TO_KILL[@]}"; do
        greMsg "Attempting to kill processes on port $PORT (requires sudo)..."
        PIDS=$(sudo lsof -t -i:$PORT)
        if [ -n "$PIDS" ]; then
            echo "$PIDS" | tr ' ' '\n' | while read -r pid_to_kill; do
                if [ -n "$pid_to_kill" ]; then
                    greMsg "Killing PID $pid_to_kill on port $PORT"
                    sudo kill -9 "$pid_to_kill"
                fi
            done
            greMsg "Kill attempt on port $PORT completed."
        else
            purMsg "No processes found on port $PORT."
        fi
    done
else
    purMsg "No specific ports identified for fallback kill. If issues persist, check manually."
fi

# --- Final Cleanup using pkill for known process names ---
purMsg "-------------------------Final pkill cleanup (Broad attempt)-------------------------"
bluMsg "This section may require sudo privileges if not already root."
KNOWN_PROCESS_PATTERNS=("egg-server" "HttpServer" "firewalld-ui" "node .*Firewalld-UI" "node .*egg-scripts start")

for pattern in "${KNOWN_PROCESS_PATTERNS[@]}"; do
    greMsg "Attempting to pkill processes matching '$pattern' (requires sudo)..."
    # Check if any processes match before trying to kill, to avoid non-zero exit code from pkill if no match
    if pgrep -f "$pattern" > /dev/null; then
        if sudo pkill -f "$pattern"; then
            greMsg "pkill -f \"$pattern\" executed. Processes matching (if any) should be terminated."
        else
            redMsg "pkill -f \"$pattern\" failed, even though processes were found. Check permissions or process state."
        fi
    else
        purMsg "No processes found matching '$pattern' for pkill."
    fi
done

greMsg "-------------------------Firewalld-UI Shutdown Process Completed-------------------------"
purMsg "Please verify that all related processes have been stopped."
purMsg "You can check with: ps aux | grep -E \"egg-server|HttpServer|firewalld-ui|node .*Firewalld-UI|egg-scripts\""
purMsg "And for listening ports: sudo lsof -i -P -n | grep LISTEN"

exit 0
