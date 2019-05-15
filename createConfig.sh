#!/bin/bash
rpath="$(readlink $BASH_SOURCE)"
if [ -z "$rpath" ];then
    rpath=$BASH_SOURCE
fi
root="$(cd $(dirname $rpath) && pwd)"
cd "$root"

user="${SUDO_USER:-$(whoami)}"
home="$(eval echo ~$user)"

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
            -e "s|LOGDIR|$logdir|g" -e "s|LOGFILE|$logfile|g" template/privoxy.plist > $home/Library/LaunchAgents/$servicename.plist
    ;;
    Linux)
        log "Making service file($servicename)..."
        #TODO service文件放到/etc/systemd/system,另外要用sudo
        sed -e "s|SERVICENAME|$servicename|g" -e "s|CONFIGFILE|$configfile|g" \
            -e "s|PRIVOXY|$(which privoxy)|g" -e "s|ROOT|$root|g" template/privoxy.service > runtime/$servicename.service
    ;;
esac