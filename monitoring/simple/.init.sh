#!/bin/sh
set -e

rand(){
    local LEN=$1;
    cat /dev/urandom | tr -dc '[:alpha:]' | fold -w${LEN} | head -n 1;
}

writeRand(){
    local LEN=${1};
    local DIR=${2};
    local FILE=${3};
    local PFIX=${4};
    local TRA="."; local TRB=".";
    if [ "toLower" = "${5}" ]; then
        local TRA="[:upper:]"; local TRB="[:lower:]";
    elif [ "toUpper" = "${5}" ]; then
        local TRA="[:lower:]"; local TRB="[:upper:]";
    fi

    [ ! -d ${DIR} ] && mkdir -p ${DIR};
    [ ! -f "${DIR}/${FILE}" ] && \
    echo -n "${PFIX}$(rand ${LEN})" | tr ${TRA} ${TRB} > "./${DIR}/${FILE}" && \
    echo "./${DIR}/${FILE} created."
}

mkdir -p "./.secret";
echo -n "minio"             > "./.secret/.minio.host";
echo -n "9000"              > "./.secret/.minio.port";
echo -n "ap-southeast-3"    > "./.secret/.minio.region";
writeRand 32 ".secret" ".minio.rootuser";
writeRand 64 ".secret" ".minio.rootpass";

writeRand 64 ".secret" ".minio.loki-secretkey";
writeRand 64 ".secret" ".minio.mimir-secretkey";
writeRand 64 ".secret" ".minio.pyroscope-secretkey";
writeRand 64 ".secret" ".minio.tempo-secretkey";

writeRand 16 ".secret" ".minio.loki-accesskey"      "loki-";
writeRand 16 ".secret" ".minio.mimir-accesskey"     "mimir-";
writeRand 16 ".secret" ".minio.pyroscope-accesskey" "pyroscope-";
writeRand 16 ".secret" ".minio.tempo-accesskey"     "tempo-";

writeRand 8 ".secret" ".minio.loki-bucket"      "loki-"         "toLower";
writeRand 8 ".secret" ".minio.mimir-bucket"     "mimir-"        "toLower";
writeRand 8 ".secret" ".minio.pyroscope-bucket" "pyroscope-"    "toLower";
writeRand 8 ".secret" ".minio.tempo-bucket"     "tempo-"        "toLower";
