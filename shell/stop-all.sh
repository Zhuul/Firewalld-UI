#!/bin/bash

# Get the project root directory
# Assuming this script is in the 'shell' subdirectory of the project root
SCRIPT_STOP_ALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P )" # Use -P for physical path
PROJECT_ROOT_DIR=$(dirname "$SCRIPT_STOP_ALL_DIR") # This is the Project Root Directory

cd "$PROJECT_ROOT_DIR" || { echo -e "\n\E[1;31mERROR: Failed to cd into project root $PROJECT_ROOT_DIR\033[0m\n" >&2; exit 1; }

# Define output colors
redMsg() { echo -e "\n\033[1;31m$*\033[0m\n" >&2; } # Bold Red
greMsg() { echo -e "\n\033[1;32m$*\033[0m\n" >&2; } # Bold Green
bluMsg() { echo -e "\n\033[1;34m$*\033[0m\n" >&2; } # Bold Blue (no blink)
purMsg() { echo -e "\n\033[1;35m$*\033[0m\n" >&2; } # Bold Purple

RUN_WITH_LOCAL_NODE_SCRIPT="$PROJECT_ROOT_DIR/scripts/run-with-local-node.sh"

if [ ! -x "$RUN_WITH_LOCAL_NODE_SCRIPT" ]; then
    redMsg "Error: Local node runner script ($RUN_WITH_LOCAL_NODE_SCRIPT) not found or not executable."
    redMsg "Please ensure project setup (e.g., 'npm run waf') is complete."
    exit 1 # Exit if the runner script is missing
fi

purMsg "-------------------------Starting Firewalld-UI Shutdown Process-------------------------"

# --- Check PM2 availability ---
purMsg "-------------------------Checking PM2 Availability-------------------------"
if bash "$RUN_WITH_LOCAL_NODE_SCRIPT" npx --no-install pm2 -v > /dev/null 2>&1; then
    greMsg "PM2 is available via npx."
    PM2_AVAILABLE=true
else
    purMsg "PM2 does not seem to be installed or accessible via npx from the local Node environment."
    purMsg "PM2-related stop operations will be skipped."
    purMsg "You might need to run 'sh shell/startup.sh' or 'sh shell/pm2.sh' to install PM2."
    PM2_AVAILABLE=false
fi

# --- Stop PM2 Managed Frontend (HttpServer) ---
if [ "$PM2_AVAILABLE" = true ]; then
    purMsg "-------------------------Stopping PM2 Frontend (HttpServer)-------------------------"
    # Check if HttpServer is running before trying to stop/delete
    # Use --no-install to prevent npx from downloading pm2 if it's missing at this stage (though we checked above)
    if bash "$RUN_WITH_LOCAL_NODE_SCRIPT" npx --no-install pm2 describe HttpServer > /dev/null 2>&1; then
        greMsg "HttpServer is running. Attempting to stop and delete it via PM2..."
        if bash "$RUN_WITH_LOCAL_NODE_SCRIPT" npx --no-install pm2 delete HttpServer; then
            greMsg "HttpServer stopped and deleted successfully via PM2."
        else
            redMsg "Failed to stop/delete HttpServer via PM2. It might have already been stopped or an error occurred."
        fi
    else
        purMsg "HttpServer is not currently managed by PM2 or already stopped."
    fi
else
    purMsg "Skipping PM2 Frontend stop because PM2 is not available."
fi

# --- Stop Egg.js Backend (egg-server) ---
purMsg "-------------------------Stopping Egg.js Backend (egg-server)-------------------------"
# egg-scripts is a devDependency, run via run-with-local-node.sh which handles path to node_modules/.bin
greMsg "Attempting to stop Egg.js backend (egg-server)..."
# The --title must match what was used to start it. From package.json, it's "egg-server".
if bash "$RUN_WITH_LOCAL_NODE_SCRIPT" egg-scripts stop --title=egg-server; then
    greMsg "Egg.js backend (egg-server) stop command executed successfully."
    greMsg "Note: egg-scripts stop might not give explicit feedback if the server wasn't running."
else
    redMsg "Failed to execute Egg.js backend (egg-server) stop command."
    purMsg "This might be okay if the server was not running or was stopped by other means."
fi

