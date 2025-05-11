#!/bin/bash

HTTP=$(grep "httpPort" ./express/config.js | grep -Eo '[0-9]{1,4}')
HTTPS=$(grep "httpsPort" ./express/config.js | grep -Eo '[0-9]{1,4]')
SERVER=$(grep "port" ./config/config.prod.js | grep -Eo '[0-9]{1,4}')

redMsg() { echo -e "\\n\E[1;31m$*\033[0m\\n"; }
greMsg() { echo -e "\\n\E[1;32m$*\033[0m\\n"; }
bluMsg() { echo -e "\\n\033[5;34m$*\033[0m\\n"; }
purMsg() { echo -e "\\n\033[35m$*\033[0m\\n"; }

HSERVERANP=$(netstat -anp |grep -w $SERVER)
if [[ -n "$HSERVERANP" ]];then
  purMsg $SERVER port is already in use
  purMsg "Use lsof -i:$SERVER or netstat -anp | grep -w $SERVER to view detailed information"
  purMsg "Use kill PID to terminate the process (PID is the process ID)"
fi
