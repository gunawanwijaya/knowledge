#!/bin/sh
set -e
cat << EOF > /healthcheck
set -e
mc stat local/$(cat /run/secrets/minio.loki-bucket) > /dev/null 2>&1
EOF
chmod +x /healthcheck;

export MINIO_REGION=$(cat /run/secrets/minio.region);
export MINIO_OPTS="\
--anonymous \
--address=:$(cat /run/secrets/minio.port) \
--console-address=:9001\
"
[ ! -z $MC_JSON ]  && export MINIO_OPTS="$MINIO_OPTS --json" ;
[ ! -z $MC_QUIET ] && export MINIO_OPTS="$MINIO_OPTS --quiet";

init(){
    sleep .95;
    local ALIAS="local";
    mc alias set ${ALIAS} \
        "http://localhost:9000" \
        "$(cat ${MINIO_ROOT_USER_FILE})" \
        "$(cat ${MINIO_ROOT_PASSWORD_FILE})" \
    ;

    local ACCESS=$(cat /run/secrets/minio.loki-accesskey);
    local SECRET=$(cat /run/secrets/minio.loki-secretkey);
    mc admin user add ${ALIAS} "${ACCESS}" "${SECRET}";
    local ACCESS=$(cat /run/secrets/minio.mimir-accesskey);
    local SECRET=$(cat /run/secrets/minio.mimir-secretkey);
    mc admin user add ${ALIAS} "${ACCESS}" "${SECRET}";
    local ACCESS=$(cat /run/secrets/minio.pyroscope-accesskey);
    local SECRET=$(cat /run/secrets/minio.pyroscope-secretkey);
    mc admin user add ${ALIAS} "${ACCESS}" "${SECRET}";
    local ACCESS=$(cat /run/secrets/minio.tempo-accesskey);
    local SECRET=$(cat /run/secrets/minio.tempo-secretkey);
    mc admin user add ${ALIAS} "${ACCESS}" "${SECRET}";

    local ACCESS=$(cat /run/secrets/minio.loki-accesskey);
    mc admin policy attach ${ALIAS} readwrite --user "${ACCESS}";
    local ACCESS=$(cat /run/secrets/minio.mimir-accesskey);
    mc admin policy attach ${ALIAS} readwrite --user "${ACCESS}";
    local ACCESS=$(cat /run/secrets/minio.pyroscope-accesskey);
    mc admin policy attach ${ALIAS} readwrite --user "${ACCESS}";
    local ACCESS=$(cat /run/secrets/minio.tempo-accesskey);
    mc admin policy attach ${ALIAS} readwrite --user "${ACCESS}";

    local BUCKET=$(cat /run/secrets/minio.loki-bucket);
    mc mb --with-lock --region="${MINIO_REGION}" "${ALIAS}/${BUCKET}";
    local BUCKET=$(cat /run/secrets/minio.mimir-bucket);
    mc mb --with-lock --region="${MINIO_REGION}" "${ALIAS}/${BUCKET}";
    local BUCKET=$(cat /run/secrets/minio.pyroscope-bucket);
    mc mb --with-lock --region="${MINIO_REGION}" "${ALIAS}/${BUCKET}";
    local BUCKET=$(cat /run/secrets/minio.tempo-bucket);
    mc mb --with-lock --region="${MINIO_REGION}" "${ALIAS}/${BUCKET}";

    mc admin update ${ALIAS} & # run update in background
}; init & # run init in background

minio server ${MINIO_OPTS} /data/minio/disk{1...4};
