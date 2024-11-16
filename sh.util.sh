#!/bin/sh
set -e

rand(){
    local LEN=$1;
    local TRA="$2";
    local TRB="$3";
    if   [ "toLower" = "${TRA}" ];           then TRA="[:upper:]"; TRB="[:lower:]";
    elif [ "toUpper" = "${TRA}" ];           then TRA="[:lower:]"; TRB="[:upper:]";
    elif [ -z "${TRA}" ] || [ -z "${TRB}" ]; then TRA="";          TRB="";
    fi
    cat /dev/urandom | tr -dc '[:alpha:]' | fold -w${LEN} | head -n 1 | tr "${TRA}" "${TRB}";
}

build_secret(){
    build(){
        local PATH=$1; local TEXT=$2;
        [ ! -s "${PATH}" ] && echo "${TEXT}" > "${PATH}" && echo "${PATH} created" || echo "${PATH} existed";
    };
    mkdir -p "./.secret";
    local RAND="$(rand 64)";         build "./.secret/postgres__ro_password" "readonly_${RAND}";
    local RAND="$(rand 32 toLower)"; build "./.secret/postgres__ro_username" "readonly_${RAND}";
    local RAND="$(rand 64)";         build "./.secret/postgres__rp_password" "replica_${RAND}";
    local RAND="$(rand 32 toLower)"; build "./.secret/postgres__rp_slotname" "replica_${RAND}";
    local RAND="$(rand 32 toLower)"; build "./.secret/postgres__rp_username" "replica_${RAND}";
    local RAND="$(rand 16 toLower)"; build "./.secret/postgres_database" "root_${RAND}";
    local RAND="$(rand 64)";         build "./.secret/postgres_password" "root_${RAND}";
    local RAND="$(rand 32 toLower)"; build "./.secret/postgres_username" "root_${RAND}";
    local RAND="$(rand 16 toLower)"; build "./.secret/sonar_database" "root_${RAND}";
    local RAND="$(rand 64)";         build "./.secret/sonar_password" "root_${RAND}";
    local RAND="$(rand 32 toLower)"; build "./.secret/sonar_username" "root_${RAND}";
}

$@;