# --- Stop firewalld-ui systemd service ---
purMsg "-------------------------Stopping firewalld-ui systemd service-------------------------"
if command -v systemctl &> /dev/null; then
    # Check if the service is active, enabled, or in a failed state
    SERVICE_EXISTS=$(sudo systemctl list-unit-files | grep -q firewalld-ui.service && echo "exists" || echo "not_exists")

    if [ "$SERVICE_EXISTS" = "exists" ]; then
        greMsg "Attempting to stop, disable, reset-failed, and mask firewalld-ui.service (requires sudo if not already root)..."
        
        # Attempt to stop the service
        if sudo systemctl is-active --quiet firewalld-ui.service; then
            if sudo systemctl stop firewalld-ui.service; then
                greMsg "firewalld-ui.service stopped successfully."
            else
                purMsg "firewalld-ui.service stop command issued. It might have already been stopped or failed to stop (status $?). Continuing."
            fi
        else
            purMsg "firewalld-ui.service was not active."
        fi
        
        greMsg "Waiting 2 seconds..."
        sleep 2

        # Attempt to disable the service
        if sudo systemctl is-enabled --quiet firewalld-ui.service; then
            if sudo systemctl disable firewalld-ui.service; then
                greMsg "firewalld-ui.service disabled successfully."
            else
                redMsg "Failed to disable firewalld-ui.service. Status: $? (This may require manual intervention if it keeps restarting)"
            fi
        else
            purMsg "firewalld-ui.service was not enabled."
        fi

        # Reload systemd daemon to apply changes like disable
        greMsg "Reloading systemd daemon..."
        if sudo systemctl daemon-reload; then
            greMsg "systemd daemon-reload successful."
        else
            redMsg "systemd daemon-reload failed. Status: $?"
        fi
        sleep 1

        # Attempt to mask the service
        greMsg "Attempting to mask firewalld-ui.service..."
        if sudo systemctl mask firewalld-ui.service; then
            greMsg "firewalld-ui.service masked successfully."
        else
            redMsg "Failed to mask firewalld-ui.service. Status: $? (This is a strong indicator of a problem if it fails)"
        fi

        # Attempt to reset the failed state of the service
        if sudo systemctl is-failed --quiet firewalld-ui.service; then
            if sudo systemctl reset-failed firewalld-ui.service; then
                greMsg "firewalld-ui.service reset-failed successfully."
            else
                purMsg "Failed to reset-failed firewalld-ui.service. Status: $? (This may not be an issue if the service wasn't in a failed state)."
            fi
        else
            purMsg "firewalld-ui.service was not in a failed state."
        fi

        greMsg "Waiting 3 seconds after systemd operations..."
        sleep 3
    else
        purMsg "firewalld-ui.service unit does not appear to exist. Skipping systemd operations."
    fi
else
    purMsg "systemctl command not found. Skipping systemd service operations."
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

# Define full paths for script patterns for specificity
# These paths are derived from the project structure and ps aux output
EGG_SCRIPTS_BIN_FULL_PATH="$DIR/node_modules/.bin/egg-scripts"
EGG_MASTER_SCRIPT_FULL_PATH="$DIR/node_modules/egg-scripts/lib/start-cluster.js" # As seen in ps aux for PID 15869
EGG_APP_WORKER_SCRIPT_FULL_PATH="$DIR/node_modules/egg-cluster/lib/app_worker.js" # As seen for PID 15876+
EGG_AGENT_WORKER_SCRIPT_FULL_PATH="$DIR/node_modules/egg-cluster/lib/agent_worker.js"
PM2_BIN_FULL_PATH="$DIR/node_modules/.bin/pm2"

KNOWN_PROCESS_PATTERNS=()

# 1. NPM script that starts everything (e.g., PID 15847 `npm run start:systemd`)
# pgrep -f "npm run start:systemd" should match if run from within $DIR or if $DIR is in its CWD path description
# Making it more specific by anchoring to $DIR if possible, or just the command.
# `ps aux` shows "npm run start:systemd" without full path context for npm itself, but it's likely run within $DIR.
KNOWN_PROCESS_PATTERNS+=("npm run start:systemd")

# 2. The egg-scripts start process (e.g., PID 15858), typically run by a generic 'node'
# Matches: node /usr/local/src/Firewalld-UI/node_modules/.bin/egg-scripts start ...
KNOWN_PROCESS_PATTERNS+=("node $EGG_SCRIPTS_BIN_FULL_PATH start")

