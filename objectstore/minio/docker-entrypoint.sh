#!/bin/sh
set -e

[ ! -s "/healthcheck" ] && echo 'echo "unhealthy" && exit 1' > /healthcheck && chmod +x /healthcheck;

MINIO_OPTS="--anonymous --address=:9000 --console-address=:9001"
if [ "${MC_JSON}"  = "1" ]; then MINIO_OPTS="$MINIO_OPTS --json" ; fi
if [ "${MC_QUIET}" = "1" ]; then MINIO_OPTS="$MINIO_OPTS --quiet"; fi
if [ -z "${OUTPUT}" ]; then OUTPUT="/dev/stdout"; fi

template_policy(){ local BUCKET="$1"; cat << EOF
{ "Version": "2012-10-17", "Statement": [{
    "Effect": "Allow", "Action": "s3:*", "Resource": ["arn:aws:s3:::${BUCKET}/*"]
}] }
EOF
}

setup(){
    if [ "$2" -le 0 ]; then echo "unable to set alias"; kill -TERM -$$; fi # forcefully terminate this current session
    local S=$1;
    local N=$2; ((N--));
    local ALIAS="my-minio";
    # local ROOT_USER="$(cat ${MINIO_ROOT_USER_FILE})";
    # local ROOT_PASS="$(cat ${MINIO_ROOT_PASSWORD_FILE})";
    mc alias set "${ALIAS}" "http://0.0.0.0:9000" \
        "$(cat ${MINIO_ROOT_USER_FILE})" \
        "$(cat ${MINIO_ROOT_PASSWORD_FILE})" \
    >"${OUTPUT}" 2>&1 || (sleep "${S}" && setup "${S}" $N);

    setup_creds(){ # setup each credentials ----------------------------------------------------------------------------
        local ACCESS="$1"; shift;
        local SECRET="$1"; shift;
        mc admin user info "${ALIAS}" "${ACCESS}" >"${OUTPUT}" 2>&1 || (
            mc admin user add "${ALIAS}" "${ACCESS}" "${SECRET}" >"${OUTPUT}" 2>&1 &&
            mc admin user info "${ALIAS}" "${ACCESS}" >"${OUTPUT}" 2>&1 &&
            true
        );
        setup_buckets(){ # create each buckets -------------------------------------------------------------------------
            [ $# -eq 0 ] && return 0;
            local BUCKET="$1"; shift;
            local POLICY="admin-${BUCKET}";
            mc stat "${ALIAS}/${BUCKET}" >"${OUTPUT}" 2>&1 || (
                mc mb --with-lock --region="${MINIO_REGION}" "${ALIAS}/${BUCKET}" >"${OUTPUT}" 2>&1 &&
                mc stat "${ALIAS}/${BUCKET}" >"${OUTPUT}" 2>&1 &&
                true
            );
            setup_policy(){ # setup policy for each buckets ------------------------------------------------------------
                template_policy "${BUCKET}" > "/tmp/${POLICY}.json"
                mc admin policy create "${ALIAS}" "${POLICY}" "/tmp/${POLICY}.json" >"${OUTPUT}" 2>&1 &&
                mc admin policy attach "${ALIAS}" "${POLICY}" --user "${ACCESS}" >"${OUTPUT}" 2>&1 &&
                mc admin policy info "${ALIAS}" "${POLICY}" >"${OUTPUT}" 2>&1 &&
                rm "/tmp/${POLICY}.json";
            }
            mc admin policy info "${ALIAS}" "${POLICY}" >"${OUTPUT}" 2>&1 || setup_policy;
            setup_buckets $@;
        }
        setup_buckets $@;
    }

    mkdir -p "/tmp";
    setup_creds "${LOKI_ACCESS}" "${LOKI_SECRET}" \
        "${LOKI_BUCKET_BLOCKS}" \
        "${LOKI_BUCKET_RULER}";
    setup_creds "${MIMIR_ACCESS}" "${MIMIR_SECRET}" \
        "${MIMIR_BUCKET_BLOCKS}" \
        "${MIMIR_BUCKET_RULER}" \
        "${MIMIR_BUCKET_ALERTMANAGER}";
    setup_creds "${TEMPO_ACCESS}" "${TEMPO_SECRET}" \
        "${TEMPO_BUCKET_BLOCKS}";
    setup_creds "${PYROSCOPE_ACCESS}" "${PYROSCOPE_SECRET}" \
        "${PYROSCOPE_BUCKET_BLOCKS}";
    echo 'echo "healthy"; exit 0' > /healthcheck && chmod +x /healthcheck;
}

setup .33 5 & minio server ${MINIO_OPTS} "/mnt/disk{1...3}/minio" >"${OUTPUT}" 2>&1;
