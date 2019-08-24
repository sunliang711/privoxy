#!/bin/bash
rpath="$(readlink $BASH_SOURCE)"
if [ -z "$rpath" ];then
    rpath=$BASH_SOURCE
fi
root="$(cd $(dirname $rpath) && pwd)"
cd "$root"

RED=$(tput setaf 1)
RESET=$(tput sgr0)

user=${SUDO_USER:-$(whoami)}
home=$(eval echo ~$user)
db="$(cat db)"

function check(){
    if (($EUID==0));then
        echo "Don't need run as root."
        exit 1
    fi
}

log(){
    datetime=$(date +%FT%T)
    echo "$datetime $*"
}

function usage(){
    cat <<-EOF
	Usage: $(basename $0) CMD
	CMD:
    	install
    	uninstall
	EOF
    exit 1
}

function installAutoconf(){
    cd "$root"
    bash ./installAutoconf.sh
    cd "$root"
}

function installPrivoxyFromSource(){
    cd "$root"
    echo "installPrivoxyFromSource()"
    if ! command -v autoconf >/dev/null 2>&1;then
        installAutoconf
    fi

    bash ./installPrivoxy.sh

    cd "$root"
}

function install(){
    cat installMessage
    cd "$root"
    echo "install()"
    check
    if ! command -v privoxy >/dev/null 2>&1;then
        #install privoxy
        if command -v apt-get >/dev/null 2>&1;then
            sudo apt-get install -y privoxy
        elif command -v yum >/dev/null 2>&1;then
            sudo yum install -y privoxy
        elif command -v pacman >/dev/null 2>&1;then
            sudo pacman -S privoxy --noconfirm
        elif [ "$(uname)" = "Darwin" ];then
            installPrivoxyFromSource
        fi
    fi
    if ! command -v privoxy >/dev/null 2>&1;then
        echo "Please install privoxy manually."
        exit 1
    fi

    if ! command -v sqlite3 >/dev/null 2>&1;then
        bash ./installSqlite3.sh
    fi

    if ! command -v sqlite3 >/dev/null 2>&1;then
        echo "Please install sqlite3 manually."
        exit 1
    fi

    #create db
    sqlite3 "$db" "CREATE TABLE IF NOT EXISTS config(id integer primary key autoincrement,name varchar,local_port int unique,upstream varchar,logdir varchar,ispac int);"
    # sqlite3 "$db" "insert into config values(1,'sspac',8118,'localhost:1080','/tmp',1)"
    # sqlite3 "$db" "insert into config values(2,'global',8118,'localhost:1080','/tmp',0)"

    case $(uname) in
        Linux)
            sudo ln -sf $root/pctl /usr/local/bin
        ;;
        Darwin)
            sudo ln -sf $root/pctl /usr/local/bin
        ;;
    esac
}

function uninstall(){
    cd "$root"
    echo "uninstall()"
    sudo rm /usr/local/bin/pctl
    cd "$root"
}

cmd=$1
case $cmd in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    *)
        usage
        ;;
esac

