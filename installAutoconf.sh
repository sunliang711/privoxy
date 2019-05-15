#!/bin/bash
root="$(cd $(dirname ${BASH_SOURCE}) && pwd)"
cd "$root"

echo "installAutoconf()"
# curl -O -L http://ftpmirror.gnu.org/autoconf/autoconf-2.69.tar.gz
cp autoconf-2.69.tar.gz /tmp
cd /tmp
tar xvf autoconf-2.69*
cd autoconf-2.69*
./configure
make
sudo make install
