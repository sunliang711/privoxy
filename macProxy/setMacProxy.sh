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
pacfile=gfwlist.pac


msg(){
    echo "enX: $enX"
    echo  "cnw: $cnw"
    echo "host: $host"
}

usage(){
    cat<<-EOF
	Usage: $(basename $0) CMD

		CMD:
		    http    <port>
		    https   <port>
		    socks   <port>

		    pac     [upstream:default: localhost:1080] [protocol: default: SOCKS5] [serverport]
		    unset   [http | https | socks | pac] (empty for all)

		    editPac
		    list|status

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
    upstream=${1:-"localhost:1080"}
    protocol=${2:-"SOCKS5"}
    pacServerPort=${3:-$defaultPacServerPort}
    if [ ! -d pacDirectory ];then
        mkdir pacDirectory
    fi
    sed -e "s|PACDIRECTORY|$root/pacDirectory|g" \
        -e "s|PYTHON|$(which python)|g" \
        -e "s|PORT|$pacServerPort|g" pacServer.plist > $home/Library/LaunchAgents/pacServer.plist

    sed -e "s|UPSTREAM|$upstream|g" \
        -e "s|PROTOCOL|$protocol|g" \
        $pacfile > pacDirectory/proxy.pac

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

editPac(){
    editor=vi
    if command -v vim >/dev/null 2>&1;then
        editor=vim
    fi
    oldmd5sum="$(python ../md5.py $pacfile)"
    $editor $pacfile
    newmd5sum="$(python ../md5.py $pacfile)"

    if [ "$oldmd5sum" != "$newmd5sum" ];then
        echo "Pac file changed."
        echo "Restart pac server if needed."
    else
        echo "Pac file not change."
    fi

}

list(){
    autoproxyurl="$(networksetup -getautoproxyurl $cnw)"
    webproxy="$(networksetup -getwebproxy $cnw)"
    securewebproxy="$(networksetup -getsecurewebproxy $cnw)"
    socksproxy="$(networksetup -getsocksfirewallproxy $cnw)"

    if  echo "$autoproxyurl"| grep '^Enabled:' | grep -iq 'Yes';then
        url="$(networksetup -getautoproxyurl $cnw | perl -ne 'print $2 if /(URL:\s*)(.+)/')"
        printf "Pac enabled at url: $green$url$reset\n"
    else
        printf "Pac disabled.\n"
    fi

    if echo "$webproxy" | grep '^Enabled:' | grep -iq 'Yes';then
        server="$(networksetup -getwebproxy $cnw | grep Server | perl -ne 'print $2 if /(Server:\s*)(.+)/')"
        port="$(networksetup -getwebproxy $cnw | grep Port| perl -ne 'print $2 if /(Port:\s*)(.+)/')"
        printf "Http proxy enabled at $green$server:$port$reset.\n"
    else
        printf "Http proxy disabled.\n"
    fi

    if echo "$securewebproxy" | grep '^Enabled:' | grep -iq 'Yes';then
        server="$(networksetup -getsecurewebproxy $cnw | grep Server | perl -ne 'print $2 if /(Server:\s*)(.+)/')"
        port="$(networksetup -getsecurewebproxy $cnw | grep Port| perl -ne 'print $2 if /(Port:\s*)(.+)/')"
        printf "Https proxy enabled at $green$server:$port$reset.\n"
    else
        printf "Https proxy disabled.\n"
    fi

    if echo "$socksproxy" | grep '^Enabled:' | grep -iq 'Yes';then
        server="$(networksetup -getsocksfirewallproxy $cnw | grep Server | perl -ne 'print $2 if /(Server:\s*)(.+)/')"
        port="$(networksetup -getsocksfirewallproxy $cnw | grep Port| perl -ne 'print $2 if /(Port:\s*)(.+)/')"
        printf "socks proxy enabled at $green$server:$port$reset.\n"
    else
        printf "socks proxy disabled.\n"
    fi
}

cmd=$1
shift
case $cmd in
    http)
        setHttpProxy "$@"
        ;;
    https)
        setHttpsProxy "$@"
        ;;
    socks)
        setSocksProxy "$@"
        ;;
    pac)
        setPac "$@"
        ;;
    unset)
        unset "$@"
        ;;
    editPac)
        editPac "$@"
        ;;
    list|status)
        list "$@"
        ;;
    *)
        usage
        ;;
esac
