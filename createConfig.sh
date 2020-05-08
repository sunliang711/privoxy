#!/bin/bash
rpath="$(readlink $BASH_SOURCE)"
if [ -z "$rpath" ];then
    rpath=$BASH_SOURCE
fi
root="$(cd $(dirname $rpath) && pwd)"
cd "$root"

user="${SUDO_USER:-$(whoami)}"
home="$(eval echo ~$user)"

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

log(){
    datetime=$(date +%FT%T)
    echo "$datetime $*"
}

db="$(cat db)"

id=${1:?'missing id'}
record="$(bash queryById.sh $id)"
#must set IFS
IFS=$'|'
#must use "$record" instead of $record
read unuse_name local_port upstream logdir ispac <<< "$record"

NAME="$(bash name.sh $id)"
actionsfile="$NAME.action"
logfile="$NAME.log"
servicename="$NAME"
configfile="$NAME.config"

if [ ! -d runtime ];then
    mkdir runtime
fi

if (($ispac == 1));then
    log "Making actionsfile($actionsfile)..."
    #TODO 是否要先判断是否已经存在runtime/$actionsfile,存在的话,就不用tempalte里的重新生成,这样每个id都自己维护自己的pac
    sed -e "s|UPSTREAM|$upstream|g" template/pac.action > runtime/$actionsfile
    log "Making configfile($configfile)..."
    sed -e "s|LOGDIR|$logdir|g" -e "s|LOGFILE|$logfile|g" -e "s|LOCAL_PORT|${local_port}|g" \
        -e "s|ACTIONSFILE|$root/runtime/$actionsfile|g" template/pac.config >runtime/$configfile
else
    log "Making configfile($configfile)..."
    sed -e "s|LOGDIR|$logdir|g" -e "s|LOGFILE|$logfile|g" -e "s|LOCAL_PORT|${local_port}|g" \
        -e "s|UPSTREAM|$upstream|g" template/global.config > runtime/$configfile
fi
case $(uname) in
    Darwin)
        log "Making plist file($servicename)..."
        if [ ! -d "$home/Library/LaunchAgents" ];then
            mkdir -p "$home/Library/LaunchAgents"
        fi
        sed -e "s|SERVICENAME|$servicename|g" -e "s|CONFIGFILE|$configfile|g" \
            -e "s|PRIVOXY|$(which privoxy)|g" -e "s|ROOT|$root|g" \
            -e "s|LOGDIR|$logdir|g" -e "s|LOGFILE|$logfile|g" template/privoxy.plist > runtime/$servicename.plist
        ln -sf "$root/runtime/$servicename.plist" $home/Library/LaunchAgents
    ;;
    Linux)
        log "Making service file($servicename)..."
        sed -e "s|SERVICENAME|$servicename|g" -e "s|CONFIGFILE|$configfile|g" \
            -e "s|USER|$user|g" \
            -e "s|PRIVOXY|$(which privoxy)|g" -e "s|ROOT|$root|g" template/privoxy.service > runtime/$servicename.service
        runAsRoot ln -sf "$root/runtime/$servicename.service" /etc/systemd/system
        runAsRoot systemctl daemon-reload
        runAsRoot systemctl enable $servicename
    ;;
esac
