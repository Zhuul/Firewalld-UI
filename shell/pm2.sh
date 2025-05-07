#!/bin/bash

redMsg() { echo -e "\\n\E[1;31m$*\033[0m\\n"; }
greMsg() { echo -e "\\n\E[1;32m$*\033[0m\\n"; }
bluMsg() { echo -e "\\n\033[5;34m$*\033[0m\\n"; }
purMsg() { echo -e "\\n\033[35m$*\033[0m\\n"; }

DIR=$(pwd)

read -r -p "Please install pm2 first. Do you want to install it? [y/n] " input
case $input in
    [yY][eE][sS]|[yY])
       npm install pm2 -g --registry=https://registry.npmmirror.com
            if [ $? -eq 0 ]; then
            greMsg "pm2 installation successful"
            NPM_GLOBAL_BIN=$(npm bin -g 2>/dev/null)
            if [ -n "$NPM_GLOBAL_BIN" ] && [ -x "$NPM_GLOBAL_BIN/pm2" ]; then
                echo "$NPM_GLOBAL_BIN/pm2" # Output the path to pm2
                exit 0
            else
                # Fallback if npm bin -g doesn't work or pm2 not found there
                # Try to find pm2 in common global paths
                if command -v pm2 &>/dev/null; then
                    PM2_PATH=$(command -v pm2)
                    echo "$PM2_PATH"
                    exit 0
                else
                    redMsg "Could not determine pm2 installation path after install."
                    exit 1
                fi
            fi
            else
            redMsg "pm2 installation failed"
            exit 1
            fi
		;;
    [nN][oO]|[nN])
		echo "Please install pm2 manually"
        exit 1
       	;;
    *)
		echo "Please enter y/n"
		;;
    esac
