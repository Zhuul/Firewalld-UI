#!/bin/bash

# First give the script execution permissions, execute chmod -R 777 ./startup.sh in the project root directory

# Get the parent directory, project root directory
DIR=$(dirname $(dirname "$0"))

cd $DIR

chmod -R 777 $DIR/shell/http.sh
chmod -R 777 $DIR/shell/https.sh
chmod -R 777 $DIR/shell/modules.sh
chmod -R 777 $DIR/shell/node.sh
chmod -R 777 $DIR/shell/pm2.sh
chmod -R 777 $DIR/shell/server.sh
chmod -R 777 $DIR/shell/reload.sh
chmod -R 777 $DIR/shell/clean.sh
chmod -R 777 $DIR/shell/secret.sh

# Define output colors 
redMsg() { echo -e "\\n\E[1;31m$*\033[0m\\n"; }
greMsg() { echo -e "\\n\E[1;32m$*\033[0m\\n"; }
bluMsg() { echo -e "\\n\033[5;34m$*\033[0m\\n"; }
purMsg() { echo -e "\\n\033[35m$*\033[0m\\n"; }

HTTP=$(grep "httpPort" $DIR/express/config.js | grep -Eo '[0-9]{1,4}')
HTTPS=$(grep "httpsPort" $DIR/express/config.js | grep -Eo '[0-9]{1,4}')
SERVER=$(grep "port" $DIR/config/config.prod.js | grep -Eo '[0-9]{1,4}')

greMsg -------------------------Startup process begins $(date +%F%n%T)------------------------- 

echo -------------------------Port Information-------------------------

if [ ! $HTTP ]; then
redMsg Front-end port HTTP does not exist
else
bluMsg Front-end port HTTP: $HTTP
sh ./shell/http.sh
fi

if [ ! $HTTPS ]; then  
redMsg Front-end port HTTPS does not exist 
else
bluMsg Front-end port HTTPS: $HTTPS
sh ./shell/https.sh
fi

if [ ! $SERVER ]; then
redMsg Back-end port does not exist 
else
bluMsg Back-end port: $SERVER
sh ./shell/server.sh
fi

sleep 3

# Delete below to skip key detection
echo -------------------------Key Generation-------------------------
sh $DIR/shell/secret.sh
# Delete above to skip key detection

echo -------------------------Environment Detection-------------------------

NODEFILES=$(dirname $(pwd))
# Check if node is installed
NODE=$(node -v)
if [ $? -ne 0 ]; then
    redMsg "Please install node first and try again"
    redMsg "Note: Each time node is installed, the $NODEFILES/shell/node directory will be deleted"
    sh ./shell/node.sh
    if [ $? -eq 1 ]; then
    exit 1
fi
else
greMsg "node is installed Version: $NODE Recommended node version is >= v16.18.1"
fi

sleep 3

# Check if pm2 is installed
PM=$(pm2 -v)
if [ $? -ne 0 ]; then
    redMsg "Please install pm2 first and try again"
    sh ./shell/pm2.sh
    if [ $? -eq 1 ]; then
    exit 1
    fi
else
    PMV=$(pm2 -v)
    greMsg "pm2 is installed Version: $PMV"
fi

FIRE=$(firewall-cmd -V)
if [ $? -ne 0 ]; then
redMsg "Please install firewalld firewall first and try again"
exit 1
else
greMsg "firewalld is installed Version: $FIRE"
fi

# Check if tcpkill is installed
which dsniff >/dev/null
if [ $? -ne 0 ]; then
    redMsg "It is recommended to install dsniff (does not affect usage)"
else
greMsg "tcpkill is installed"
fi

FIRE=$(firewall-cmd -V)
if [ $? -ne 0 ]; then
redMsg "Please install firewalld firewall first and try again"
exit 1
else
greMsg "firewalld is installed Version: $FIRE"
fi

# Check passed

cd $DIR

# Check if node_modules exists
sh ./shell/modules.sh
if [ $? -ne 0 ]; then
redMsg "Please download front-end and back-end dependencies and try again, front-end: $DIR/express back-end: $DIR"
exit 1
else
greMsg "Front-end and back-end dependencies have been downloaded";
fi
# Check if node_modules exists

# --- Add new systemd service setup ---
purMsg "-------------------------Setting up systemd service-------------------------"
PROJECT_INSTALL_DIR="$DIR" 
SERVICE_FILE_SOURCE="$(dirname "$0")/firewalld-ui.service" 
SERVICE_FILE_DEST="/etc/systemd/system/firewalld-ui.service"
TEMP_SERVICE_FILE="/tmp/firewalld-ui.service.$$"

if [ ! -f "$SERVICE_FILE_SOURCE" ]; then
    redMsg "ERROR: Service file template not found at $SERVICE_FILE_SOURCE"
    exit 1
fi

