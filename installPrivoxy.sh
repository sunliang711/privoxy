#!/bin/bash
rpath="$(readlink $BASH_SOURCE)"
if [ -z "$rpath" ];then
    rpath=$BASH_SOURCE
fi
me="$(cd $(dirname $rpath) && pwd)"
cd "$me"

user=${SUDO_USER:-$(whoami)}
echo "installPrivoxyFromSource()"
if ! command -v autoconf >/dev/null 2>&1;then
    echo "Need autoconf!"
    exit 1
fi

cp privoxy-3.0.24*tar.gz /tmp
# curl -LO https://svwh.dl.sourceforge.net/project/ijbswa/Sources/3.0.24%20%28stable%29/privoxy-3.0.24-stable-src.tar.gz
cd /tmp
tar xvf privoxy-3.0*
cd privoxy-3.0*
autoheader
autoconf
./configure
make
#MacOS needed
sudo make install  USER=${user} GROUP=staff
sudo ln -sf /usr/local/sbin/privoxy /usr/local/bin
