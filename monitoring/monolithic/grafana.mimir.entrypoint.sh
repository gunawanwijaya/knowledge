#!/bin/sh
# set -e

# ----------------------------------------------------------------------------------------------------------------------
EXITCODE="/tmp/otelcol-contrib.exit";
sleep .5 & /otelcol-contrib.exec.sh \
  "/etc/config/otelcol-contrib.yml" \
  "/config.0.yml" \
  "mimir" \
  "mimir-all:${HTTP_LISTEN_PORT}" \
  "${STDOUT}" \
  "/var/log/mimir/otelcol-contrib.jsonl" \
  "${EXITCODE}" \
& wait -n;
if [ -r "${EXITCODE}" ]; then { CODE=$(cat ${EXITCODE}); [ ${CODE} -ge 0 ] && [ ${CODE} -le 127 ] && exit ${CODE}; } fi
# ----------------------------------------------------------------------------------------------------------------------
S3_HOST=$(cat /run/secrets/minio.host);
S3_PORT=$(cat /run/secrets/minio.port);
S3_REGION=$(cat /run/secrets/minio.region);
S3_BUCKET_ALERTMANAGER=$(cat /run/secrets/minio.mimir-bucket-alertmanager);
S3_BUCKET_BLOCKS=$(cat /run/secrets/minio.mimir-bucket-blocks);
S3_BUCKET_RULER=$(cat /run/secrets/minio.mimir-bucket-ruler);
S3_ACCESS=$(cat /run/secrets/minio.mimir-accesskey);
S3_SECRET=$(cat /run/secrets/minio.mimir-secretkey);
S3_ENDPOINT="${S3_HOST}:${S3_PORT}"
RING_REPLICA=1
RING_STORE="inmemory"
QUERIER_FRONTEND="mimir-all:${GRPC_LISTEN_PORT}"
QUERIER_SCHEDULER=""
# ----------------------------------------------------------------------------------------------------------------------
mimir -config.file="/etc/config/mimir.yml" -target="${TARGET}" \
  -server.grpc-listen-port="${GRPC_LISTEN_PORT}" \
  -server.http-listen-port="${HTTP_LISTEN_PORT}" \
  \
  -common.storage.backend="s3" \
  -common.storage.s3.insecure=true \
  -common.storage.s3.signature-version="v4" \
  -common.storage.s3.storage-class="STANDARD" \
  -common.storage.s3.endpoint="${S3_ENDPOINT}" \
  -common.storage.s3.region="${S3_REGION}" \
  -common.storage.s3.access-key-id="${S3_ACCESS}" \
  -common.storage.s3.secret-access-key="${S3_SECRET}" \
  -common.storage.s3.bucket-name="${S3_BUCKET_BLOCKS}" \
  -alertmanager-storage.s3.bucket-name="${S3_BUCKET_ALERTMANAGER}" \
  -blocks-storage.s3.bucket-name="${S3_BUCKET_BLOCKS}" \
  -ruler-storage.s3.bucket-name="${S3_BUCKET_RULER}" \
  \
  -ingester.ring.replication-factor="${RING_REPLICA}" \
  -alertmanager.sharding-ring.replication-factor="${RING_REPLICA}" \
  -store-gateway.sharding-ring.replication-factor="${RING_REPLICA}" \
  -query-frontend.scheduler-address="${QUERIER_SCHEDULER}" \
  -ruler.query-frontend.address="${QUERIER_FRONTEND}" \
  -querier.frontend-address="${QUERIER_FRONTEND}" \
  -querier.scheduler-address="${QUERIER_SCHEDULER}" \
  \
  -store-gateway.sharding-ring.store="${RING_STORE}" \
  -compactor.ring.store="${RING_STORE}" \
  -alertmanager.sharding-ring.store="${RING_STORE}" \
  -ruler.ring.store="${RING_STORE}" \
  -query-scheduler.ring.store="${RING_STORE}" \
  -ingester.ring.store="${RING_STORE}" \
  -ingester.partition-ring.store="${RING_STORE}" \
  -distributor.ha-tracker.store="${RING_STORE}" \
  -distributor.ring.store="${RING_STORE}" \
  -overrides-exporter.ring.store="${RING_STORE}" \
  2>&1 | tee "/var/log/mimir/mimir.jsonl" > "${STDOUT}";



# CONFIG_FILE="/config.0.yml";
# cp "/etc/config/mimir.yml" "${CONFIG_FILE}";
# CONFIG_OTELCOL_CONTRIB_FILE="/config.1.yml";
# cp "/etc/config/otelcol-contrib.yml" "${CONFIG_OTELCOL_CONTRIB_FILE}";

