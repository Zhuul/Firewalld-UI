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
    unset NODE_EXECUTABLE
    unset NPM_CLI_JS_PATH
    # It's safer to exit if node paths can't be sourced, as subsequent commands rely on them.
    # exit 1 # Consider if this is too strict or if script should attempt to continue.
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
    if [ -f "$DIR/shell/pm2.sh" ]; then
        greMsg "Attempting to get PM2 path from $DIR/shell/pm2.sh..."
        PM2_EXECUTABLE_PATH_OUTPUT=$(sh "$DIR/shell/pm2.sh" 2>/dev/null) # Suppress pm2.sh errors for cleaner output
        PM2_SETUP_STATUS=$?
        TEMP_PM2_EXECUTABLE=$(echo "$PM2_EXECUTABLE_PATH_OUTPUT" | xargs)

        if [ $PM2_SETUP_STATUS -eq 0 ] && [ -n "$TEMP_PM2_EXECUTABLE" ] && [ -f "$TEMP_PM2_EXECUTABLE" ] && [ -x "$TEMP_PM2_EXECUTABLE" ]; then
            PM2_EXECUTABLE="$TEMP_PM2_EXECUTABLE"
            greMsg "Using PM2 executable from shell/pm2.sh: $PM2_EXECUTABLE"
        else
            purMsg "shell/pm2.sh did not yield a valid PM2 executable. Status: $PM2_SETUP_STATUS, Output: '$PM2_EXECUTABLE_PATH_OUTPUT'."
        fi
    fi

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
        "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" delete HttpServer > /dev/null 2>&1
        pm2_delete_status=$?
        if [ $pm2_delete_status -eq 0 ]; then greMsg "PM2 delete HttpServer command successful."; else purMsg "PM2 delete HttpServer command finished (status $pm2_delete_status - process may not have been running)."; fi

        greMsg "Attempting to stop PM2 daemon process: $NODE_EXECUTABLE $PM2_EXECUTABLE kill"
        "$NODE_EXECUTABLE" "$PM2_EXECUTABLE" kill > /dev/null 2>&1
        pm2_kill_status=$?
        if [ $pm2_kill_status -eq 0 ]; then greMsg "PM2 kill command successful."; else purMsg "PM2 kill command finished (status $pm2_kill_status - daemon may not have been running)."; fi
        if [ $pm2_delete_status -ne 0 ] || [ $pm2_kill_status -ne 0 ]; then
             # If PM2 commands had issues, wait a bit before pkill
            greMsg "Waiting 3 seconds after PM2 stop attempts..."
            sleep 3
        fi
    else
        redMsg "No valid PM2 executable found. Skipping PM2 stop."
    fi
else
    purMsg "NODE_EXECUTABLE not set. Skipping PM2 stop."
fi

# --- Stop Egg.js Backend (egg-server) ---
purMsg "-------------------------Stopping Egg.js Backend (egg-server)-------------------------"
EGG_SCRIPTS_PATH="$DIR/node_modules/.bin/egg-scripts"
EGG_SERVER_STOPPED_GRACEFULLY=false
if [ -n "$NODE_EXECUTABLE" ] && [ -f "$EGG_SCRIPTS_PATH" ]; then
    greMsg "Attempting to stop egg-server using local egg-scripts: $NODE_EXECUTABLE $EGG_SCRIPTS_PATH stop --sticky --title=egg-server"
    "$NODE_EXECUTABLE" "$EGG_SCRIPTS_PATH" stop --sticky --title=egg-server
    stop_status=$?
    if [ $stop_status -eq 0 ]; then
        greMsg "Local egg-scripts stop command executed successfully."
        EGG_SERVER_STOPPED_GRACEFULLY=true
    else
        purMsg "Local egg-scripts stop command finished (may have already been stopped or encountered an issue). Exit status: $stop_status"
    fi
