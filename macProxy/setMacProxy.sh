#!/bin/bash
rpath=$(readlink ${BASH_SOURCE})
if [ -z "$rpath" ];then
    rpath=${BASH_SOURCE}
fi
root="$(cd $(dirname $rpath) && pwd)"
cd $root
user=${SUDO_USER:-$(whoami)}
home=$(eval echo ~$user)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
cyan=$(tput setaf 5)
reset=$(tput sgr0)
runAsRoot(){
    cmd="$@"
    if [ -z "$cmd" ];then
        echo "${red}Need cmd${reset}"
        exit 1
    fi

    if (($EUID==0));then
        sh -c "$cmd"
    else
        if ! command -v sudo >/dev/null 2>&1;then
            echo "Need sudo cmd"
            exit 1
        fi
        sudo sh -c "$cmd"
    fi
}
enX="$(route -n get 8.8.8.8 | perl -ne 'print $2 if /(interface:\s*)(\w+)/')"

cnw="$(networksetup -listnetworkserviceorder | grep $enX |perl -ne 'print $2 if /(Hardware Port: )([^,]+)/')"

host=localhost

defaultPacServerPort=28989
# defaultPacServerDirectory=$(pwd)
defaultPacfile=gfwlist.pac


msg(){
    echo "enX: $enX"
    echo  "cnw: $cnw"
    echo "host: $host"
}

usage(){
    cat<<-EOF
		Usage: $(basename $0) options

		options:
		http    <port>
		https   <port>
		socks   <port>

		pac     <upstream> [serverport]
		        defaultPacServerPort:           $defaultPacServerPort
		unset   [http | https | socks | pac] (empty for all)
	EOF
    exit 1
}

setHttpProxy(){
    port=${1:?'missing port'}
    msg
    networksetup -setwebproxy $cnw $host $port
}

setHttpsProxy(){
    port=${1:?'missing port'}
    msg
    networksetup -setsecurewebproxy $cnw $host $port
}


setSocksProxy(){
    port=${1:?'missing port'}
    msg
    networksetup -setsocksfirewallproxy $cnw $host $port
}

setPac(){
    pacServerHost=$host
    upstream=${1:?'missing upstream: for example localhost:1080'}
    pacServerPort=${2:-$defaultPacServerPort}
    if [ ! -d pacDirectory ];then
        mkdir pacDirectory
    fi
    sed -e "s|PACDIRECTORY|$root/pacDirectory|g" \
        -e "s|PYTHON|$(which python)|g" \
        -e "s|PORT|$pacServerPort|g" pacServer.plist > $home/Library/LaunchAgents/pacServer.plist

    sed -e "s|UPSTREAM|$upstream|g" gfwlist.pac > pacDirectory/proxy.pac

    cat<<-EOF
		pacServerHost: $pacServerHost
		pacServerPort: $pacServerPort
	EOF
    launchctl unload -w $home/Library/LaunchAgents/pacServer.plist 2>/dev/null
    launchctl load -w $home/Library/LaunchAgents/pacServer.plist
    networksetup -setautoproxyurl $cnw "http://$host:$pacServerPort/proxy.pac"
}

unsetHttpProxy(){
    networksetup -setwebproxystate $cnw off
}

unsetHttpsProxy(){
    networksetup -setsecurewebproxystate $cnw off
}

unsetSocksProxy(){
    networksetup -setsocksfirewallproxystate $cnw off
}

unsetPac(){
    launchctl unload -w $home/Library/LaunchAgents/pacServer.plist 2>/dev/null
    networksetup -setautoproxystate $cnw off
}

unset(){
    typ=${1}
    if [ -z "$typ" ];then
        unsetHttpProxy
        unsetHttpsProxy
        unsetSocksProxy
        unsetPac
        exit 0
    fi
    case "$typ" in
        http)
            unsetHttpProxy
            ;;
        https)
            unsetHttpsProxy
            ;;
        socks)
            unsetSocksProxy
            ;;
        pac)
            unsetPac
            ;;
        *)
            usage
            ;;

    esac
}

case $1 in
    http)
        port=$2
        setHttpProxy $port
        ;;
    https)
        port=$2
        setHttpsProxy $port
        ;;
    socks)
        port=$2
        setSocksProxy $port
        ;;
    pac)
        upstream=$2
        pacsrvport=$3
        setPac $upstream "$pacsrvport"
        ;;
    unset)
        unset "$2"
        ;;
    *)
        usage
        ;;
esac