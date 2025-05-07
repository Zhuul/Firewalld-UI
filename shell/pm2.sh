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
            ln -sf $DIR/shell/node/node-v16.18.1-linux-x64/bin/pm2 /usr/local/bin
            greMsg "pm2 installation successful"
            exit 0
            else
            redMsg "pm2 installation failed";
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
