#!/bin/sh
set -e
# ----------------------------------------------------------------------------------------------------------------------
OUT="/dev/stdout";
HEALTHY="message=healthy";
export MINIO_REGION=$(cat /run/secrets/minio.region);
export MINIO_OPTS="--anonymous --address=:$(cat /run/secrets/minio.port) --console-address=:9001"
[ ! -z $MC_JSON ]  && \
    HEALTHY='{"message":"healthy"}' \
    export MINIO_OPTS="$MINIO_OPTS --json" ;
[ ! -z $MC_QUIET ] && \
    OUT="/dev/null" \
    export MINIO_OPTS="$MINIO_OPTS --quiet";
# ----------------------------------------------------------------------------------------------------------------------
OK="healthcheck-ok"
echo '[ "'${OK}'"=$(mc cat "/'${OK}'") ]' >"/healthcheck";
chmod +x "/healthcheck";
# ----------------------------------------------------------------------------------------------------------------------
setup() {
local ALIAS="my-minio";
if [ -z $1 ]; then # BASE SETUP ----------------------------------------------------------------------------------------
    sleep .75;
    local USER="$(cat ${MINIO_ROOT_USER_FILE})";
    local PASS="$(cat ${MINIO_ROOT_PASSWORD_FILE})";
    mc alias set "${ALIAS}" "http://0.0.0.0:9000" "${USER}" "${PASS}" >"${OUT}" 2>&1;
    setup loki      >"${OUT}" 2>&1 && \
    setup mimir     >"${OUT}" 2>&1 && \
    setup tempo     >"${OUT}" 2>&1 && \
    setup pyroscope >"${OUT}" 2>&1;
    echo "${OK}" >"/${OK}" && echo "${HEALTHY}";
    mc admin update "${ALIAS}" -y;
elif [ ! -z $1 ]; then # EACH SETUP ------------------------------------------------------------------------------------
    local BUCKET=$(cat /run/secrets/minio.$1-bucket);
    local ACCESS=$(cat /run/secrets/minio.$1-accesskey);
    local SECRET=$(cat /run/secrets/minio.$1-secretkey);
    local POLICY="admin-${BUCKET}";
    trap "rm \"/${POLICY}.json\"" EXIT;
    echo "{\"Version\": \"2012-10-17\",\"Statement\": [{\
        \"Effect\": \"Allow\",\"Action\": \"s3:*\",\"Resource\": [\"arn:aws:s3:::${BUCKET}/*\"]\
    }]}" >"/${POLICY}.json";
    local STAT=$(mc stat "${ALIAS}/${BUCKET}");
    case "${STAT}" in *"error"*) mc mb --with-lock --region="${MINIO_REGION}" "${ALIAS}/${BUCKET}";; *) echo "${STAT}";; esac
    local USERINFO=$(mc admin user info "${ALIAS}" "${ACCESS}");
    case "${USERINFO}" in *"error"*) mc admin user add "${ALIAS}" "${ACCESS}" "${SECRET}";; *) echo "${USERINFO}";; esac
    local POLICYINFO=$(mc admin policy info "${ALIAS}" "${POLICY}");
    case "${POLICYINFO}" in *"error"*) mc admin policy create "${ALIAS}" "${POLICY}" "/${POLICY}.json";; *) echo "${POLICYINFO}";; esac
    local USERINFO=$(mc admin user info "${ALIAS}" "${ACCESS}");
    case "${USERINFO}" in *"${POLICY}"*) echo "${USERINFO}";; *) mc admin policy attach "${ALIAS}" "${POLICY}" --user "${ACCESS}";; esac
fi };
# ----------------------------------------------------------------------------------------------------------------------
main() {
    setup & # run setup in background
    minio server ${MINIO_OPTS} "/mnt/disk{1...3}/minio";
}; main
