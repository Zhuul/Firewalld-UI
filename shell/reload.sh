#!/bin/bash

# Get the parent directory, project root directory
DIR=$(dirname $(dirname "$0"))

sleep 10

echo Executing the first time >/dev/null 1>>$DIR/shell/shell.log
sh $DIR/shell/startup.sh 1 >> $DIR/shell/shell.log
if [ $? -ne 0 ]; then
sleep 5
echo Executing the second time >/dev/null 1>>$DIR/shell/shell.log
sh $DIR/shell/startup.sh 2 >> $DIR/shell/shell.log
    if [ $? -ne 0 ]; then
    sleep 5
    cd $DIR
    npm run start:linux  >>$DIR/shell/shell.log
    sh $DIR/shell/startup.sh 3 >> $DIR/shell/shell.log
        if [ $? -ne 0 ]; then
        echo "reload third time successful">>$DIR/shell/shell.log
        else
        echo "reload third time failed">>$DIR/shell/shell.log
        fi
    else
    echo "reload second time successful">>$DIR/shell/shell.log
    fi
else
echo "reload first time successful">>$DIR/shell/shell.log
fi
