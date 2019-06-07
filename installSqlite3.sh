#!/bin/bash
prefix=${1:-"/usr/local"}
echo "prefix: $prefix"
rpath="$(readlink $BASH_SOURCE)"
if [ -z "$rpath" ];then
    rpath=$BASH_SOURCE
fi
root="$(cd $(dirname $rpath) && pwd)"
cd "$root"

cp sqlite-autoconf-*.tar.gz /tmp
cd /tmp
tar xvf ./sqlite-autoconf-*.tar.gz
cd sqlite-autoconf*
./configure --prefix="$prefix"
make
sudo make install
