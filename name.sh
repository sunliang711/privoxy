#!/bin/bash
rpath="$(readlink $BASH_SOURCE)"
if [ -z "$rpath" ];then
    rpath=$BASH_SOURCE
fi
root="$(cd $(dirname $rpath) && pwd)"
cd "$root"

id=${1:?'missing id'}
record="$(bash queryById.sh $id)"
if [ -z $record ];then
    echo "no record with id: $id" 1>&2
    exit 1
fi

echo "privoxy-$id"