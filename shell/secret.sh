#!/bin/bash
DIR=$(pwd)

# Define output colors 
redMsg() { echo -e "\\n\E[1;31m$*\033[0m\\n"; }
greMsg() { echo -e "\\n\E[1;32m$*\033[0m\\n"; }
bluMsg() { echo -e "\\n\033[5;34m$*\033[0m\\n"; }
purMsg() { echo -e "\\n\033[35m$*\033[0m\\n"; }

if [ ! -f "$DIR/secretKey/fingerprint/PRIVATE-KEY.txt" ];then
    redMsg "Fingerprint key not detected"
    redMsg "Cannot be generated normally, need to skip key detection, delete the line below key generation in the $DIR/shell/startup.sh script"
    redMsg "Generating fingerprint key"
    redMsg "Press Enter for all prompts"
    ssh-keygen -t rsa -b 2048 -f$DIR/secretKey/fingerprint/PRIVATE-KEY.txt
    openssl rsa -in $DIR/secretKey/fingerprint/PRIVATE-KEY.txt -pubout -outform PEM -out $DIR/secretKey/fingerprint/PUBLIC-KEY.txt
else
greMsg "Fingerprint key already exists"
fi

if [ ! -f "$DIR/secretKey/token/PRIVATE-KEY.txt" ];then
    redMsg "Token key not detected"
    redMsg "Cannot be generated normally, need to skip key detection, delete the line below key generation in the $DIR/shell/startup.sh script"
    redMsg "Generating token key"
    redMsg "Press Enter for all prompts"
    ssh-keygen -t rsa -b 2048 -f $DIR/secretKey/token/PRIVATE-KEY.txt
    openssl rsa -in $DIR/secretKey/token/PRIVATE-KEY.txt -pubout -outform PEM -out $DIR/secretKey/token/PUBLIC-KEY.txt
else
greMsg "Token key already exists"
fi