elif [ -n "$NODE_EXECUTABLE" ] && [ -n "$NPM_CLI_JS_PATH" ]; then
    greMsg "Local egg-scripts not found at $EGG_SCRIPTS_PATH. Falling back to npm run stop (may have issues)."
    greMsg "Attempting to stop egg-server using npm script: $NODE_EXECUTABLE $NPM_CLI_JS_PATH run stop -- --title=egg-server"
    "$NODE_EXECUTABLE" "$NPM_CLI_JS_PATH" run stop -- --title=egg-server # package.json stop script
    stop_status=$?
    if [ $stop_status -eq 0 ]; then
        greMsg "egg-server stop script executed successfully."
        EGG_SERVER_STOPPED_GRACEFULLY=true
    else
        purMsg "npm run stop script finished. Exit status: $stop_status"
    fi
else
    purMsg "NODE_EXECUTABLE not set or local egg-scripts/npm not available. Skipping backend stop."
fi

if [ "$EGG_SERVER_STOPPED_GRACEFULLY" = true ]; then
    greMsg "Waiting 5 seconds for egg-server to terminate gracefully..."
    sleep 5
else
    greMsg "egg-server did not stop gracefully or stop command not fully executed. Proceeding to port/pkill checks more quickly."
    sleep 2
fi


# --- Stop firewalld-ui systemd service ---
purMsg "-------------------------Stopping firewalld-ui systemd service-------------------------"
if command -v systemctl &> /dev/null; then
    greMsg "Attempting to stop firewalld-ui.service (requires sudo if not already root)..."
    if sudo systemctl is-active --quiet firewalld-ui.service; then
        if sudo systemctl stop firewalld-ui.service; then
            greMsg "firewalld-ui.service stopped successfully."
            greMsg "Waiting 3 seconds for systemd service to stop..."
            sleep 3
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
if [ -z "$SERVER_PORT_FROM_CONFIG" ]; then
    SERVER_PORT_EFFECTIVE="7001"
    purMsg "Could not reliably determine backend server port from $PROD_CONFIG_JS, will use default $SERVER_PORT_EFFECTIVE for kill attempt."
else
    SERVER_PORT_EFFECTIVE="$SERVER_PORT_FROM_CONFIG"
fi

PORTS_TO_KILL=()
[ -n "$HTTP_PORT" ] && PORTS_TO_KILL+=("$HTTP_PORT")
[ -n "$HTTPS_PORT" ] && PORTS_TO_KILL+=("$HTTPS_PORT")
[ -n "$SERVER_PORT_EFFECTIVE" ] && PORTS_TO_KILL+=("$SERVER_PORT_EFFECTIVE")

