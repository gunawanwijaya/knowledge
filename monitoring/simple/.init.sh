#!/bin/sh
set -e

rand(){
    LEN=$1;
    cat /dev/urandom | tr -dc '[:alpha:]' | fold -w${LEN} | head -n 1;
}
writeRand(){
    local len=${1};
    local dir=${2};
    local file=${3};
    local prefix=${4};
    local tra="."; local trb=".";
    if [ "toLower" = "${5}" ]; then
        local tra="[:upper:]";
        local trb="[:lower:]";
    elif [ "toUpper" = "${5}" ]; then
        local tra="[:lower:]";
        local trb="[:upper:]";
    fi

    [ ! -d ${dir} ] && mkdir -p ${dir};
    [ ! -f "${dir}/${file}" ] && \
    echo -n "${prefix}$(rand ${len})" | tr ${tra} ${trb} > "./${dir}/${file}" && \
    echo "./${dir}/${file} created."
}
writeRand 32 ".secret" ".minio.rootuser";
writeRand 64 ".secret" ".minio.rootpass";
echo -n "minio" > "./.secret/.minio.host"
echo -n "9000" > "./.secret/.minio.port"
echo -n "ap-southeast-3" > "./.secret/.minio.region"

writeRand 64 ".secret" ".minio.loki-secretkey";
writeRand 64 ".secret" ".minio.mimir-secretkey";
writeRand 64 ".secret" ".minio.pyroscope-secretkey";
writeRand 64 ".secret" ".minio.tempo-secretkey";

writeRand 16 ".secret" ".minio.loki-accesskey" "loki-";
writeRand 16 ".secret" ".minio.mimir-accesskey" "mimir-";
writeRand 16 ".secret" ".minio.pyroscope-accesskey" "pyroscope-";
writeRand 16 ".secret" ".minio.tempo-accesskey" "tempo-";

writeRand 8 ".secret" ".minio.loki-bucket" "loki-" "toLower";
writeRand 8 ".secret" ".minio.mimir-bucket" "mimir-" "toLower";
writeRand 8 ".secret" ".minio.pyroscope-bucket" "pyroscope-" "toLower";
writeRand 8 ".secret" ".minio.tempo-bucket" "tempo-" "toLower";
