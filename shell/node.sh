#!/bin/bash

# Define output colors
redMsg() { echo -e "\n\E[1;31m$*\033[0m\n" >&2; }
purMsg() { echo -e "\n\033[35m$*\033[0m\n" >&2; }

purMsg "DEPRECATED: The shell/node.sh script is no longer used for Node.js installation."
purMsg "Node.js is now managed by the scripts in the 'scripts' directory (ensure-local-node.sh and run-with-local-node.sh),"
purMsg "and is typically set up by running 'npm run waf' from the project root."
redMsg "If this script was called, please update the calling script to reflect the new Node.js management approach."
# Exit with a success code as it's a no-op, but the message indicates deprecation.
# If it's critical that this script is not called, consider 'exit 1' after ensuring all callers are updated.
exit 0
