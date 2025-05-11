#!/bin/bash

HTTP=$(grep "httpPort" ./express/config.js | grep -Eo '[0-9]{1,4}')
HTTPS=$(grep "httpsPort" ./express/config.js | grep -Eo '[0-9]{1,4}')
SERVER=$(grep "port" ./config/config.prod.js | grep -Eo '[0-9]{1,4}')

redMsg() { echo -e "\\n\E[1;31m$*\033[0m\\n"; }
greMsg() { echo -e "\\n\E[1;32m$*\033[0m\\n"; }
bluMsg() { echo -e "\\n\033[5;34m$*\033[0m\\n"; }
purMsg() { echo -e "\\n\033[35m$*\033[0m\\n"; }

HTTPCHECK=$(firewall-cmd --query-port=$HTTP/tcp)

HTTPANP=$(netstat -anp |grep -w $HTTP)
if [[ -n "$HTTPANP" ]];then
  purMsg $HTTP port is already in use
  purMsg "Use lsof -i:$HTTP or netstat -anp | grep -w $HTTP to view detailed information"
  purMsg "Use kill PID to terminate the process (PID is the process ID)"
fi

if [ $HTTPCHECK = "yes" ];then
bluMsg Firewall has opened the front-end HTTP port $HTTP
else 
redMsg Firewall has not opened the front-end HTTP port $HTTP. Cloud servers need to be opened in the console as well.

read -r -p "Do you want to open port $HTTP? [y/n] " input
case $input in
    [yY][eE][sS]|[yY])
       firewall-cmd --permanent --add-port=$HTTP/tcp
            if [ $? -eq 0 ]; then
            firewall-cmd --reload
            greMsg "Successfully opened port $HTTP"
            else
            redMsg "Failed to open port $HTTP";
            fi
		;;
    [nN][oO]|[nN])
		echo "Please manually open port $HTTP. To skip the check, delete the line sh ./http.sh in the startup.sh script."
       	;;
    *)
		echo "Please enter y/n"
		;;
    esac
fi

