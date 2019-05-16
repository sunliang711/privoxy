#!/bin/bash
rpath=$(readlink ${BASH_SOURCE})
if [ -z "$rpath" ];then
    rpath=${BASH_SOURCE}
fi
me="$(cd $(dirname $rpath) && pwd)"
cd $me


enX="$(route -n get 8.8.8.8 | perl -ne 'print $2 if /(interface:\s*)(\w+)/')"

cnw="$(networksetup -listnetworkserviceorder | grep $enX |perl -ne 'print $2 if /(Hardware Port: )([^,]+)/')"

host=localhost

defaultPacServerPort=28989
# defaultPacServerDirectory=$(pwd)
defaultPacfile=gfwlist.pac

pacServerPortFile=/tmp/pacServerPortFile

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

		pac     <LOCAL_PROXY_PORT> [serverport]
		        defaultPacServerPort:           $defaultPacServerPort
		unset
	EOF
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
    upstreamPort=${1:?'missing upstream port'}
    pacServerPort=${2:-$defaultPacServerPort}

    sed -e "s|UPSTREAMPORT|$upstreamPort|g" gfwlist.pac > proxy.pac
    cat<<-EOF
		pacServerHost: $pacServerHost
		pacServerPort: $pacServerPort
	EOF
    if ! command -v python3 >/dev/null 2>&1;then
        nohup python -m SimpleHTTPServer $pacServerPort >/dev/null 2>&1 &
    else
        nohup python3 -m http.server $pacServerPort --bind=$pacServerHost >/dev/null 2>&1 &
    fi
    networksetup -setautoproxyurl $cnw "http://$host:$pacServerPort/proxy.pac"
    echo -n "$pacServerPort" > $pacServerPortFile
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
    networksetup -setautoproxystate $cnw off
    pacServerPort="$(cat $pacServerPortFile 2>/dev/null)"
    if [ -n "$pacServerPort" ];then
        echo "pacServerPort: $pacServerPort"
        pid="$(lsof -iTCP -sTCP:LISTEN -P | grep $pacServerPort | awk '{print $2}')"
        kill -s TERM $pid
    else
        echo "pacServerPort is null"
    fi

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
        port=$2
        pacsrvport=$3
        setPac $port "$pacsrvport"
        ;;
    unset)
        unsetHttpProxy
        unsetHttpsProxy
        unsetSocksProxy
        unsetPac
        ;;
    *)
        usage
        ;;
esac
