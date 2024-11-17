#!/bin/sh
set -e
# ----------------------------------------------------------------------------------------------------------------------
OUT=/dev/stdout;
HEALTHY="message=healthy";
UNHEALTHY="message=unhealthy";
export MINIO_REGION=$(cat /run/secrets/minio.region);
export MINIO_OPTS="--anonymous --address=:$(cat /run/secrets/minio.port) --console-address=:9001"
if [ ! -z $MC_JSON ]; then
    HEALTHY='{"level":"INFO","message":"healthy"}';
    UNHEALTHY='{"level":"INFO","message":"unhealthy"}';
    export MINIO_OPTS="$MINIO_OPTS --json" ;
fi
if [ ! -z $MC_QUIET ]; then
    OUT=/dev/null;
    export MINIO_OPTS="$MINIO_OPTS --quiet";
fi
# ----------------------------------------------------------------------------------------------------------------------
echo 'echo "unhealthy"; exit 1' >"/healthcheck";
chmod +x "/healthcheck";
# ----------------------------------------------------------------------------------------------------------------------


setup() {
local ALIAS="my-minio";
if [ "mc" = "$1" ]; then # MINIO CLIENT SETUP --------------------------------------------------------------------------
    if [ "$2" -le 0 ]; then
        echo "${UNHEALTHY}";
        kill -TERM -$$; # forcefully terminate this current session
    else
        local N=$2; ((N--));
        local USER="$(cat ${MINIO_ROOT_USER_FILE})";
        local PASS="$(cat ${MINIO_ROOT_PASSWORD_FILE})";
        mc alias set "${ALIAS}" "http://0.0.0.0:9000" "${USER}" "${PASS}" >"${OUT}" 2>&1 || (sleep .33 && setup mc $N);
    fi
elif [ -z $1 ]; then # BASE SETUP --------------------------------------------------------------------------------------
    setup mc 5                  && \
    setup loki blocks           && \
    setup loki ruler            && \
    setup mimir blocks          && \
    setup mimir alertmanager    && \
    setup mimir ruler           && \
    setup tempo                 && \
    setup pyroscope             && \
    echo 'echo "healthy"; exit 0' >"/healthcheck" && \
    mc admin update "${ALIAS}" -y >"${OUT}" 2>&1;

    /healthcheck >/dev/null 2>&1 && echo "${HEALTHY}";
elif [ ! -z $1 ]; then # EACH SETUP ------------------------------------------------------------------------------------
    local ACCESS="$(cat /run/secrets/minio.$1-accesskey)";
    local SECRET="$(cat /run/secrets/minio.$1-secretkey)";
    local BUCKET="";
    if [ ! -z $2 ]; then
        BUCKET="$(cat /run/secrets/minio.$1-bucket-$2)";
    else
        BUCKET="$(cat /run/secrets/minio.$1-bucket)";
    fi
    local POLICY="admin-${BUCKET}";

    mc stat "${ALIAS}/${BUCKET}" >"${OUT}" 2>&1 || ( \
        mc mb --with-lock --region="${MINIO_REGION}" "${ALIAS}/${BUCKET}" >"${OUT}" 2>&1 && \
        mc stat "${ALIAS}/${BUCKET}" >"${OUT}" 2>&1 && \
        true
    );
    mc admin user info "${ALIAS}" "${ACCESS}" >"${OUT}" 2>&1 || ( \
        mc admin user add "${ALIAS}" "${ACCESS}" "${SECRET}" >"${OUT}" 2>&1 && \
        mc admin user info "${ALIAS}" "${ACCESS}" >"${OUT}" 2>&1 && \
        true
    );
    mc admin policy info "${ALIAS}" "${POLICY}" >"${OUT}" 2>&1 || ( \
        echo "{ \
            \"Version\": \"2012-10-17\", \
            \"Statement\": [{ \
                \"Effect\": \"Allow\", \
                \"Action\": \"s3:*\", \
                \"Resource\": [ \
                    \"arn:aws:s3:::${BUCKET}/*\" \
                ] \
            }] \
        }" >"/${POLICY}.json" && \
        mc admin policy create "${ALIAS}" "${POLICY}" "/${POLICY}.json" >"${OUT}" 2>&1 && \
        mc admin policy attach "${ALIAS}" "${POLICY}" --user "${ACCESS}" >"${OUT}" 2>&1 && \
        mc admin policy info "${ALIAS}" "${POLICY}" >"${OUT}" 2>&1 && \
        rm "/${POLICY}.json";
        true
    );
fi };
# ----------------------------------------------------------------------------------------------------------------------
main() {
    setup & # run setup in background
    minio server ${MINIO_OPTS} "/mnt/disk{1...3}/minio";
}; main
