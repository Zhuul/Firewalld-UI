#!/bin/bash

redMsg() { echo -e "\\n\E[1;31m$*\033[0m\\n"; }
greMsg() { echo -e "\\n\E[1;32m$*\033[0m\\n"; }
bluMsg() { echo -e "\\n\033[5;34m$*\033[0m\\n"; }
purMsg() { echo -e "\\n\033[35m$*\033[0m\\n"; }

SCRIPT_DIR_PM2="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT_DIR_PM2=$(dirname "$SCRIPT_DIR_PM2")
NODE_VERSION_FROM_NODE_SH="v22.1.0" # Ensure this matches node.sh
# EXPECTED_PM2_INSTALL_PATH="${PROJECT_ROOT_DIR_PM2}/shell/node/node-${NODE_VERSION_FROM_NODE_SH}-linux-x64/bin/pm2"
EXPECTED_PM2_INSTALL_PATH="/usr/local/src/Firewalld-UI/shell/node/node-v22.1.0-linux-x64/lib/node_modules/pm2/bin/pm2"
find_pm2_executable_after_install() {
    purMsg "Attempting to find pm2 executable after install..."

    purMsg "1. Checking EXPECTED_PM2_INSTALL_PATH: $EXPECTED_PM2_INSTALL_PATH"
    if [ -f "$EXPECTED_PM2_INSTALL_PATH" ]; then
        purMsg "File exists at EXPECTED_PM2_INSTALL_PATH."
        if [ ! -x "$EXPECTED_PM2_INSTALL_PATH" ]; then
            purMsg "Attempting to make $EXPECTED_PM2_INSTALL_PATH executable..."
            chmod +x "$EXPECTED_PM2_INSTALL_PATH"
            if [ $? -ne 0 ]; then
                redMsg "Failed to chmod +x $EXPECTED_PM2_INSTALL_PATH"
            fi
        fi
        if [ -x "$EXPECTED_PM2_INSTALL_PATH" ]; then
            purMsg "Using EXPECTED_PM2_INSTALL_PATH: $EXPECTED_PM2_INSTALL_PATH"
            echo "$EXPECTED_PM2_INSTALL_PATH"
            return 0
        else
            redMsg "File at $EXPECTED_PM2_INSTALL_PATH is still not executable."
            ls -l "$EXPECTED_PM2_INSTALL_PATH"
        fi
    else
        redMsg "File does NOT exist at EXPECTED_PM2_INSTALL_PATH."
    fi

    USR_LOCAL_BIN_PM2="/usr/local/bin/pm2"
    purMsg "2. Checking standard symlink/global path: $USR_LOCAL_BIN_PM2"
    if [ -x "$USR_LOCAL_BIN_PM2" ]; then
        purMsg "Using $USR_LOCAL_BIN_PM2"
        echo "$USR_LOCAL_BIN_PM2"
        return 0
    else
        purMsg "$USR_LOCAL_BIN_PM2 not found or not executable."
        if [ -f "$USR_LOCAL_BIN_PM2" ]; then ls -l "$USR_LOCAL_BIN_PM2"; fi
    fi
    
    purMsg "3. Checking command -v pm2"
    if command -v pm2 &>/dev/null; then
        PM2_CMD_V_PATH=$(command -v pm2)
        purMsg "command -v pm2 found: $PM2_CMD_V_PATH"
        if [ -x "$PM2_CMD_V_PATH" ]; then
            purMsg "Using command -v pm2 path: $PM2_CMD_V_PATH"
            echo "$PM2_CMD_V_PATH"
            return 0
        else
            redMsg "Path from command -v pm2 ($PM2_CMD_V_PATH) is not executable."
            ls -l "$PM2_CMD_V_PATH"
        fi
    else
        redMsg "command -v pm2 did NOT find pm2 in PATH."
    fi

    purMsg "4. Checking npm prefix -g path"
    NPM_EXEC_PATH=$(command -v npm)
    purMsg "Using npm at: $NPM_EXEC_PATH"
    NPM_PREFIX_PATH=$($NPM_EXEC_PATH prefix -g 2>/dev/null)
    if [ -n "$NPM_PREFIX_PATH" ]; then
        NPM_GLOBAL_PM2_PATH="${NPM_PREFIX_PATH}/bin/pm2"
        purMsg "npm prefix -g is: $NPM_PREFIX_PATH. Checking for pm2 at: $NPM_GLOBAL_PM2_PATH"
        if [ -f "$NPM_GLOBAL_PM2_PATH" ]; then
            purMsg "File exists at npm global pm2 path."
            if [ ! -x "$NPM_GLOBAL_PM2_PATH" ]; then
                purMsg "Attempting to make $NPM_GLOBAL_PM2_PATH executable..."
                chmod +x "$NPM_GLOBAL_PM2_PATH"
            fi
            if [ -x "$NPM_GLOBAL_PM2_PATH" ]; then
                purMsg "Using npm global pm2 path: $NPM_GLOBAL_PM2_PATH"
                echo "$NPM_GLOBAL_PM2_PATH"
                return 0
            else
                redMsg "File at $NPM_GLOBAL_PM2_PATH is still not executable."
                ls -l "$NPM_GLOBAL_PM2_PATH"
            fi
        else
            redMsg "File does NOT exist at npm global pm2 path: $NPM_GLOBAL_PM2_PATH"
        fi
    else
        redMsg "npm prefix -g did not return a path using $NPM_EXEC_PATH."
    fi
    
    redMsg "find_pm2_executable_after_install: Could not find a working pm2 executable."
    return 1
}

read -r -p "pm2 not detected or not in PATH. Do you want to attempt to install it globally? [y/n] " input
case $input in
    [yY][eE][sS]|[yY])
       purMsg "Attempting to install pm2 globally using npm..."
       NPM_TO_USE=$(command -v npm)
       if [ -z "$NPM_TO_USE" ] || ! [ -x "$NPM_TO_USE" ]; then
           redMsg "npm command not found or not executable. Please ensure node.sh ran successfully."
           if [ -x "/usr/local/bin/npm" ]; then
               NPM_TO_USE="/usr/local/bin/npm"
               purMsg "Using fallback npm path: $NPM_TO_USE"
           else
               exit 1
           fi
       fi
       purMsg "Using npm: $NPM_TO_USE for pm2 installation."

       "$NPM_TO_USE" install pm2 -g --registry=https://registry.npmmirror.com
       INSTALL_STATUS=$?

       if [ $INSTALL_STATUS -eq 0 ]; then
            greMsg "npm install pm2 -g command finished."
            PM2_EXECUTABLE_OUTPUT=$(find_pm2_executable_after_install)
            FIND_STATUS=$?

            if [ $FIND_STATUS -eq 0 ] && [ -n "$PM2_EXECUTABLE_OUTPUT" ]; then
                greMsg "pm2 found at: $PM2_EXECUTABLE_OUTPUT"
                echo "$PM2_EXECUTABLE_OUTPUT"
                exit 0
            else
                redMsg "pm2 installed, but find_pm2_executable_after_install could not determine its path or it's not executable."
                exit 1
            fi
       else
            redMsg "npm install pm2 -g failed with status $INSTALL_STATUS."
            exit 1
       fi
        ;;
    [nN][oO]|[nN])
        purMsg "Skipping pm2 installation. Please install pm2 manually and ensure it's in your PATH."
        exit 1
           ;;
    *)
        redMsg "Invalid input. Please enter y/n."
        exit 1
        ;;
esac