UNIQUE_PORTS_TO_KILL=($(echo "${PORTS_TO_KILL[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

if [ ${#UNIQUE_PORTS_TO_KILL[@]} -gt 0 ]; then
    for PORT_TO_KILL in "${UNIQUE_PORTS_TO_KILL[@]}"; do
        greMsg "Attempting to clear port $PORT_TO_KILL (requires sudo)..."
        for attempt in 1 2 3; do
            PIDS_ON_PORT=$(sudo lsof -t -i:$PORT_TO_KILL 2>/dev/null)
            if [ -n "$PIDS_ON_PORT" ]; then
                greMsg "[Port $PORT_TO_KILL - Attempt $attempt] Found PIDs: $PIDS_ON_PORT. Sending SIGKILL..."
                echo "$PIDS_ON_PORT" | tr ' ' '\n' | while read -r pid_to_kill; do
                    if [ -n "$pid_to_kill" ]; then # Ensure pid_to_kill is not empty
                        sudo kill -9 "$pid_to_kill"
                    fi
                done
                greMsg "[Port $PORT_TO_KILL - Attempt $attempt] SIGKILL sent. Waiting 2s..."
                sleep 2
            else
                purMsg "[Port $PORT_TO_KILL - Attempt $attempt] No processes found."
                break # Exit attempts loop for this port
            fi
        done
        # Final check for the port
        if sudo lsof -t -i:$PORT_TO_KILL 2>/dev/null; then
            redMsg "Processes on port $PORT_TO_KILL might still be running after multiple kill attempts."
        else
            greMsg "Port $PORT_TO_KILL appears to be clear."
        fi
    done
else
    purMsg "No specific ports identified for fallback kill. If issues persist, check manually."
fi

# --- Final Cleanup using pkill for known process names ---
# This is a broader attempt to catch anything missed.
purMsg "-------------------------Final pkill cleanup (Broad attempt)-------------------------"
bluMsg "This section may require sudo privileges if not already root."

# More specific patterns first, then broader ones.
# Focus on scripts and executables within the project directory.
# The .* is greedy, so be careful. Using $DIR to scope it.
# Ensure NODE_EXECUTABLE is set before using it in patterns.
NODE_EXEC_PATTERN=""
if [ -n "$NODE_EXECUTABLE" ]; then
    # Escape for regex, e.g. / becomes \/
    ESCAPED_NODE_EXECUTABLE=$(echo "$NODE_EXECUTABLE" | sed 's/[/\\\\]/\\\\\\\\&/g') # Corrected sed escaping for bash
    NODE_EXEC_PATTERN="$ESCAPED_NODE_EXECUTABLE"
fi

KNOWN_PROCESS_PATTERNS=(
    "$NODE_EXEC_PATTERN .*/node_modules/.bin/pm2"                 # Local PM2
    # Specific egg patterns - targeting common script paths and the --title
    "$NODE_EXEC_PATTERN .*/node_modules/.bin/egg-scripts start"   # Initial egg-scripts start command
    "$NODE_EXEC_PATTERN .*/egg-scripts/lib/start-cluster.js"     # Egg master process script often used by egg-scripts
    "$NODE_EXEC_PATTERN .*/egg-cluster/lib/app_worker.js"        # Egg app worker script
    "$NODE_EXEC_PATTERN .*/egg-cluster/lib/agent_worker.js"      # Egg agent worker script
    "egg-server"                                                 # Process title (from --title=egg-server)
    "$NODE_EXEC_PATTERN .*/node_modules/.bin/egg-scripts stop"    # Local egg-scripts stop (if it hung)
    "HttpServer"                                                 # General HttpServer name (PM2 default)
    "firewalld-ui"                                               # Systemd service name
    # Broader pattern for any node process running from the project dir
    "$NODE_EXEC_PATTERN .*$DIR"
)
# Add a very generic one if NODE_EXECUTABLE was not set
if [ -z "$NODE_EXEC_PATTERN" ]; then
    KNOWN_PROCESS_PATTERNS+=("node .*Firewalld-UI") # Fallback if local node path unknown
fi


for pattern in "${KNOWN_PROCESS_PATTERNS[@]}"; do
    if [ -z "$pattern" ]; then continue; fi # Skip empty patterns
    greMsg "Attempting to pkill processes matching '$pattern' (requires sudo)..."
    if sudo pgrep -f "$pattern" > /dev/null; then
        if sudo pkill -SIGKILL -f "$pattern"; then # Send SIGKILL directly
            greMsg "pkill -SIGKILL -f \"$pattern\" executed. Processes matching (if any) should be terminated."
            greMsg "Waiting 2 seconds after pkill for '$pattern'..."
            sleep 2
        else
            # pkill can return 1 if no processes were matched, even if pgrep found them (race condition)
            # or if it fails to kill (permissions, zombie processes)
            purMsg "pkill -f \"$pattern\" command finished. (status $?). This might be okay if processes were already gone."
        fi
    else
        purMsg "No processes found matching '$pattern' for pkill."
    fi
done

greMsg "-------------------------Firewalld-UI Shutdown Process Completed-------------------------"
purMsg "Please verify that all related processes have been stopped."
purMsg "You can check with: ps aux | grep -E \"egg-server|HttpServer|firewalld-ui|node .*Firewalld-UI|egg-scripts|pm2\" | grep -v grep"
purMsg "And for listening ports: sudo lsof -i -P -n | grep LISTEN"

exit 0
