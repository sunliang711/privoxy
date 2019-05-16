#!/bin/bash
id=${1:?'missing id'}
db="$(cat db)"
# the following line comes from install.sh
# sqlite3 "$db" "CREATE TABLE config(id integer primary key autoincrement,name varchar,local_port int unique,upstream varchar,logdir varchar,ispac int);"
sqliteCommand="select name,local_port,upstream,logdir,ispac from config where id=$id;"
# for DEBUG
# echo "sqliteCommand: $sqliteCommand" 1>&2
record=$(sqlite3 $db "$sqliteCommand")
if [ -z "$record" ];then
    echo "No config record with id: $id" 1>&2
    exit 1
fi
# for DEBUG
# echo "record: $record" 1>&2
echo "$record"