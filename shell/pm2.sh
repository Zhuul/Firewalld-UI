#!/bin/bash

redMsg() { echo -e "\\n\E[1;31m$*\033[0m\\n"; }
greMsg() { echo -e "\\n\E[1;32m$*\033[0m\\n"; }
bluMsg() { echo -e "\\n\033[5;34m$*\033[0m\\n"; }
purMsg() { echo -e "\\n\033[35m$*\033[0m\\n"; }

# This script assumes node.sh has run and correctly set up node and npm,
# potentially symlinking them to /usr/local/bin/ or adding them to /etc/profile.

# Get the directory where this script (pm2.sh) is located
SCRIPT_DIR_PM2="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Get the project root directory (assuming shell/ is one level down from root)
PROJECT_ROOT_DIR_PM2=$(dirname "$SCRIPT_DIR_PM2")
# Define the expected path to pm2 based on node.sh's installation pattern
# This needs the exact Node version string used in node.sh
# Let's try to get it from node.sh or make it a variable if node.sh is consistent
# For now, hardcoding based on your find output's version.
# Ideally, node.sh would export this or write it to a known file.
NODE_VERSION_FROM_NODE_SH="v22.1.0" # Ensure this matches node.sh
EXPECTED_PM2_PATH="${PROJECT_ROOT_DIR_PM2}/shell/node/node-${NODE_VERSION_FROM_NODE_SH}-linux-x64/bin/pm2"

# Function to find pm2, prioritizing the path relative to node.sh's install
find_pm2_executable() {
    purMsg "Attempting to find pm2 executable..."
    purMsg "1. Checking EXPECTED_PM2_PATH: $EXPECTED_PM2_PATH"
    if [ -f "$EXPECTED_PM2_PATH" ]; then # Check if file exists first
        purMsg "File exists at EXPECTED_PM2_PATH."
        if [ -x "$EXPECTED_PM2_PATH" ]; then # Then check if executable
            purMsg "File is executable. Using EXPECTED_PM2_PATH."
            echo "$EXPECTED_PM2_PATH"
            return 0
        else
            redMsg "File exists at EXPECTED_PM2_PATH but is NOT executable. Check permissions."
            ls -l "$EXPECTED_PM2_PATH" # Show permissions
        fi
    else
        redMsg "File does NOT exist at EXPECTED_PM2_PATH."
    fi

    purMsg "2. Checking command -v pm2"
    if command -v pm2 &>/dev/null; then
        PM2_CMD_V_PATH=$(command -v pm2)
        purMsg "command -v pm2 found: $PM2_CMD_V_PATH"
        if [ -x "$PM2_CMD_V_PATH" ]; then
            purMsg "Using command -v pm2 path."
            echo "$PM2_CMD_V_PATH"
            return 0
        else
            redMsg "command -v pm2 found path $PM2_CMD_V_PATH but it's NOT executable."
            ls -l "$PM2_CMD_V_PATH"
        fi
    else
        redMsg "command -v pm2 did NOT find pm2 in PATH."
    fi

    purMsg "3. Checking npm prefix -g path"
    NPM_PREFIX_PATH=$(npm prefix -g 2>/dev/null)
    if [ -n "$NPM_PREFIX_PATH" ]; then
        NPM_GLOBAL_PM2_PATH="${NPM_PREFIX_PATH}/bin/pm2"
        purMsg "npm prefix -g is: $NPM_PREFIX_PATH. Checking for pm2 at: $NPM_GLOBAL_PM2_PATH"
        if [ -f "$NPM_GLOBAL_PM2_PATH" ]; then
            purMsg "File exists at npm global pm2 path."
            if [ -x "$NPM_GLOBAL_PM2_PATH" ]; then
                purMsg "Using npm global pm2 path."
                echo "$NPM_GLOBAL_PM2_PATH"
                return 0
            else
                redMsg "File exists at npm global pm2 path but is NOT executable."
                ls -l "$NPM_GLOBAL_PM2_PATH"
            fi
        else
            redMsg "File does NOT exist at npm global pm2 path: $NPM_GLOBAL_PM2_PATH"
        fi
    else
        redMsg "npm prefix -g did not return a path."
    fi
    
    redMsg "find_pm2_executable: Could not find pm2."
    return 1
}

read -r -p "pm2 not detected or not in PATH. Do you want to attempt to install it globally? [y/n] " input
case $input in
    [yY][eE][sS]|[yY])
       purMsg "Attempting to install pm2 globally using npm (this will use the Node.js managed by node.sh)..."
       # Assuming /usr/local/bin/npm is the one from node.sh
       # If node.sh symlinks npm to /usr/local/bin/npm, this should work as intended.
       if ! command -v npm &>/dev/null; then
           redMsg "npm command not found. Please ensure node.sh ran successfully and npm is in PATH."
           exit 1
       fi

       npm install pm2 -g --registry=https://registry.npmmirror.com
       INSTALL_STATUS=$?

       if [ $INSTALL_STATUS -eq 0 ]; then
            greMsg "npm install pm2 -g command finished."
            # Try to find pm2 again after installation
            PM2_EXECUTABLE=$(find_pm2_executable)
            if [ -n "$PM2_EXECUTABLE" ]; then
                greMsg "pm2 found at: $PM2_EXECUTABLE"
                echo "$PM2_EXECUTABLE" # Output the path to pm2
                exit 0
            else
                redMsg "pm2 installed, but could not determine its executable path automatically."
                redMsg "Expected path: $EXPECTED_PM2_PATH"
                redMsg "Please ensure the directory containing pm2 is in your PATH or symlinked correctly by node.sh."
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
