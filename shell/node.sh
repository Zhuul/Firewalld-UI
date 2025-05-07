#!/bin/bash

# Define output colors
redMsg() { echo -e "\\n\E[1;31m$*\033[0m\\n"; }
greMsg() { echo -e "\\n\E[1;32m$*\033[0m\\n"; }
bluMsg() { echo -e "\\n\033[5;34m$*\033[0m\\n"; }
purMsg() { echo -e "\\n\033[35m$*\033[0m\\n"; }

# DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd);

DIR=$(pwd)

read -r -p "Please install node first. Do you want to download node-v16.18.1-linux-x64? [y/n] " input
case $input in
    [yY][eE][sS]|[yY])
      rm -rf $DIR/shell/node/*
      wget https://nodejs.org/dist/v16.18.1/node-v16.18.1-linux-x64.tar.gz -P $DIR/shell/node/
            if [ $? -eq 0 ]; then
            RES=$(grep "$DIR/shell/node/node-v16.18.1-linux-x64/bin" /etc/profile)
            tar xvf $DIR/shell/node/node-v16.18.1-linux-x64.tar.gz -C $DIR/shell/node/
              if [ "$RES" = "" ];then
              chmod -R 777 /etc/profile
              echo >>/etc/profile
              echo export PATH=\$PATH:$DIR/sehll/node/node-v16.18.1-linux-x64/bin>>/etc/profile
              source /etc/profile
              ln -sf $DIR/shell/node/node-v16.18.1-linux-x64/bin/node /usr/local/bin/node
              ln -sf $DIR/shell/node/node-v16.18.1-linux-x64/bin/npm /usr/local/bin/npm

              sleep 3
              NODE=$(node -v)
              if [ $? -eq 0 ]; then
              greMsg "node installation successful"
              exit 0
              else
              redMsg "node installation failed"
              exit 1
              fi

              else
              ln -sf $DIR/shell/node/node-v16.18.1-linux-x64/bin/node /usr/local/bin/node
              ln -sf $DIR/shell/node/node-v16.18.1-linux-x64/bin/npm /usr/local/bin/npm

              sleep 3
              NODE=$(node -v)
              if [ $? -eq 0 ]; then
              greMsg "node installation successful"
              exit 0
              else
              redMsg "node installation failed"
              exit 1
              fi

              exit 0
              fi
            else
            redMsg "Download failed";
            exit 1
            fi
		;;
    [nN][oO]|[nN])
		echo "Please install manually. Recommended node version is >= v16.18.1"
		echo "To change the version, modify the link in $DIR/node.sh and replace occurrences of node-v16.18.1-linux-x64 in this file and pm2.sh"
        exit 1
       	;;
    *)
		echo "Please enter y/n"
		;;
    esac
