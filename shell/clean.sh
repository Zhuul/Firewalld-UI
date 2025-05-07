#!/bin/bash
DIR=$(dirname $(dirname "$0"))

echo --------------------Scheduled task executing database cleanup $(date +%F%n%T)-------------------->>$DIR/shell/shell.log
sqlite3 $DIR/database/sqlite-prod.db 'VACUUM;'>>$DIR/shell/shell.log
sqlite3 $DIR/database/sqlite-local.db 'VACUUM;'>>$DIR/shell/shell.log
sqlite3 $DIR/database/sqlite-default.db 'VACUUM;'>>$DIR/shell/shell.log

echo --------------------Scheduled task executing log cleanup $(date +%F%n%T)-------------------->>$DIR/shell/shell.log
rm -rf $DIR/logs/*

rm -rf $DIR/shell/shell.log

sh $DIR/shell/reload.sh>>$DIR/shell/shell.log

# Database cleanup commands
# Clean all data in the accesss table (will not delete the table, only delete all data inside)
# In the root directory /database directory
# sqlite3 ./sqlite-prod.db "DELETE FROM accesss;"
# sqlite3 ./sqlite-prod.db 'VACUUM;'

# Root directory
# sqlite3 ./database/sqlite-prod.db 'SELECT secret FROM users WHERE username = "your username";'
# grep secret ./config.json | head -n 1