purMsg "Customizing service file template from $SERVICE_FILE_SOURCE..."
# Replace placeholder for WorkingDirectory. The template uses /workspaces/Firewalld-UI
sed "s|WorkingDirectory=/workspaces/Firewalld-UI|WorkingDirectory=${PROJECT_INSTALL_DIR}|g" "$SERVICE_FILE_SOURCE" > "$TEMP_SERVICE_FILE"
if [ $? -ne 0 ]; then
    redMsg "ERROR: Failed to customize WorkingDirectory in service file template using sed."
    rm -f "$TEMP_SERVICE_FILE"
    exit 1
fi

# Replace placeholder for PIDFile. The template uses %H/run/egg-server.pid
sed -i "s|PIDFile=%H/run/egg-server.pid|PIDFile=${PROJECT_INSTALL_DIR}/run/egg-server.pid|g" "$TEMP_SERVICE_FILE"
if [ $? -ne 0 ]; then
    redMsg "ERROR: Failed to customize PIDFile in service file template using sed."
    rm -f "$TEMP_SERVICE_FILE"
    exit 1
fi

purMsg "Installing systemd service file to $SERVICE_FILE_DEST..."
cp "$TEMP_SERVICE_FILE" "$SERVICE_FILE_DEST"
CP_STATUS=$?
rm -f "$TEMP_SERVICE_FILE" # Clean up temp file

if [ $CP_STATUS -eq 0 ]; then
    greMsg "Service file successfully copied to $SERVICE_FILE_DEST."
    chmod 644 "$SERVICE_FILE_DEST"
    
    purMsg "Reloading systemd daemon..."
    systemctl daemon-reload
    if [ $? -ne 0 ]; then
        redMsg "Warning: systemctl daemon-reload failed. Proceeding, but manual check might be needed."
    fi
    
    purMsg "Enabling firewalld-ui service to start on boot..."
    systemctl enable firewalld-ui.service
    if [ $? -ne 0 ]; then
        redMsg "Warning: systemctl enable firewalld-ui.service failed. Service may not start on boot."
    fi
    
    purMsg "Attempting to start/restart firewalld-ui service..."
    systemctl restart firewalld-ui.service
    if [ $? -ne 0 ]; then
        redMsg "ERROR: systemctl restart firewalld-ui.service failed."
        redMsg "Check service status with: systemctl status firewalld-ui.service"
        redMsg "And logs with: journalctl -u firewalld-ui.service"
        # Consider if this should be a fatal error (exit 1)
    else
        greMsg "Service firewalld-ui setup complete. The service should now be managed by systemd."
    fi
else
    redMsg "ERROR: Failed to copy customized service file to $SERVICE_FILE_DEST."
    exit 1 
fi
purMsg "-------------------------Systemd service setup finished-------------------------"

# Start front-end and back-end services
cd $DIR
purMsg "Entering root directory $DIR"

if [ ! -f "./express/express-linux" ];then
redMsg "Front-end directory or executable does not exist"
exit 1
fi

purMsg "Entering front-end directory $DIR/express"
cd ./express
# chmod -R 777
purMsg "Modifying front-end execution permissions, executing command chmod -R 777 express-linux"
chmod -R 777 express-linux

if [ $? -ne 0 ]; then
redMsg "Front-end directory or executable does not exist"
exit 1
fi

sleep 5

echo -------------------------Official Start-------------------------

purMsg "Returning to root directory $DIR to start service"
cd ../

echo -e >/dev/null 1>>$DIR/shell/shell.log
echo -e ------------------------- $(date +%F%n%T) >/dev/null 1>>$DIR/shell/shell.log -------------------------

purMsg "Startup log stored in $DIR/shell.log"

if [[ $1 -eq 2 ]];then
    echo Executing reload >>$DIR/shell/shell.log
else 
    npm run stop:linux >/dev/null 1>>$DIR/shell/shell.log
    if [ $? -ne 0 ]; then
    redMsg "npm run stop:linux command execution error Possible reasons: 1: Incomplete environment 2: Already started 3: Port occupied"
    exit 1
    else
    greMsg "Checking if the service has been successfully started before";
    fi
fi

# #If pm2 is not installed, run npm run start:linux:index
npm run start:linux >/dev/null 1>>$DIR/shell/shell.log
cd ./express
pm2 start express-linux --name=HttpServer --exp-backoff-restart-delay=1000
cd ../

if [ $? -ne 0 ]; then
redMsg "Service startup failed"
redMsg "npm run start:linux command execution error Possible reasons: 1: Incomplete environment 2: Already started 3: Port occupied"
redMsg "Use lsof -i:port number to view the occupying process"
redMsg "Use kill PID to terminate the process (PID is the process number)"
exit 1
else
greMsg "Service started successfully";
bluMsg "Front-end HTTP: Local IP:$HTTP"
bluMsg "Front-end HTTPS: Local IP:$HTTPS (If HTTPS is not deployed, please access HTTP)"
bluMsg "Back-end: Local IP:$SERVER"
fi

greMsg -------------------------Startup process ends $(date +%F%n%T)-------------------------
echo -e \ >/dev/null 1>>$DIR/shell/shell.log
echo -e ------------------------- $(date +%F%n%T) >/dev/null 1>>$DIR/shell/shell.log -------------------------

exit 0
