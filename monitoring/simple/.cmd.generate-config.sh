#!/bin/sh
set -e

_HOST="$(cat ./.secret/.minio.host)";
_PORT="$(cat ./.secret/.minio.port)";
_REGION="$(cat ./.secret/.minio.region)";
generate_config(){
    local SERVICE=$1;
    local TARGET=$2;
    local SUFFIX=$3;
    # local DATADIR="/var/lib/${SERVICE}/${SERVICE}-${TARGET}${SUFFIX}";
    local DATADIR="/var/lib/${SERVICE}";
    local _ACCESS="$(cat ./.secret/.minio.${SERVICE}-accesskey)";
    local _SECRET="$(cat ./.secret/.minio.${SERVICE}-secretkey)";

    local _COMPACTOR="compactor";
    local _QUERIER="querier-0";
    local _QUERY_FRONTEND="query-frontend";
    local _QUERY_SCHEDULER="query-scheduler";
    local _MEMBERLIST_JOIN="ingester-0";
    if [ "${TARGET}" = "all" ]; then
        _COMPACTOR="all";
        _QUERIER="all";
        _QUERY_FRONTEND="all";
        _QUERY_SCHEDULER="all";
        _MEMBERLIST_JOIN="all";
    fi

    case "${SERVICE}" in
    "loki")
        local _BUCKET_BLOCKS="$(cat ./.secret/.minio.loki-bucket-blocks)";
        local _BUCKET_RULER="$(cat ./.secret/.minio.loki-bucket-ruler)";
        # --------------------------------------------------------------------------------------------------------------
        local CONFIG_FILE="./grafana.${SERVICE}.config-${TARGET}.gen.yml";
        rm -f "${CONFIG_FILE}"; cp "./grafana.${SERVICE}.config.yml" "${CONFIG_FILE}";
        # --------------------------------------------------------------------------------------------------------------
        local FIND="target: \"all\"";
        local REPL="target: \"${TARGET}\"";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local _ADD="";
        _ADD="${_ADD}, endpoint: \"${_HOST}:${_PORT}\"";
        _ADD="${_ADD}, region: \"${_REGION}\"";
        _ADD="${_ADD}, access_key_id: \"${_ACCESS}\"";
        _ADD="${_ADD}, secret_access_key: \"${_SECRET}\"";
        _ADD="${_ADD}, bucketnames: \"${_BUCKET_BLOCKS}\"";
        _ADD="${_ADD}, s3forcepathstyle: true";
        _ADD="${_ADD}, signature_version: v4";
        _ADD="${_ADD}, storage_class: STANDARD";
        local FIND="s3: { insecure: true }";
        local REPL="s3: { insecure: true ${_ADD} }";
        sed -i "s|${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local _ADD="";
        _ADD="${_ADD}\\n  rule_path: \"${DATADIR}/rules\"";
        _ADD="${_ADD}\\n  wal: { dir: \"${DATADIR}/ruler-wal\" }";
        _ADD="${_ADD}\\n  storage: { type: s3, s3: { bucketnames: \"${_BUCKET_RULER}\" }, local: { directory: \"${DATADIR}/ruler_storage\" } }";
        local FIND="ruler:";
        local REPL="ruler:${_ADD}";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="ingester:";
        local REPL="ingester:\\n  wal: { dir: \"${DATADIR}/ingester-wal\" }";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        # local _ADD="";
        # _ADD="${_ADD}\\n  boltdb: { directory: \"${DATADIR}/boltdb\" }";
        # _ADD="${_ADD}\\n  filesystem: { directory: \"${DATADIR}/local_chunk\" }";
        # _ADD="${_ADD}\\n  boltdb_shipper: { active_index_directory: \"${DATADIR}/boltdb_index\", cache_location: \"${DATADIR}/boltdb_cache\" }";
        # _ADD="${_ADD}\\n  tsdb_shipper: { active_index_directory: \"${DATADIR}/tsdb_index\", cache_location: \"${DATADIR}/tsdb_cache\" }";
        # local FIND="storage_config:";
        # local REPL="storage_config:${_ADD}";
        # sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="frontend:";
        local REPL="frontend:\\n  tail_proxy_url: \"http://${SERVICE}-${_QUERY_SCHEDULER}:3100\"";
        if [ ! "${TARGET}" = "all" ]; then
            REPL="${REPL}\\n  scheduler_address: \"${SERVICE}-${_QUERY_SCHEDULER}:3101\""
        fi
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="frontend_worker:";
        local REPL="frontend_worker:\\n  scheduler_address: \"${SERVICE}-${_QUERY_SCHEDULER}:3101\"";
        if [ "${TARGET}" = "all" ]; then
            REPL="frontend_worker:\\n  frontend_address: \"${SERVICE}-${_QUERY_FRONTEND}:3101\"";
        fi
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local _ADD="";
        _ADD="${_ADD}\\n  compactor_address: \"http://${SERVICE}-${_COMPACTOR}:3100\"";
        _ADD="${_ADD}\\n  compactor_grpc_address: \"${SERVICE}-${_COMPACTOR}:3101\"";
        local FIND="common:";
        local REPL="common:${_ADD}";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="memberlist:";
        local REPL="memberlist:\\n  join_members: [\"${SERVICE}-${_MEMBERLIST_JOIN}:7946\"]";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
    ;;
    "mimir")
        local _BUCKET_BLOCKS="$(cat ./.secret/.minio.mimir-bucket-blocks)";
        local _BUCKET_ALERTMANAGER="$(cat ./.secret/.minio.mimir-bucket-alertmanager)";
        local _BUCKET_RULER="$(cat ./.secret/.minio.mimir-bucket-ruler)";
        # --------------------------------------------------------------------------------------------------------------
        local CONFIG_FILE="./grafana.${SERVICE}.config-${TARGET}.gen.yml";
        rm -f "${CONFIG_FILE}"; cp "./grafana.${SERVICE}.config.yml" "${CONFIG_FILE}";
        # --------------------------------------------------------------------------------------------------------------
        local FIND="target: \"all\"";
        local REPL="target: \"${TARGET}\"";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local _ADD="";
        _ADD="${_ADD}, endpoint: \"${_HOST}:${_PORT}\"";
        _ADD="${_ADD}, region: \"${_REGION}\"";
        _ADD="${_ADD}, access_key_id: \"${_ACCESS}\"";
        _ADD="${_ADD}, secret_access_key: \"${_SECRET}\"";
        local FIND="s3: { insecure: true }";
        local REPL="s3: { insecure: true ${_ADD} }";
        sed -i "s|${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="alertmanager:";
        local REPL="alertmanager:\\n  data_dir: \"${DATADIR}/alertmanager\"";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="ruler:";
        local REPL="ruler:\\n  rule_path: \"${DATADIR}/rules\"";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="compactor:";
        local REPL="compactor:\\n  data_dir: \"${DATADIR}/compactor\"";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="activity_tracker:";
        local REPL="activity_tracker:\\n  filepath: \"${DATADIR}/activity-tracker.log\"";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="frontend_worker:";
        local REPL="frontend_worker:\\n  scheduler_address: \"${SERVICE}-${_QUERY_SCHEDULER}:3201\"";
        if [ "${TARGET}" = "all" ]; then
            REPL="frontend_worker:\\n  frontend_address: \"${SERVICE}-${_QUERY_FRONTEND}:3201\"";
        fi
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="memberlist:";
        local REPL="memberlist:\\n  join_members: [\"${SERVICE}-${_MEMBERLIST_JOIN}:7946\"]";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="blocks_storage:";
        local REPL="blocks_storage:\\n  s3: { bucket_name: \"${_BUCKET_BLOCKS}\" }\\n  bucket_store: { sync_dir: \"${DATADIR}/tsdb_sync\" }\\n  tsdb: { dir: \"${DATADIR}/tsdb\" }";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="alertmanager_storage:";
        local REPL="alertmanager_storage:\\n  s3: { bucket_name: \"${_BUCKET_ALERTMANAGER}\" }\\n  local: { path: \"${DATADIR}/alertmanager\" }";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="ruler_storage:";
        local REPL="ruler_storage:\\n  s3: { bucket_name: \"${_BUCKET_RULER}\" }\\n  local: { directory: \"${DATADIR}/ruler\" }";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
    ;;
    "pyroscope")
        local CONFIG_FILE="./grafana.pyroscope.config-${TARGET}.gen.yml";
        rm -f "${CONFIG_FILE}"; cp ./grafana.pyroscope.config.yml ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="target: \"all\"";
        local REPL="target: \"${TARGET}\"";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local _ADD="";
        _ADD="${_ADD}, endpoint: \"${_HOST}:${_PORT}\"";
        _ADD="${_ADD}, region: \"${_REGION}\"";
        _ADD="${_ADD}, access_key_id: \"${_ACCESS}\"";
        _ADD="${_ADD}, secret_access_key: \"${_SECRET}\"";
        local FIND="s3: { insecure: true }";
        local REPL="s3: { insecure: true ${_ADD} }";
        sed -i "s|${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="pyroscopedb:";
        local REPL="pyroscopedb:\\n  data_path: \"${DATADIR}/data\"";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
        # --------------------------------------------------------------------------------------------------------------
        local FIND="memberlist:";
        local REPL="memberlist:\\n  join_members: [\"${SERVICE}-${_MEMBERLIST_JOIN}:7946\"]";
        sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
    ;;
    "tempo")
    ;;
    esac;
}

generate_config loki all;
generate_config mimir all;
generate_config pyroscope all;