# 3. The egg master process (e.g., PID 15869), typically run by a generic 'node'
# Matches: node --no-deprecation --trace-warnings /usr/local/src/Firewalld-UI/node_modules/egg-scripts/lib/start-cluster.js
# Using ".*" to account for node options like --no-deprecation or other arguments.
KNOWN_PROCESS_PATTERNS+=("node .*$EGG_MASTER_SCRIPT_FULL_PATH")

# Common names/titles that might appear in process list
KNOWN_PROCESS_PATTERNS+=("egg-server")      # Process title from --title=egg-server
KNOWN_PROCESS_PATTERNS+=("HttpServer")      # PM2 default name for frontend, if used
KNOWN_PROCESS_PATTERNS+=("firewalld-ui")    # systemd service name, if it appears directly in ps command lines

# Patterns for processes specifically run by the project's local NODE_EXECUTABLE (NODE_EXEC_PATTERN)
if [ -n "$NODE_EXEC_PATTERN" ]; then
    # 4. App workers (e.g., PID 15876+), which use the local NODE_EXECUTABLE
    KNOWN_PROCESS_PATTERNS+=("$NODE_EXEC_PATTERN .*$EGG_APP_WORKER_SCRIPT_FULL_PATH")
    # 5. Agent workers (if any), also using local NODE_EXECUTABLE
    KNOWN_PROCESS_PATTERNS+=("$NODE_EXEC_PATTERN .*$EGG_AGENT_WORKER_SCRIPT_FULL_PATH")
    # 9. Local PM2 if run by the local NODE_EXECUTABLE
    KNOWN_PROCESS_PATTERNS+=("$NODE_EXEC_PATTERN .*$PM2_BIN_FULL_PATH")
    # 10. Catch-all for any other process run by the specific local Node within the project directory
    KNOWN_PROCESS_PATTERNS+=("$NODE_EXEC_PATTERN .*$DIR")
fi

# 11. Fallback/general catch-all for ANY 'node' process running scripts from within the project directory.
# This is important if some processes are started with a generic 'node' and not caught by specific paths above,
# or if NODE_EXECUTABLE was not set. This pattern helps catch PIDs 15858 and 15869 if other patterns fail.
# Example: "node /some/other/script/in/Firewalld-UI/something.js"
KNOWN_PROCESS_PATTERNS+=("node .*$DIR")