# load(){
#     local COMPACTOR="compactor";
#     local QUERIER="querier-0";
#     local QUERY_FRONTEND="query-frontend";
#     local QUERY_SCHEDULER="query-scheduler";
#     local MEMBERLIST_JOIN="ingester-0";
#     if [ "${TARGET}" = "all" ]; then
#         COMPACTOR="all";
#         QUERIER="all";
#         QUERY_FRONTEND="all";
#         QUERY_SCHEDULER="all";
#         MEMBERLIST_JOIN="all";
#     fi
#     local DATADIR="/var/lib/${SERVICE}";
#     local HOST="$(cat /run/secrets/minio.host)";
#     local PORT="$(cat /run/secrets/minio.port)";
#     local REGION="$(cat /run/secrets/minio.region)";
#     local ACCESS="$(cat /run/secrets/minio.${SERVICE}-accesskey)";
#     local SECRET="$(cat /run/secrets/minio.${SERVICE}-secretkey)";
#     local BUCKET_BLOCKS="$(cat /run/secrets/minio.mimir-bucket-blocks)";
#     local BUCKET_ALERTMANAGER="$(cat /run/secrets/minio.mimir-bucket-alertmanager)";
#     local BUCKET_RULER="$(cat /run/secrets/minio.mimir-bucket-ruler)";
#     # --------------------------------------------------------------------------------------------------------------
#     local FIND="target: \"all\"";
#     local REPL="target: \"${TARGET}\"";
#     sed -i "s|^${FIND}|${REPL}|" "${CONFIG_FILE}";
#     # --------------------------------------------------------------------------------------------------------------
#     local ADD="";
#     ADD="${ADD}\\n  storage:";
#     ADD="${ADD}\\n    backend: \"s3\"";
#     ADD="${ADD}\\n    s3:";
#     ADD="${ADD}\\n      insecure: true";
#     ADD="${ADD}\\n      endpoint: \"${HOST}:${PORT}\"";
#     ADD="${ADD}\\n      region: \"${REGION}\"";
#     ADD="${ADD}\\n      access_key_id: \"${ACCESS}\"";
#     ADD="${ADD}\\n      secret_access_key: \"${SECRET}\"";
#     local FIND="common:";
#     local REPL="common:${ADD}";
#     sed -i "s|${FIND}|${REPL}|" "${CONFIG_FILE}";
#     # --------------------------------------------------------------------------------------------------------------
#     local FIND="ruler:";
#     local REPL="ruler:\\n  rule_path: \"${DATADIR}/rules\"";
#     sed -i "s|${FIND}|${REPL}|" "${CONFIG_FILE}";
#     # --------------------------------------------------------------------------------------------------------------
#     local FIND="ruler_storage:";
#     local REPL="ruler_storage:\\n  backend: s3\\n  s3: { bucket_name: \"${BUCKET_RULER}\" }";
#     sed -i "s|${FIND}|${REPL}|" "${CONFIG_FILE}";
#     # --------------------------------------------------------------------------------------------------------------
#     local FIND="alertmanager:";
#     local REPL="alertmanager:\\n  data_dir: \"${DATADIR}/alertmanager\"";
#     sed -i "s|${FIND}|${REPL}|" "${CONFIG_FILE}";
#     # --------------------------------------------------------------------------------------------------------------
#     local FIND="alertmanager_storage:";
#     local REPL="alertmanager_storage:\\n  backend: s3\\n  s3: { bucket_name: \"${BUCKET_ALERTMANAGER}\" }";
#     sed -i "s|${FIND}|${REPL}|" "${CONFIG_FILE}";
#     # --------------------------------------------------------------------------------------------------------------
#     local ADD="";
#     ADD="${ADD}\\n  backend: \"s3\"";
#     ADD="${ADD}\\n  s3: { bucket_name: \"${BUCKET_BLOCKS}\" }";
#     ADD="${ADD}\\n  bucket_store: { sync_dir: \"${DATADIR}/tsdb-sync\" }";
#     ADD="${ADD}\\n  tsdb: { dir: \"${DATADIR}/tsdb\" }";
#     local FIND="blocks_storage:";
#     local REPL="blocks_storage:${ADD}";
#     sed -i "s|${FIND}|${REPL}|" "${CONFIG_FILE}";
#     # --------------------------------------------------------------------------------------------------------------
#     local FIND="compactor:";
#     local REPL="compactor:\\n  data_dir: \"${DATADIR}/compactor\"";
#     sed -i "s|${FIND}|${REPL}|" "${CONFIG_FILE}";
#     # --------------------------------------------------------------------------------------------------------------
#     local FIND="activity_tracker:";
#     local REPL="activity_tracker:\\n  filepath: \"${DATADIR}/activity-tracker.log\"";
#     sed -i "s|${FIND}|${REPL}|" "${CONFIG_FILE}";
#     # --------------------------------------------------------------------------------------------------------------
#     local FIND="frontend_worker:";
#     local REPL="frontend_worker:\\n  scheduler_address: \"${SERVICE}-${QUERY_SCHEDULER}:${GRPC_LISTEN_PORT}\"";
#     if [ "${TARGET}" = "all" ]; then
#         REPL="frontend_worker:\\n  frontend_address: \"${SERVICE}-${QUERY_FRONTEND}:${GRPC_LISTEN_PORT}\"";
#     fi
#     sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
#     # --------------------------------------------------------------------------------------------------------------
#     local FIND="memberlist:";
#     local REPL="memberlist:\\n  join_members: [\"${SERVICE}-${MEMBERLIST_JOIN}:7946\"]";
#     sed -i "s|^${FIND}|${REPL}|" ${CONFIG_FILE};
#     # --------------------------------------------------------------------------------------------------------------
# }

# load;

# otelcol-contrib --config="${CONFIG_OTELCOL_CONTRIB_FILE}" \
#     2>&1 | tee "/var/log/${SERVICE}/otelcol-contrib.jsonl" &

# # echo "{\"message\":\"healthy\",\"version\":\"$(mimir -version | head -n 1)\"}";

# mimir -config.file="${CONFIG_FILE}" \
#     2>&1 | tee "/var/log/${SERVICE}/${SERVICE}.jsonl";



# mimir -config.file="/config.yml" -target="${target}" \
#     -querier.frontend-address="mimir-${query_frontend}:3201" \
#     -memberlist.join="mimir-${memberlist_join}:7946" \
#  2>&1 | tee "/var/log/mimir/mimir-${target}${suffix}.log";
#     # > /logpipe;

# # -querier.scheduler-address="mimir-${query_scheduler}:3201" \
# # -ingester.ring.tokens-file-path \
# # -alertmanager-storage.local.path \
# # -store-gateway.sharding-ring.tokens-file-path
