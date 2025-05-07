#!/bin/bash

# Define output colors
redMsg() { echo -e "\\n\E[1;31m$*\033[0m\\n"; }
greMsg() { echo -e "\\n\E[1;32m$*\033[0m\\n"; }
bluMsg() { echo -e "\\n\033[5;34m$*\033[0m\\n"; }
purMsg() { echo -e "\\n\033[35m$*\033[0m\\n"; }

# DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd);
# Get the current directory, not the code file directory, in startup.sh cd $(dirname $(pwd))
DIR=$(pwd)

# Check npm version
NPM_VERSION=$(npm -v)
REQUIRED_NPM_VERSION="7.0.0"

if [ "$(printf '%s\n' "$REQUIRED_NPM_VERSION" "$NPM_VERSION" | sort -V | head -n1)" != "$REQUIRED_NPM_VERSION" ]; then
  redMsg "Your npm version is outdated. Please update to npm $REQUIRED_NPM_VERSION or later."
  exit 1
fi

if [ ! -d "$DIR/node_modules/" ];then
redMsg "Detected that $DIR/node_modules does not exist"
redMsg "If the download fails, please delete $DIR/node_modules and $DIR/express/node_modules and try again"
read -r -p "Do you want to run npm install? Please ensure a smooth network connection (manual use of cnpm/yarn is recommended) ? [y/n] " input
case $input in
    [yY][eE][sS]|[yY])
        npm install
            if [ $? -ne 0 ]; then
            redMsg "Error downloading backend dependencies"
            exit 1
            else
            greMsg "Successfully downloaded backend dependencies";
            fi
        cd ./express
        if [ ! -d "$DIR/express/node_modules/" ];then
            npm install
                if [ $? -ne 0 ]; then
                redMsg "Error downloading frontend dependencies"
                exit 1
                else
                greMsg "Successfully downloaded frontend dependencies";
                exit 0
                fi
            cd ../
            exit 0
            else
            exit 0
        fi
		;;
    [nN][oO]|[nN])
		echo "Please download manually"
        exit 1
       	;;
    *)
		echo "Please enter y/n"
		exit 1
		;;
esac
fi