for pattern in "${KNOWN_PROCESS_PATTERNS[@]}"; do
    if [ -z "$pattern" ]; then continue; fi # Skip empty patterns
    greMsg "Attempting to find and kill processes matching '$pattern' (requires sudo)..."
    
    # Use pgrep to find PIDs, then kill them. This is safer than `pkill -f` which might kill itself.
    PIDS_TO_KILL=$(pgrep -f "$pattern")
    
    if [ -n "$PIDS_TO_KILL" ]; then
        # Filter out the current script's PID ($$) and its parent's PID ($PPID might be sudo or shell)
        # to prevent accidental self-termination if patterns are too broad.
        # This is a basic filter; truly robust filtering can be complex.
        CURRENT_SCRIPT_PID=$$
        # Get parent PID, which could be the shell running the script or sudo
        # If sudo is used, $PPID inside script is the sudo command's PID.
        # The actual parent shell that invoked sudo is harder to get reliably from within.
        
        FILTERED_PIDS=""
        for pid_val in $PIDS_TO_KILL; do
            # Simple check: ensure we are not killing the script's own PID.
            # A more robust check would involve checking command lines of $pid_val.
            # For now, we rely on specific patterns not matching the script itself.
            # The main risk was `pkill -f "pattern"` matching its own `sudo pkill -f "pattern"` cmdline.
            # `pgrep` first, then `kill` largely mitigates this specific self-kill issue for `pkill`.
            
            # Check if the PID belongs to the pgrep command itself (can happen with very broad patterns)
            # or the current shell. This is a basic safeguard.
            pgrep_cmd_line=$(ps -o args= -p "$pid_val" 2>/dev/null)
            if [[ "$pgrep_cmd_line" == *"pgrep -f"* ]]; then
                purMsg "Skipping pgrep process $pid_val itself."
                continue
            fi
            if [ "$pid_val" -eq "$CURRENT_SCRIPT_PID" ]; then
                purMsg "Skipping current script PID $pid_val."
                continue
            fi

            FILTERED_PIDS="$FILTERED_PIDS $pid_val"
        done

        if [ -n "$FILTERED_PIDS" ]; then
            greMsg "Found PIDs for pattern '$pattern': $FILTERED_PIDS. Sending SIGKILL..."
            # Simpler and potentially more robust loop for space-separated PIDs
            for pid_to_kill_val in $FILTERED_PIDS; do # Relies on shell word splitting
                if [ -n "$pid_to_kill_val" ]; then # Ensure pid_val is not empty
                    greMsg "Attempting to kill PID: $pid_to_kill_val for pattern '$pattern'"
                    sudo kill -9 "$pid_to_kill_val"
                    # Brief pause to allow system to process kill, might help with rapid checks
                    # sleep 0.1 
                fi
            done
            greMsg "SIGKILL sent to PIDs for '$pattern'. Waiting 2s..."
            sleep 2
            # Verify
            if pgrep -f "$pattern" > /dev/null; then
                # Re-check, excluding the current pgrep from matching itself if pattern is too broad
                REMAINING_PIDS=$(pgrep -f "$pattern" | grep -v "^$$\$") # Basic attempt to exclude current pgrep
                if [ -n "$REMAINING_PIDS" ]; then
                    redMsg "Processes matching '$pattern' might still be running after pkill attempts: $REMAINING_PIDS"
                    ps -ef | grep -E "$pattern" | grep -v grep
                else
                    greMsg "Processes matching '$pattern' appear to be terminated."
                fi
            else
                greMsg "Processes matching '$pattern' appear to be terminated."
            fi
        else
            purMsg "No PIDs to kill for pattern '$pattern' after filtering (or none found initially)."
        fi
    else
        purMsg "No processes found matching '$pattern' via pgrep."
    fi
done

# --- Aggressive Last Resort: killall specific Node executable ---
purMsg "-------------------------Aggressive Last Resort Kill-------------------------"
if [ -n "$NODE_EXECUTABLE" ] && [ -x "$NODE_EXECUTABLE" ]; then
    # Check if any processes are still running using this specific node executable within the project directory
    # This is a safeguard to only run killall if our specific node processes are likely still there.
    # pgrep -f will match the full command line.
    if sudo pgrep -f "$NODE_EXECUTABLE .*$DIR" > /dev/null; then
        redMsg "Attempting aggressive killall for $NODE_EXECUTABLE processes related to the project."
        bluMsg "This will target all instances of $NODE_EXECUTABLE."
        bluMsg "If this breaks your terminal, it might be because a VS Code process or similar was also using this exact Node.js path (unlikely for system VS Code server but possible)."
        sudo killall -9 "$NODE_EXECUTABLE" # Corrected syntax: -9 is an option, then the process name/path
        greMsg "killall -9 \"$NODE_EXECUTABLE\" command issued. Waiting 3 seconds..."
        sleep 3
        # Final verification for this specific node executable
        if sudo pgrep -f "$NODE_EXECUTABLE .*$DIR" > /dev/null; then
            redMsg "Processes running with $NODE_EXECUTABLE within $DIR might STILL be running after killall."
            sudo ps aux | grep "$NODE_EXECUTABLE" | grep "$DIR" | grep -v grep
        else
            greMsg "Processes running with $NODE_EXECUTABLE within $DIR appear to be terminated after killall."
        fi
    else
        purMsg "No processes found running with $NODE_EXECUTABLE within $DIR. Skipping aggressive killall."
    fi
else
    purMsg "NODE_EXECUTABLE not defined or not executable. Skipping aggressive killall."
fi


greMsg "-------------------------Firewalld-UI Shutdown Process Completed-------------------------"
purMsg "Please verify that all related processes have been stopped."
purMsg "You can check with: ps aux | grep -E \"egg-server|HttpServer|firewalld-ui|node .*Firewalld-UI|egg-scripts|pm2\" | grep -v grep"
purMsg "And for listening ports: sudo lsof -i -P -n | grep LISTEN"

# Final terminal reset
if command -v tput &> /dev/null; then
    tput sgr0
else
    printf '\\033[0m'
fi

exit 0
